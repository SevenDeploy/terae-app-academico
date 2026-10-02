/// As 13 telas com a fonte Lexend e os ícones Material de verdade, em 100% e
/// em 200% (RNFM01). Complementa `telas_test.dart`, que usa a fonte de teste
/// (cada letra um quadrado de 1 em, mais larga que a Lexend): aqui valem as
/// medidas reais de altura de linha e de largura do texto, as do aparelho.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
