/// Jornada principal da paciente no aparelho (Atividade 5, §12; RFM01, RFM03,
/// RFM05, RFM11; D17, D20), sobre os repositórios em memória (D19): nada sai
/// do aparelho, então roda em qualquer emulador sem o Firebase.
///
/// TM00 → TM01 (e-mail e senha) → TM02 → TM03 (três escolhas) → TM04 →
/// TM13 → TM14 → TM15 (corrigir) → TM14 → excluir → TM13 → "Sair" → TM00.
///
/// Uso, com o emulador ligado:
///   flutter test integration_test/jornada_principal_test.dart -d emulator-5554
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/memoria/estado_memoria.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

/// 2/10/2026 às 10:00 na clínica, o "agora" das demais suítes.
final DateTime _agora = instanteNaClinica(2026, 10, 2, 10);

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// O primeiro cartão da TM13 (a lista vem do mais recente).
Finder get _primeiroRegistro => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('registro-'),
    )
    .first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ana entra, registra, corrige, exclui e sai', (tester) async {
    final relogio = RelogioFixo(_agora);
    final memoria = await MemoriaDemonstracao.carregar(
      relogio: relogio,
      latencia: Duration.zero,
    );
    await tester.pumpWidget(
      TeraeApp(
        repositorios: memoria.repositorios,
        sessao: Sessao(),
        relogio: relogio,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM00')), findsOneWidget);

    // TM01: e-mail e senha (RFM01, D14).
    await _tocar(tester, find.byKey(const Key('ir-entrar')));
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'ana.lucia.martins@exemplo.test',
    );
    await tester.enterText(
      find.byKey(const Key('campo-senha')),
      senhaDeDemonstracao,
    );
    await _tocar(tester, find.byKey(const Key('entrar')));
    expect(find.byKey(const Key('TM02')), findsOneWidget);
    expect(find.text('Olá, Ana'), findsOneWidget);

    // TM03 → TM04 (RFM03, RFM05, RNFM02).
    await _tocar(tester, find.byKey(const Key('atalho-diario')));
    for (final opcao in ['Tomei tudo', 'Leve', 'Cansaço']) {
      await _tocar(tester, find.text(opcao));
    }
    await _tocar(tester, find.byKey(const Key('enviar-diario')));
    expect(find.text('Registro enviado!'), findsOneWidget);

    // TM13 → TM14 → TM15 (RFM11, D17: o de hoje ainda muda).
    await _tocar(tester, find.byKey(const Key('voltar-ao-inicio')));
    await _tocar(tester, find.byKey(const Key('aba-diario')));
    await _tocar(tester, find.byKey(const Key('abrir-registros')));
    expect(find.byKey(const Key('TM13')), findsOneWidget);
    final chaveDoNovo = tester.widget(_primeiroRegistro).key!;
    await _tocar(tester, _primeiroRegistro);
    expect(find.byKey(const Key('TM14')), findsOneWidget);
    expect(find.text('Cansaço'), findsWidgets);
    await _tocar(tester, find.byKey(const Key('corrigir-registro')));
    await _tocar(tester, find.text('Moderada'));
    await _tocar(tester, find.text('Sono ruim'));
    await _tocar(tester, find.byKey(const Key('salvar-correcao')));
    expect(find.byKey(const Key('TM14')), findsOneWidget);
    expect(find.text('Registro corrigido.'), findsOneWidget);
    expect(find.text('Sono ruim'), findsWidgets);

    // Excluir: lógico, pede confirmação e some da TM13.
    await _tocar(tester, find.byKey(const Key('excluir-registro')));
    await _tocar(tester, find.byKey(const Key('confirmar-exclusao')));
    expect(find.byKey(const Key('TM13')), findsOneWidget);
    expect(find.byKey(chaveDoNovo), findsNothing, reason: 'some da lista');
    final excluido = memoria.estado.registros.values.singleWhere(
      (r) => r.excluidoEm != null,
    );
    expect(excluido.sintomaPredominante, 'Sono ruim');

    // "Sair" volta à TM00 (D20).
    await _tocar(tester, find.byTooltip('Voltar'));
    await _tocar(tester, find.byKey(const Key('aba-inicio')));
    await _tocar(tester, find.byTooltip('Abrir menu'));
    await _tocar(tester, find.byKey(const Key('menu-sair')));
    expect(find.byKey(const Key('TM00')), findsOneWidget);
  });
}
