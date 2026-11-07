/// Regra da confirmação de presença (evolução de TO, F2; D27).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/profissional_saude.dart';
import 'package:terae_app/dados/regras/presenca.dart';
import 'package:terae_app/nucleo/textos/encontros.dart';

final DateTime _agora = DateTime.utc(2026, 10, 2, 14);

Agendamento _sessao(Duration daqui, SituacaoAgendamento situacao) =>
    Agendamento(
      id: 'ag',
      pacienteId: 'p',
      profissionalId: 'pr',
      dataHora: _agora.add(daqui),
      situacao: situacao,
    );

void main() {
  test('responde enquanto a sessão está marcada e não começou', () {
    expect(
      podeResponder(
        _sessao(const Duration(days: 3), SituacaoAgendamento.agendado),
        _agora,
      ),
      isTrue,
    );
    expect(
      podeResponder(
        _sessao(const Duration(minutes: 1), SituacaoAgendamento.agendado),
        _agora,
      ),
      isTrue,
    );
  });

  test('na hora, depois, cancelada ou realizada, não responde mais', () {
    for (final (daqui, situacao) in [
      (Duration.zero, SituacaoAgendamento.agendado),
      (const Duration(hours: -1), SituacaoAgendamento.agendado),
      (const Duration(days: 3), SituacaoAgendamento.cancelado),
      (const Duration(days: -3), SituacaoAgendamento.realizado),
    ]) {
      expect(
        podeResponder(_sessao(daqui, situacao), _agora),
        isFalse,
        reason: '$daqui $situacao',
      );
    }
  });

  test('o encontro se chama sessão na TO e consulta no resto', () {
    const to = ProfissionalSaude(
      id: 't',
      nome: 'Tiago',
      registroConselho: 'CREFITO',
      especialidade: 'Terapia ocupacional',
    );
    const psi = ProfissionalSaude(
      id: 'h',
      nome: 'Helena',
      registroConselho: 'CRM',
      especialidade: 'Psiquiatria',
    );
    expect(nomeDoEncontro(to), 'Sessão de terapia ocupacional');
    expect(palavraDoEncontro(to), 'sessão');
    expect(nomeDoEncontro(psi), 'Consulta');
    expect(nomeDoEncontro(null), 'Consulta');
  });
}
