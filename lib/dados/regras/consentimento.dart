/// Quem pode aceitar o termo de consentimento (RFM09; TM09 passo 2; §22
/// Consentimento), como regra pura: vale na memória (o "servidor simulado")
/// e na tela, que só mostra o que a regra permite.
library;

import '../../nucleo/tempo/data_civil.dart';
import '../enums/qualidade_consentimento.dart';

/// ECA art. 2º: criança é quem tem menos de 12 anos completos; a partir daí,
/// adolescente.
const int idadeQueDeixaDeSerCrianca = 12;

/// Anos completos em [hoje] de quem nasceu em [nascimento]. O ano só se
/// completa no dia do aniversário; quem nasceu em 29/02 completa em 01/03 nos
/// anos sem esse dia (Código Civil, art. 132, § 3º).
int idadeEmAnos({required DataCivil nascimento, required DataCivil hoje}) {
  final anos = hoje.ano - nascimento.ano;
  final faltaOAniversario =
      hoje.mes < nascimento.mes ||
      (hoje.mes == nascimento.mes && hoje.dia < nascimento.dia);
  return faltaOAniversario ? anos - 1 : anos;
}

/// O paciente é criança em [hoje] — dia civil da clínica, `DataCivil.hoje`
/// do `Relogio` (ECA art. 2º)?
bool ehCrianca({required DataCivil nascimento, required DataCivil hoje}) =>
    idadeEmAnos(nascimento: nascimento, hoje: hoje) < idadeQueDeixaDeSerCrianca;

/// Qualidades que podem aceitar o termo do paciente nascido em [nascimento]:
/// criança, só a mãe, o pai ou o responsável legal (LGPD art. 14, § 1º);
/// adolescente e adulto, o próprio paciente ou o responsável legal.
List<QualidadeConsentimento> qualidadesPermitidas({
  required DataCivil nascimento,
  required DataCivil hoje,
}) => ehCrianca(nascimento: nascimento, hoje: hoje)
    ? const [QualidadeConsentimento.responsavelLegal]
    : QualidadeConsentimento.values;

/// [qualidade] pode aceitar o termo do paciente nascido em [nascimento]?
bool qualidadePermitida(
  QualidadeConsentimento qualidade, {
  required DataCivil nascimento,
  required DataCivil hoje,
}) => qualidadesPermitidas(
  nascimento: nascimento,
  hoje: hoje,
).contains(qualidade);
