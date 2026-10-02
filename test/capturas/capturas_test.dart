/// Capturas das 13 telas (golden) em `docs/capturas/`, para comparar com os
/// mockups do protótipo (P01–P08) e ilustrar a entrega: tema claro, 360×800
/// lógicos com densidade 2 (720×1600 px), memória real de demonstração,
/// relógio parado e a fonte Lexend e os ícones Material de verdade
/// (`../acessibilidade/telas_reais.dart`).
///
/// Cada captura espera a tela assentar (`pumpAndSettle`): nenhuma animação
/// fica pela metade. As sombras são desenhadas como no aparelho
/// (`debugDisableShadows = false` só durante a captura; o `flutter_test` as
/// troca por blocos sólidos por padrão).
///
/// Gerar de novo: `flutter test --update-goldens test/capturas`. A imagem
/// depende da rasterização do sistema; estas foram geradas no Windows.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/app.dart';

import '../acessibilidade/telas_reais.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesReais);

  for (final tela in telasReais) {
    testWidgets('${tela.descricao} → docs/capturas/${tela.arquivo}.png', (
      tester,
    ) async {
      aparelho(tester);
      debugDisableShadows = false;
      try {
        await tela.abrir(tester);
        expect(find.byKey(Key(tela.tela)), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.binding.hasScheduledFrame, isFalse);
        await expectLater(
          find.byType(TeraeApp),
          matchesGoldenFile('../../docs/capturas/${tela.arquivo}.png'),
        );
      } finally {
        debugDisableShadows = true;
      }
    });
  }
}
