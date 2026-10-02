import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/memoria/regras.dart';

void main() {
  group('regraDoAlerta (§7.1)', () {
    test('(a) crítica dispara mesmo sem histórico', () {
      expect(
        regraDoAlerta(nova: Intensidade.critica, anterior: null),
        RegraAlerta.intensidadeCritica,
      );
      for (final anterior in Intensidade.values) {
        expect(
          regraDoAlerta(nova: Intensidade.critica, anterior: anterior),
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
        Intensidade.moderada,
        Intensidade.critica,
      ]) {
        expect(
          regraDoAlerta(nova: Intensidade.grave, anterior: anterior),
          isNull,
          reason: 'anterior $anterior',
        );
      }
    });

    test('leve e moderada nunca disparam', () {
      for (final nova in [Intensidade.leve, Intensidade.moderada]) {
        for (final anterior in [null, ...Intensidade.values]) {
          expect(regraDoAlerta(nova: nova, anterior: anterior), isNull);
        }
      }
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
