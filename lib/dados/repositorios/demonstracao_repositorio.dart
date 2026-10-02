/// D11 — controles do painel de demonstração, que a TM00 mostra só em
/// `kDebugMode`: simular "sem conexão" (fila `naFila`, TM04/TM05 com envio
/// pendente) e reiniciar os dados das personas.
abstract interface class ControleDemonstracao {
  bool get semConexao;

  /// Liga ou desliga a falta de conexão simulada. Ao religar, a fila não é
  /// reenviada sozinha: quem quiser chama `RepositorioDiario.reenviarFila`.
  Future<void> definirSemConexao({required bool semConexao});

  /// Volta aos dados de demonstração iniciais (datas relativas a hoje, D9).
  Future<void> reiniciarDados();
}
