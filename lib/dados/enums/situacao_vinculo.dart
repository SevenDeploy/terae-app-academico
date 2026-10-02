/// `VinculoCuidador.situacao` (§22).
///
/// Pendentes e ativos contam no limite de dois (§7.4); revogar não apaga o histórico.
enum SituacaoVinculo {
  pendente('Convite em aberto'),
  ativo('Autorizado'),
  revogado('Acesso removido');

  const SituacaoVinculo(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;

  /// Conta no limite de dois cuidadores por paciente (§23).
  bool get contaNoLimite => this != revogado;
}
