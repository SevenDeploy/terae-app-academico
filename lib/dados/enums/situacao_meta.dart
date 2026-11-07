/// `MetaTerapeutica.situacao` (evolução de TO, F3; D25, D35).
///
/// Em que pé está a meta, na língua da família (RNFM01). A ordem é a da tela:
/// as em andamento primeiro, depois as alcançadas e as que saíram de cena
/// (nada é apagado, §23). No mapa vai o `name`.
enum SituacaoMeta {
  ativa('Em andamento'),
  alcancada('Alcançada'),
  interrompida('Interrompida'),
  substituida('Substituída por outra');

  const SituacaoMeta(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01).
  final String rotulo;
}
