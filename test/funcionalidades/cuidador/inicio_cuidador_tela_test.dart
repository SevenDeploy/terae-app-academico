import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../apoio/dubles.dart';
import '../publico/apoio_telas.dart';
import 'apoio_cuidador.dart';

Future<Sessao> _abrir(
  WidgetTester tester, {
  VisaoCuidadorFake? visao,
  Sessao? sessao,
  Relogio? relogio,
}) async {
  final s = sessao ?? (Sessao()..entrar(vinculosReginaComPacienteCompleto()));
  await tester.pumpWidget(
    montarApp(
      sessao: s,
      em: Rotas.cuidadorInicio,
      visaoCuidador: visao ?? VisaoCuidadorFake(),
      relogio: relogio,
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Finder _em(Key chave, Finder alvo) =>
    find.descendant(of: find.byKey(chave), matching: alvo);

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quem acompanha, aviso, próximo remédio e próxima consulta', (
    tester,
  ) async {
    final visao = VisaoCuidadorFake();
    await _abrir(tester, visao: visao);
    expect(find.byKey(const Key('TM08')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing, reason: 'sem abas');
    expect(find.text('Olá, Regina!'), findsOneWidget);
    expect(find.text('Você acompanha Ana Lúcia Martins'), findsOneWidget);
    expect(find.byKey(const Key('aviso-acesso-limitado')), findsOneWidget);
    expect(find.textContaining('acesso limitado'), findsOneWidget);

    const remedio = Key('proximo-remedio');
    expect(_em(remedio, find.text('Hoje às 21:00')), findsOneWidget);
    expect(
      _em(remedio, find.text('Melatonina — 3 mg, 1 comprimido')),
      findsOneWidget,
    );

    const consulta = Key('proxima-consulta');
    expect(_em(consulta, find.text('Dra. Helena Prado')), findsOneWidget);
    expect(
      _em(consulta, find.text('Quarta-feira, 7 de outubro às 14:00')),
      findsOneWidget,
    );
    expect(_em(consulta, find.text('em 5 dias')), findsOneWidget);

    expect(find.byKey(const Key('conteudo-clinico-bloqueado')), findsOneWidget);
    expect(visao.chamadas.toSet(), {'c-regina|p-ana'});
  });

  testWidgets('passados os horários de hoje, o próximo remédio é amanhã', (
    tester,
  ) async {
    await _abrir(
      tester,
      relogio: RelogioFixo(instanteNaClinica(2026, 10, 2, 22)),
    );
    const remedio = Key('proximo-remedio');
    expect(_em(remedio, find.text('Amanhã às 08:00')), findsOneWidget);
    expect(
      _em(remedio, find.text('Sertralina — 50 mg, 1 comprimido')),
      findsOneWidget,
    );
    expect(_em(remedio, find.text('Vitamina D — 1 gota')), findsOneWidget);
  });

  testWidgets('os atalhos empilham a TM11 e a TM12, e o voltar traz à TM08', (
    tester,
  ) async {
    await _abrir(tester);
    await _tocar(tester, find.byKey(const Key('atalho-medicacao')));
    expect(find.byKey(const Key('TM11')), findsOneWidget);
    await _tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM08')), findsOneWidget);

    await _tocar(tester, find.byKey(const Key('atalho-agenda')));
    expect(find.byKey(const Key('TM12')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM08')), findsOneWidget);
  });

  testWidgets('com um perfil só, o menu tem Sair e não Trocar perfil', (
    tester,
  ) async {
    final sessao = await _abrir(tester);
    await _tocar(tester, find.byKey(const Key('menu-cuidador')));
    expect(find.text('Trocar perfil'), findsNothing);
    await _tocar(tester, find.text('Sair'));
    expect(sessao.autenticada, isFalse);
    expect(find.byKey(const Key('TM00')), findsOneWidget);
  });

  testWidgets('com vários perfis, Trocar perfil reabre a seleção', (
    tester,
  ) async {
    final sessao = Sessao()..entrar(vinculosMistos());
    sessao.escolherPerfil(
      sessao.perfis.firstWhere((p) => p.papel == Papel.cuidador),
    );
    await _abrir(tester, sessao: sessao);
    expect(find.text('Olá, Conta!'), findsOneWidget);
    await _tocar(tester, find.byKey(const Key('menu-cuidador')));
    await _tocar(tester, find.text('Trocar perfil'));
    expect(sessao.perfilAtivo, isNull);
    expect(find.byKey(const Key('TM01')), findsOneWidget);
  });

  testWidgets('acesso negado vira mensagem simples com Tentar de novo', (
    tester,
  ) async {
    final visao = VisaoCuidadorFake()..recusa = MotivoRecusa.acessoNegado;
    await _abrir(tester, visao: visao);
    expect(find.text(MotivoRecusa.acessoNegado.mensagem), findsOneWidget);
    expect(find.byKey(const Key('proximo-remedio')), findsNothing);

    visao.recusa = null;
    await _tocar(tester, find.byKey(const Key('tentar-de-novo')));
    expect(find.text(MotivoRecusa.acessoNegado.mensagem), findsNothing);
    expect(find.text('Hoje às 21:00'), findsOneWidget);
  });

  testWidgets('não mostra CPF, nascimento, motivo nem conteúdo de registro', (
    tester,
  ) async {
    await _abrir(tester);
    conferirQueNaoMostraDadoProibido(tester);
  });

  testWidgets('sem estouro com fonte 2× em 360×800, com o menu aberto', (
    tester,
  ) async {
    telaPequena(tester);
    final sessao = Sessao()..entrar(vinculosMistos());
    sessao.escolherPerfil(
      sessao.perfis.firstWhere((p) => p.papel == Papel.cuidador),
    );
    await _abrir(tester, sessao: sessao);
    semEstouro(tester);
    await _tocar(tester, find.byKey(const Key('menu-cuidador')));
    semEstouro(tester);
  });

  testWidgets('sem estouro com fonte 2× também na mensagem de erro', (
    tester,
  ) async {
    telaPequena(tester);
    await _abrir(
      tester,
      visao: VisaoCuidadorFake()..recusa = MotivoRecusa.acessoNegado,
    );
    semEstouro(tester);
  });

  testWidgets('alvos de toque de 48 e com rótulo', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);
    await conferirAlvosDeToque(tester);
    semantica.dispose();
  });
}
