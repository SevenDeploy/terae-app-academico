/// `RegistroDiario.situacaoEnvio` (§22).
///
/// Enquanto `naFila`, nenhuma tela afirma que a equipe foi avisada (§19, §23).
enum SituacaoEnvio {
  naFila('Aguardando conexão para enviar'),
  enviado('Enviado');

  const SituacaoEnvio(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
