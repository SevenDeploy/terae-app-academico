/// Regras da confirmação de presença (evolução de TO, F2; D27) como funções
/// puras, para a memória, a persistência e a TM18 decidirem igual.
library;

import '../enums/situacao_agendamento.dart';
import '../modelos/agendamento.dart';

/// D27 — dá para responder (ou mudar a resposta) enquanto a sessão estiver
/// marcada e ainda não tiver começado. Depois disso, ou se a clínica
/// cancelou, a resposta fica como está.
bool podeResponder(Agendamento agendamento, DateTime agora) =>
    agendamento.situacao == SituacaoAgendamento.agendado &&
    agendamento.dataHora.isAfter(agora);
