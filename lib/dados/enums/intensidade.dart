/// `RegistroDiario.intensidadeSintoma`: "O quanto isso atrapalhou o dia?"
/// (quadro 18e do portal da família; P3, D8 revista).
///
/// Os nomes são os do corpo da API do portal (`leve`, `moderado`, `grave`,
/// `critico`), para a fonte Terae local (P4) mandar sem tradução. A pergunta
/// é opcional. `critico` ("Muito — precisamos de ajuda") abre a ajuda
/// imediata (TM05) no próprio aparelho, sem esperar a rede (RFM04, §7.1). O
/// formulário nunca diz "alerta" nem "crítico".
enum Intensidade {
  leve(
    'Pouco — quase não atrapalhou',
    curto: 'Pouco',
    naLista: 'Quase não atrapalhou',
  ),
  moderado(
    'Mais ou menos — atrapalhou um pouco',
    curto: 'Mais ou menos',
    naLista: 'Atrapalhou mais ou menos',
  ),
  grave(
    'Bastante — atrapalhou o dia',
    curto: 'Bastante',
    naLista: 'Atrapalhou o dia',
  ),
  critico(
    'Muito — precisamos de ajuda',
    curto: 'Muito',
    naLista: 'Precisamos de ajuda',
  );

  const Intensidade(this.rotulo, {required this.curto, required this.naLista});

  /// A opção do formulário (RNFM01). No mapa vai o `name`.
  final String rotulo;

  /// A palavra curta do recibo ("O quanto atrapalhou: Bastante").
  final String curto;

  /// O selo da lista ("Atrapalhou o dia").
  final String naLista;

  /// Abre a ajuda imediata (TM05) em vez da confirmação (TM04).
  bool get ehCritico => this == critico;

  /// Os que mostram os números de emergência quando o registro fica guardado
  /// no aparelho ("Bastante" e "Muito", como o `RegistroGuardado` do portal).
  bool get pedeAjudaSemInternet => this == grave || this == critico;

  /// Lê o valor gravado; aceita a grafia antiga das A3/A4 (`moderada`,
  /// `critica`, D8), para o documento que ficou no Firebase antes da semente
  /// nova e o banco migrado (SQLite v4).
  static Intensidade? doNome(String nome) => switch (nome) {
    'moderada' => moderado,
    'critica' => critico,
    _ => values.where((v) => v.name == nome).firstOrNull,
  };
}
