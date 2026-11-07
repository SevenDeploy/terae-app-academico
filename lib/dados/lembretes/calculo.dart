import '../modelos/agendamento.dart';
import '../regras/lembretes.dart';
import '../repositorios/falhas.dart';
import '../repositorios/paciente_repositorio.dart';
import '../repositorios/programa_em_casa_repositorio.dart';
import 'lembrete.dart';

/// Lê as sessões e as atividades dos [pacienteIds] e devolve os lembretes
/// que as [preferencias] pedem (F2, D28). Paciente que não pôde ser lido
/// agora (sem conexão e sem cópia) fica de fora desta vez; o app reagenda na
/// próxima abertura.
Future<List<Lembrete>> calcularLembretes({
  required PreferenciasDeLembrete preferencias,
  required List<String> pacienteIds,
  required RepositorioPaciente paciente,
  required RepositorioProgramaEmCasa programa,
  required DateTime agora,
}) async {
  if (!preferencias.algumLigado) return const [];
  final sessoes = <Agendamento>[];
  var temAtividades = false;
  for (final pid in pacienteIds) {
    try {
      if (preferencias.vesperaDaSessao) {
        sessoes.addAll(await paciente.agendamentos(pid));
      }
      if (preferencias.atividadesDeCasa && !temAtividades) {
        temAtividades = (await programa.atividades(pid)).isNotEmpty;
      }
    } on RecusaDeRegra {
      continue;
    }
  }
  return lembretesPara(
    preferencias: preferencias,
    sessoes: sessoes,
    temAtividades: temAtividades,
    agora: agora,
  );
}
