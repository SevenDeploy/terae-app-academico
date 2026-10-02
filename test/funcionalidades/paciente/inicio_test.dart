import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

Future<void> _abrirMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('menu-inicio')));
  await tester.pumpAndSettle();
}

void main() {
  group('TM02 Início (RFM02)', () {
    testWidgets('saudação, próxima consulta, atalho e receita só leitura', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester);
      expect(find.byKey(const Key('TM02')), findsOneWidget);

      expect(find.text('Sexta-feira, 2 de outubro'), findsOneWidget);
      expect(find.text('Olá, Ana'), findsOneWidget);
      expect(find.byKey(const Key('atalho-diario')), findsOneWidget);

      final consulta = find.byKey(const Key('proxima-consulta'));
      for (final texto in [
        'Dra. Helena Prado',
        'Quarta-feira, 7 de outubro às 14:00',
        'Em 5 dias',
      ]) {
        expect(
          find.descendant(of: consulta, matching: find.text(texto)),
          findsOneWidget,
          reason: texto,
        );
      }

      final receita = find.byKey(const Key('orientacao-vigente'));
      for (final texto in [
        'Tome 1 comprimido de manhã, depois do café.',
        'Sertralina',
        '50 mg, 1 comprimido',
        '08:00',
        'Receita válida até 31/10/2026.',
      ]) {
        expect(
          find.descendant(of: receita, matching: find.text(texto)),
          findsOneWidget,
          reason: texto,
        );
      }
      // Só leitura: nenhum campo nem botão dentro da receita.
      expect(
        find.descendant(of: receita, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(
        find.descendant(of: receita, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );

      expect(
        find.text('Peça a renovação da sua receita em 6 dias'),
        findsOneWidget,
      );
    });

    testWidgets('sem consulta nem receita, diz isso em linguagem simples', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester, paciente: PacienteComDados());
      expect(find.textContaining('Nenhuma consulta marcada'), findsOneWidget);
      expect(find.text('Nenhuma receita em uso no momento.'), findsOneWidget);
      expect(find.byKey(const Key('lembrete-renovacao')), findsNothing);
    });

    testWidgets('falha ao carregar oferece "Tentar de novo"', (tester) async {
      final paciente = PacienteComDados.completo()..falhar = true;
      await abrirAppDoPaciente(tester, paciente: paciente);
      expect(find.text('Tentar de novo'), findsOneWidget);
      // O atalho ao diário não depende da leitura.
      expect(find.byKey(const Key('atalho-diario')), findsOneWidget);

      paciente.falhar = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('Dra. Helena Prado'), findsOneWidget);
    });

    testWidgets('o atalho abre o diário com um toque', (tester) async {
      await abrirAppDoPaciente(tester);
      await tester.tap(find.byKey(const Key('atalho-diario')));
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteDiario);
      expect(find.byKey(const Key('TM03')), findsOneWidget);
    });
  });

  group('menu da TM02 (§21)', () {
    testWidgets('conta de um perfil: só "Sair", que leva à TM00', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(tester);
      await _abrirMenu(tester);
      expect(find.byKey(const Key('menu-trocar-perfil')), findsNothing);
      await tester.tap(find.byKey(const Key('menu-sair')));
      await tester.pumpAndSettle();
      expect(app.sessao.autenticada, isFalse);
      expect(localDe(tester), Rotas.boasVindas);
      expect(find.byKey(const Key('TM00')), findsOneWidget);
    });

    testWidgets('vários perfis: "Trocar perfil" reabre a seleção', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosPatricia());
      sessao.escolherPerfil(
        sessao.perfis.firstWhere((p) => p.paciente.id == 'p-miguel'),
      );
      await abrirAppDoPaciente(tester, sessao: sessao);
      // Saudação a quem usa o app, e de quem é o perfil.
      expect(find.text('Olá, Patrícia'), findsOneWidget);
      expect(find.text('Perfil de Miguel Andrade Neves'), findsOneWidget);

      await _abrirMenu(tester);
      await tester.tap(find.byKey(const Key('menu-trocar-perfil')));
      await tester.pumpAndSettle();
      expect(sessao.perfilAtivo, isNull);
      expect(localDe(tester), Rotas.entrarPerfil);
    });
  });
}
