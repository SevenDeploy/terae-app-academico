/// `RegistroDeAtividade.quem` (evolução de TO, F1; D24, D26).
///
/// Quem contou como foi: o próprio paciente (titular) ou quem cuida dele (o
/// responsável legal). Vem da voz do perfil, nunca é perguntado.
enum QuemRegistrou {
  paciente('O próprio paciente'),
  responsavel('Quem cuida');

  const QuemRegistrou(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
