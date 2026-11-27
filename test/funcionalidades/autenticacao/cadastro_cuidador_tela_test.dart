import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/funcionalidades/autenticacao/widgets_cadastro.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../publico/apoio_telas.dart';
import 'apoio_autenticacao.dart';

final Finder _continuar = find.byKey(const Key('continuar'));

Future<void> _abrir(
  WidgetTester tester,
  AutenticacaoFake autenticacao, {
  Sessao? sessao,
}) async {
  await tester.pumpWidget(
    montarApp(
      sessao: sessao ?? SessaoEspia(),
      em: Rotas.cadastroCuidador,
      autenticacao: autenticacao,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> _passo1(
  WidgetTester tester, {
  String codigo = codigoDoConvite,
  String cpf = cpfDoCuidador,
}) async {
  await tester.enterText(find.byKey(const Key('campo-codigo')), codigo);
  await tester.enterText(find.byKey(const Key('campo-cpf')), cpf);
  await _tocar(tester, _continuar);
}

/// Passos 3 e 4: aceite, "Continuar" e o acesso de Regina.
Future<void> _aceitarEContinuar(WidgetTester tester) async {
  await _tocar(tester, find.byKey(const Key('aceite-termo')));
  await _tocar(tester, _continuar);
  await _criarAcesso(tester, idRegina);
}

/// Passo 4 (D14): nome, e-mail, senha e confirmação, e "Criar acesso".
Future<void> _criarAcesso(WidgetTester tester, NovoAcesso acesso) async {
  await tester.enterText(find.byKey(const Key('campo-nome')), acesso.nome);
  await tester.enterText(find.byKey(const Key('campo-email')), acesso.email);
  await tester.enterText(find.byKey(const Key('campo-senha')), acesso.senha);
  await tester.enterText(
    find.byKey(const Key('campo-confirmacao')),
    acesso.senha,
  );
  await _tocar(tester, find.byKey(const Key('criar-acesso')));
}

bool _habilitado(WidgetTester tester, Finder botao) => tester
    .widget<ButtonStyleButton>(
      find.descendant(of: botao, matching: find.bySubtype<ButtonStyleButton>()),
    )
    .enabled;

void _noPasso(int passo) {
  expect(find.byKey(const Key('TM10')), findsOneWidget);
  expect(
    find.textContaining('Etapa ${etapaDoPasso(passo)} de 3'),
    findsOneWidget,
    reason: 'esperava a etapa do passo $passo',
  );
  expect(
    find.byKey(Key('passo-$passo')),
    findsOneWidget,
    reason: 'esperava o passo $passo',
  );
}

void main() {
  testWidgets('avança pelos quatro passos e aceita com o acesso criado', (
    tester,
  ) async {
    final sessao = SessaoEspia();
    final autenticacao = AutenticacaoFake();
    await _abrir(tester, autenticacao, sessao: sessao);
    _noPasso(1);

    await _passo1(tester);
    expect(autenticacao.conferencias, ['$codigoDoConvite|$cpfDoCuidador']);
    _noPasso(2);
    expect(
      find.text('Ana Lúcia Martins convidou você para acompanhar o cuidado.'),
      findsOneWidget,
    );

    await _tocar(tester, _continuar);
    _noPasso(3);
    expect(_habilitado(tester, _continuar), isFalse);

    await _aceitarEContinuar(tester);
    expect(autenticacao.aceites, [idRegina]);
    expect(sessao.entradas.single.conta.id, 'c-regina');
  });

  testWidgets('o quadro diz o que verá e o que não verá (RNFM05)', (
    tester,
  ) async {
    await _abrir(tester, AutenticacaoFake());
    await _passo1(tester);
    final vera = find.byKey(const Key('quadro-vera'));
    final naoVera = find.byKey(const Key('quadro-nao-vera'));
    for (final trecho in ['agenda', 'remédios', 'avisos']) {
      expect(
        find.descendant(of: vera, matching: find.textContaining(trecho)),
        findsOneWidget,
        reason: trecho,
      );
    }
    for (final trecho in ['evolução clínica', 'diário']) {
      expect(
        find.descendant(of: naoVera, matching: find.textContaining(trecho)),
        findsOneWidget,
        reason: trecho,
      );
    }
  });

  testWidgets('o quadro e o termo servem a quem só faz TO: falam de sessão '
      'ou consulta e só prometem remédios "se houver" (roteiro da A5, CT06; '
      'D29)', (tester) async {
    // O convite público só traz o nome do paciente: antes da conta, a TM10
    // não sabe as linhas de cuidado, e o cuidador de quem só faz TO não vê
    // medicação (D29).
    await _abrir(tester, AutenticacaoFake());
    await _passo1(tester);
    final vera = find.byKey(const Key('quadro-vera'));
    expect(
      find.descendant(
        of: vera,
        matching: find.textContaining('sessão ou consulta'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(of: vera, matching: find.textContaining('Se houver')),
      findsOneWidget,
    );
    expect(find.textContaining('A medicação:'), findsNothing);
    expect(find.textContaining('de cada consulta'), findsNothing);

    await _tocar(tester, _continuar);
    _noPasso(3);
    expect(
      find.textContaining('a agenda, os remédios e os avisos'),
      findsNothing,
    );
    expect(
      find.textContaining('se houver, os horários dos remédios'),
      findsOneWidget,
    );
  });

  testWidgets('aceita com a sessão de verdade e cai na TM08', (tester) async {
    await _abrir(tester, AutenticacaoFake(), sessao: Sessao());
    await _passo1(tester);
    await _tocar(tester, _continuar);
    await _aceitarEContinuar(tester);
    expect(find.byKey(const Key('TM08')), findsOneWidget);
  });

  group('recusas do passo 1 viram mensagem simples', () {
    for (final (motivo, codigo) in [
      (MotivoRecusa.codigoJaUsado, 'USADO2'),
      (MotivoRecusa.codigoExpirado, 'VENCE2'),
      (MotivoRecusa.conviteRevogado, 'REVOG2'),
    ]) {
      testWidgets(motivo.name, (tester) async {
        await _abrir(
          tester,
          AutenticacaoFake(recusaPorCodigo: {codigo: motivo}),
        );
        await _passo1(tester, codigo: codigo);
        _noPasso(1);
        expect(find.text(motivo.mensagem), findsOneWidget);
      });
    }

    testWidgets('CPF diferente do informado pelo paciente', (tester) async {
      await _abrir(tester, AutenticacaoFake());
      await _passo1(tester, cpf: cpfDaPaciente);
      _noPasso(1);
      expect(find.text(MotivoRecusa.cpfNaoConfere.mensagem), findsOneWidget);
    });

    testWidgets('CPF com dígito errado nem chega ao repositório', (
      tester,
    ) async {
      final autenticacao = AutenticacaoFake();
      await _abrir(tester, autenticacao);
      await _passo1(tester, cpf: '11144477700');
      expect(find.text(MotivoRecusa.cpfInvalido.mensagem), findsOneWidget);
      expect(autenticacao.conferencias, isEmpty);
    });
  });

  testWidgets('limite de dois no aceite: fica no passo 4 com a mensagem', (
    tester,
  ) async {
    final sessao = SessaoEspia();
    await _abrir(
      tester,
      AutenticacaoFake(recusaNoPasso3: MotivoRecusa.limiteDeCuidadores),
      sessao: sessao,
    );
    await _passo1(tester);
    await _tocar(tester, _continuar);
    await _aceitarEContinuar(tester);
    _noPasso(4);
    expect(find.text(MotivoRecusa.limiteDeCuidadores.mensagem), findsOneWidget);
    expect(sessao.entradas, isEmpty);
  });

  testWidgets('convite revogado entre o passo 1 e o 3 volta ao passo 1', (
    tester,
  ) async {
    await _abrir(
      tester,
      AutenticacaoFake(recusaNoPasso3: MotivoRecusa.conviteRevogado),
    );
    await _passo1(tester);
    await _tocar(tester, _continuar);
    await _aceitarEContinuar(tester);
    _noPasso(1);
    expect(find.text(MotivoRecusa.conviteRevogado.mensagem), findsOneWidget);
  });

  testWidgets('voltar do Android no passo 2 volta ao passo 1', (tester) async {
    await _abrir(tester, AutenticacaoFake());
    await _passo1(tester);
    _noPasso(2);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _noPasso(1);
  });

  testWidgets('sem estouro com fonte 2× em 360×800, nos três passos', (
    tester,
  ) async {
    telaPequena(tester);
    await _abrir(tester, AutenticacaoFake());
    await _tocar(tester, _continuar);
    semEstouro(tester);
    await _passo1(tester);
    semEstouro(tester);
    await _tocar(tester, _continuar);
    await _tocar(tester, find.byKey(const Key('aceite-termo')));
    semEstouro(tester);
  });

  testWidgets('alvos de toque de 48 e com rótulo, nos três passos', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, AutenticacaoFake());
    await conferirAlvosDeToque(tester);
    await _passo1(tester);
    await conferirAlvosDeToque(tester);
    await _tocar(tester, _continuar);
    await conferirAlvosDeToque(tester);
    semantica.dispose();
  });
}
