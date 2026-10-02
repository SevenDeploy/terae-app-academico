import '../modelos/agendamento.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';

/// Leitura do paciente e da jornada para o perfil paciente/família (RFM02,
/// RFM06; TM02, TM05, TM06). Tudo é cópia de leitura: o app não edita
/// paciente, consulta nem receita (RF07, RF03).
///
/// "Hoje" e "agora" vêm do `Relogio` da implementação. Paciente inexistente
/// recusa com `acessoNegado`.
abstract interface class RepositorioPaciente {
  Future<Paciente> paciente(String pacienteId);

  /// Profissional de referência (TM05) ou da consulta.
  Future<ProfissionalSaude> profissional(String profissionalId);

  /// RFM02 — próxima consulta `agendado` com `dataHora` de agora em diante.
  Future<Agendamento?> proximaConsulta(String pacienteId);

  /// RFM06 — todas as consultas do paciente, por `dataHora` crescente.
  Future<List<Agendamento>> agendamentos(String pacienteId);

  /// RFM02 — receita vigente hoje no horário da clínica, ou `null`.
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId);

  /// Itens da receita (cronograma por horário).
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId);

  /// RFM06 — marcos da jornada, por `data` crescente.
  Future<List<MarcoJornada>> marcos(String pacienteId);
}
