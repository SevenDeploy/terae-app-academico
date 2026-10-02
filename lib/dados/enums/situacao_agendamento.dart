/// `Agendamento.situacao` (§22).
enum SituacaoAgendamento {
  agendado('Marcada'),
  realizado('Realizada'),
  cancelado('Cancelada');

  const SituacaoAgendamento(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
