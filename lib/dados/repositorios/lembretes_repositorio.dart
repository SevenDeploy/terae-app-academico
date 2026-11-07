import '../lembretes/lembrete.dart';

/// Os lembretes locais (evolução de TO, F2; D28; TM19): sem servidor nem
/// FCM, agendados no próprio aparelho, no fuso da clínica, com texto que não
/// revela o tratamento. As preferências ficam no aparelho e somem no "Sair".
abstract interface class RepositorioLembretes {
  Future<PreferenciasDeLembrete> preferencias();

  Future<void> salvar(PreferenciasDeLembrete preferencias);

  /// Pede ao Android a permissão de notificação (13+); devolve se pode
  /// mostrar. Sem pedido possível (web, testes), `true`.
  Future<bool> pedirPermissao();

  /// Se o Android já deixa mostrar notificações, sem pedir nada (a TM19 só
  /// explica o pedido para quem ainda não deu). Sem como saber, `true`.
  Future<bool> notificacoesPermitidas();

  /// Troca os lembretes agendados pelos de agora: as sessões marcadas e as
  /// atividades de casa dos [pacienteIds] (os perfis paciente/família da
  /// conta), conforme as preferências. Devolve o que ficou agendado.
  ///
  /// Chamadas seguidas rodam uma depois da outra, cada uma com as
  /// preferências do momento em que começa. Se [cancelarTudo] vier no meio,
  /// esta não agenda nada e devolve a lista vazia.
  Future<List<Lembrete>> reagendar(List<String> pacienteIds);

  /// Mostra agora um lembrete de teste ("Os lembretes estão ligados").
  Future<void> testar();

  /// D20 — "Sair": cancela todos e apaga as preferências na hora, sem esperar
  /// um [reagendar] em curso (que então desiste).
  Future<void> cancelarTudo();
}
