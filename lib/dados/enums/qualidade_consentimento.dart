/// `Consentimento.qualidade` (§22).
///
/// Quem aceitou o termo: o titular ou, se o paciente for criança, um dos pais ou o
/// responsável legal (LGPD art. 14, § 1º; TM09 passo 2).
enum QualidadeConsentimento {
  titular('Sou o próprio paciente'),
  responsavelLegal('Sou a mãe, o pai ou o responsável legal');

  const QualidadeConsentimento(this.rotulo);

  /// Texto em linguagem simples para a tela (RNFM01). No mapa vai o `name`.
  final String rotulo;
}
