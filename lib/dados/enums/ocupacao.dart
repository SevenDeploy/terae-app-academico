/// `AtividadeDeCasa.ocupacao` (evolução de TO, F1).
///
/// A área da vida que a atividade treina, inspirada nas ocupações do OTPF-4
/// que o Terae web usa nas metas, com nomes de casa (RNFM01): o app nunca
/// mostra a sigla nem o termo técnico.
enum Ocupacao {
  autocuidado('Autocuidado'),
  tarefasDaCasa('Tarefas da casa'),
  brincar('Brincar'),
  escola('Escola'),
  sonoEDescanso('Sono e descanso'),
  lazer('Lazer'),
  convivio('Convívio'),
  trabalho('Trabalho');

  const Ocupacao(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
