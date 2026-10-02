/// Acessibilidade das telas do paciente (RNFM01, RNFM06, D10): sem estouro
/// com fonte em 200% num aparelho de 360×800, alvos de toque de 48 dp com
/// rótulo, contraste de texto AA e seletores com `selected` na semântica.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

RegistroDiario _registro(Intensidade intensidade) => RegistroDiario(
  id: '7d0f3c1e-2b4a-4c5d-8e6f-a1b2c3d4e5f6',
  pacienteId: 'p-ana',
  registradoEm: agoraDeTeste,
  adesao: Adesao.parcial,
  intensidade: intensidade,
  sintomaPredominante: 'Nenhum em especial',
  observacao: 'Uma observação comprida para ver a quebra de linha na tela.',
  situacaoEnvio: SituacaoEnvio.naFila,
);

/// Uma tela do paciente e como chegar a ela.
class _Caso {
  const _Caso(this.nome, this.chave, this.abrir);

  final String nome;
  final String chave;
  final Future<void> Function(WidgetTester tester) abrir;
}

Future<void> _ir(WidgetTester tester, String rota, {Object? extra}) async {
  roteadorDe(tester).go(rota, extra: extra);
  await tester.pumpAndSettle();
}

final List<_Caso> _casos = [
  _Caso('TM02 Início', 'TM02', (t) => abrirAppDoPaciente(t)),
  _Caso('TM03 Diário', 'TM03', (t) async {
    await abrirAppDoPaciente(t, em: Rotas.pacienteDiario);
    // Com escolhas feitas (marca de seleção e dica da crítica à vista).
    for (final opcao in ['Tomei uma parte', 'Crítica', 'Nenhum em especial']) {
      await t.ensureVisible(find.text(opcao));
      await t.tap(find.text(opcao));
      await t.pumpAndSettle();
    }
  }),
  _Caso('TM04 Diário enviado (na fila)', 'TM04', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioEnviado,
      extra: ResultadoEnvio(registro: _registro(Intensidade.grave)),
    );
  }),
  _Caso('TM04 Diário enviado (enviado)', 'TM04', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioEnviado,
      extra: DiarioControlavel.enviadoDe(_registro(Intensidade.moderada)),
    );
  }),
  _Caso('TM05 Ajuda imediata (avisado)', 'TM05', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioAjuda,
      extra: DiarioControlavel.enviadoDe(_registro(Intensidade.critica)),
    );
  }),
  _Caso('TM05 Ajuda imediata (pendente)', 'TM05', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioAjuda,
      extra: ResultadoEnvio(registro: _registro(Intensidade.critica)),
    );
  }),
  _Caso(
    'TM06 Jornada',
    'TM06',
    (t) => abrirAppDoPaciente(t, em: Rotas.pacienteJornada),
  ),
  _Caso(
    'TM07 Cuidadores (2/2)',
    'TM07',
    (t) => abrirAppDoPaciente(t, em: Rotas.pacienteCuidadores),
  ),
  _Caso('TM07 Cuidadores (convite e erros)', 'TM07', (t) async {
    await abrirAppDoPaciente(
      t,
      em: Rotas.pacienteCuidadores,
      cuidadores: CuidadoresEmMemoria([reginaAtiva()]),
    );
    final convidar = find.byKey(const Key('convidar'));
    await t.ensureVisible(convidar);
    await t.tap(convidar);
    await t.pumpAndSettle();
  }),
];

void main() {
  group('fonte em 200% num aparelho de 360×800, sem estouro', () {
    for (final caso in _casos) {
      testWidgets(caso.nome, (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await caso.abrir(tester);
        expect(find.byKey(Key(caso.chave)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('alvos de toque de 48 dp com rótulo e contraste AA', () {
    for (final caso in _casos) {
      testWidgets(caso.nome, (tester) async {
        final semantica = tester.ensureSemantics();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await caso.abrir(tester);
        expect(find.byKey(Key(caso.chave)), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  });

  testWidgets('seletores do diário expõem selected e grupo exclusivo', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
    for (final opcao in [
      ...Adesao.values.map((a) => a.rotulo),
      ...Intensidade.values.map((i) => i.rotulo),
      'Cansaço',
    ]) {
      expect(
        tester.getSemantics(find.text(opcao)),
        isSemantics(
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
        reason: opcao,
      );
    }
    await tester.ensureVisible(find.text('Grave'));
    await tester.tap(find.text('Grave'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Grave')),
      isSemantics(isSelected: true, hasSelectedState: true, label: 'Grave'),
    );
    expect(
      tester.getSemantics(find.text('Leve')),
      isSemantics(isSelected: false, hasSelectedState: true),
    );
    semantica.dispose();
  });

  testWidgets(
    'a intensidade escolhida aparece com nome no resumo (nunca só cor)',
    (tester) async {
      await abrirAppDoPaciente(tester);
      await _ir(
        tester,
        Rotas.pacienteDiarioEnviado,
        extra: DiarioControlavel.enviadoDe(_registro(Intensidade.grave)),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('resumo-envio')),
          matching: find.text('Grave'),
        ),
        findsOneWidget,
      );
    },
  );
}
