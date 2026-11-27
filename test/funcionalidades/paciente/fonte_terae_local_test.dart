/// As telas como a fonte Terae local as mostra (`CapacidadesDaFonte
/// .teraeLocal`): o que a API do portal não tem some da tela por inteiro,
/// sem botão morto, e o resto fica como no Firebase. Os dados são os da
/// memória de demonstração (Antônio, só terapia ocupacional).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../../acessibilidade/telas_reais.dart';

String _atividade(int n) =>
    'ca000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// "Abotoar…" de Antônio, sem registro hoje.
final String _abotoar = _atividade(5);

/// "Segurar o copo…" de Antônio, feito hoje.
final String _copo = _atividade(6);

Future<void> _abrir(
  WidgetTester tester,
  String em, {
  Persona persona = Persona.antonio,
  CapacidadesDaFonte capacidades = CapacidadesDaFonte.teraeLocal,
}) =>
    abrirComMemoria(tester, persona: persona, em: em, capacidades: capacidades);

void main() {
  testWidgets('Início: sem o atalho do diário e sem o cartão da Jornada', (
    tester,
  ) async {
    await _abrir(tester, Rotas.pacienteInicio);
    expect(find.byKey(const Key('TM02')), findsOneWidget);
    expect(find.byKey(const Key('cartao-jornada')), findsNothing);
    expect(find.byKey(const Key('cartao-diario')), findsNothing);
    expect(find.byKey(const Key('abrir-programa-em-casa')), findsOneWidget);

    await _abrir(
      tester,
      Rotas.pacienteInicio,
      capacidades: CapacidadesDaFonte.completa,
    );
    expect(
      find.byKey(const Key('cartao-jornada')),
      findsOneWidget,
      reason: 'no Firebase, o Início fica como na A5',
    );
    expect(find.byKey(const Key('cartao-diario')), findsOneWidget);
  });

  testWidgets('Diário: a aba existe e diz que está indisponível', (
    tester,
  ) async {
    await _abrir(tester, Rotas.pacienteDiario);
    expect(find.byKey(const Key('diario-indisponivel')), findsOneWidget);
    expect(find.text('Diário ainda indisponível aqui'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing, reason: 'sem botão morto');
  });

  testWidgets('Em casa: sem a faixa dos 14 dias, sem metas, sem Jornada e '
      'sem a ocupação', (tester) async {
    await _abrir(tester, Rotas.pacienteCasa);
    expect(find.byKey(const Key('TM16')), findsOneWidget);
    expect(find.byKey(Key('atividade-$_abotoar')), findsOneWidget);
    expect(find.byKey(const Key('faixa-de-dias')), findsNothing);
    expect(find.text('Últimos 14 dias'), findsNothing);
    expect(find.byKey(const Key('ver-a-jornada-completa')), findsNothing);
    expect(find.text('Autocuidado'), findsNothing);
  });

  testWidgets('Atividade: sem a faixa, sem "Desfazer"; "Corrigir" fica', (
    tester,
  ) async {
    await _abrir(tester, Rotas.atividade(_copo));
    expect(find.byKey(const Key('TM17')), findsOneWidget);
    expect(find.byKey(const Key('faixa-da-atividade')), findsNothing);
    expect(find.byKey(const Key('desfazer-atividade')), findsNothing);
    expect(find.byKey(const Key('corrigir-atividade')), findsOneWidget);
  });

  testWidgets('Conta: sem "Cuidadores que você autorizou"; Lembretes fica', (
    tester,
  ) async {
    await _abrir(tester, Rotas.pacienteConta);
    expect(find.byKey(const Key('TM21')), findsOneWidget);
    expect(find.byKey(const Key('conta-cuidadores')), findsNothing);
    expect(find.byKey(const Key('conta-lembretes')), findsOneWidget);
  });

  testWidgets('Boas-vindas: sem o primeiro acesso e sem o painel de '
      'demonstração', (tester) async {
    await _abrir(tester, Rotas.boasVindas, persona: Persona.semSessao);
    expect(find.byKey(const Key('TM00')), findsOneWidget);
    expect(find.byKey(const Key('ir-entrar')), findsOneWidget);
    expect(find.byKey(const Key('ir-primeiro-acesso')), findsNothing);
    expect(find.byKey(const Key('abrir-painel-demonstracao')), findsNothing);
  });
}
