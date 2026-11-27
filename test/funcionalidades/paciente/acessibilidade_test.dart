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
  sintomas: 'Um relato comprido para ver a quebra de linha na tela do recibo.',
  intensidadeSintoma: intensidade,
  observacoes: 'Uma observação comprida para ver a quebra de linha na tela.',
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
  _Caso('TM03 Diário (lista com os selos)', 'TM03', (t) async {
    await abrirAppDoPaciente(
      t,
      em: Rotas.pacienteDiario,
      diario: DiarioControlavel(ModoDoDiario.comConexao, [
        registroEnviado('r1', observacoes: 'Uma observação comprida.'),
        registroEnviado(
          'r2',
          em: agoraDeTeste.subtract(const Duration(days: 1)),
          revisadoEm: agoraDeTeste,
        ),
        registroEnviado(
          'r3',
          em: agoraDeTeste.subtract(const Duration(days: 2)),
          intensidade: Intensidade.critico,
          alertou: true,
        ),
      ]),
    );
  }),
  _Caso('TM03 Diário (vazio)', 'TM03', (t) async {
    await abrirAppDoPaciente(t, em: Rotas.pacienteDiario);
  }),
  _Caso('TM13 Novo registro (com escolhas)', 'TM13', (t) async {
    await abrirAppDoPaciente(t, em: Rotas.pacienteNovoRegistro);
    for (final opcao in ['Segui uma parte', 'Muito — precisamos de ajuda']) {
      await t.ensureVisible(find.text(opcao));
      await t.tap(find.text(opcao));
      await t.pumpAndSettle();
    }
  }),
  _Caso('TM13 Novo registro (sem internet)', 'TM13', (t) async {
    await abrirAppDoPaciente(
      t,
      em: Rotas.pacienteNovoRegistro,
      conexao: semInternet(),
    );
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
      extra: DiarioControlavel.enviadoDe(_registro(Intensidade.moderado)),
    );
  }),
  _Caso('TM05 Ajuda imediata (avisado)', 'TM05', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioAjuda,
      extra: DiarioControlavel.enviadoDe(_registro(Intensidade.critico)),
    );
  }),
  _Caso('TM05 Ajuda imediata (pendente)', 'TM05', (t) async {
    await abrirAppDoPaciente(t);
    await _ir(
      t,
      Rotas.pacienteDiarioAjuda,
      extra: ResultadoEnvio(registro: _registro(Intensidade.critico)),
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
    // Com a AppBar da D22, o erro empurra a lista e o "Revogar" ficava com
    // 12 dp à mostra sob a barra (meio rolado, não alvo pequeno): o
    // formulário vai ao topo da área rolável, inteiro.
    await t.ensureVisible(find.byKey(const Key('formulario-convite')));
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

  testWidgets('os cartões do diário expõem checked e grupo exclusivo (P3)', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrirAppDoPaciente(tester, em: Rotas.pacienteNovoRegistro);
    for (final opcao in [
      'Segui tudo',
      'Segui uma parte',
      'Não deu para seguir',
      ...Intensidade.values.map((i) => i.rotulo),
    ]) {
      expect(
        tester.getSemantics(find.text(opcao)),
        isSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
        reason: opcao,
      );
    }
    final bastante = Intensidade.grave.rotulo;
    await tester.ensureVisible(find.text(bastante));
    await tester.tap(find.text(bastante));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text(bastante)),
      isSemantics(isChecked: true, hasCheckedState: true, label: bastante),
    );
    expect(
      tester.getSemantics(find.text(Intensidade.leve.rotulo)),
      isSemantics(isChecked: false, hasCheckedState: true),
    );
    semantica.dispose();
  });

  testWidgets('o quanto atrapalhou aparece com nome no recibo (nunca só cor)', (
    tester,
  ) async {
    await abrirAppDoPaciente(tester);
    await _ir(
      tester,
      Rotas.pacienteDiarioEnviado,
      extra: DiarioControlavel.enviadoDe(_registro(Intensidade.grave)),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('resumo-envio')),
        matching: find.text('Bastante'),
      ),
      findsOneWidget,
    );
  });
}
