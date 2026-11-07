/// `Paciente.linhasDeCuidado` (D21, evolução de TO).
///
/// O que o paciente faz na clínica. Decide as abas, o Início e a guarda de
/// rota: o acompanhamento clínico traz a receita e os remédios; a terapia
/// ocupacional traz as atividades de casa (aba "Em casa"). O diário vale para
/// todos (o alerta da crítica também protege a família de TO, como o
/// acompanhamento do Terae web).
enum LinhaDeCuidado {
  acompanhamentoClinico('Acompanhamento clínico'),
  terapiaOcupacional('Terapia ocupacional');

  const LinhaDeCuidado(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
