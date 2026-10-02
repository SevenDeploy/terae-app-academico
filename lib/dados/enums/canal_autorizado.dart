/// `Consentimento.canalAutorizado` (§22).
///
/// Canal autorizado para receber resumos (R05; TM09 passo 3).
enum CanalAutorizado {
  impresso('Papel, entregue na clínica'),
  email('E-mail'),
  aplicativo('Aqui no aplicativo');

  const CanalAutorizado(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
