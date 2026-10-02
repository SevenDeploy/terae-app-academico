import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/funcionalidades/paciente/diario/diario_controlador.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/uuid.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

/// Só a tela [tela] entre as do paciente está montada.
void _naTela(String tela) {
  // As abas ficam montadas (IndexedStack); só TM04/TM05 saem de verdade.
  expect(find.byKey(Key(tela)), findsOneWidget, reason: 'esperava $tela');
  for (final cheia in ['TM04', 'TM05']) {
    if (cheia != tela) {
      expect(find.byKey(Key(cheia)), findsNothing, reason: '$cheia aberta');
    }
  }
}

/// A opção [texto] do seletor está marcada (semântica `selected`)?
Matcher _marcada({required bool sim}) => isSemantics(
  isButton: true,
  isInMutuallyExclusiveGroup: true,
  hasSelectedState: true,
  isSelected: sim,
);

void main() {
  group('TM03 → TM04 em até cinco toques (§12, RNFM02)', () {
    testWidgets('do Início ao diário enviado, contando os toques', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(tester);
      final toques = ContadorDeToques(tester);
      _naTela('TM02');

      await toques.tocar(find.byKey(const Key('atalho-diario')));
      expect(toques.total, lessThanOrEqualTo(2), reason: '§12: até 2 toques');
      expect(localDe(tester), Rotas.pacienteDiario);

      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);

      expect(toques.total, lessThanOrEqualTo(5));
      _naTela('TM04');
      expect(find.text('Registro enviado!'), findsOneWidget);

      final registro = app.diario.enviados.single;
      expect(uuidV4Valido(registro.id), isTrue, reason: 'UUID do aparelho');
      expect(registro.pacienteId, 'p-ana');
      expect(registro.registradoEm, agoraDeTeste);
      expect(registro.adesao, Adesao.total);
      expect(registro.intensidade, Intensidade.leve);
      expect(registro.sintomaPredominante, 'Cansaço');
      expect(registro.observacao, isNull, reason: 'observação é opcional');
      expect(registro.situacaoEnvio, SituacaoEnvio.naFila);

      // Resumo do que foi enviado, com o nome da intensidade (não só cor).
      final resumo = find.byKey(const Key('resumo-envio'));
      for (final texto in ['Tomei tudo', 'Leve', 'Cansaço']) {
        expect(
          find.descendant(of: resumo, matching: find.text(texto)),
          findsOneWidget,
        );
      }
    });

    testWidgets('pela aba também é um toque até o diário', (tester) async {
      await abrirAppDoPaciente(tester);
      await tester.tap(find.byKey(const Key('aba-diario')));
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteDiario);
    });

    testWidgets('sem as três escolhas, Enviar fica desabilitado', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      expect(
        tester.widget<FilledButton>(_filledDe(botaoEnviar)).enabled,
        false,
      );
      await toques.tocar(find.text('Tomei tudo'));
      await toques.tocar(find.text('Leve'));
      expect(find.text('Para enviar, escolha o sintoma.'), findsOneWidget);
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(app.diario.enviados, isEmpty);
    });

    testWidgets('a observação opcional vai no registro', (tester) async {
      final app = await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await tester.enterText(
        find.byKey(const Key('campo-observacao')),
        '  Dormi pouco.  ',
      );
      await toques.tocar(botaoEnviar);
      expect(app.diario.enviados.single.observacao, 'Dormi pouco.');
      expect(find.text('Dormi pouco.'), findsOneWidget, reason: 'no resumo');
    });

    testWidgets('cada registro ganha um UUID novo', (tester) async {
      final app = await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      for (var i = 0; i < 2; i++) {
        await preencherDiario(toques);
        await toques.tocar(botaoEnviar);
        await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
        await toques.tocar(find.byKey(const Key('aba-diario')));
      }
      final ids = app.diario.enviados.map((r) => r.id).toList();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
    });

    testWidgets('dois toques em Enviar mandam um registro só', (tester) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.tap(botaoEnviar, warnIfMissed: false);
      await tester.pump();
      expect(app.diario.enviados, hasLength(1));
      expect(find.text('Enviando…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_filledDe(botaoEnviar)).enabled,
        false,
      );

      app.diario.responder();
      await tester.pumpAndSettle();
      _naTela('TM04');
      expect(app.diario.enviados, hasLength(1));
    });

    testWidgets('falha inesperada mantém o preenchimento e explica', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.falha),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      _naTela('TM03');
      expect(
        find.textContaining('Não foi possível guardar seu registro'),
        findsOneWidget,
      );
      expect(app.diario.enviados, hasLength(1));
      expect(tester.getSemantics(find.text('Cansaço')), _marcada(sim: true));
      semantica.dispose();
    });
  });

  group('crítica → TM05 sem esperar a rede (RFM04, §7.1)', () {
    testWidgets('abre a TM05 na hora mesmo com envio lento', (tester) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: 'Crítica');
      await toques.tocar(botaoEnviar);

      _naTela('TM05');
      expect(localDe(tester), Rotas.pacienteDiarioAjuda);
      expect(find.byKey(const Key('ligar-188')), findsOneWidget);
      expect(find.byKey(const Key('ligar-192')), findsOneWidget);
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);

      // A resposta chega depois: só então "avisado".
      app.diario.responder();
      await tester.pumpAndSettle();
      expect(find.text('Seu profissional foi avisado.'), findsOneWidget);
      expect(
        find.text('O aviso chegou para Dra. Helena Prado.'),
        findsOneWidget,
      );
      expect(find.text('Envio pendente'), findsNothing);
    });

    testWidgets('sem conexão: envio pendente, nunca "avisado"', (tester) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.semConexao),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: 'Crítica');
      await toques.tocar(botaoEnviar);

      _naTela('TM05');
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(find.textContaining('quando houver conexão'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);
      expect(app.diario.enviados.single.intensidade, Intensidade.critica);

      // CVV com um toque.
      await tester.tap(find.byKey(const Key('ligar-188')));
      await tester.pump();
      expect(app.lancador.abertos, [Uri(scheme: 'tel', path: '188')]);
    });

    testWidgets('falha do envio crítico também fica pendente', (tester) async {
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.falha),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: 'Crítica');
      await toques.tocar(botaoEnviar);
      _naTela('TM05');
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);
      // Falha inesperada: não promete que ficou guardado.
      expect(find.textContaining('guardado'), findsNothing);
      expect(
        find.textContaining('Não conseguimos enviar seu registro'),
        findsOneWidget,
      );
    });

    testWidgets('"Ciente" leva ao Início', (tester) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: 'Crítica');
      await toques.tocar(botaoEnviar);
      expect(find.text('Seu profissional foi avisado.'), findsOneWidget);
      await toques.tocar(find.byKey(const Key('ciente')));
      expect(localDe(tester), Rotas.pacienteInicio);
      _naTela('TM02');
    });
  });

  group('TM04 sem conexão e volta automática (RFM05, §19, D10)', () {
    testWidgets(
      'na fila: "será enviado quando houver conexão", sem "avisado"',
      (tester) async {
        await abrirAppDoPaciente(
          tester,
          em: Rotas.pacienteDiario,
          diario: DiarioControlavel(ModoDoDiario.semConexao),
        );
        final toques = ContadorDeToques(tester);
        await preencherDiario(toques, intensidade: 'Grave');
        await toques.tocar(botaoEnviar);
        _naTela('TM04');
        expect(find.text('Registro guardado'), findsOneWidget);
        expect(find.textContaining('quando houver conexão'), findsOneWidget);
        expect(falaEmAvisado, findsNothing);
      },
    );

    testWidgets('envio lento abre a TM04 em 2 s e se atualiza depois', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(const Duration(milliseconds: 1900));
      _naTela('TM03');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      _naTela('TM04');
      expect(find.textContaining('quando houver conexão'), findsOneWidget);

      app.diario.responder();
      await tester.pump();
      expect(find.text('Registro enviado!'), findsOneWidget);
    });

    testWidgets('falha depois do prazo: TM04 não promete que ficou guardado', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(prazoDeResposta);
      await tester.pump();
      _naTela('TM04');

      app.diario.falharPendente();
      await tester.pump();
      expect(find.text('Registro não enviado'), findsOneWidget);
      expect(find.textContaining('guardado'), findsNothing);
      expect(falaEmAvisado, findsNothing);
    });

    testWidgets('volta sozinha ao Início em 3 s', (tester) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump();
      await tester.pump();
      _naTela('TM04');

      await tester.pump(const Duration(milliseconds: 2900));
      _naTela('TM04');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteInicio);
      _naTela('TM02');
    });

    testWidgets('com navegação acessível não volta sozinha (D10)', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      _naTela('TM04');

      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      _naTela('TM04');
      expect(find.textContaining('abre sozinha'), findsNothing);

      await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
      expect(localDe(tester), Rotas.pacienteInicio);
      _naTela('TM02');
    });
  });

  group('aba com estado e envio sem volta ao formulário (§21)', () {
    testWidgets('trocar de aba e voltar preserva o diário em preenchimento', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, adesao: 'Tomei uma parte');
      await tester.enterText(
        find.byKey(const Key('campo-observacao')),
        'Rascunho',
      );

      await toques.tocar(find.byKey(const Key('aba-jornada')));
      expect(localDe(tester), Rotas.pacienteJornada);
      await toques.tocar(find.byKey(const Key('aba-diario')));
      expect(localDe(tester), Rotas.pacienteDiario);

      expect(
        tester.getSemantics(find.text('Tomei uma parte')),
        _marcada(sim: true),
      );
      expect(
        tester.getSemantics(find.text('Tomei tudo')),
        _marcada(sim: false),
      );
      expect(tester.getSemantics(find.text('Leve')), _marcada(sim: true));
      expect(tester.getSemantics(find.text('Cansaço')), _marcada(sim: true));
      expect(find.text('Rascunho'), findsOneWidget);
      semantica.dispose();
    });

    for (final critica in [false, true]) {
      final saida = critica ? 'TM05' : 'TM04';
      testWidgets(
        'depois da $saida, voltar não reabre o formulário preenchido',
        (tester) async {
          final semantica = tester.ensureSemantics();
          await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
          final toques = ContadorDeToques(tester);
          await preencherDiario(
            toques,
            intensidade: critica ? 'Crítica' : 'Moderada',
          );
          await tester.enterText(
            find.byKey(const Key('campo-observacao')),
            'Texto enviado',
          );
          await toques.tocar(botaoEnviar);
          _naTela(saida);

          // Voltar do Android: Início, nunca o formulário.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(localDe(tester), Rotas.pacienteInicio);
          _naTela('TM02');

          await toques.tocar(find.byKey(const Key('aba-diario')));
          _naTela('TM03');
          for (final opcao in ['Tomei tudo', 'Leve', 'Crítica', 'Cansaço']) {
            expect(
              tester.getSemantics(find.text(opcao)),
              _marcada(sim: false),
              reason: opcao,
            );
          }
          expect(find.text('Texto enviado'), findsNothing);
          expect(
            tester.widget<FilledButton>(_filledDe(botaoEnviar)).enabled,
            false,
          );
          semantica.dispose();
        },
      );
    }
  });

  group('voltar do Android nas abas (§21)', () {
    testWidgets('no Diário volta ao Início; no Início fecha o app', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteInicio);
      expect(await tester.binding.handlePopRoute(), isFalse);
    });
  });
}

Finder _filledDe(Finder botao) =>
    find.descendant(of: botao, matching: find.byType(FilledButton));
