/// As 13 telas com a fonte Lexend e os ícones Material de verdade, em 100% e
/// em 200% (RNFM01). Complementa `telas_test.dart`, que usa a fonte de teste
/// (cada letra um quadrado de 1 em, mais larga que a Lexend): aqui valem as
/// medidas reais de altura de linha e de largura do texto, as do aparelho.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import 'telas_reais.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesReais);

  for (final escala in [1.0, 2.0]) {
    group('Lexend em ${(escala * 100).round()}%, sem estouro', () {
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

  // A barra do portal tem 5 abas de rótulo curto; o teste de estouro não pega
  // quebra de linha. Ana tem a barra mais cheia (as duas linhas de cuidado).
  // Antes (D22), "Cuidadores" quebrava em duas linhas a 360 dp.
  for (final escala in [1.0, 2.0]) {
    testWidgets('rótulo de aba em uma linha só a 360 dp com a Inter em '
        '${(escala * 100).round()}%', (tester) async {
      aparelho(tester, escala: escala);
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteInicio,
      );
      // Os ícones também são RichText; ficam só os rótulos.
      const nomes = {'Início', 'Diário', 'Em casa', 'Agenda', 'Conta'};
      final rotulos = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byWidgetPredicate(
          (w) => w is RichText && nomes.contains(w.text.toPlainText()),
        ),
      );
      expect(rotulos, findsNWidgets(nomes.length));
      for (final paragrafo in tester.renderObjectList<RenderParagraph>(
        rotulos,
      )) {
        // O tamanho já na escala do rótulo (a barra limita a escala do texto).
        final tamanho = paragrafo.textScaler.scale(
          paragrafo.text.style!.fontSize!,
        );
        expect(
          paragrafo.size.height,
          lessThan(tamanho * 2),
          reason: '"${paragrafo.text.toPlainText()}" quebrou de linha',
        );
      }
    });
  }
}
