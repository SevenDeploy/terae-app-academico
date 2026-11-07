/// TM18 Sessões (evolução de TO, F2; D27, D29) com a memória real: a
/// confirmação de presença na voz de quem usa o app, "Falar com a clínica",
/// o cartão do Início e o que o cuidador vê.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../../acessibilidade/telas_reais.dart';
import 'apoio_paciente.dart';

String _ag(int n) => 'ad000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// Sessão do Miguel daqui a 3 dias; do Antônio, daqui a 7.
final String _sessaoMiguel = _ag(6);
final String _sessaoAntonio = _ag(12);

Future<void> _comoMiguel(WidgetTester tester, {required String em}) async {
  await abrirComMemoria(
    tester,
    persona: Persona.patricia,
    em: Rotas.entrarPerfil,
  );
  await tocar(tester, find.text('Miguel Andrade Neves'));
}

void main() {
  group('TM18 Sessões', () {
    testWidgets('a mãe responde "Sim, vamos" e depois muda para "Não vamos '
        'conseguir"; a sessão continua marcada', (tester) async {
      await _comoMiguel(tester, em: Rotas.pacienteInicio);
      final cartao = find.byKey(const Key('proxima-consulta'));
      expect(
        find.descendant(
          of: cartao,
          matching: find.text('PRÓXIMA SESSÃO DE MIGUEL'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cartao, matching: find.text('Vocês vão? Responda')),
        findsOneWidget,
      );
      await tocar(tester, cartao);
      expect(find.byKey(const Key('TM18')), findsOneWidget);
      expect(find.text('Vocês vão?'), findsOneWidget);
      expect(find.text('Sessão de terapia ocupacional'), findsWidgets);

      await tocar(tester, find.byKey(Key('vamos-$_sessaoMiguel')));
      expect(find.text('A clínica recebeu sua resposta.'), findsOneWidget);
      await tocar(tester, find.byKey(Key('mudar-$_sessaoMiguel')));
      await tocar(tester, find.byKey(Key('nao-vamos-$_sessaoMiguel')));
      expect(
        find.textContaining('A clínica foi avisada. A sessão continua marcada'),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('proxima-consulta')),
          matching: find.text('Avisaram que não vão'),
        ),
        findsOneWidget,
        reason: 'o Início relê a resposta ao voltar',
      );
    });

    testWidgets('o titular lê "Você vai?" e "Sim, vou"; sem conexão, a '
        'resposta fica guardada', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteSessoes,
        preparar: (m) =>
            m.repositorios.demonstracao.definirSemConexao(semConexao: true),
      );
      expect(find.text('Você vai?'), findsOneWidget);
      expect(find.text('Sua agenda'), findsOneWidget);
      await tocar(tester, find.byKey(Key('vamos-$_sessaoAntonio')));
      expect(find.text('Sim, vou'), findsOneWidget);
      expect(
        find.textContaining('Guardado no aparelho. Vai para a clínica'),
        findsOneWidget,
      );
      expect(
        m.estado.filaPresenca[_sessaoAntonio]!.situacaoEnvio,
        SituacaoEnvio.naFila,
      );
      expect(
        m.estado.filaPresenca[_sessaoAntonio]!.resposta,
        RespostaPresenca.vamos,
      );
    });

    testWidgets('anteriores aparecem com a situação; a Ana já confirmou a '
        'consulta', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteSessoes,
      );
      expect(find.text('Consultas e sessões'), findsOneWidget);
      expect(find.byKey(Key('resposta-${_ag(3)}')), findsOneWidget);
      expect(
        find.text('Sessão de terapia ocupacional com Tiago Moreira'),
        findsOneWidget,
      );
      expect(find.text('Realizada'), findsWidgets);
    });

    testWidgets('"Falar com a clínica" liga ou abre o WhatsApp do número '
        'fictício', (tester) async {
      final app = await abrirAppDoPaciente(tester, em: Rotas.pacienteSessoes);
      await tocar(tester, find.byKey(const Key('ligar-para-a-clinica')));
      await tocar(tester, find.byKey(const Key('whatsapp-da-clinica')));
      expect(app.lancador.abertos.map((u) => u.toString()), [
        'tel:+556500000000',
        'https://wa.me/556500000000',
      ]);
    });
  });

  group('textos do encontro (F2)', () {
    testWidgets('Antônio: "Sua próxima sessão"; a Jornada da Ana chama a TO '
        'de sessão', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteInicio,
      );
      expect(find.text('SUA PRÓXIMA SESSÃO'), findsOneWidget);
    });

    testWidgets('a cuidadora vê a presença confirmada (D29)', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.regina,
        em: Rotas.cuidadorInicio,
      );
      expect(find.text('Presença confirmada'), findsOneWidget);
      expect(find.byKey(const Key('atalho-medicacao')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('atalho-agenda')));
      expect(find.text('Presença confirmada'), findsOneWidget);
    });
  });
}
