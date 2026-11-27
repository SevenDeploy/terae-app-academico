/// As abas do paciente refazem os lembretes locais (evolução de TO, F2; D28;
/// achado 3 da revisão da F2): ao abrir, ao voltar ao Início e ao voltar do
/// segundo plano, para os 7 dias das atividades de casa não acabarem com o
/// app vivo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/lembretes/lembrete.dart';
import 'package:terae_app/dados/memoria/lembretes_memoria.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../acessibilidade/telas_reais.dart';

Future<MemoriaDemonstracao> _antonioComAtividades(WidgetTester tester) =>
    abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteInicio,
      preparar: (m) => m.repositorios.lembretes.salvar(
        const PreferenciasDeLembrete(
          vesperaDaSessao: true,
          atividadesDeCasa: true,
        ),
      ),
    );

bool _temLembretePelaFrente(MemoriaDemonstracao m) =>
    (m.repositorios.lembretes as LembretesMemoria).agendados.any(
      (l) => l.quando.isAfter(m.relogio.agora()),
    );

void main() {
  testWidgets('ao abrir as abas, os lembretes são feitos com a agenda de '
      'agora', (tester) async {
    final m = await _antonioComAtividades(tester);
    final agendados = (m.repositorios.lembretes as LembretesMemoria).agendados;
    expect(agendados.where((l) => l.texto.startsWith('Amanhã')), hasLength(1));
    expect(
      agendados.where((l) => l.texto.startsWith('Hora das atividades')),
      isNotEmpty,
    );
  });

  testWidgets('8 dias depois, de volta ao Início, há lembretes pela frente', (
    tester,
  ) async {
    final m = await _antonioComAtividades(tester);
    (m.relogio as RelogioFixo).avancar(const Duration(days: 8));
    expect(_temLembretePelaFrente(m), isFalse);
    await tocar(tester, find.text('Agenda').last);
    await tocar(tester, find.text('Início').last);
    expect(_temLembretePelaFrente(m), isTrue);
  });

  testWidgets('8 dias depois, o app volta do segundo plano e refaz', (
    tester,
  ) async {
    final m = await _antonioComAtividades(tester);
    (m.relogio as RelogioFixo).avancar(const Duration(days: 8));
    expect(_temLembretePelaFrente(m), isFalse);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_temLembretePelaFrente(m), isTrue);
  });
}
