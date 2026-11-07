import '../enums/resposta_presenca.dart';
import '../modelos/confirmacao_de_presenca.dart';

/// A confirmação de presença nas sessões (evolução de TO, F2; D27; TM18):
/// "Sim, vamos" ou "Não vamos conseguir". Nunca cancela a sessão; só avisa a
/// clínica.
///
/// Como o diário, a resposta vai primeiro para o aparelho e depois para o
/// servidor: sem conexão fica na fila (`naFila`) e sai sozinha quando a
/// conexão volta. Toda recusa é `RecusaDeRegra` (`falhas.dart`).
abstract interface class RepositorioPresenca {
  /// As respostas do paciente, por id do agendamento, com as da fila.
  Future<Map<String, ConfirmacaoDePresenca>> respostas(String pacienteId);

  /// D27 — responde (ou troca a resposta de) uma sessão marcada que ainda não
  /// começou. Recusa `agendamentoInexistente` e `sessaoEncerrada`.
  Future<ConfirmacaoDePresenca> responder({
    required String pacienteId,
    required String agendamentoId,
    required RespostaPresenca resposta,
  });
}
