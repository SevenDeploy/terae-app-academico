/// `ConfirmacaoDePresenca.resposta` (evolução de TO, F2; D27).
///
/// Como o "confirmar sessão" do Terae web: "Sim, vamos" ou "Não vamos
/// conseguir". O "não" só avisa a clínica — a sessão continua marcada e nunca
/// é cancelada pelo app. O texto na tela segue a voz do perfil (D24): o
/// titular lê "Sim, vou"; quem cuida, "Sim, vamos".
enum RespostaPresenca {
  vamos('Sim, vamos', 'Sim, vou'),
  naoVamos('Não vamos conseguir', 'Não vou conseguir');

  const RespostaPresenca(this.rotulo, this.rotuloNaPrimeiraPessoa);

  /// Texto para quem cuida do paciente (RNFM01). No mapa vai o `name`.
  final String rotulo;

  /// Texto para o próprio paciente.
  final String rotuloNaPrimeiraPessoa;
}
