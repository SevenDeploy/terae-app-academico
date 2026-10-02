/// D11 — controles do painel de demonstração, que a TM00 mostra só em
/// `kDebugMode`: simular "sem conexão" (fila `naFila`, TM04/TM05 com envio
/// pendente) e reiniciar os dados das personas.
abstract interface class ControleDemonstracao {
  bool get semConexao;

  /// Liga ou desliga a falta de conexão simulada. Ao religar
  /// (`semConexao: false`), reenvia a fila (`RepositorioDiario.reenviarFila`)
  /// antes de responder, na ordem do aparelho; o alerta de um crítico que
  /// estava na fila nasce nesse momento (§19).
  Future<void> definirSemConexao({required bool semConexao});

  /// Volta aos dados de demonstração iniciais (datas relativas a hoje, D9).
  Future<void> reiniciarDados();
}
