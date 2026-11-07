/// Regras puras do programa em casa (evolução de TO, F1; D26).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/ocupacao.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/atividade_de_casa.dart';
import 'package:terae_app/dados/modelos/registro_de_atividade.dart';
import 'package:terae_app/dados/regras/programa_em_casa.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

final DataCivil _hoje = DataCivil(2026, 10, 2);

AtividadeDeCasa _atividade(
  String id, {
  int publicadaHaDias = 10,
  int? encerradaHaDias,
  int vezes = 3,
}) {
  final publicada = _hoje.somarDias(-publicadaHaDias);
  final encerrada = encerradaHaDias == null
      ? null
      : _hoje.somarDias(-encerradaHaDias);
  return AtividadeDeCasa(
    id: id,
    pacienteId: 'p',
    profissionalId: 'pr',
    titulo: 'Atividade $id',
    texto: 'Faça assim.',
    vezesPorSemana: vezes,
    ocupacao: Ocupacao.brincar,
    publicadaEm: instanteNaClinica(
      publicada.ano,
      publicada.mes,
      publicada.dia,
      9,
    ),
    encerradaEm: encerrada == null
        ? null
        : instanteNaClinica(encerrada.ano, encerrada.mes, encerrada.dia, 9),
  );
}

int _seq = 0;

RegistroDeAtividade _registro(
  String atividadeId,
  int haDias,
  AdesaoEmCasa adesao, {
  bool desfeito = false,
}) {
  final dia = _hoje.somarDias(-haDias);
  final em = instanteNaClinica(dia.ano, dia.mes, dia.dia, 19);
  return RegistroDeAtividade(
    id: 'r${++_seq}',
    pacienteId: 'p',
    atividadeId: atividadeId,
    dia: dia,
    adesao: adesao,
    quem: QuemRegistrou.responsavel,
    registradoEm: em,
    situacaoEnvio: SituacaoEnvio.enviado,
    excluidoEm: desfeito ? em : null,
  );
}

void main() {
  group('atividades vigentes', () {
    test('publicada até hoje e não encerrada; na ordem da publicação', () {
      final antiga = _atividade('a', publicadaHaDias: 20);
      final nova = _atividade('b', publicadaHaDias: 2);
      final futura = _atividade('c', publicadaHaDias: -1);
      final encerrada = _atividade('d', encerradaHaDias: 1);
      final encerraHoje = _atividade('e', encerradaHaDias: 0);
      expect(
        atividadesVigentes([
          nova,
          futura,
          encerrada,
          antiga,
          encerraHoje,
        ], _hoje).map((a) => a.id),
        ['a', 'b'],
      );
    });
  });

  group('registro do dia (D26)', () {
    test('acha o que vale e ignora o desfeito; reaproveita até o desfeito', () {
      final desfeito = _registro('a', 0, AdesaoEmCasa.feito, desfeito: true);
      final ontem = _registro('a', 1, AdesaoEmCasa.emParte);
      expect(registroDoDia([desfeito, ontem], 'a', _hoje), isNull);
      expect(registroParaReaproveitar([desfeito, ontem], 'a', _hoje), desfeito);
      expect(registroDoDia([desfeito, ontem], 'a', _hoje.somarDias(-1)), ontem);
      expect(registroDoDia([ontem], 'b', _hoje.somarDias(-1)), isNull);
    });

    test('só se corrige ou desfaz no mesmo dia, e o que ainda vale', () {
      expect(
        podeAlterarRegistro(_registro('a', 0, AdesaoEmCasa.feito), _hoje),
        isTrue,
      );
      expect(
        podeAlterarRegistro(_registro('a', 1, AdesaoEmCasa.feito), _hoje),
        isFalse,
      );
      expect(
        podeAlterarRegistro(
          _registro('a', 0, AdesaoEmCasa.feito, desfeito: true),
          _hoje,
        ),
        isFalse,
      );
    });
  });

  group('dois registros do mesmo dia, de aparelhos diferentes (D31)', () {
    RegistroDeAtividade com(
      int hora,
      AdesaoEmCasa adesao, {
      bool desfeito = false,
    }) {
      final em = instanteNaClinica(_hoje.ano, _hoje.mes, _hoje.dia, hora);
      return RegistroDeAtividade(
        id: 'r$hora',
        pacienteId: 'p',
        atividadeId: 'a',
        dia: _hoje,
        adesao: adesao,
        quem: QuemRegistrou.responsavel,
        registradoEm: em,
        situacaoEnvio: SituacaoEnvio.enviado,
        excluidoEm: desfeito ? em : null,
      );
    }

    test('vale o mais recente, em qualquer ordem, e é ele que se corrige, '
        'que a faixa mostra e que a semana conta', () {
      final cedo = com(8, AdesaoEmCasa.feito);
      final tarde = com(20, AdesaoEmCasa.naoFeito);
      for (final ordem in [
        [cedo, tarde],
        [tarde, cedo],
      ]) {
        expect(registroDoDia(ordem, 'a', _hoje), tarde);
        expect(registroParaReaproveitar(ordem, 'a', _hoje), tarde);
        expect(
          faixaDeDias(ordem, _hoje, atividadeId: 'a').last.adesao,
          AdesaoEmCasa.naoFeito,
        );
        expect(vezesNaSemana(ordem, 'a', _hoje), 0);
      }
    });

    test('um desfeito mais novo não esconde o que ainda vale', () {
      final vale = com(8, AdesaoEmCasa.emParte);
      final desfeito = com(20, AdesaoEmCasa.feito, desfeito: true);
      expect(registroParaReaproveitar([desfeito, vale], 'a', _hoje), vale);
      expect(registroDoDia([desfeito, vale], 'a', _hoje), vale);
    });
  });

  group('vezes na semana', () {
    test('conta os dias dos últimos 7 com "sim" ou "em parte"', () {
      final registros = [
        _registro('a', 0, AdesaoEmCasa.feito),
        _registro('a', 2, AdesaoEmCasa.emParte),
        _registro('a', 3, AdesaoEmCasa.naoFeito),
        _registro('a', 6, AdesaoEmCasa.feito),
        _registro('a', 7, AdesaoEmCasa.feito), // fora da semana
        _registro('a', 4, AdesaoEmCasa.feito, desfeito: true),
        _registro('b', 1, AdesaoEmCasa.feito), // outra atividade
      ];
      expect(vezesNaSemana(registros, 'a', _hoje), 3);
      expect(vezesNaSemana(registros, 'b', _hoje), 1);
    });
  });

  group('faixa de 14 dias', () {
    test('do mais antigo a hoje; com a atividade, a resposta dela', () {
      final registros = [
        _registro('a', 0, AdesaoEmCasa.naoFeito),
        _registro('a', 13, AdesaoEmCasa.feito),
        _registro('a', 14, AdesaoEmCasa.feito), // fora
        _registro('b', 0, AdesaoEmCasa.emParte),
      ];
      final faixa = faixaDeDias(registros, _hoje, atividadeId: 'a');
      expect(faixa, hasLength(diasDaFaixa));
      expect(faixa.first, DiaDaFaixa(_hoje.somarDias(-13), AdesaoEmCasa.feito));
      expect(faixa.last, DiaDaFaixa(_hoje, AdesaoEmCasa.naoFeito));
      expect(faixa.where((d) => d.adesao != null), hasLength(2));
    });

    test('sem atividade, a melhor resposta do dia entre todas', () {
      final registros = [
        _registro('a', 0, AdesaoEmCasa.naoFeito),
        _registro('b', 0, AdesaoEmCasa.emParte),
        _registro('a', 1, AdesaoEmCasa.naoFeito),
        _registro('b', 1, AdesaoEmCasa.feito, desfeito: true),
      ];
      final faixa = faixaDeDias(registros, _hoje);
      expect(faixa.last.adesao, AdesaoEmCasa.emParte);
      expect(faixa[faixa.length - 2].adesao, AdesaoEmCasa.naoFeito);
    });
  });

  test('resumo de hoje: qualquer resposta conta como registrada', () {
    final a = _atividade('a');
    final b = _atividade('b');
    final encerrada = _atividade('c', encerradaHaDias: 1);
    final registros = [
      _registro('a', 0, AdesaoEmCasa.naoFeito),
      _registro('c', 0, AdesaoEmCasa.feito),
      _registro('b', 1, AdesaoEmCasa.feito),
    ];
    expect(resumoDeHoje([a, b, encerrada], registros, _hoje), (
      registradas: 1,
      total: 2,
    ));
  });

  group('modelos (invariantes)', () {
    test('reflexão em branco vira nula; longa demais é recusada', () {
      expect(_registroCom(reflexao: '   ').reflexao, isNull);
      expect(_registroCom(reflexao: ' Bom dia. ').reflexao, 'Bom dia.');
      expect(() => _registroCom(reflexao: 'x' * 501), throwsArgumentError);
    });

    test('atividade: título, texto e vezes por semana dentro dos limites', () {
      expect(() => _atividade('a', vezes: 0), throwsArgumentError);
      expect(() => _atividade('a', vezes: 8), throwsArgumentError);
      expect(
        () => AtividadeDeCasa(
          id: 'a',
          pacienteId: 'p',
          profissionalId: 'pr',
          titulo: ' ',
          texto: '',
          vezesPorSemana: 1,
          ocupacao: Ocupacao.lazer,
          publicadaEm: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });

    test('corrigir no mesmo dia volta a valer e vai para a fila', () {
      final desfeito = _registro('a', 0, AdesaoEmCasa.feito, desfeito: true);
      final em = DateTime.utc(2026, 10, 2, 23);
      final corrigido = desfeito.corrigido(
        adesao: AdesaoEmCasa.emParte,
        reflexao: 'Só um pouco.',
        quem: QuemRegistrou.responsavel,
        em: em,
      );
      expect(corrigido.id, desfeito.id);
      expect(corrigido.excluido, isFalse);
      expect(corrigido.situacaoEnvio, SituacaoEnvio.naFila);
      expect(corrigido.atualizadoEm, em);
      expect(corrigido.dia, desfeito.dia);
    });
  });
}

RegistroDeAtividade _registroCom({String? reflexao}) => RegistroDeAtividade(
  id: 'x',
  pacienteId: 'p',
  atividadeId: 'a',
  dia: _hoje,
  adesao: AdesaoEmCasa.feito,
  reflexao: reflexao,
  quem: QuemRegistrou.paciente,
  registradoEm: DateTime.utc(2026, 10, 2, 12),
  situacaoEnvio: SituacaoEnvio.naFila,
);
