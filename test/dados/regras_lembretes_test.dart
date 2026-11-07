/// Quais lembretes agendar (evolução de TO, F2; D28).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/lembretes/lembrete.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/regras/lembretes.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

/// 2/10/2026 10:00 na clínica.
final DateTime _agora = instanteNaClinica(2026, 10, 2, 10);

Agendamento _sessao(String id, DateTime quando, {bool cancelada = false}) =>
    Agendamento(
      id: id,
      pacienteId: 'p',
      profissionalId: 'pr',
      dataHora: quando,
      situacao: cancelada
          ? SituacaoAgendamento.cancelado
          : SituacaoAgendamento.agendado,
    );

void main() {
  test('tudo desligado: nenhum lembrete', () {
    expect(
      lembretesPara(
        preferencias: const PreferenciasDeLembrete(),
        sessoes: [_sessao('a', instanteNaClinica(2026, 10, 5, 14))],
        temAtividades: true,
        agora: _agora,
      ),
      isEmpty,
    );
  });

  test('véspera: na hora escolhida do dia anterior, só de sessão marcada e '
      'futura; a de amanhã cedo cuja véspera já passou fica de fora', () {
    final lembretes = lembretesPara(
      preferencias: const PreferenciasDeLembrete(
        vesperaDaSessao: true,
        horaDaVespera: 20,
      ),
      sessoes: [
        _sessao('depois', instanteNaClinica(2026, 10, 7, 14)),
        _sessao('amanha', instanteNaClinica(2026, 10, 3, 8)),
        _sessao('hoje-cedo', instanteNaClinica(2026, 10, 2, 9)),
        _sessao(
          'cancelada',
          instanteNaClinica(2026, 10, 9, 9),
          cancelada: true,
        ),
      ],
      temAtividades: false,
      agora: _agora,
    );
    expect(lembretes.map((l) => l.quando), [
      instanteNaClinica(2026, 10, 2, 20),
      instanteNaClinica(2026, 10, 6, 20),
    ]);
    expect(
      lembretes.first.texto,
      'Amanhã às 08:00 tem compromisso na clínica.',
    );
    expect(lembretes.every((l) => l.titulo == 'Terae'), isTrue);
  });

  test('atividades de casa: um por dia nos próximos 7, a partir de hoje se '
      'a hora ainda não passou', () {
    final cedo = lembretesPara(
      preferencias: const PreferenciasDeLembrete(
        atividadesDeCasa: true,
        horaDasAtividades: 8,
      ),
      sessoes: const [],
      temAtividades: true,
      agora: _agora,
    );
    expect(cedo, hasLength(6), reason: 'hoje às 8h já passou');
    final tarde = lembretesPara(
      preferencias: const PreferenciasDeLembrete(
        atividadesDeCasa: true,
        horaDasAtividades: 19,
      ),
      sessoes: const [],
      temAtividades: true,
      agora: _agora,
    );
    expect(tarde, hasLength(diasDeLembretesDeCasa));
    expect(tarde.first.quando, instanteNaClinica(2026, 10, 2, 19));
    expect({for (final l in tarde) l.id}, hasLength(tarde.length));
    final semAtividades = lembretesPara(
      preferencias: const PreferenciasDeLembrete(atividadesDeCasa: true),
      sessoes: const [],
      temAtividades: false,
      agora: _agora,
    );
    expect(semAtividades, isEmpty);
  });

  test('as horas padrão estão entre as que a TM19 oferece; hora guardada '
      'fora delas volta à padrão (achado 5 da revisão)', () {
    const padrao = PreferenciasDeLembrete();
    expect(horasDaVespera, contains(padrao.horaDaVespera));
    expect(horasDasAtividades, contains(padrao.horaDasAtividades));
    final antiga = PreferenciasDeLembrete.fromMap({
      'vesperaDaSessao': true,
      'horaDaVespera': 7,
      'atividadesDeCasa': true,
      'horaDasAtividades': 17,
    });
    expect(antiga.horaDaVespera, padrao.horaDaVespera);
    expect(antiga.horaDasAtividades, padrao.horaDasAtividades);
    expect(antiga.vesperaDaSessao && antiga.atividadesDeCasa, isTrue);
  });

  test('o texto nunca diz com quem, o quê nem de quem (D28)', () {
    final lembretes = lembretesPara(
      preferencias: const PreferenciasDeLembrete(
        vesperaDaSessao: true,
        atividadesDeCasa: true,
      ),
      sessoes: [_sessao('a', instanteNaClinica(2026, 10, 5, 14))],
      temAtividades: true,
      agora: _agora,
    );
    for (final l in lembretes) {
      for (final proibido in ['terapia', 'Tiago', 'Miguel', 'consulta', 'TO']) {
        expect(l.texto.contains(proibido), isFalse, reason: l.texto);
      }
    }
  });
}
