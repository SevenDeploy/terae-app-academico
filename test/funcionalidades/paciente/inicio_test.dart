import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

/// Abre a aba Conta (TM21), onde ficou o antigo menu do Início.
Future<void> _abrirConta(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('aba-conta')));
  await tester.pumpAndSettle();
}

/// Rola a TM21 (lista preguiçosa) até [chave] aparecer.
Future<void> _rolarAte(WidgetTester tester, String chave) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(chave)),
    120,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('TM21')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
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
      // A saudação do portal ("Bom dia, Ana.") pela hora do relógio.
      expect(
        find.textContaining(RegExp(r'^(Bom dia|Boa tarde|Boa noite), Ana\.$')),
        findsOneWidget,
      );
      // D24: a titular lê sobre si.
      expect(find.text('Como foi o seu dia?'), findsOneWidget);
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
      await tester.ensureVisible(find.byKey(const Key('atalho-diario')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('atalho-diario')));
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteDiario);
      expect(find.byKey(const Key('TM03')), findsOneWidget);
    });
  });

  group('aba Conta (TM21; §21)', () {
    testWidgets('"Cuidadores que você autorizou" abre a TM07 empilhada; '
        'voltar leva ao Início (D22)', (tester) async {
      await abrirAppDoPaciente(tester);
      await _abrirConta(tester);
      await _rolarAte(tester, 'conta-cuidadores');
      await tester.tap(find.byKey(const Key('conta-cuidadores')));
      await tester.pumpAndSettle();
      // `push` empilha sem trocar o local da configuração do go_router: a
      // prova é a TM07 na tela.
      expect(find.byKey(const Key('TM07')), findsOneWidget);
      expect(find.byKey(const Key('TM02')), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteInicio);
      expect(find.byKey(const Key('TM02')), findsOneWidget);
    });

    testWidgets('conta de um perfil: seus dados, lembretes, cuidadores e '
        '"Sair", que leva à TM00', (tester) async {
      final app = await abrirAppDoPaciente(tester);
      expect(find.byKey(const Key('seletor-de-paciente')), findsNothing);
      await _abrirConta(tester);
      expect(find.byKey(const Key('TM21')), findsOneWidget);
      expect(find.byKey(const Key('conta-seus-dados')), findsOneWidget);
      expect(find.text('Seus dados'), findsOneWidget);
      await _rolarAte(tester, 'conta-lembretes');
      await _rolarAte(tester, 'conta-cuidadores');
      await _rolarAte(tester, 'conta-sair');
      await tester.tap(find.byKey(const Key('conta-sair')));
      await tester.pumpAndSettle();
      expect(app.sessao.autenticada, isFalse);
      expect(localDe(tester), Rotas.boasVindas);
      expect(find.byKey(const Key('TM00')), findsOneWidget);
    });

    testWidgets('vários perfis: "Quem você acompanha" troca o paciente', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosPatricia());
      sessao.escolherPerfil(
        sessao.perfis.firstWhere((p) => p.paciente.id == 'p-miguel'),
      );
      await abrirAppDoPaciente(tester, sessao: sessao);
      // Saudação a quem usa o app, e de quem é o perfil.
      expect(find.textContaining(', Patrícia.'), findsOneWidget);
      expect(find.text('Perfil de Miguel Andrade Neves'), findsOneWidget);
      // D24: a responsável lê sobre o filho; D21: só TO, sem remédios.
      expect(find.text('Como foi o dia de Miguel?'), findsOneWidget);
      expect(find.byKey(const Key('orientacao-vigente')), findsNothing);
      expect(find.byKey(const Key('lembrete-renovacao')), findsNothing);
      expect(find.byKey(const Key('proxima-consulta')), findsOneWidget);
      expect(find.byKey(const Key('atalho-diario')), findsOneWidget);

      // O topo mostra o paciente e, com vários perfis, abre a folha.
      expect(find.byKey(const Key('seletor-de-paciente')), findsOneWidget);
      await _abrirConta(tester);
      final laura = sessao.perfis.firstWhere((p) => p.paciente.id == 'p-laura');
      await tester.tap(find.byKey(Key('conta-perfil-${laura.chave}')));
      await tester.pumpAndSettle();
      expect(sessao.perfilAtivo, laura);
      expect(find.text('Laura Andrade Neves'), findsWidgets);
    });
  });
}
