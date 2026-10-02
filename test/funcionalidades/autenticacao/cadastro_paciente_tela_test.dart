import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/funcionalidades/autenticacao/cadastro_controlador.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../publico/apoio_telas.dart';
import 'apoio_autenticacao.dart';

final Finder _continuar = find.byKey(const Key('continuar'));
final Finder _google = find.byKey(const Key('continuar-google'));
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

Future<void> _passo3(WidgetTester tester) async {
  await _tocar(tester, find.text(CanalAutorizado.aplicativo.rotulo));
  await _tocar(tester, find.byKey(const Key('aceite-termo')));
  await _tocar(tester, _google);
  await _tocar(tester, find.byKey(Key('conta-${idNova.idProvedor}')));
}

bool _habilitado(WidgetTester tester, Finder botao) => tester
    .widget<ButtonStyleButton>(
      find.descendant(of: botao, matching: find.bySubtype<ButtonStyleButton>()),
    )
    .enabled;

void _noPasso(int passo) {
  expect(find.byKey(const Key('TM09')), findsOneWidget);
  expect(
    find.textContaining('Passo $passo de 3'),
    findsOneWidget,
    reason: 'esperava o passo $passo',
  );
}

void main() {
  testWidgets('avança pelos três passos e ativa com termo, canal e conta', (
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
    expect(_habilitado(tester, _google), isFalse);

    await _passo3(tester);
    final ativacao = autenticacao.ativacoes.single;
    expect(ativacao.qualidade, QualidadeConsentimento.responsavelLegal);
    expect(ativacao.canal, CanalAutorizado.aplicativo);
    expect(ativacao.versaoTermo, versaoTermoConsentimento);
    expect(ativacao.identidade, idNova);
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
