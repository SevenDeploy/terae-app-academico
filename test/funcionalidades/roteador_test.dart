import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/roteador.dart';

import '../apoio/app_de_teste.dart';
import '../apoio/dubles.dart';

/// Monta o app com dublês e devolve o roteador.
Future<GoRouter> _abrir(
  WidgetTester tester,
  Sessao sessao, {
  String em = Rotas.boasVindas,
}) async {
  await tester.pumpWidget(appDeTeste(sessao: sessao, em: em));
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

Future<void> _ir(WidgetTester tester, GoRouter roteador, String rota) async {
  roteador.go(rota);
  await tester.pumpAndSettle();
}

String _local(GoRouter roteador) =>
    roteador.routerDelegate.currentConfiguration.uri.path;

/// Só a tela [tela] está visível entre as 13 (TM00…TM12).
void _naTela(String tela) {
  for (final outra in Rotas.porTela.keys) {
    expect(
      find.byKey(Key(outra)),
      outra == tela ? findsOneWidget : findsNothing,
      reason: 'esperava só $tela na tela',
    );
  }
}

final Finder _barraDeAbas = find.byType(NavigationBar);

Future<void> _voltarDoAndroid(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('guardaDePerfil (função pura)', () {
    test('sem sessão: públicas abrem, o resto vai para a TM00', () {
      final sessao = Sessao();
      for (final rota in Rotas.todas) {
        expect(
          guardaDePerfil(sessao, rota),
          Rotas.publicas.contains(rota) ? isNull : Rotas.boasVindas,
          reason: rota,
        );
      }
      expect(guardaDePerfil(sessao, '/inexistente'), Rotas.boasVindas);
    });

    test('cada papel só alcança as próprias rotas', () {
      // Com as duas linhas de cuidado, o paciente alcança todas as suas.
      final paciente = Sessao()..entrar(vinculosAna(linhas: asDuasLinhas));
      final cuidador = Sessao()..entrar(vinculosRegina());
      for (final rota in Rotas.todas) {
        expect(
          guardaDePerfil(paciente, rota),
          Rotas.doPaciente.contains(rota) ? isNull : Rotas.pacienteInicio,
          reason: 'paciente em $rota',
        );
        expect(
          guardaDePerfil(cuidador, rota),
          Rotas.doCuidador.contains(rota) ? isNull : Rotas.cuidadorInicio,
          reason: 'cuidador em $rota',
        );
      }
    });

    test('sem perfil ativo, tudo leva à seleção de perfil', () {
      final sessao = Sessao()..entrar(vinculosPatricia());
      for (final rota in Rotas.todas) {
        expect(
          guardaDePerfil(sessao, rota),
          rota == Rotas.entrarPerfil ? isNull : Rotas.entrarPerfil,
          reason: rota,
        );
      }
    });
  });

  group('sem sessão', () {
    testWidgets('só as rotas públicas abrem', (tester) async {
      final roteador = await _abrir(tester, Sessao());
      _naTela('TM00');

      await _ir(tester, roteador, Rotas.entrar);
      _naTela('TM01');
      await _ir(tester, roteador, Rotas.cadastroPaciente);
      _naTela('TM09');
      await _ir(tester, roteador, Rotas.cadastroCuidador);
      _naTela('TM10');

      for (final rota in [
        ...Rotas.doPaciente,
        ...Rotas.doCuidador,
        Rotas.entrarPerfil,
        '/inexistente',
      ]) {
        await _ir(tester, roteador, rota);
        expect(_local(roteador), Rotas.boasVindas, reason: rota);
        _naTela('TM00');
      }
    });

    testWidgets('link direto para o diário abre a TM00', (tester) async {
      await _abrir(tester, Sessao(), em: Rotas.pacienteDiario);
      _naTela('TM00');
    });
  });

  group('perfil paciente/família', () {
    testWidgets('entrar leva ao Início com a barra de abas', (tester) async {
      final sessao = Sessao();
      final roteador = await _abrir(tester, sessao, em: Rotas.entrar);
      sessao.entrar(vinculosAna());
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.pacienteInicio);
      _naTela('TM02');
      expect(_barraDeAbas, findsOneWidget);
    });

    testWidgets('as três abas (sem TO), TM07, TM04 e TM05 abrem; o resto '
        'volta ao Início', (tester) async {
      final sessao = Sessao()..entrar(vinculosAna());
      final roteador = await _abrir(tester, sessao);
      _naTela('TM02');

      await tester.tap(find.byKey(const Key('aba-diario')));
      await tester.pumpAndSettle();
      _naTela('TM03');
      await tester.tap(find.byKey(const Key('aba-jornada')));
      await tester.pumpAndSettle();
      _naTela('TM06');

      // D22: a TM07 saiu da barra; abre empilhada, sem as abas.
      await _ir(tester, roteador, Rotas.pacienteCuidadores);
      _naTela('TM07');
      expect(_barraDeAbas, findsNothing, reason: 'TM07 sem as abas');

      await _ir(tester, roteador, Rotas.pacienteDiarioEnviado);
      _naTela('TM04');
      expect(_barraDeAbas, findsNothing, reason: 'TM04 em tela cheia');
      await _ir(tester, roteador, Rotas.pacienteDiarioAjuda);
      _naTela('TM05');
      expect(_barraDeAbas, findsNothing, reason: 'TM05 em tela cheia');

      for (final rota in [
        ...Rotas.publicas,
        ...Rotas.doCuidador,
        Rotas.entrarPerfil,
        '/inexistente',
      ]) {
        await _ir(tester, roteador, rota);
        expect(_local(roteador), Rotas.pacienteInicio, reason: rota);
        _naTela('TM02');
      }
    });

    testWidgets('a barra marca a aba ativa como selecionada', (tester) async {
      final semantica = tester.ensureSemantics();
      final sessao = Sessao()..entrar(vinculosAna());
      await _abrir(tester, sessao, em: Rotas.pacienteJornada);
      expect(
        tester.getSemantics(find.byKey(const Key('aba-jornada'))),
        isSemantics(isSelected: true, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('aba-inicio'))),
        isSemantics(isSelected: false),
      );
      semantica.dispose();
    });

    testWidgets('voltar do Android: aba → Início; TM04/TM05 → Início', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosAna());
      final roteador = await _abrir(tester, sessao, em: Rotas.pacienteJornada);
      _naTela('TM06');
      await _voltarDoAndroid(tester);
      expect(_local(roteador), Rotas.pacienteInicio);
      _naTela('TM02');

      for (final rota in [
        Rotas.pacienteDiarioEnviado,
        Rotas.pacienteDiarioAjuda,
      ]) {
        await _ir(tester, roteador, rota);
        await _voltarDoAndroid(tester);
        expect(_local(roteador), Rotas.pacienteInicio, reason: rota);
        _naTela('TM02');
      }
    });

    testWidgets('no Início, voltar do Android não é tratado (fecha o app)', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosAna());
      await _abrir(tester, sessao);
      expect(await tester.binding.handlePopRoute(), isFalse);
    });

    testWidgets('sair leva à TM00', (tester) async {
      final sessao = Sessao()..entrar(vinculosAna());
      final roteador = await _abrir(tester, sessao, em: Rotas.pacienteDiario);
      sessao.sair();
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.boasVindas);
      _naTela('TM00');
    });
  });

  group('linhas de cuidado (D21, D22)', () {
    test('a guarda recusa "Em casa" a quem não tem terapia ocupacional', () {
      final clinico = Sessao()..entrar(vinculosAna());
      final to = Sessao()..entrar(vinculosAntonio());
      expect(guardaDePerfil(clinico, Rotas.pacienteCasa), Rotas.pacienteInicio);
      expect(guardaDePerfil(to, Rotas.pacienteCasa), isNull);
      // O diário vale para todos (o alerta da crítica também protege a
      // família de TO).
      for (final sessao in [clinico, to]) {
        expect(guardaDePerfil(sessao, Rotas.pacienteDiario), isNull);
        expect(guardaDePerfil(sessao, Rotas.pacienteRegistros), isNull);
      }
      final cuidador = Sessao()..entrar(vinculosRegina());
      expect(
        guardaDePerfil(cuidador, Rotas.pacienteCasa),
        Rotas.cuidadorInicio,
      );
    });

    Iterable<String> abasNaBarra(WidgetTester tester) => [
      for (final destino in tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      ))
        (destino.key! as ValueKey<String>).value,
    ];

    testWidgets('sem TO: três abas e link direto para Em casa volta ao '
        'Início', (tester) async {
      final sessao = Sessao()..entrar(vinculosAna());
      final roteador = await _abrir(tester, sessao, em: Rotas.pacienteCasa);
      expect(_local(roteador), Rotas.pacienteInicio);
      _naTela('TM02');
      expect(abasNaBarra(tester), ['aba-inicio', 'aba-diario', 'aba-jornada']);
    });

    testWidgets('só TO (Antônio): Em casa entre o Diário e a Jornada, e '
        'cada aba abre a própria tela', (tester) async {
      final sessao = Sessao()..entrar(vinculosAntonio());
      final roteador = await _abrir(tester, sessao);
      expect(abasNaBarra(tester), [
        'aba-inicio',
        'aba-diario',
        'aba-casa',
        'aba-jornada',
      ]);
      for (final (aba, tela, rota) in [
        ('aba-casa', 'TM16', Rotas.pacienteCasa),
        ('aba-jornada', 'TM06', Rotas.pacienteJornada),
        ('aba-diario', 'TM03', Rotas.pacienteDiario),
        ('aba-inicio', 'TM02', Rotas.pacienteInicio),
      ]) {
        await tester.tap(find.byKey(Key(aba)));
        await tester.pumpAndSettle();
        expect(_local(roteador), rota, reason: aba);
        _naTela(tela);
      }
    });

    testWidgets('a barra marca Em casa como selecionada; voltar leva ao '
        'Início', (tester) async {
      final semantica = tester.ensureSemantics();
      final sessao = Sessao()..entrar(vinculosAna(linhas: asDuasLinhas));
      final roteador = await _abrir(tester, sessao, em: Rotas.pacienteCasa);
      _naTela('TM16');
      expect(
        tester.getSemantics(find.byKey(const Key('aba-casa'))),
        isSemantics(isSelected: true, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('aba-diario'))),
        isSemantics(isSelected: false),
      );
      await _voltarDoAndroid(tester);
      expect(_local(roteador), Rotas.pacienteInicio);
      _naTela('TM02');
      semantica.dispose();
    });
  });

  testWidgets('TM07: voltar (seta ou Android) leva ao Início, mesmo por link '
      'direto (D22)', (tester) async {
    final sessao = Sessao()..entrar(vinculosAna());
    final roteador = await _abrir(tester, sessao, em: Rotas.pacienteCuidadores);
    _naTela('TM07');
    await _voltarDoAndroid(tester);
    expect(_local(roteador), Rotas.pacienteInicio);
    _naTela('TM02');

    unawaited(roteador.push(Rotas.pacienteCuidadores));
    await tester.pumpAndSettle();
    _naTela('TM07');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_local(roteador), Rotas.pacienteInicio);
    _naTela('TM02');
  });

  group('perfil cuidador', () {
    testWidgets('link direto para /paciente/diario cai em /cuidador/inicio', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosRegina());
      final roteador = await _abrir(tester, sessao, em: Rotas.pacienteDiario);
      expect(_local(roteador), Rotas.cuidadorInicio);
      _naTela('TM08');
      expect(_barraDeAbas, findsNothing, reason: 'cuidador não tem abas');

      for (final rota in [
        ...Rotas.doPaciente,
        ...Rotas.publicas,
        Rotas.entrarPerfil,
        '/inexistente',
      ]) {
        await _ir(tester, roteador, rota);
        expect(_local(roteador), Rotas.cuidadorInicio, reason: rota);
        _naTela('TM08');
      }
    });

    testWidgets('TM11 e TM12 empilham sobre a TM08 e voltam a ela', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosRegina());
      final roteador = await _abrir(tester, sessao);
      _naTela('TM08');

      for (final rota in [Rotas.cuidadorMedicacao, Rotas.cuidadorAgenda]) {
        unawaited(roteador.push(rota));
        await tester.pumpAndSettle();
        _naTela(rota == Rotas.cuidadorMedicacao ? 'TM11' : 'TM12');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(_local(roteador), Rotas.cuidadorInicio, reason: rota);
        _naTela('TM08');
      }

      await _ir(tester, roteador, Rotas.cuidadorAgenda);
      _naTela('TM12');
      await _voltarDoAndroid(tester);
      expect(_local(roteador), Rotas.cuidadorInicio);
      _naTela('TM08');
    });

    testWidgets('sair leva à TM00', (tester) async {
      final sessao = Sessao()..entrar(vinculosRegina());
      final roteador = await _abrir(tester, sessao);
      sessao.sair();
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.boasVindas);
      _naTela('TM00');
    });
  });

  group('conta com mais de um perfil', () {
    testWidgets('entrar leva a /entrar/perfil e nada mais abre', (
      tester,
    ) async {
      final sessao = Sessao();
      final roteador = await _abrir(tester, sessao, em: Rotas.entrar);
      sessao.entrar(vinculosPatricia());
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.entrarPerfil);
      _naTela('TM01');

      for (final rota in [Rotas.pacienteInicio, Rotas.cuidadorInicio]) {
        await _ir(tester, roteador, rota);
        expect(_local(roteador), Rotas.entrarPerfil, reason: rota);
      }
    });

    testWidgets('escolher abre o início do papel; trocar reabre a seleção', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosMistos());
      final roteador = await _abrir(tester, sessao);
      expect(_local(roteador), Rotas.entrarPerfil);

      sessao.escolherPerfil(
        sessao.perfis.firstWhere((p) => p.papel == Papel.cuidador),
      );
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.cuidadorInicio);
      _naTela('TM08');
      await _ir(tester, roteador, Rotas.pacienteInicio);
      expect(_local(roteador), Rotas.cuidadorInicio);

      sessao.trocarPerfil();
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.entrarPerfil);
      _naTela('TM01');

      sessao.escolherPerfil(
        sessao.perfis.firstWhere((p) => p.papel == Papel.pacienteFamilia),
      );
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.pacienteInicio);
      _naTela('TM02');
    });

    testWidgets('sair da seleção leva à TM00', (tester) async {
      final sessao = Sessao()..entrar(vinculosPatricia());
      final roteador = await _abrir(tester, sessao);
      sessao.sair();
      await tester.pumpAndSettle();
      expect(_local(roteador), Rotas.boasVindas);
    });
  });
}
