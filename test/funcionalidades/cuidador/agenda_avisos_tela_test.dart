import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/repositorios/visao_cuidador_repositorio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../publico/apoio_telas.dart';
import 'apoio_cuidador.dart';

Future<void> _abrir(WidgetTester tester, {VisaoCuidadorFake? visao}) async {
  await tester.pumpWidget(
    montarApp(
      sessao: Sessao()..entrar(vinculosReginaComPacienteCompleto()),
      em: Rotas.cuidadorAgenda,
      visaoCuidador: visao ?? VisaoCuidadorFake(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _em(Key chave, Finder alvo) =>
    find.descendant(of: find.byKey(chave), matching: alvo);

void main() {
  testWidgets('próximas consultas: data, hora e profissional, em ordem', (
    tester,
  ) async {
    await _abrir(tester);
    expect(find.byKey(const Key('TM12')), findsOneWidget);
    expect(
      find.byKey(const Key('consulta-ag-0')),
      findsNothing,
      reason: 'já passou',
    );
    expect(
      find.byKey(const Key('consulta-ag-2')),
      findsNothing,
      reason: 'cancelada',
    );

    const primeira = Key('consulta-ag-1');
    expect(
      _em(primeira, find.text('Quarta-feira, 7 de outubro')),
      findsOneWidget,
    );
    expect(_em(primeira, find.text('às 14:00')), findsOneWidget);
    expect(_em(primeira, find.text('Dra. Helena Prado')), findsOneWidget);
    expect(_em(primeira, find.text('Psiquiatria')), findsOneWidget);
    expect(_em(primeira, find.text('em 5 dias')), findsOneWidget);

    const segunda = Key('consulta-ag-3');
    expect(_em(segunda, find.text('às 10:30')), findsOneWidget);
    expect(_em(segunda, find.text('Dra. Larissa Campos')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(primeira)).dy,
      lessThan(tester.getTopLeft(find.byKey(segunda)).dy),
    );
  });

  testWidgets('sessão de TO cancelada vira "Sessão cancelada" (F2)', (
    tester,
  ) async {
    await _abrir(
      tester,
      visao: VisaoCuidadorFake(
        consultas: [
          ...consultasDeTeste,
          consultaDe(
            'ag-4',
            instanteNaClinica(2026, 10, 15, 9),
            profissionalId: 'pr-larissa',
            situacao: SituacaoAgendamento.cancelado,
          ),
        ],
      ),
    );
    expect(
      _em(const Key('aviso-cancelada-ag-4'), find.text('Sessão cancelada')),
      findsOneWidget,
    );
    expect(
      _em(const Key('aviso-cancelada-ag-2'), find.text('Consulta cancelada')),
      findsOneWidget,
    );
  });

  testWidgets('avisos de consulta cancelada e de renovação próxima', (
    tester,
  ) async {
    await _abrir(tester);
    const cancelada = Key('aviso-cancelada-ag-2');
    expect(_em(cancelada, find.text('Consulta cancelada')), findsOneWidget);
    expect(
      _em(cancelada, find.text('Quarta-feira, 14 de outubro às 09:00')),
      findsOneWidget,
    );
    expect(_em(cancelada, find.text('Com Dra. Helena Prado')), findsOneWidget);
    expect(
      _em(
        const Key('aviso-renovacao'),
        find.text('Renovar a receita até 08/10/2026 (em 6 dias).'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renovação distante não vira aviso', (tester) async {
    await _abrir(
      tester,
      visao: VisaoCuidadorFake(
        receita: receitaDe(dataRenovacao: DataCivil(2026, 11, 20)),
      ),
    );
    expect(find.byKey(const Key('aviso-renovacao')), findsNothing);
  });

  testWidgets('alerta à equipe só com data, hora e ciência do profissional', (
    tester,
  ) async {
    await _abrir(tester);
    const visto = Key('aviso-alerta-0');
    const naoVisto = Key('aviso-alerta-1');
    expect(_em(visto, find.text('Aviso enviado à equipe')), findsOneWidget);
    expect(_em(visto, find.text('Em 01/10/2026 às 22:10')), findsOneWidget);
    expect(
      _em(visto, find.text('O profissional viu em 02/10/2026 às 08:05.')),
      findsOneWidget,
    );
    expect(_em(naoVisto, find.text('Em 28/09/2026 às 19:30')), findsOneWidget);
    expect(
      _em(naoVisto, find.text('O profissional ainda não viu.')),
      findsOneWidget,
    );
    for (final chave in [visto, naoVisto]) {
      expect(
        _em(chave, find.byType(Text)),
        findsNWidgets(3),
        reason: 'título, data e hora, ciência — e nada mais',
      );
    }
  });

  testWidgets('a hora do alerta sai no fuso da clínica (−04:00)', (
    tester,
  ) async {
    await _abrir(
      tester,
      visao: VisaoCuidadorFake(
        alertas: [AvisoDeAlerta(emitidoEm: DateTime.utc(2026, 10, 2, 1, 30))],
      ),
    );
    expect(find.text('Em 01/10/2026 às 21:30'), findsOneWidget);
  });

  testWidgets('sem consultas nem avisos, diz isso', (tester) async {
    await _abrir(
      tester,
      visao: VisaoCuidadorFake(
        consultas: const [],
        alertas: const [],
        receita: receitaDe(dataRenovacao: DataCivil(2026, 12, 1)),
      ),
    );
    expect(find.text('Nenhuma consulta marcada.'), findsOneWidget);
    expect(find.text('Nenhum aviso agora.'), findsOneWidget);
  });

  testWidgets('não mostra CPF, nascimento, motivo nem conteúdo de registro', (
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
