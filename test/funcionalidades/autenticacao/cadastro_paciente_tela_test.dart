import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/funcionalidades/autenticacao/cadastro_controlador.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import '../publico/apoio_telas.dart';
import 'apoio_autenticacao.dart';

final Finder _continuar = find.byKey(const Key('continuar'));
final Finder _codigo = find.byKey(const Key('campo-codigo'));

Future<void> _abrir(
  WidgetTester tester,
  AutenticacaoFake autenticacao, {
  Sessao? sessao,
}) async {
  await tester.pumpWidget(
    montarApp(
      sessao: sessao ?? SessaoEspia(),
      em: Rotas.cadastroPaciente,
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
  String codigo = 'k7q-2m9',
  String cpf = '52998224725',
  String nascimento = '14032010',
}) async {
  await tester.enterText(_codigo, codigo);
  await tester.enterText(find.byKey(const Key('campo-cpf')), cpf);
  await tester.enterText(find.byKey(const Key('campo-nascimento')), nascimento);
  await _tocar(tester, _continuar);
}

Future<void> _passo2(WidgetTester tester) async {
  await _tocar(
    tester,
    find.text(QualidadeConsentimento.responsavelLegal.rotulo),
  );
  await _tocar(tester, _continuar);
}

/// Passos 3 e 4: canal, aceite, "Continuar" e o acesso de [acesso].
Future<void> _passo3(WidgetTester tester, {NovoAcesso? acesso}) async {
  await _tocar(tester, find.text(CanalAutorizado.aplicativo.rotulo));
  await _tocar(tester, find.byKey(const Key('aceite-termo')));
  await _tocar(tester, _continuar);
  await _criarAcesso(tester, acesso ?? idNova);
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
  expect(find.byKey(const Key('TM09')), findsOneWidget);
  expect(
    find.textContaining('Passo $passo de 4'),
    findsOneWidget,
    reason: 'esperava o passo $passo',
  );
}

void main() {
  testWidgets('avança pelos quatro passos e ativa com termo, canal e acesso', (
    tester,
  ) async {
    final sessao = SessaoEspia();
    final autenticacao = AutenticacaoFake();
    await _abrir(tester, autenticacao, sessao: sessao);
    _noPasso(1);

    await _passo1(tester);
    expect(autenticacao.conferencias, [
      '$codigoDaClinica|$cpfDaPaciente|2010-03-14',
    ]);
    _noPasso(2);
    expect(
      find.text('Encontramos o cadastro de Ana Lúcia Martins.'),
      findsOneWidget,
    );
    expect(_habilitado(tester, _continuar), isFalse);

    await _passo2(tester);
    _noPasso(3);
    expect(find.text('Versão $versaoTermoConsentimento'), findsOneWidget);
    expect(_habilitado(tester, _continuar), isFalse);

    await _passo3(tester);
    final ativacao = autenticacao.ativacoes.single;
    expect(ativacao.qualidade, QualidadeConsentimento.responsavelLegal);
    expect(ativacao.canal, CanalAutorizado.aplicativo);
    expect(ativacao.versaoTermo, versaoTermoConsentimento);
    expect(ativacao.acesso, idNova);
    expect(sessao.entradas, hasLength(1));
  });

  testWidgets('máscaras: código em maiúsculas, CPF e data pontuados', (
    tester,
  ) async {
    await _abrir(tester, AutenticacaoFake());
    await tester.enterText(_codigo, 'k7q-2m9xyz');
    await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
    await tester.enterText(
      find.byKey(const Key('campo-nascimento')),
      '14032010',
    );
    expect(find.text('K7Q2M9'), findsOneWidget);
    expect(find.text('529.982.247-25'), findsOneWidget);
    expect(find.text('14/03/2010'), findsOneWidget);
  });

  testWidgets('erros locais ficam no campo e não chamam o repositório', (
    tester,
  ) async {
    final autenticacao = AutenticacaoFake();
    await _abrir(tester, autenticacao);
    await _tocar(tester, _continuar);
    expect(find.textContaining('O código tem 6 letras'), findsOneWidget);
    expect(find.text('Digite o CPF.'), findsOneWidget);
    expect(find.textContaining('Digite dia, mês e ano'), findsOneWidget);

    await _passo1(tester, cpf: '12345678900', nascimento: '31122030');
    expect(find.text(MotivoRecusa.cpfInvalido.mensagem), findsOneWidget);
    expect(find.textContaining('não pode ser depois de hoje'), findsOneWidget);
    expect(autenticacao.conferencias, isEmpty);
    _noPasso(1);
  });

  group('recusas do passo 1 viram mensagem simples', () {
    for (final (motivo, codigo) in [
      (MotivoRecusa.codigoJaUsado, 'USADO1'),
      (MotivoRecusa.codigoExpirado, 'VENCE1'),
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

    testWidgets('CPF que não é o do convite', (tester) async {
      await _abrir(tester, AutenticacaoFake());
      await _passo1(tester, cpf: cpfDoCuidador);
      _noPasso(1);
      expect(find.text(MotivoRecusa.cpfNaoConfere.mensagem), findsOneWidget);
    });

    testWidgets('nascimento que não confere', (tester) async {
      await _abrir(tester, AutenticacaoFake());
      await _passo1(tester, nascimento: '15032010');
      expect(
        find.text(MotivoRecusa.nascimentoNaoConfere.mensagem),
        findsOneWidget,
      );
    });

    testWidgets('código de cuidador na TM09', (tester) async {
      await _abrir(tester, AutenticacaoFake());
      await _passo1(tester, codigo: codigoDoConvite);
      expect(
        find.text(MotivoRecusa.tipoDeCodigoErrado.mensagem),
        findsOneWidget,
      );
    });
  });

  testWidgets('código usado entre o passo 1 e o 3 volta ao passo 1', (
    tester,
  ) async {
    final sessao = SessaoEspia();
    await _abrir(
      tester,
      AutenticacaoFake(recusaNoPasso3: MotivoRecusa.codigoJaUsado),
      sessao: sessao,
    );
    await _passo1(tester);
    await _passo2(tester);
    await _passo3(tester);
    _noPasso(1);
    expect(find.text(MotivoRecusa.codigoJaUsado.mensagem), findsOneWidget);
    expect(find.text('K7Q2M9'), findsOneWidget, reason: 'o campo é mantido');
    expect(sessao.entradas, isEmpty);
  });

  group('criança (menos de 12 anos) só pelo responsável legal '
      '(ECA art. 2º; LGPD art. 14 § 1º)', () {
    const explicacaoCrianca =
        'Como o paciente tem menos de 12 anos, quem usa o aplicativo e aceita '
        'o termo é a mãe, o pai ou o responsável legal.';
    final titular = find.text(QualidadeConsentimento.titular.rotulo);

    testWidgets('Miguel (7 anos): "o próprio paciente" fica indisponível, '
        'com explicação; ativa pelo responsável', (tester) async {
      final semantica = tester.ensureSemantics();
      final autenticacao = AutenticacaoFake(
        nascimentoDoCadastro: DataCivil(2019, 3, 8),
      );
      await _abrir(tester, autenticacao);
      await _passo1(tester, nascimento: '08032019');
      _noPasso(2);
      expect(
        tester.getSemantics(titular),
        isSemantics(hasEnabledState: true, isEnabled: false, isSelected: false),
      );
      expect(find.text(explicacaoCrianca), findsOneWidget);

      await _tocar(tester, titular);
      expect(
        _habilitado(tester, _continuar),
        isFalse,
        reason: 'tocar no indisponível não escolhe',
      );
      await _passo2(tester);
      await _passo3(tester);
      expect(
        autenticacao.ativacoes.single.qualidade,
        QualidadeConsentimento.responsavelLegal,
      );
      semantica.dispose();
    });

    for (final (nascimento, digitado, crianca) in [
      (DataCivil(2014, 10, 3), '03102014', true),
      (DataCivil(2014, 10, 2), '02102014', false),
    ]) {
      testWidgets(
        'nascido em $nascimento: ${crianca ? '11 anos e 364 dias, '
                  'indisponível' : '12 anos no dia do aniversário, disponível'}',
        (tester) async {
          final semantica = tester.ensureSemantics();
          await _abrir(
            tester,
            AutenticacaoFake(nascimentoDoCadastro: nascimento),
          );
          await _passo1(tester, nascimento: digitado);
          expect(
            tester.getSemantics(titular),
            isSemantics(hasEnabledState: true, isEnabled: !crianca),
          );
          await _tocar(tester, titular);
          expect(_habilitado(tester, _continuar), !crianca);
          semantica.dispose();
        },
      );
    }

    testWidgets('adolescente (16) escolhe o próprio paciente; o aviso fala '
        'só de criança', (tester) async {
      final autenticacao = AutenticacaoFake();
      await _abrir(tester, autenticacao);
      await _passo1(tester);
      expect(
        find.text(
          'Se o paciente for criança (menos de 12 anos), quem usa o aplicativo '
          'e aceita o termo é a mãe, o pai ou o responsável legal.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('adolescente'), findsNothing);
      expect(find.text(explicacaoCrianca), findsNothing);
      await _tocar(tester, titular);
      await _tocar(tester, _continuar);
      await _passo3(tester);
      expect(
        autenticacao.ativacoes.single.qualidade,
        QualidadeConsentimento.titular,
      );
    });

    testWidgets('recusa criancaComoTitular no passo 3 volta ao passo 2 sem '
        'escolha', (tester) async {
      final sessao = SessaoEspia();
      await _abrir(
        tester,
        AutenticacaoFake(recusaNoPasso3: MotivoRecusa.criancaComoTitular),
        sessao: sessao,
      );
      await _passo1(tester);
      await _tocar(tester, titular);
      await _tocar(tester, _continuar);
      await _passo3(tester);
      _noPasso(2);
      expect(
        find.text(MotivoRecusa.criancaComoTitular.mensagem),
        findsOneWidget,
      );
      expect(_habilitado(tester, _continuar), isFalse);
      expect(sessao.entradas, isEmpty);
    });
  });

  testWidgets('voltar do Android e o botão Voltar recuam um passo', (
    tester,
  ) async {
    await _abrir(tester, AutenticacaoFake());
    await _passo1(tester);
    await _passo2(tester);
    _noPasso(3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _noPasso(2);
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'a escolha do passo 2 é mantida',
    );
    await _tocar(tester, find.byKey(const Key('voltar-passo')));
    _noPasso(1);
    expect(find.text('529.982.247-25'), findsOneWidget);
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
    await _passo2(tester);
    semEstouro(tester);
    await _tocar(tester, find.text(CanalAutorizado.impresso.rotulo));
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
    await _passo2(tester);
    await conferirAlvosDeToque(tester);
    semantica.dispose();
  });
}
