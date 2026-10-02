/// `ConviteAcesso.tipo` (§22).
///
/// O código serve aos dois cadastros por convite (RFM09): TM09 e TM10.
enum TipoConvite {
  paciente('Código da clínica'),
  cuidador('Convite de cuidador');

  const TipoConvite(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
