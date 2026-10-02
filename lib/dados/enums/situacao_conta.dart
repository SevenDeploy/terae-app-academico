/// `ContaUsuario.situacao` (§22).
enum SituacaoConta {
  ativa('Ativa'),
  inativa('Inativa');

  const SituacaoConta(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
