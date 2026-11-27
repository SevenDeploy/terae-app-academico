/// TM19 Lembretes (evolução de TO, F2; D28), com a memória real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/memoria/lembretes_memoria.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../acessibilidade/telas_reais.dart';
import 'apoio_paciente.dart';

void main() {
  testWidgets('Antônio abre pela aba Conta, liga a véspera às 20:00 e as '
      'atividades; salva e vê os próximos', (tester) async {
    final m = await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteInicio,
    );
    await tocar(tester, find.byKey(const Key('aba-conta')));
    await tocar(tester, find.byKey(const Key('conta-lembretes')));
    expect(find.byKey(const Key('TM19')), findsOneWidget);
    expect(find.text('Nenhum lembrete agendado.'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('lembrete-vespera')));
    await tocar(
      tester,
      find.descendant(
        of: find.byKey(const Key('hora-da-vespera')),
        matching: find.text('20:00'),
      ),
    );
    await tocar(tester, find.byKey(const Key('lembrete-casa')));
    await tocar(tester, find.byKey(const Key('salvar-lembretes')));
    expect(find.text('Lembretes salvos.'), findsOneWidget);
    expect(
      find.text('Hora das atividades de casa. Depois, conte como foi no app.'),
      findsWidgets,
    );
    final lembretes = m.repositorios.lembretes as LembretesMemoria;
    expect(
      lembretes.agendados.where((l) => l.texto.startsWith('Amanhã')),
      hasLength(1),
    );

    await tocar(tester, find.byKey(const Key('lembrete-de-teste')));
    expect(lembretes.testes, 1);
  });

  testWidgets('ligar as atividades sem escolher a hora: 18:00 aparece '
      'marcada e é a que vale (achado 5)', (tester) async {
    final m = await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteLembretes,
    );
    await tocar(tester, find.byKey(const Key('lembrete-casa')));
    final seletor = find.byKey(const Key('hora-da-casa'));
    expect(
      find.descendant(of: seletor, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: seletor, matching: find.text('18:00')),
      findsOneWidget,
    );
    await tocar(tester, find.byKey(const Key('salvar-lembretes')));
    final casa = (m.repositorios.lembretes as LembretesMemoria).agendados.where(
      (l) => l.texto.startsWith('Hora das atividades'),
    );
    expect(casa, isNotEmpty);
    expect(casa.every((l) => formatarHora(l.quando) == '18:00'), isTrue);
  });

  testWidgets('antes de salvar, diz por que o Android vai pedir a permissão; '
      'depois de dada, o texto some (achado 6)', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteLembretes,
    );
    expect(find.byKey(const Key('motivo-da-permissao')), findsNothing);
    await tocar(tester, find.byKey(const Key('lembrete-vespera')));
    expect(find.byKey(const Key('motivo-da-permissao')), findsOneWidget);
    await tocar(tester, find.byKey(const Key('salvar-lembretes')));
    expect(find.byKey(const Key('motivo-da-permissao')), findsNothing);
  });

  testWidgets('quem já deu a permissão antes não lê que o Android vai '
      'perguntar', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteLembretes,
      preparar: (m) async =>
          (m.repositorios.lembretes as LembretesMemoria).jaPermitiu = true,
    );
    await tocar(tester, find.byKey(const Key('lembrete-vespera')));
    expect(find.byKey(const Key('motivo-da-permissao')), findsNothing);
  });

  testWidgets('sem permissão do Android, explica onde liberar', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteLembretes,
      preparar: (m) async =>
          (m.repositorios.lembretes as LembretesMemoria).permitido = false,
    );
    await tocar(tester, find.byKey(const Key('lembrete-vespera')));
    await tocar(tester, find.byKey(const Key('salvar-lembretes')));
    expect(find.byKey(const Key('sem-permissao')), findsOneWidget);
    expect(find.text('Lembretes salvos.'), findsNothing);
  });

  testWidgets('quem não faz TO não vê a opção das atividades de casa', (
    tester,
  ) async {
    await abrirAppDoPaciente(tester, em: Rotas.pacienteLembretes);
    expect(find.byKey(const Key('lembrete-vespera')), findsOneWidget);
    expect(find.byKey(const Key('lembrete-casa')), findsNothing);
  });
}
