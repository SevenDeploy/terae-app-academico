import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../../apoio/dubles.dart';
import '../publico/apoio_telas.dart';
import 'apoio_autenticacao.dart';

final Finder _google = find.byKey(const Key('continuar-google'));
final Finder _apple = find.byKey(const Key('continuar-apple'));

Future<void> _abrirEntrar(
  WidgetTester tester, {
  required Sessao sessao,
  AutenticacaoFake? autenticacao,
}) async {
  await tester.pumpWidget(
    montarApp(sessao: sessao, em: Rotas.entrar, autenticacao: autenticacao),
  );
  await tester.pumpAndSettle();
}

Future<void> _escolherConta(WidgetTester tester, IdentidadeProvedor id) async {
  await tester.tap(_google);
  await tester.pumpAndSettle();
  expect(find.text('Escolha uma conta'), findsOneWidget);
  await tester.tap(find.byKey(Key('conta-${id.idProvedor}')));
  await tester.pumpAndSettle();
}

void main() {
  group('/entrar', () {
    testWidgets('Google abre "Escolha uma conta" e entra com a escolhida', (
      tester,
    ) async {
      final sessao = SessaoEspia();
      final autenticacao = AutenticacaoFake();
      await _abrirEntrar(tester, sessao: sessao, autenticacao: autenticacao);
      expect(find.byKey(const Key('TM01')), findsOneWidget);
      expect(find.textContaining('não guarda senha'), findsOneWidget);

      await tester.tap(_google);
      await tester.pumpAndSettle();
      expect(autenticacao.pedidosDeContas, [Provedor.google]);
      expect(find.text('Regina'), findsOneWidget);
      expect(find.text('c-regina@exemplo.test'), findsOneWidget);

      await tester.tap(find.byKey(Key('conta-${idRegina.idProvedor}')));
      await tester.pumpAndSettle();
      expect(autenticacao.entradas, [idRegina]);
      expect(sessao.entradas, hasLength(1));
      expect(sessao.entradas.single.conta.id, 'c-regina');
      expect(find.text('Escolha uma conta'), findsNothing);
    });

    testWidgets('fechar a folha não entra', (tester) async {
      final sessao = SessaoEspia();
      final autenticacao = AutenticacaoFake();
      await _abrirEntrar(tester, sessao: sessao, autenticacao: autenticacao);
      await tester.tap(_google);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(autenticacao.entradas, isEmpty);
      expect(sessao.entradas, isEmpty);
    });

    testWidgets('com a sessão de verdade, a cuidadora cai na TM08', (
      tester,
    ) async {
      await _abrirEntrar(
        tester,
        sessao: Sessao(),
        autenticacao: AutenticacaoFake(),
      );
      await _escolherConta(tester, idRegina);
      expect(find.byKey(const Key('TM08')), findsOneWidget);
    });

    testWidgets('conta sem acesso mostra a recusa e não abre sessão', (
      tester,
    ) async {
      final sessao = SessaoEspia();
      await _abrirEntrar(
        tester,
        sessao: sessao,
        autenticacao: AutenticacaoFake(
          recusaNaEntrada: {idNova.idProvedor: MotivoRecusa.contaSemAcesso},
        ),
      );
      await _escolherConta(tester, idNova);
      expect(find.text(MotivoRecusa.contaSemAcesso.mensagem), findsOneWidget);
      expect(sessao.entradas, isEmpty);
    });

    testWidgets('fora do iOS, só Google', (tester) async {
      await _abrirEntrar(tester, sessao: Sessao());
      expect(_google, findsOneWidget);
      expect(_apple, findsNothing);
    });

    testWidgets('no iOS, também "Continuar com Apple" (diretriz 4.8)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final autenticacao = AutenticacaoFake(
          contas: [
            identidadeDe('c-ana', 'Ana Lúcia', provedor: Provedor.apple),
          ],
        );
        await _abrirEntrar(
          tester,
          sessao: SessaoEspia(),
          autenticacao: autenticacao,
        );
        expect(_google, findsOneWidget);
        expect(_apple, findsOneWidget);
        expect(find.text('Continuar com Apple'), findsOneWidget);

        await tester.tap(_apple);
        await tester.pumpAndSettle();
        expect(autenticacao.pedidosDeContas, [Provedor.apple]);
        expect(find.text('Ana Lúcia'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('o atalho do primeiro acesso leva à TM09', (tester) async {
      await _abrirEntrar(tester, sessao: Sessao());
      await tester.ensureVisible(find.byKey(const Key('ir-primeiro-acesso')));
      await tester.tap(find.byKey(const Key('ir-primeiro-acesso')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primeiro-acesso-clinica')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('TM09')), findsOneWidget);
    });

    testWidgets('sem estouro com fonte 2× em 360×800, com a folha aberta', (
      tester,
    ) async {
      telaPequena(tester);
      await _abrirEntrar(
        tester,
        sessao: SessaoEspia(),
        autenticacao: AutenticacaoFake(
          recusaNaEntrada: {idNova.idProvedor: MotivoRecusa.contaSemAcesso},
        ),
      );
      semEstouro(tester);
      await tester.ensureVisible(_google);
      await tester.tap(_google);
      await tester.pumpAndSettle();
      semEstouro(tester);
      final conta = find.byKey(Key('conta-${idNova.idProvedor}'));
      await tester.ensureVisible(conta);
      await tester.pumpAndSettle();
      await tester.tap(conta);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aviso-recusa')), findsOneWidget);
      semEstouro(tester);
    });

    testWidgets('alvos de toque de 48 e com rótulo', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrirEntrar(
        tester,
        sessao: SessaoEspia(),
        autenticacao: AutenticacaoFake(),
      );
      await conferirAlvosDeToque(tester);
      await tester.tap(_google);
      await tester.pumpAndSettle();
      await conferirAlvosDeToque(tester);
      semantica.dispose();
    });
  });

  group('/entrar/perfil', () {
    Future<SessaoEspia> abrirSelecao(WidgetTester tester) async {
      final sessao = SessaoEspia()..abrir(vinculosMistos());
      await tester.pumpWidget(
        montarApp(sessao: sessao, em: Rotas.entrarPerfil),
      );
      await tester.pumpAndSettle();
      return sessao;
    }

    testWidgets('lista os perfis com papel e nome', (tester) async {
      await abrirSelecao(tester);
      expect(find.byKey(const Key('TM01')), findsOneWidget);
      expect(find.text('Paciente ou família'), findsOneWidget);
      expect(find.text('Miguel Andrade Neves'), findsOneWidget);
      expect(find.text('Cuidador'), findsOneWidget);
      expect(find.text('Ana Lúcia Martins'), findsOneWidget);
      expect(_google, findsNothing);
    });

    testWidgets('tocar num perfil chama escolherPerfil com ele', (
      tester,
    ) async {
      final sessao = await abrirSelecao(tester);
      await tester.tap(find.byKey(const Key('perfil-cuidador-p-ana')));
      await tester.pumpAndSettle();
      expect(sessao.escolhidos, [
        sessao.perfis.firstWhere((p) => p.papel == Papel.cuidador),
      ]);
    });

    testWidgets('com a sessão de verdade, escolher abre o início do papel', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosMistos());
      await tester.pumpWidget(
        montarApp(sessao: sessao, em: Rotas.entrarPerfil),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('perfil-cuidador-p-ana')));
      await tester.pumpAndSettle();
      expect(sessao.perfilAtivo?.papel, Papel.cuidador);
      expect(find.byKey(const Key('TM08')), findsOneWidget);
    });

    testWidgets('Sair encerra a sessão e volta à TM00', (tester) async {
      final sessao = Sessao()..entrar(vinculosPatricia());
      await tester.pumpWidget(
        montarApp(sessao: sessao, em: Rotas.entrarPerfil),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('sair')));
      await tester.tap(find.byKey(const Key('sair')));
      await tester.pumpAndSettle();
      expect(sessao.autenticada, isFalse);
      expect(find.byKey(const Key('TM00')), findsOneWidget);
    });

    testWidgets('sem estouro com fonte 2× em 360×800', (tester) async {
      telaPequena(tester);
      await abrirSelecao(tester);
      semEstouro(tester);
    });

    testWidgets('alvos de toque de 48 e com rótulo', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrirSelecao(tester);
      await conferirAlvosDeToque(tester);
      semantica.dispose();
    });
  });
}
