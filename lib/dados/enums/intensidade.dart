/// `RegistroDiario.intensidade` (§22).
///
/// Seletor de quatro níveis da TM03. `critica` abre a TM05 no próprio aparelho, sem
/// esperar a rede (RFM04, §7.1).
enum Intensidade {
  leve('Leve'),
  moderada('Moderada'),
  grave('Grave'),
  critica('Crítica');

  const Intensidade(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;

  /// Abre a ajuda imediata (TM05) em vez da confirmação (TM04).
  bool get ehCritica => this == critica;
}
