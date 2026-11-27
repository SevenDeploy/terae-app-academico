/// Regras da Agenda (quadro 18i do portal) como funções puras: as sessões
/// marcadas agrupadas por semana, como `agruparPorSemana` do portal
/// (`apps/portal/src/estado/agenda.ts`).
library;

import '../../nucleo/tempo/data_civil.dart';
import '../modelos/agendamento.dart';

/// Uma semana da agenda: de segunda a domingo, no dia da clínica.
class SemanaDaAgenda {
  const SemanaDaAgenda({
    required this.segunda,
    required this.titulo,
    required this.sessoes,
  });

  /// A segunda-feira que abre a semana.
  final DataCivil segunda;

  /// "Esta semana", "Próxima semana" ou "Semana de 23/11".
  final String titulo;
  final List<Agendamento> sessoes;
}

/// A segunda-feira (dia civil da clínica) da semana de [dia].
DataCivil segundaDaSemana(DataCivil dia) =>
    dia.somarDias(-(dia.diaDaSemana - 1));

/// Agrupa as [sessoes] (já na ordem em que devem aparecer) por semana, de
/// segunda a domingo: "Esta semana", "Próxima semana" e depois "Semana de
/// 23/11". Uma sessão de semana que já passou cai em "Esta semana", como no
/// portal.
List<SemanaDaAgenda> agruparPorSemana(
  List<Agendamento> sessoes,
  DateTime agora,
) {
  final estaSemana = segundaDaSemana(DataCivil.doInstante(agora));
  final proximaSemana = estaSemana.somarDias(7);
  final semanas = <SemanaDaAgenda>[];
  for (final sessao in sessoes) {
    final segunda = segundaDaSemana(DataCivil.doInstante(sessao.dataHora));
    final indice = semanas.indexWhere((s) => s.segunda == segunda);
    if (indice >= 0) {
      semanas[indice].sessoes.add(sessao);
      continue;
    }
    final titulo = !segunda.ehDepoisDe(estaSemana)
        ? 'Esta semana'
        : segunda == proximaSemana
        ? 'Próxima semana'
        : 'Semana de ${_diaEMes(segunda)}';
    semanas.add(
      SemanaDaAgenda(segunda: segunda, titulo: titulo, sessoes: [sessao]),
    );
  }
  return semanas;
}

String _diaEMes(DataCivil d) =>
    '${d.dia.toString().padLeft(2, '0')}/${d.mes.toString().padLeft(2, '0')}';
