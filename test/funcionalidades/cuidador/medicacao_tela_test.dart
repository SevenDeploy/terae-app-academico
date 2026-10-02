import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import '../publico/apoio_telas.dart';
import 'apoio_cuidador.dart';

Future<void> _abrir(WidgetTester tester, {VisaoCuidadorFake? visao}) async {
  await tester.pumpWidget(
    montarApp(
      sessao: Sessao()..entrar(vinculosReginaComPacienteCompleto()),
      em: Rotas.cuidadorMedicacao,
      visaoCuidador: visao ?? VisaoCuidadorFake(),
    ),
  );
  await tester.pumpAndSettle();
}

/// O cartão (Material do `Cartao`) que contém [texto].
Finder _cartaoCom(String texto) =>
    find.ancestor(of: find.text(texto), matching: find.byType(Material)).first;

void main() {
  testWidgets('lista do dia agrupada por horário, com medicamento e dose', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.byKey(const Key('TM11')), findsOneWidget);
    expect(find.text('Sexta-feira, 2 de outubro'), findsOneWidget);

    final manha = _cartaoCom('08:00');
    for (final linha in [
      'Sertralina — 50 mg, 1 comprimido',
      'Vitamina D — 1 gota',
    ]) {
      expect(
        find.descendant(of: manha, matching: find.text(linha)),
        findsOneWidget,
      );
    }
    final noite = _cartaoCom('21:00');
    expect(
      find.descendant(
        of: noite,
        matching: find.text('Melatonina — 3 mg, 1 comprimido'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: noite, matching: find.text('Próximo horário')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _cartaoCom('Quando precisar'),
        matching: find.text('Dipirona — 500 mg, se tiver dor'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('próximos dias e data de renovação da receita', (tester) async {
    await _abrir(tester);
    for (final dia in [
      'Sábado, 3 de outubro',
      'Domingo, 4 de outubro',
      'Segunda-feira, 5 de outubro',
    ]) {
      expect(find.text(dia), findsOneWidget, reason: dia);
    }
    expect(find.text('08:00 — Sertralina, Vitamina D'), findsNWidgets(3));
    expect(
      find.text('Renovar a receita até 08/10/2026 (em 6 dias).'),
      findsOneWidget,
    );
  });

  testWidgets('os próximos dias param no fim da vigência', (tester) async {
    await _abrir(
      tester,
      visao: VisaoCuidadorFake(
        receita: receitaDe(
          vigenciaFim: DataCivil(2026, 10, 3),
          dataRenovacao: DataCivil(2026, 9, 30),
        ),
      ),
    );
    expect(find.text('Sábado, 3 de outubro'), findsOneWidget);
    expect(find.text('Domingo, 4 de outubro'), findsNothing);
    expect(
      find.text('A data de renovar a receita era 30/09/2026 (há 2 dias).'),
      findsOneWidget,
    );
  });

  testWidgets('sem receita vigente, diz isso em linguagem simples', (
    tester,
  ) async {
    await _abrir(tester, visao: VisaoCuidadorFake(semReceita: true));
    expect(find.text('Nenhuma receita em uso agora.'), findsOneWidget);
  });

  testWidgets('somente leitura: nenhum campo nem botão de ação', (
    tester,
  ) async {
    await _abrir(tester);
    final corpo = find.byType(SingleChildScrollView);
    for (final alvo in [
      find.byType(TextField),
      find.byType(Checkbox),
      find.byType(InkWell),
      find.bySubtype<ButtonStyleButton>(),
    ]) {
      expect(find.descendant(of: corpo, matching: alvo), findsNothing);
    }
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('não mostra CPF, nascimento, orientação nem registro', (
    tester,
  ) async {
    await _abrir(tester);
    conferirQueNaoMostraDadoProibido(tester);
  });

  testWidgets('sem estouro com fonte 2× em 360×800', (tester) async {
    telaPequena(tester);
    await _abrir(tester);
    semEstouro(tester);
  });

  testWidgets('alvos de toque de 48 e com rótulo', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester);
    await conferirAlvosDeToque(tester);
    semantica.dispose();
  });
}
