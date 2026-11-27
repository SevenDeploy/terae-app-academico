/// O cuidador no Terae local (portal da família, quadro 18j): o Início é o da
/// família (programa de hoje primeiro, diário bloqueado) e a moldura ganha a
/// aba "Em casa" com "Registrar o de hoje". No Firebase (D29) a TM08 segue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/linha_de_cuidado.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/roteador.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../apoio/dubles.dart';

/// Cuidadora de uma criança só de TO, como a avó Rosa no Terae local.
Sessao _cuidadoraDeTo() => Sessao()
  ..entrar(
    VinculosDaConta(
      conta: contaDe('c-rosa', 'Rosa Souza'),
      acompanhados: [
        pacienteDe(
          'p-alice',
          'Alice Souza',
          linhas: soTerapiaOcupacional,
        ).paraCuidador(),
      ],
    ),
  );

void main() {
  group('guardaDePerfil: o programa em casa do cuidador', () {
    test('sem a capacidade da fonte, /cuidador/casa volta ao Início', () {
      final sessao = _cuidadoraDeTo();
      for (final rota in Rotas.doProgramaDoCuidador) {
        expect(
          guardaDePerfil(sessao, rota),
          Rotas.cuidadorInicio,
          reason: rota,
        );
        expect(
          guardaDePerfil(sessao, rota, programaDoCuidador: true),
          isNull,
          reason: rota,
        );
      }
    });

    test('com a capacidade, sem terapia ocupacional ainda volta ao Início', () {
      final sessao = Sessao()
        ..entrar(
          VinculosDaConta(
            conta: contaDe('c-regina', 'Regina'),
            acompanhados: [
              pacienteDe('p-ana', 'Ana Lúcia Martins').paraCuidador(),
            ],
          ),
        );
      expect(
        sessao.perfilAtivo!.paciente.linhasDeCuidado,
        isNot(contains(LinhaDeCuidado.terapiaOcupacional)),
      );
      expect(
        guardaDePerfil(sessao, Rotas.cuidadorCasa, programaDoCuidador: true),
        Rotas.cuidadorInicio,
      );
    });

    test('o paciente nunca alcança as rotas do cuidador', () {
      final paciente = Sessao()..entrar(vinculosAntonio());
      for (final rota in Rotas.doProgramaDoCuidador) {
        expect(
          guardaDePerfil(paciente, rota, programaDoCuidador: true),
          Rotas.pacienteInicio,
          reason: rota,
        );
      }
    });

    test('o cuidador nunca alcança o diário nem as rotas do paciente', () {
      final sessao = _cuidadoraDeTo();
      for (final rota in [
        Rotas.pacienteDiario,
        Rotas.pacienteNovoRegistro,
        Rotas.pacienteCasa,
        Rotas.pacienteAtividade,
      ]) {
        expect(
          guardaDePerfil(sessao, rota, programaDoCuidador: true),
          Rotas.cuidadorInicio,
          reason: rota,
        );
      }
    });
  });

  group('Início e moldura do cuidador com a fonte Terae local', () {
    testWidgets('Início da família: programa primeiro, diário bloqueado, '
        'sem botões de presença e "Registrar o de hoje"', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.regina,
        em: Rotas.cuidadorInicio,
        capacidades: CapacidadesDaFonte.teraeLocal,
      );
      expect(find.byKey(const Key('TM02')), findsOneWidget);
      expect(find.byKey(const Key('faixa-modo-cuidador')), findsOneWidget);
      // Com o programa na fonte, a faixa diz o que o cuidador vê, como o portal.
      expect(
        find.textContaining('programa em casa e a agenda de'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('diario-fora-do-acesso')), findsOneWidget);
      expect(find.byKey(const Key('cartao-diario')), findsNothing);
      expect(find.byKey(const Key('atalho-diario')), findsNothing);
      expect(find.text('Registrar o de hoje'), findsOneWidget);
      // O cuidador não responde a presença: nada de Confirmar/Avisar.
      expect(find.text('Confirmar presença'), findsNothing);
      expect(find.text('Avisar que não vamos'), findsNothing);
      // O programa vem antes da sessão (18j).
      final programa = tester.getTopLeft(
        find.byKey(const Key('atalho-em-casa')),
      );
      final sessao = tester.getTopLeft(
        find.byKey(const Key('proxima-consulta')),
      );
      expect(programa.dy, lessThan(sessao.dy));
      // As abas: Início, Em casa, Agenda e Conta (nunca o Diário).
      expect(find.byKey(const Key('aba-casa')), findsOneWidget);
      expect(find.byKey(const Key('aba-diario')), findsNothing);
    });

    testWidgets('"Registrar o de hoje" abre o Em casa do cuidador e a '
        'atividade empilha e volta', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.regina,
        em: Rotas.cuidadorInicio,
        capacidades: CapacidadesDaFonte.teraeLocal,
      );
      await tocar(tester, find.byKey(const Key('abrir-programa-em-casa')));
      expect(find.byKey(const Key('TM16')), findsOneWidget);
      final primeira = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('atividade-'),
      );
      await tocar(tester, primeira.first);
      expect(find.byKey(const Key('TM17')), findsOneWidget);
      await tocar(tester, find.byType(BackButton));
      expect(find.byKey(const Key('TM16')), findsOneWidget);
    });

    testWidgets('no Firebase a TM08 continua e não há aba Em casa; o link '
        'direto volta ao Início', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.regina,
        em: Rotas.cuidadorCasa,
      );
      expect(find.byKey(const Key('TM08')), findsOneWidget);
      expect(find.byKey(const Key('aba-casa')), findsNothing);
      expect(find.byKey(const Key('TM16')), findsNothing);
    });
  });
}
