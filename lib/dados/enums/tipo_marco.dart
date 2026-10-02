/// `MarcoJornada.tipo` (§22).
///
/// Tipos de marco da jornada em linguagem simples (RFM06, RNF06).
enum TipoMarco {
  reavaliacao('Reavaliação'),
  orientacao('Orientação'),
  proximoPasso('Próximo passo');

  const TipoMarco(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
