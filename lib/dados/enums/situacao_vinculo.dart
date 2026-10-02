/// `VinculoCuidador.situacao` (§22).
///
/// Ativos e pendentes com convite em aberto contam no limite de dois (§7.4;
/// regra em `dados/regras/cuidadores.dart`, que depende do convite e da
/// hora); revogar não apaga o histórico.
enum SituacaoVinculo {
  pendente('Convite em aberto'),
  ativo('Autorizado'),
  revogado('Acesso removido');

  const SituacaoVinculo(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
