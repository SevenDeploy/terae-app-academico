/// Acessibilidade das 13 telas com a memória real de demonstração (RNFM01,
/// D10): num celular de 360×800, alvos de toque de 48 dp (Android) e 44 pt
/// (iOS) com rótulo falado, contraste de texto AA, fonte do aparelho em 100%
/// e em 200% sem estouro nem exceção, e os seletores de escolha única dizendo
/// ao leitor de tela qual opção está marcada (`selected`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/funcionalidades/paciente/diario/diario_controlador.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../dados/memoria_apoio.dart';
import 'telas_reais.dart';

/// Opção de seletor de escolha única, marcada ou não.
Matcher _opcao({required bool marcada}) => isSemantics(
  isButton: true,
  isInMutuallyExclusiveGroup: true,
  hasSelectedState: true,
  isSelected: marcada,
  hasTapAction: true,
);

/// Confere que, entre [rotulos], só [marcado] está `selected`.
void _soEstaMarcada(
  WidgetTester tester,
  Iterable<String> rotulos, {
  String? marcado,
}) {
  for (final rotulo in rotulos) {
    expect(
      tester.getSemantics(find.text(rotulo)),
      _opcao(marcada: rotulo == marcado),
      reason: rotulo,
    );
  }
}

void main() {
  group('alvos de toque, rótulos e contraste AA em 360×800', () {
    for (final tela in telasReais) {
      testWidgets(tela.descricao, (tester) async {
        final semantica = tester.ensureSemantics();
        aparelho(tester);
        await tela.abrir(tester);
        expect(find.byKey(Key(tela.tela)), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  });

  for (final escala in [1.0, 2.0]) {
    group('fonte do aparelho em ${(escala * 100).round()}%, sem estouro', () {
      for (final tela in telasReais) {
        testWidgets(tela.descricao, (tester) async {
          aparelho(tester, escala: escala);
          await tela.abrir(tester);
          expect(find.byKey(Key(tela.tela)), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  group('seletores expõem a opção marcada (D10)', () {
    testWidgets('TM03: adesão, intensidade e sintoma', (tester) async {
      final semantica = tester.ensureSemantics();
      aparelho(tester);
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      final adesoes = Adesao.values.map((a) => a.rotulo);
      final intensidades = Intensidade.values.map((i) => i.rotulo);
      _soEstaMarcada(tester, adesoes);
      _soEstaMarcada(tester, intensidades);
      _soEstaMarcada(tester, sintomasDoDiario);

      await preencherDiario(
        tester,
        adesao: Adesao.parcial.rotulo,
        intensidade: Intensidade.grave.rotulo,
        sintoma: 'Sono ruim',
      );
      _soEstaMarcada(tester, adesoes, marcado: Adesao.parcial.rotulo);
      _soEstaMarcada(tester, intensidades, marcado: Intensidade.grave.rotulo);
      _soEstaMarcada(tester, sintomasDoDiario, marcado: 'Sono ruim');

      // Trocar a escolha desmarca a anterior.
      await tocar(tester, find.text(Intensidade.leve.rotulo));
      _soEstaMarcada(tester, intensidades, marcado: Intensidade.leve.rotulo);
      semantica.dispose();
    });

    testWidgets('TM09: quem vai usar (passo 2) e canal (passo 3)', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      aparelho(tester);
      await abrirComMemoria(
        tester,
        persona: Persona.semSessao,
        em: Rotas.cadastroPaciente,
      );
      await tester.enterText(find.byKey(const Key('campo-codigo')), codigoJoao);
      await tester.enterText(find.byKey(const Key('campo-cpf')), cpfJoao);
      await tester.enterText(
        find.byKey(const Key('campo-nascimento')),
        '19071999',
      );
      await tocar(tester, find.byKey(const Key('continuar')));

      final qualidades = QualidadeConsentimento.values.map((q) => q.rotulo);
      _soEstaMarcada(tester, qualidades);
      await tocar(tester, find.text(QualidadeConsentimento.titular.rotulo));
      _soEstaMarcada(
        tester,
        qualidades,
        marcado: QualidadeConsentimento.titular.rotulo,
      );

      await tocar(tester, find.byKey(const Key('continuar')));
      final canais = CanalAutorizado.values.map((c) => c.rotulo);
      _soEstaMarcada(tester, canais);
      await tocar(tester, find.text(CanalAutorizado.aplicativo.rotulo));
      _soEstaMarcada(
        tester,
        canais,
        marcado: CanalAutorizado.aplicativo.rotulo,
      );
      semantica.dispose();
    });

    testWidgets('abas do paciente: só a aba atual está selected', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      aparelho(tester);
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteSessoes,
      );
      // Ana tem as duas linhas de cuidado (D21): as cinco abas do portal.
      const abas = {
        'aba-inicio': false,
        'aba-diario': false,
        'aba-casa': false,
        'aba-agenda': true,
        'aba-conta': false,
      };
      for (final MapEntry(key: chave, value: atual) in abas.entries) {
        expect(
          tester.getSemantics(find.byKey(Key(chave))),
          isSemantics(hasSelectedState: true, isSelected: atual),
          reason: chave,
        );
      }
      semantica.dispose();
    });
  });
}
