import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import 'apoio_paciente.dart';

/// Ordem vertical dos textos na tela.
List<String> _ordem(WidgetTester tester, Finder dentro, List<String> textos) {
  final posicoes = {
    for (final t in textos)
      t: tester
          .getTopLeft(find.descendant(of: dentro, matching: find.text(t)))
          .dy,
  };
  return [...textos]..sort((a, b) => posicoes[a]!.compareTo(posicoes[b]!));
}

void main() {
  group('TM06 Jornada (RFM06)', () {
    testWidgets('orientação vigente, próximos passos e história', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteJornada);
      expect(find.byKey(const Key('TM06')), findsOneWidget);

      final orientacao = find.byKey(const Key('orientacao-agora'));
      expect(
        find.descendant(
          of: orientacao,
          matching: find.text('Tome 1 comprimido de manhã, depois do café.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: orientacao,
          matching: find.text('Peça a renovação da receita até 08/10/2026.'),
        ),
        findsOneWidget,
      );

      // Próximos: consulta marcada e o marco à frente, do mais perto.
      final proximos = find.byKey(const Key('proximos'));
      expect(
        _ordem(tester, proximos, [
          'Nova avaliação',
          'Consulta com Dra. Helena Prado',
        ]),
        ['Consulta com Dra. Helena Prado', 'Nova avaliação'],
      );
      expect(
        find.descendant(
          of: proximos,
          matching: find.text(
            'Quarta-feira, 7 de outubro às 14:00 · em 5 dias',
          ),
        ),
        findsOneWidget,
      );

      // História: do mais recente ao mais antigo, com a situação da consulta.
      final historia = find.byKey(const Key('historia'));
      expect(
        _ordem(tester, historia, ['Primeira avaliação', 'Rotina de sono']),
        ['Rotina de sono', 'Primeira avaliação'],
      );
      expect(
        find.descendant(of: historia, matching: find.text('Cancelada')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: historia, matching: find.text('Realizada')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: historia,
          matching: find.text('Deitar no mesmo horário ajuda a dormir melhor.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem nada ainda, mostra o começo da jornada', (tester) async {
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteJornada,
        paciente: PacienteComDados(
          consultas: const [],
          marcosDaJornada: const [],
        ),
      );
      expect(find.textContaining('Sua jornada começa agora'), findsOneWidget);
    });

    testWidgets('falha ao carregar oferece "Tentar de novo"', (tester) async {
      final paciente = PacienteComDados.completo()..falhar = true;
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteJornada,
        paciente: paciente,
      );
      expect(find.text('Tentar de novo'), findsOneWidget);
      paciente.falhar = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proximos')), findsOneWidget);
    });
  });
}
