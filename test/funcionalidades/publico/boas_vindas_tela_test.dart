import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:terae_app/dados/repositorios/demonstracao_repositorio.dart';
import 'package:terae_app/funcionalidades/publico/boas_vindas_tela.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tema/tema.dart';
import 'package:terae_app/nucleo/widgets/faixa_emergencia.dart';
import 'package:terae_app/nucleo/widgets/selo_academico.dart';

import '../../apoio/dubles.dart';
import 'apoio_telas.dart';

const Key _painel = Key('abrir-painel-demonstracao');

/// A TM00 sozinha, sem roteador, para conferir a condição do painel D11.
Widget _soATela({required bool modoDepuracao}) => MultiProvider(
  providers: [
    Provider<ControleDemonstracao>.value(value: DemonstracaoDuble()),
    Provider<LancadorExterno>.value(value: LancadorDuble()),
  ],
  child: MaterialApp(
    theme: temaTerae(),
    home: BoasVindasTela(modoDepuracao: modoDepuracao),
  ),
);

Future<void> _abrirFolha(WidgetTester tester, Key botao) async {
  await tester.tap(find.byKey(botao));
  await tester.pumpAndSettle();
}

Future<void> _fecharFolha(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Fechar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem sessão, liga para o CVV 188 e o SAMU 192 com um toque', (
    tester,
  ) async {
    final lancador = LancadorDuble();
    await tester.pumpWidget(montarApp(sessao: Sessao(), lancador: lancador));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM00')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ligar-188')));
    await tester.tap(find.byKey(const Key('ligar-192')));
    expect(lancador.abertos, [Uri.parse('tel:188'), Uri.parse('tel:192')]);
  });

  testWidgets('mostra a marca, o propósito e o selo acadêmico', (tester) async {
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();
    expect(find.text('Terae'), findsOneWidget);
    expect(
      find.text('Acompanhe o seu tratamento entre uma consulta e outra.'),
      findsOneWidget,
    );
    expect(find.byType(SeloAcademico), findsOneWidget);
  });

  testWidgets('Entrar abre a TM01, e o voltar traz de volta', (tester) async {
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-entrar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM01')), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM00')), findsOneWidget);
  });

  testWidgets('Primeiro acesso: código da clínica → TM09; convite → TM10', (
    tester,
  ) async {
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();

    await _abrirFolha(tester, const Key('ir-primeiro-acesso'));
    expect(find.text('Recebi um código da clínica'), findsOneWidget);
    expect(find.text('Recebi um convite de cuidador'), findsOneWidget);
    await tester.tap(find.byKey(const Key('primeiro-acesso-clinica')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM09')), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _abrirFolha(tester, const Key('ir-primeiro-acesso'));
    await tester.tap(find.byKey(const Key('primeiro-acesso-cuidador')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM10')), findsOneWidget);
  });

  testWidgets('a política de privacidade abre numa folha', (tester) async {
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();
    await _abrirFolha(tester, const Key('politica-privacidade'));
    expect(find.text('Sem senha'), findsOneWidget);
    await _fecharFolha(tester);
    expect(find.text('Sem senha'), findsNothing);
  });

  group('painel de demonstração (D11)', () {
    test('o padrão segue kDebugMode: some na versão de release', () {
      expect(const BoasVindasTela().modoDepuracao, kDebugMode);
    });

    testWidgets('fora do modo de depuração, o painel não aparece', (
      tester,
    ) async {
      await tester.pumpWidget(_soATela(modoDepuracao: false));
      expect(find.byKey(const Key('TM00')), findsOneWidget);
      expect(find.byKey(_painel), findsNothing);
      expect(find.byTooltip('Painel de demonstração'), findsNothing);
    });

    testWidgets('no modo de depuração, o painel aparece', (tester) async {
      await tester.pumpWidget(_soATela(modoDepuracao: true));
      expect(find.byKey(_painel), findsOneWidget);
    });

    testWidgets('liga a falta de conexão e reinicia os dados', (tester) async {
      final controle = DemonstracaoEspia();
      await tester.pumpWidget(
        montarApp(sessao: Sessao(), demonstracao: controle),
      );
      await tester.pumpAndSettle();
      await _abrirFolha(tester, _painel);

      await tester.tap(find.byKey(const Key('demo-sem-conexao')));
      await tester.pumpAndSettle();
      expect(controle.semConexao, isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('demo-reiniciar')));
      await tester.pumpAndSettle();
      expect(controle.reinicios, 1);
      expect(find.text('Pronto: os dados voltaram ao início.'), findsOneWidget);
    });
  });

  testWidgets('sem estouro com fonte 2× em 360×800, na tela e nas folhas', (
    tester,
  ) async {
    telaPequena(tester);
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();
    semEstouro(tester);

    for (final botao in const [
      Key('ir-primeiro-acesso'),
      Key('politica-privacidade'),
      _painel,
    ]) {
      await tester.ensureVisible(find.byKey(botao));
      await _abrirFolha(tester, botao);
      semEstouro(tester);
      await _fecharFolha(tester);
    }
  });

  testWidgets('alvos de toque de 48 e com rótulo, na tela e nas folhas', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(montarApp(sessao: Sessao()));
    await tester.pumpAndSettle();
    await conferirAlvosDeToque(tester);

    await _abrirFolha(tester, const Key('ir-primeiro-acesso'));
    await conferirAlvosDeToque(tester);
    await _fecharFolha(tester);

    await _abrirFolha(tester, _painel);
    await conferirAlvosDeToque(tester);
    semantica.dispose();
  });
}
