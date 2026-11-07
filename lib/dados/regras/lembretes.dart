/// Quais lembretes agendar (evolução de TO, F2; D28), como função pura: a
/// memória e o aparelho decidem igual, e o teste confere sem plugin.
library;

import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../enums/situacao_agendamento.dart';
import '../lembretes/lembrete.dart';
import '../modelos/agendamento.dart';

/// Título de toda notificação: só o nome do app.
const String tituloDoLembrete = 'Terae';

/// Quantos dias à frente os lembretes das atividades são agendados (o app
/// reagenda a cada abertura).
const int diasDeLembretesDeCasa = 7;

/// Os lembretes de [agora] em diante:
/// - com [PreferenciasDeLembrete.vesperaDaSessao], um na véspera de cada
///   sessão ou consulta marcada, à hora escolhida (no fuso da clínica);
/// - com [PreferenciasDeLembrete.atividadesDeCasa] e [temAtividades], um por
///   dia nos próximos [diasDeLembretesDeCasa] dias.
///
/// O texto nunca diz com quem nem o quê (D28). Ordenados pelo horário.
List<Lembrete> lembretesPara({
  required PreferenciasDeLembrete preferencias,
  required Iterable<Agendamento> sessoes,
  required bool temAtividades,
  required DateTime agora,
}) {
  final lembretes = <Lembrete>[];
  if (preferencias.vesperaDaSessao) {
    final marcadas =
        sessoes
            .where(
              (s) =>
                  s.situacao == SituacaoAgendamento.agendado &&
                  s.dataHora.isAfter(agora),
            )
            .toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    for (final (i, s) in marcadas.indexed) {
      final vespera = DataCivil.doInstante(s.dataHora).somarDias(-1);
      final quando = instanteNaClinica(
        vespera.ano,
        vespera.mes,
        vespera.dia,
        preferencias.horaDaVespera,
      );
      if (!quando.isAfter(agora)) continue;
      lembretes.add(
        Lembrete(
          id: 1000 + i,
          titulo: tituloDoLembrete,
          texto:
              'Amanhã às ${formatarHora(s.dataHora)} tem compromisso na '
              'clínica.',
          quando: quando,
        ),
      );
    }
  }
  if (preferencias.atividadesDeCasa && temAtividades) {
    final hoje = DataCivil.doInstante(agora);
    for (var d = 0; d < diasDeLembretesDeCasa; d++) {
      final dia = hoje.somarDias(d);
      final quando = instanteNaClinica(
        dia.ano,
        dia.mes,
        dia.dia,
        preferencias.horaDasAtividades,
      );
      if (!quando.isAfter(agora)) continue;
      lembretes.add(
        Lembrete(
          id: 2000 + d,
          titulo: tituloDoLembrete,
          texto: 'Hora das atividades de casa. Depois, conte como foi no app.',
          quando: quando,
        ),
      );
    }
  }
  return lembretes..sort((a, b) => a.quando.compareTo(b.quando));
}
