/// O cartão da sessão do portal (quadros 18d e 18i) no Início e na Agenda: o
/// bloco da data, a duração, a clínica ao lado da data, as semanas e o
/// telefone da clínica vindo do paciente (Terae local).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/paciente.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

/// Ana como o Terae local a entrega: com a clínica e, se dado, o telefone.
Sessao _sessaoLocal({String? telefone}) {
  final ana = Paciente(
    id: 'p-ana',
    contaId: 'c-ana',
    profissionalRefId: '',
    nome: 'Ana Lúcia Martins',
    ativo: true,
    nomeDaClinica: 'Clínica Raízes',
    telefoneDaClinica: telefone,
  );
  final base = vinculosAna();
  return Sessao()..entrar(
    VinculosDaConta(
      conta: base.conta,
      pacientes: [ana],
      qualidades: base.qualidades,
    ),
  );
}

Agendamento _em(String id, DateTime instante, {int? minutos}) => Agendamento(
  id: id,
  pacienteId: 'p-ana',
  profissionalId: 'pr-helena',
  dataHora: instante,
  situacao: SituacaoAgendamento.agendado,
  duracaoMinutos: minutos,
);

void main() {
  group('Início: o cartão da próxima sessão do portal', () {
    testWidgets('bloco da data, "14:00 · 50 minutos" e a clínica ao lado da '
        'data', (tester) async {
      final paciente = PacienteComDados(
        consulta: _em('ag-1', instanteNaClinica(2026, 10, 7, 14), minutos: 50),
      );
      await abrirAppDoPaciente(
        tester,
        sessao: _sessaoLocal(),
        paciente: paciente,
      );
      expect(
        find.text('Sexta-feira, 2 de outubro · Clínica Raízes'),
        findsOneWidget,
      );
      final cartao = find.byKey(const Key('proxima-consulta'));
      for (final texto in ['Qua', '7', 'out', '14:00 · 50 minutos']) {
        expect(
          find.descendant(of: cartao, matching: find.text(texto)),
          findsOneWidget,
          reason: texto,
        );
      }
    });

    testWidgets('sem duração (Firebase) só a hora; sem clínica só a data', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester);
      expect(find.text('Sexta-feira, 2 de outubro'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('proxima-consulta')),
          matching: find.text('14:00'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Agenda: as sessões por semana', () {
    testWidgets('"Esta semana", "Próxima semana" e "Semana de dd/mm"', (
      tester,
    ) async {
      // Hoje, sexta 2/10/2026: a semana vai de seg 28/9 a dom 4/10.
      final paciente = PacienteComDados(
        consultas: [
          _em('a', instanteNaClinica(2026, 10, 3, 9)),
          _em('b', instanteNaClinica(2026, 10, 7, 14)),
          _em('c', instanteNaClinica(2026, 10, 8, 10)),
          _em('d', instanteNaClinica(2026, 10, 21, 10)),
        ],
      );
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteSessoes,
        paciente: paciente,
      );
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Próxima semana'), findsOneWidget);
      expect(find.text('Semana de 19/10'), findsOneWidget);
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(find.byKey(Key('sessao-$id')), findsOneWidget, reason: id);
      }
      // A ordem na tela é a da data.
      final topo = [
        for (final id in ['a', 'b', 'c', 'd'])
          tester.getTopLeft(find.byKey(Key('sessao-$id'))).dy,
      ];
      expect([...topo]..sort(), topo);
    });
  });

  group('Falar com a clínica: o telefone vem do paciente', () {
    testWidgets('com o telefone do /eu: Ligar para ele, sem WhatsApp nem '
        '"fictício"', (tester) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteSessoes,
        sessao: _sessaoLocal(telefone: '+55 65 3000-0000'),
      );
      expect(find.byKey(const Key('whatsapp-da-clinica')), findsNothing);
      expect(find.text('+55 65 3000-0000'), findsOneWidget);
      expect(find.textContaining('fictício'), findsNothing);
      await tocar(tester, find.byKey(const Key('ligar-para-a-clinica')));
      expect(app.lancador.abertos.map((u) => u.toString()), [
        'tel:+556530000000',
      ]);
    });

    testWidgets('do portal mas sem telefone: só o convite a falar com a '
        'clínica', (tester) async {
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteSessoes,
        sessao: _sessaoLocal(),
      );
      expect(find.byKey(const Key('ligar-para-a-clinica')), findsNothing);
      expect(find.byKey(const Key('whatsapp-da-clinica')), findsNothing);
      expect(
        find.text('Para remarcar ou tirar dúvidas, fale com a clínica.'),
        findsOneWidget,
      );
    });

    testWidgets('no Firebase continua o número fictício da demonstração', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteSessoes);
      expect(find.byKey(const Key('whatsapp-da-clinica')), findsOneWidget);
      expect(
        find.text('(65) 0000-0000 · número fictício da demonstração'),
        findsOneWidget,
      );
    });
  });
}
