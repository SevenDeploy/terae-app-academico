import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../apoio/dubles.dart';
import '../publico/apoio_telas.dart';

/// A autenticação em duas etapas da fonte Terae local, em memória.
class _AutenticacaoComCodigoFake extends AutenticacaoDuble
    implements AutenticacaoComCodigo {
  _AutenticacaoComCodigoFake({this.codigoEnviado = true});

  final bool codigoEnviado;
  final List<(String, bool)> codigos = [];
  int reenvios = 0;

  /// O que [confirmarCodigo] faz com cada código.
  Object? Function(String codigo) aoConfirmar = (_) => null;

  CodigoDeAcessoPedido _pedido() => CodigoDeAcessoPedido(
    emailMascarado: 'ma***@exemplo.test',
    codigoEnviado: codigoEnviado,
    reenviarAPartirDe: agoraDeTeste.add(const Duration(seconds: 60)),
  );

  @override
  Future<PassoDaEntrada> iniciarEntrada({
    required String email,
    required String senha,
  }) async {
    if (senha != 'senha-certa') {
      throw const RecusaDeRegra(MotivoRecusa.credenciaisInvalidas);
    }
    return _pedido();
  }

  @override
  Future<VinculosDaConta> confirmarCodigo(
    String codigo, {
    required bool confiarNesteAparelho,
  }) async {
    codigos.add((codigo, confiarNesteAparelho));
    final erro = aoConfirmar(codigo);
    if (erro is Exception) throw erro;
    return vinculosAna();
  }

  @override
  Future<CodigoDeAcessoPedido> reenviarCodigo() async {
    reenvios++;
    return _pedido();
  }
}

final Finder _codigo = find.byKey(const Key('campo-codigo'));
final Finder _entrarComCodigo = find.byKey(const Key('entrar-com-codigo'));
final Finder _reenviar = find.byKey(const Key('reenviar-codigo'));

void main() {
  late RelogioFixo relogio;

  setUp(() => relogio = RelogioFixo(agoraDeTeste));

  Future<void> irAoCodigo(
    WidgetTester tester,
    SessaoEspia sessao,
    _AutenticacaoComCodigoFake autenticacao,
  ) async {
    await tester.pumpWidget(
      montarApp(
        sessao: sessao,
        em: Rotas.entrar,
        autenticacao: autenticacao,
        relogio: relogio,
        capacidades: CapacidadesDaFonte.teraeLocal,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'mariana@exemplo.test',
    );
    await tester.enterText(find.byKey(const Key('campo-senha')), 'senha-certa');
    await tester.ensureVisible(find.byKey(const Key('entrar')));
    await tester.tap(find.byKey(const Key('entrar')));
    await tester.pumpAndSettle();
  }

  testWidgets('no modo local, a TM01 não oferece o primeiro acesso', (
    tester,
  ) async {
    await tester.pumpWidget(
      montarApp(
        sessao: SessaoEspia(),
        em: Rotas.entrar,
        capacidades: CapacidadesDaFonte.teraeLocal,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM01')), findsOneWidget);
    expect(find.text('Primeiro acesso?'), findsNothing);
    expect(find.byKey(const Key('ir-primeiro-acesso')), findsNothing);
  });

  testWidgets('no modo local a entrada tem duas etapas como a do portal: '
      '"Etapa 1 de 2", "Continuar" e a frase do código', (tester) async {
    await tester.pumpWidget(
      montarApp(
        sessao: SessaoEspia(),
        em: Rotas.entrar,
        autenticacao: _AutenticacaoComCodigoFake(),
        relogio: relogio,
        capacidades: CapacidadesDaFonte.teraeLocal,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('entrar')),
        matching: find.text('Continuar'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Depois da senha, enviamos um código para o seu e-mail.'),
      findsOneWidget,
    );
    // O app não tem "Esqueci a senha" (não existe no Firebase nem no portal
    // local do app): nada de link morto.
    expect(find.textContaining('Esqueci'), findsNothing);
  });

  testWidgets('no Firebase a entrada é uma etapa só: "Entrar", sem '
      'indicador nem a frase do código', (tester) async {
    await tester.pumpWidget(montarApp(sessao: SessaoEspia(), em: Rotas.entrar));
    await tester.pumpAndSettle();
    expect(find.textContaining('Etapa 1 de'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('entrar')),
        matching: find.text('Entrar'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('frase-do-codigo')), findsNothing);
  });

  testWidgets('a senha certa leva à etapa 2 do portal: e-mail mascarado, '
      '6 caixas, confiar desmarcado e reenviar em 60 s', (tester) async {
    final sessao = SessaoEspia();
    final autenticacao = _AutenticacaoComCodigoFake();
    await irAoCodigo(tester, sessao, autenticacao);

    expect(find.byKey(const Key('TM01-codigo')), findsOneWidget);
    expect(find.text('Digite o código do e-mail'), findsOneWidget);
    expect(
      find.text('Enviamos um código de 6 dígitos para ma***@exemplo.test.'),
      findsOneWidget,
    );
    expect(find.text('Etapa 2 de 2'), findsOneWidget);
    final confiar = tester.widget<CheckboxListTile>(
      find.byKey(const Key('confiar-neste-aparelho')),
    );
    expect(confiar.value, isFalse);
    expect(find.text('Confiar neste aparelho por 30 dias'), findsOneWidget);
    expect(find.text('Reenviar o código em 1:00'), findsOneWidget);
    expect(sessao.entradas, isEmpty);

    // O botão só libera com os 6 dígitos; letras não entram.
    await tester.enterText(_codigo, '12a34');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    final botao = find.descendant(
      of: _entrarComCodigo,
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);

    // Colar preenche as seis caixas.
    await tester.enterText(_codigo, '654321');
    await tester.pump();
    for (final d in ['6', '5', '4', '3', '2', '1']) {
      expect(find.text(d), findsOneWidget);
    }
    await tester.ensureVisible(_entrarComCodigo);
    await tester.tap(_entrarComCodigo);
    await tester.pumpAndSettle();
    expect(autenticacao.codigos, [('654321', false)]);
    expect(sessao.entradas.single.conta.id, 'c-ana');
  });

  testWidgets('o reenvio libera depois de 60 s e avisa o código novo', (
    tester,
  ) async {
    final autenticacao = _AutenticacaoComCodigoFake();
    await irAoCodigo(tester, SessaoEspia(), autenticacao);
    relogio.avancar(const Duration(seconds: 59, milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar o código em 0:01'), findsOneWidget);
    relogio.avancar(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enviar um código novo'), findsOneWidget);

    await tester.ensureVisible(_reenviar);
    await tester.tap(_reenviar);
    await tester.pumpAndSettle();
    expect(autenticacao.reenvios, 1);
    expect(find.byKey(const Key('codigo-reenviado')), findsOneWidget);
    expect(
      find.text('Enviamos um código novo. O anterior deixou de valer.'),
      findsOneWidget,
    );
    expect(find.text('Reenviar o código em 1:00'), findsOneWidget);
  });

  testWidgets('código errado mostra as tentativas; sem tentativas volta à '
      'senha com o recado do portal', (tester) async {
    final autenticacao = _AutenticacaoComCodigoFake()
      ..aoConfirmar = (c) => c == '000000'
          ? const CodigoNaoConfere(tentativasRestantes: 1)
          : const VoltarParaASenha(
              'Você usou as 5 tentativas deste código. Por segurança, entre '
              'de novo com a sua senha.',
            );
    await irAoCodigo(tester, SessaoEspia(), autenticacao);

    await tester.enterText(_codigo, '000000');
    await tester.pump();
    await tester.ensureVisible(_entrarComCodigo);
    await tester.tap(_entrarComCodigo);
    await tester.pumpAndSettle();
    expect(
      find.text('O código não confere. Você ainda tem 1 tentativa.'),
      findsOneWidget,
    );

    await tester.enterText(_codigo, '111111');
    await tester.pump();
    await tester.ensureVisible(_entrarComCodigo);
    await tester.tap(_entrarComCodigo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM01')), findsOneWidget);
    expect(find.textContaining('Você usou as 5 tentativas'), findsOneWidget);
  });

  testWidgets('marcar "Confiar neste aparelho" vai junto com o código', (
    tester,
  ) async {
    final autenticacao = _AutenticacaoComCodigoFake();
    await irAoCodigo(tester, SessaoEspia(), autenticacao);
    await tester.ensureVisible(find.byKey(const Key('confiar-neste-aparelho')));
    await tester.tap(find.byKey(const Key('confiar-neste-aparelho')));
    await tester.enterText(_codigo, '123456');
    await tester.pump();
    await tester.ensureVisible(_entrarComCodigo);
    await tester.tap(_entrarComCodigo);
    await tester.pumpAndSettle();
    expect(autenticacao.codigos, [('123456', true)]);
  });

  testWidgets('"Voltar para a entrada" volta à senha', (tester) async {
    await irAoCodigo(tester, SessaoEspia(), _AutenticacaoComCodigoFake());
    await tester.ensureVisible(find.byKey(const Key('voltar-para-a-senha')));
    await tester.tap(find.byKey(const Key('voltar-para-a-senha')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM01')), findsOneWidget);
    expect(find.text('Entrar no portal'), findsOneWidget);
  });

  testWidgets('código não enviado: o aviso do portal, sem as caixas', (
    tester,
  ) async {
    await irAoCodigo(
      tester,
      SessaoEspia(),
      _AutenticacaoComCodigoFake(codigoEnviado: false),
    );
    expect(find.text('Não conseguimos enviar o código agora'), findsOneWidget);
    expect(_codigo, findsNothing);
    expect(_reenviar, findsOneWidget);
  });

  testWidgets('senha errada continua na senha, com a recusa', (tester) async {
    final sessao = SessaoEspia();
    await tester.pumpWidget(
      montarApp(
        sessao: sessao,
        em: Rotas.entrar,
        autenticacao: _AutenticacaoComCodigoFake(),
        capacidades: CapacidadesDaFonte.teraeLocal,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-email')), 'm@e.test');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'errada1234');
    await tester.ensureVisible(find.byKey(const Key('entrar')));
    await tester.tap(find.byKey(const Key('entrar')));
    await tester.pumpAndSettle();
    expect(
      find.text(MotivoRecusa.credenciaisInvalidas.mensagem),
      findsOneWidget,
    );
    expect(find.byKey(const Key('TM01-codigo')), findsNothing);
  });
}
