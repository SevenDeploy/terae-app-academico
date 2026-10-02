/// Contas da visão do cuidador (RFM08, §7.4; TM08, TM11, TM12), separadas das
/// telas para teste: cronograma da receita por horário, próximo remédio,
/// consultas marcadas e canceladas e o aviso de renovação.
///
/// Os horários de `ItemMedicacao` são `HH:mm` no horário da clínica; viram
/// instante por [instanteDoHorario] e a tela os exibe pelos formatadores do
/// `Relogio` (fuso −04:00, D7).
library;

import 'package:flutter/foundation.dart';

import '../../dados/enums/situacao_agendamento.dart';
import '../../dados/modelos/agendamento.dart';
import '../../dados/modelos/item_medicacao.dart';
import '../../dados/modelos/receita_uso_continuo.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';

/// Os remédios de um mesmo horário do dia.
@immutable
class GrupoDeHorario {
  const GrupoDeHorario(this.horario, this.itens);

  /// `HH:mm` no horário da clínica.
  final String horario;
  final List<ItemMedicacao> itens;
}

/// Itens com horário fixo, agrupados por horário e em ordem do dia (TM11).
List<GrupoDeHorario> agruparPorHorario(List<ItemMedicacao> itens) {
  final porHorario = <String, List<ItemMedicacao>>{};
  for (final item in itens) {
    for (final horario in item.horarios) {
      porHorario.putIfAbsent(horario, () => []).add(item);
    }
  }
  final entradas = porHorario.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (final e in entradas) GrupoDeHorario(e.key, List.unmodifiable(e.value)),
  ];
}

/// Itens sem horário fixo ("quando precisar").
List<ItemMedicacao> itensQuandoPrecisar(List<ItemMedicacao> itens) => [
  for (final item in itens)
    if (item.horarios.isEmpty) item,
];

/// Instante (UTC) do [horario] `HH:mm` da clínica no [dia].
DateTime instanteDoHorario(DataCivil dia, String horario) {
  final partes = horario.split(':');
  return instanteNaClinica(
    dia.ano,
    dia.mes,
    dia.dia,
    int.parse(partes[0]),
    int.parse(partes[1]),
  );
}

/// O próximo horário de remédio e o que tomar nele.
@immutable
class ProximaDose {
  const ProximaDose(this.instante, this.itens);

  final DateTime instante;
  final List<ItemMedicacao> itens;
}

/// Próximo horário a partir de [agora] — hoje ou, se os de hoje já passaram,
/// amanhã —, sempre dentro da vigência da [receita] (TM08).
ProximaDose? proximaDose({
  required ReceitaUsoContinuo? receita,
  required List<ItemMedicacao> itens,
  required DateTime agora,
}) {
  if (receita == null) return null;
  final grupos = agruparPorHorario(itens);
  final hoje = DataCivil.doInstante(agora);
  for (final dia in [hoje, hoje.somarDias(1)]) {
    if (!receita.vigenteEm(dia)) continue;
    for (final grupo in grupos) {
      final instante = instanteDoHorario(dia, grupo.horario);
      if (!instante.isBefore(agora)) return ProximaDose(instante, grupo.itens);
    }
  }
  return null;
}

/// Os [quantidade] dias depois de [hoje] em que a [receita] ainda vale (TM11,
/// "próximos dias").
List<DataCivil> proximosDias(
  ReceitaUsoContinuo receita,
  DataCivil hoje, {
  int quantidade = 3,
}) => [
  for (var d = 1; d <= quantidade; d++)
    if (receita.vigenteEm(hoje.somarDias(d))) hoje.somarDias(d),
];

/// Consultas marcadas de [agora] em diante, da mais próxima à mais distante.
List<Agendamento> consultasMarcadas(
  List<Agendamento> consultas,
  DateTime agora,
) => [
  for (final a in consultas)
    if (a.situacao == SituacaoAgendamento.agendado &&
        !a.dataHora.isBefore(agora))
      a,
]..sort((a, b) => a.dataHora.compareTo(b.dataHora));

/// Próxima consulta marcada, se houver (TM08).
Agendamento? proximaConsulta(List<Agendamento> consultas, DateTime agora) {
  final marcadas = consultasMarcadas(consultas, agora);
  return marcadas.isEmpty ? null : marcadas.first;
}

/// Consultas canceladas de hoje em diante, para o aviso da TM12.
List<Agendamento> consultasCanceladas(
  List<Agendamento> consultas,
  DataCivil hoje,
) => [
  for (final a in consultas)
    if (a.situacao == SituacaoAgendamento.cancelado &&
        !a.dataHora.isBefore(hoje.inicioNaClinica))
      a,
]..sort((a, b) => a.dataHora.compareTo(b.dataHora));

/// A partir de quantos dias antes a renovação da receita vira aviso (TM12).
const int diasDeAvisoDaRenovacao = 7;

/// A renovação está a [diasDeAvisoDaRenovacao] dias ou menos (ou já passou).
bool renovacaoProxima(ReceitaUsoContinuo receita, DataCivil hoje) =>
    hoje.diasAte(receita.dataRenovacao) <= diasDeAvisoDaRenovacao;
