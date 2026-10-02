/// `Alerta.regraDisparada` (§22).
///
/// As duas condições do §7.1, avaliadas no servidor: (a) intensidade crítica,
/// (b) grave em dois registros seguidos.
enum RegraAlerta {
  intensidadeCritica('Intensidade crítica'),
  graveConsecutivo('Grave em dois registros seguidos');

  const RegraAlerta(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
