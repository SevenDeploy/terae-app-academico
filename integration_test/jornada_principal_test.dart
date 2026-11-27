/// Jornada principal da paciente no aparelho (Atividade 5, §12; RFM01, RFM03,
/// RFM05, RFM11; D17 revista, D20), sobre os repositórios em memória (D19): nada sai
/// do aparelho, então roda em qualquer emulador sem o Firebase.
///
/// TM00 → TM01 (e-mail e senha) → TM02 → TM13 (novo registro) → TM04 →
/// TM15 (corrigir, versão 2) → TM04 → TM03 (a lista, "Ver a versão 1",
/// retirar com motivo) → "Sair" → TM00 (P3: o diário do portal).
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ana entra, registra, corrige, retira e sai', (tester) async {
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

    // TM13 → TM04 (RFM03, RFM05, RNFM02; P3: o diário do portal).
    await _tocar(tester, find.byKey(const Key('atalho-diario')));
    expect(find.byKey(const Key('TM13')), findsOneWidget);
    for (final opcao in ['Fiz tudo', 'Pouco — quase não atrapalhou']) {
      await _tocar(tester, find.text(opcao));
    }
    await _tocar(tester, find.byKey(const Key('enviar-diario')));
    expect(find.text('Registro enviado.'), findsOneWidget);
    final novo = memoria.estado.registros.values.singleWhere(
      (r) => r.registradoEm == _agora,
    );

    // "Corrigir agora" → TM15: corrigir cria a versão 2 (D17 revista).
    await _tocar(tester, find.byKey(const Key('corrigir-agora')));
    expect(find.byKey(const Key('TM15')), findsOneWidget);
    await _tocar(tester, find.text('Mais ou menos — atrapalhou um pouco'));
    await tester.enterText(
      find.byKey(const Key('campo-sintomas')),
      'Dormi mal.',
    );
    await _tocar(tester, find.byKey(const Key('salvar-correcao')));
    expect(find.text('Correção enviada.'), findsOneWidget);
    expect(memoria.estado.registros[novo.id]!.versao, 2);

    // TM03: a lista mostra a correção e "Ver a versão 1"; retirar com motivo.
    await _tocar(tester, find.byKey(const Key('voltar-ao-inicio')));
    await _tocar(tester, find.byKey(const Key('aba-diario')));
    expect(find.byKey(const Key('TM03')), findsOneWidget);
    expect(find.text('Corrigido · versão 2'), findsOneWidget);
    await _tocar(tester, find.byKey(Key('versoes-${novo.id}')));
    expect(find.byKey(Key('versoes-anteriores-${novo.id}')), findsOneWidget);
    await _tocar(tester, find.byKey(Key('retirar-${novo.id}')));
    await _tocar(tester, find.text('Enviei sem querer'));
    await _tocar(tester, find.byKey(const Key('confirmar-retirada')));
    expect(find.byKey(const Key('aviso-retirado')), findsOneWidget);
    final retirado = memoria.estado.registros[novo.id]!;
    expect(retirado.retirado, isTrue, reason: 'nada é apagado');
    expect(retirado.sintomas, 'Dormi mal.');

    // "Sair" volta à TM00 (D20).
    await _tocar(tester, find.byTooltip('Voltar'));
    await _tocar(tester, find.byKey(const Key('aba-inicio')));
    await _tocar(tester, find.byTooltip('Abrir menu'));
    await _tocar(tester, find.byKey(const Key('menu-sair')));
    expect(find.byKey(const Key('TM00')), findsOneWidget);
  });
}
