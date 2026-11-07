/// `RegistroDeAtividade.adesao` (evolução de TO, F1; D26).
///
/// "Conseguiu fazer hoje?", como o programa em casa do Terae web: três
/// respostas, sem julgamento — "não deu" é um dia comum, não uma falta.
enum AdesaoEmCasa {
  feito('Sim'),
  emParte('Em parte'),
  naoFeito('Não deu hoje');

  const AdesaoEmCasa(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;

  /// Conta como uma das vezes da semana (fez, mesmo que em parte).
  bool get conta => this != naoFeito;
}
