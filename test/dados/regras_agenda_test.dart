/// A Agenda agrupada por semana, como `agruparPorSemana` do portal
/// (`apps/portal/src/estado/agenda.ts`; quadro 18i).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/regras/agenda.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

Agendamento _sessao(String id, DateTime instante) => Agendamento(
  id: id,
  pacienteId: 'p',
  profissionalId: 'pr',
  dataHora: instante,
  situacao: SituacaoAgendamento.agendado,
);

void main() {
  // Quinta, 26/11/2026, 10:00 na clínica: a semana vai de seg 23/11 a dom 29/11.
  final agora = instanteNaClinica(2026, 11, 26, 10);

  group('segundaDaSemana', () {
    test('segunda a domingo, no dia civil da clínica', () {
      final segunda = DataCivil(2026, 11, 23);
      for (var dia = 23; dia <= 29; dia++) {
        expect(
          segundaDaSemana(DataCivil(2026, 11, dia)),
          segunda,
          reason: '$dia',
        );
      }
      expect(segundaDaSemana(DataCivil(2026, 11, 30)), DataCivil(2026, 11, 30));
      // Vira de mês.
      expect(segundaDaSemana(DataCivil(2026, 12, 2)), DataCivil(2026, 11, 30));
    });
  });

  group('agruparPorSemana', () {
    test('"Esta semana", "Próxima semana" e "Semana de dd/mm"', () {
      final semanas = agruparPorSemana([
        _sessao('a', instanteNaClinica(2026, 11, 27, 8)),
        _sessao('b', instanteNaClinica(2026, 11, 27, 15)),
        _sessao('c', instanteNaClinica(2026, 12, 1, 9)),
        _sessao('d', instanteNaClinica(2026, 12, 8, 9)),
        _sessao('e', instanteNaClinica(2026, 12, 16, 9)),
      ], agora);
      expect(semanas.map((s) => s.titulo), [
        'Esta semana',
        'Próxima semana',
        'Semana de 07/12',
        'Semana de 14/12',
      ]);
      expect(semanas.map((s) => s.sessoes.map((a) => a.id).toList()), [
        ['a', 'b'],
        ['c'],
        ['d'],
        ['e'],
      ]);
      expect(semanas.first.segunda, DataCivil(2026, 11, 23));
    });

    test('domingo à noite na clínica ainda é a semana que acaba (o instante '
        'em UTC já é segunda)', () {
      // 29/11 20:00 em Cuiabá = 30/11 00:00Z.
      final domingo = instanteNaClinica(2026, 11, 29, 20);
      expect(domingo.day, 30);
      final semanas = agruparPorSemana([_sessao('d', domingo)], agora);
      expect(semanas.single.titulo, 'Esta semana');
    });

    test('segunda de manhã na clínica abre a próxima semana', () {
      final semanas = agruparPorSemana([
        _sessao('s', instanteNaClinica(2026, 11, 30, 7)),
      ], agora);
      expect(semanas.single.titulo, 'Próxima semana');
    });

    test('sessão de semana que já passou também se chama "Esta semana", como '
        'no portal (a Agenda só traz as que vêm pela frente)', () {
      final semanas = agruparPorSemana([
        _sessao('antiga', instanteNaClinica(2026, 11, 10, 9)),
        _sessao('hoje', instanteNaClinica(2026, 11, 26, 14)),
      ], agora);
      expect(semanas.map((s) => s.titulo), ['Esta semana', 'Esta semana']);
      expect(semanas.map((s) => s.segunda), [
        DataCivil(2026, 11, 9),
        DataCivil(2026, 11, 23),
      ]);
    });

    test('sem sessões, sem semanas', () {
      expect(agruparPorSemana(const [], agora), isEmpty);
    });
  });
}
