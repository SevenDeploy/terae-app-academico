/// Por que a família retira um registro do diário (quadro 18f, "Retirar com
/// motivo"; `MOTIVOS_DA_RETIRADA_DO_DIARIO` do domínio do Terae).
///
/// No mapa vai o [valor] do corpo da API do portal (`dia_errado`…), para a
/// fonte Terae local (P4) mandar sem tradução. "Outro" exige um detalhe curto
/// ([detalheMaximo]).
enum MotivoDaRetirada {
  diaErrado('dia_errado', 'Registrei no dia errado'),
  pacienteErrado('paciente_errado', 'Registrei no paciente errado'),
  enviadoSemQuerer('enviado_sem_querer', 'Enviei sem querer'),
  outro('outro', 'Outro');

  const MotivoDaRetirada(this.valor, this.rotulo);

  /// A categoria como a API do portal a escreve.
  final String valor;

  /// O rótulo que a família lê (RNFM01).
  final String rotulo;

  /// O detalhe fica no registro, para a terapeuta: curto, porque o lugar de
  /// contar o dia é um registro novo.
  static const int detalheMaximo = 300;

  /// A categoria pelo [valor] gravado; `null` se não for nenhuma.
  static MotivoDaRetirada? doValor(String valor) =>
      values.where((m) => m.valor == valor).firstOrNull;
}
