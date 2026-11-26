import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../../apoio/dubles.dart';
import '../publico/apoio_telas.dart';
import 'apoio_autenticacao.dart';

final Finder _email = find.byKey(const Key('campo-email'));
final Finder _senha = find.byKey(const Key('campo-senha'));
final Finder _botaoEntrar = find.byKey(const Key('entrar'));

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

/// Preenche e-mail e senha e toca em "Entrar".
Future<void> _entrarCom(WidgetTester tester, String email, String senha) async {
  await tester.enterText(_email, email);
  await tester.enterText(_senha, senha);
  await tester.ensureVisible(_botaoEntrar);
  await tester.tap(_botaoEntrar);
  await tester.pumpAndSettle();
}

void main() {
  group('/entrar', () {
    testWidgets('e-mail e senha entram com a conta (D14)', (tester) async {
      final sessao = SessaoEspia();
      final autenticacao = AutenticacaoFake();
      await _abrirEntrar(tester, sessao: sessao, autenticacao: autenticacao);
      expect(find.byKey(const Key('TM01')), findsOneWidget);
      expect(find.textContaining('não fica guardada'), findsOneWidget);

      await _entrarCom(tester, ' ${idRegina.email} ', idRegina.senha);
      expect(autenticacao.entradas, [idRegina.email], reason: 'sem espaços');
      expect(sessao.entradas, hasLength(1));
      expect(sessao.entradas.single.conta.id, 'c-regina');
    });

    testWidgets('campo vazio ou e-mail mal formado: erro no campo, sem '
        'chamar o repositório', (tester) async {
      final sessao = SessaoEspia();
      final autenticacao = AutenticacaoFake();
      await _abrirEntrar(tester, sessao: sessao, autenticacao: autenticacao);
      await _entrarCom(tester, '', '');
      expect(find.text('Digite o e-mail.'), findsOneWidget);
      expect(find.text('Digite a senha.'), findsOneWidget);
      await _entrarCom(tester, 'regina.sem.arroba', idRegina.senha);
      expect(find.text(MotivoRecusa.emailInvalido.mensagem), findsOneWidget);
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
      await _entrarCom(tester, idRegina.email, idRegina.senha);
      expect(find.byKey(const Key('TM08')), findsOneWidget);
    });

    testWidgets('senha errada mostra a recusa e não abre sessão', (
      tester,
    ) async {
      final sessao = SessaoEspia();
      await _abrirEntrar(
        tester,
        sessao: sessao,
        autenticacao: AutenticacaoFake(),
      );
      await _entrarCom(tester, idRegina.email, '${idRegina.senha}-errada');
      expect(
        find.text(MotivoRecusa.credenciaisInvalidas.mensagem),
        findsOneWidget,
      );
      expect(sessao.entradas, isEmpty);
    });

    testWidgets('muitas tentativas mostram a espera, não "sem internet" '
        '(A5, CT03)', (tester) async {
      final sessao = SessaoEspia();
      await _abrirEntrar(
        tester,
        sessao: sessao,
        autenticacao: AutenticacaoFake(
          recusaNaEntrada: {idRegina.email: MotivoRecusa.muitasTentativas},
        ),
      );
      await _entrarCom(tester, idRegina.email, idRegina.senha);
      expect(
        find.text(
          'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.',
        ),
        findsOneWidget,
      );
      expect(find.text(MotivoRecusa.semConexao.mensagem), findsNothing);
      expect(sessao.entradas, isEmpty);
    });

    testWidgets('conta sem acesso mostra a recusa e não abre sessão', (
      tester,
    ) async {
      final sessao = SessaoEspia();
      await _abrirEntrar(
        tester,
        sessao: sessao,
        autenticacao: AutenticacaoFake(
          recusaNaEntrada: {idNova.email: MotivoRecusa.contaSemAcesso},
        ),
      );
      await _entrarCom(tester, idNova.email, idNova.senha);
      expect(find.text(MotivoRecusa.contaSemAcesso.mensagem), findsOneWidget);
      expect(sessao.entradas, isEmpty);
    });

    testWidgets('a senha fica oculta e "Mostrar senha" a revela', (
      tester,
    ) async {
      await _abrirEntrar(tester, sessao: Sessao());
      await tester.enterText(_senha, idAna.senha);
      await tester.pump();
      TextField campo() => tester.widget<TextField>(
        find.descendant(of: _senha, matching: find.byType(TextField)),
      );
      expect(campo().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(campo().obscureText, isFalse);
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

    testWidgets('sem estouro com fonte 2× em 360×800, com a recusa', (
      tester,
    ) async {
      telaPequena(tester);
      await _abrirEntrar(
        tester,
        sessao: SessaoEspia(),
        autenticacao: AutenticacaoFake(
          recusaNaEntrada: {idNova.email: MotivoRecusa.contaSemAcesso},
        ),
      );
      semEstouro(tester);
      await _entrarCom(tester, idNova.email, idNova.senha);
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
      expect(_botaoEntrar, findsNothing);
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
