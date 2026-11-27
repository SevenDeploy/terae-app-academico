/// `RegistroDiario.adesao` (§22): a única pergunta obrigatória do diário
/// (quadro 18e). Os nomes são os do corpo da API do portal.
///
/// O texto da opção depende da linha de cuidado e da voz (D32, D24), e por
/// isso mora nos `TextosDoDiario` da tela. [rotulo] é a forma neutra, para
/// os resumos que não sabem quem lê.
enum Adesao {
  total('Fizemos tudo'),
  parcial('Fizemos parte'),
  nenhuma('Não deu para fazer');

  const Adesao(this.rotulo);

  /// Texto em linguagem simples (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
