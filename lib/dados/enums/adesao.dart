/// `RegistroDiario.adesao` (§22).
///
/// Seletor de três opções da TM03 (RFM03).
enum Adesao {
  total('Tomei tudo'),
  parcial('Tomei uma parte'),
  nenhuma('Não tomei');

  const Adesao(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
