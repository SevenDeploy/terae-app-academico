/// `MarcoJornada.tipo` (§22).
///
/// Tipos de marco da jornada em linguagem simples (RFM06, RNF06).
enum TipoMarco {
  reavaliacao('Reavaliação'),
  orientacao('Orientação'),
  proximoPasso('Próximo passo'),

  /// F3 — uma meta da terapia ocupacional foi alcançada; o marco aponta para
  /// ela por `MarcoJornada.metaId`.
  metaAlcancada('Meta alcançada'),

  /// F3 (D36) — alta da terapia ocupacional: encerra o programa em casa.
  alta('Alta');

  const TipoMarco(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
