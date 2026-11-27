import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/regras.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/regras/diario.dart';

void main() {
  group('regraDoAlerta (§7.1)', () {
    test('(a) crítica dispara mesmo sem histórico', () {
      expect(
        regraDoAlerta(nova: Intensidade.critico, anterior: null),
        RegraAlerta.intensidadeCritica,
      );
      for (final anterior in Intensidade.values) {
        expect(
          regraDoAlerta(nova: Intensidade.critico, anterior: anterior),
          RegraAlerta.intensidadeCritica,
        );
      }
    });

    test('(b) grave depois de grave dispara grave consecutivo', () {
      expect(
        regraDoAlerta(nova: Intensidade.grave, anterior: Intensidade.grave),
        RegraAlerta.graveConsecutivo,
      );
    });

    test('grave isolado não dispara (anterior não grave ou ausente)', () {
      for (final anterior in [
        null,
        Intensidade.leve,
        Intensidade.moderado,
        Intensidade.critico,
      ]) {
        expect(
          regraDoAlerta(nova: Intensidade.grave, anterior: anterior),
          isNull,
          reason: 'anterior $anterior',
        );
      }
    });

    test('leve, moderado e sem resposta (P3: a pergunta é opcional) nunca '
        'disparam', () {
      for (final nova in [null, Intensidade.leve, Intensidade.moderado]) {
        for (final anterior in [null, ...Intensidade.values]) {
          expect(regraDoAlerta(nova: nova, anterior: anterior), isNull);
        }
      }
    });
  });

  group('regras do diário (P3, D17 revista)', () {
    final antes = DateTime.utc(2026, 11, 20, 22);
    RegistroDiario registro({
      SituacaoEnvio situacao = SituacaoEnvio.enviado,
      DateTime? enviadoEm,
      bool alertou = false,
      DateTime? revisadoEm,
      DateTime? retiradoEm,
      String id = 'r',
    }) => RegistroDiario(
      id: id,
      pacienteId: 'p',
      registradoEm: antes,
      adesao: Adesao.total,
      situacaoEnvio: situacao,
      enviadoEm: enviadoEm,
      alertouAEquipe: alertou,
      revisadoEm: revisadoEm,
      retiradoEm: retiradoEm,
      motivoDaRetirada: retiradoEm == null
          ? null
          : RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado),
    );

    test('pode mudar só o que chegou, sem revisão, retirada nem alerta — '
        'em qualquer dia', () {
      expect(podeAlterar(registro(enviadoEm: antes)), isTrue);
      expect(podeAlterar(registro(situacao: SituacaoEnvio.naFila)), isFalse);
      expect(podeAlterar(registro(alertou: true)), isFalse);
      expect(podeAlterar(registro(revisadoEm: antes)), isFalse);
      expect(podeAlterar(registro(retiradoEm: antes)), isFalse);
    });

    test('"Escrito em…, enviado em…" só quando esperou mais de 5 minutos', () {
      expect(esperouNaFila(registro(enviadoEm: antes)), isFalse);
      expect(
        esperouNaFila(
          registro(enviadoEm: antes.add(const Duration(minutes: 5))),
        ),
        isFalse,
      );
      expect(
        esperouNaFila(
          registro(enviadoEm: antes.add(const Duration(minutes: 6))),
        ),
        isTrue,
      );
      expect(esperouNaFila(registro(situacao: SituacaoEnvio.naFila)), isFalse);
    });

    test('a lista vai do mais novo ao mais antigo pelo recebimento, com o id '
        'no empate', () {
      final a = registro(id: 'a', enviadoEm: antes);
      final b = registro(id: 'b', enviadoEm: antes);
      final c = registro(
        id: 'c',
        enviadoEm: antes.add(const Duration(days: 1)),
      );
      final lista = [a, c, b]..sort(maisNovoPrimeiro);
      expect([for (final r in lista) r.id], ['c', 'b', 'a']);
      expect(momentoNaLista(registro(situacao: SituacaoEnvio.naFila)), antes);
    });
  });

  group('código de convite (RFM09)', () {
    test('normaliza o que a pessoa digitou', () {
      expect(normalizarCodigo(' p4x-9rc '), 'P4X9RC');
      expect(normalizarCodigo('p4x.9rc'), 'P4X9RC');
    });

    test('gera seis caracteres do alfabeto sem ambíguos', () {
      final aleatorio = Random(7);
      for (var i = 0; i < 200; i++) {
        final codigo = gerarCodigoConvite(aleatorio);
        expect(codigoBemFormado(codigo), isTrue, reason: codigo);
        expect(codigo, isNot(matches(RegExp('[01OIL]'))));
      }
    });

    test('não repete um código existente', () {
      final primeiro = gerarCodigoConvite(Random(42));
      final segundo = gerarCodigoConvite(Random(42), existentes: {primeiro});
      expect(segundo, isNot(primeiro));
      expect(codigoBemFormado(segundo), isTrue);
    });

    test('forma do código', () {
      expect(codigoBemFormado('P4X9RC'), isTrue);
      expect(codigoBemFormado('P4X9R'), isFalse);
      expect(codigoBemFormado('P4X9R0'), isFalse);
      expect(codigoBemFormado('p4x9rc'), isFalse);
    });
  });

  test('ordenar é estável: empate fica na ordem de criação', () {
    final itens = [(1, 'a'), (0, 'b'), (1, 'c'), (0, 'd'), (1, 'e')];
    final ordenados = ordenar(itens, (x, y) => x.$1.compareTo(y.$1));
    expect([for (final i in ordenados) i.$2], ['b', 'd', 'a', 'c', 'e']);
    expect(itens.first, (1, 'a'), reason: 'não muda a entrada');
  });
}
