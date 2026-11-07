/// Como o app chama o encontro com o profissional (evolução de TO, F2): na
/// terapia ocupacional é "sessão"; no acompanhamento clínico, "consulta".
/// Usado pelas telas do paciente e do cuidador, que não se importam.
library;

import '../../dados/modelos/paciente.dart';
import '../../dados/modelos/profissional_saude.dart';

/// "Sessão de terapia ocupacional" ou "Consulta" (sem profissional conhecido,
/// "Consulta", como até a F1).
String nomeDoEncontro(ProfissionalSaude? profissional) =>
    (profissional?.ehTerapiaOcupacional ?? false)
    ? 'Sessão de terapia ocupacional'
    : 'Consulta';

/// "Sessão" ou "Consulta", para rótulos curtos ("Sessão cancelada").
String tituloDoEncontro(ProfissionalSaude? profissional) =>
    (profissional?.ehTerapiaOcupacional ?? false) ? 'Sessão' : 'Consulta';

/// "sessão" ou "consulta", para frases ("Sua próxima sessão").
String palavraDoEncontro(ProfissionalSaude? profissional) =>
    (profissional?.ehTerapiaOcupacional ?? false) ? 'sessão' : 'consulta';

/// O plural para listas e títulos, pelas linhas de cuidado do [paciente]:
/// "sessões" (só TO), "consultas" (só clínico) ou "consultas e sessões".
String encontrosDoPaciente(Paciente paciente) => switch ((
  paciente.temAcompanhamentoClinico,
  paciente.temTerapiaOcupacional,
)) {
  (true, true) => 'consultas e sessões',
  (false, true) => 'sessões',
  _ => 'consultas',
};

/// "sessão" se o [paciente] só faz TO; senão "consulta" (para quando não há
/// encontro marcado e não se sabe com quem seria).
String palavraDoPaciente(Paciente paciente) =>
    paciente.temTerapiaOcupacional && !paciente.temAcompanhamentoClinico
    ? 'sessão'
    : 'consulta';
