/// Caminhos de todas as rotas do app (§21). Nenhum outro arquivo escreve
/// caminho de rota à mão (§24; conferido por `test/arquitetura_test.dart`).
///
/// Navegar: `context.go(Rotas.pacienteDiario)`; empilhar tela de detalhe do
/// cuidador: `context.push(Rotas.cuidadorMedicacao)`. Quem pode abrir cada
/// rota é decidido só em `lib/roteador.dart`.
abstract final class Rotas {
  /// TM00 Boas-vindas — público.
  static const String boasVindas = '/';

  /// TM01 Entrar — público.
  static const String entrar = '/entrar';

  /// TM01 Entrar, seleção de perfil — exige sessão (reaberta por "Trocar
  /// perfil").
  static const String entrarPerfil = '/entrar/perfil';

  /// TM09 Cadastro do paciente/família — público.
  static const String cadastroPaciente = '/cadastro/paciente';

  /// TM10 Cadastro do cuidador — público.
  static const String cadastroCuidador = '/cadastro/cuidador';

  /// TM02 Início (aba 1) — paciente.
  static const String pacienteInicio = '/paciente/inicio';

  /// TM03 Diário (aba 2) — paciente.
  static const String pacienteDiario = '/paciente/diario';

  /// Segmentos das sub-rotas do diário (só o roteador usa).
  static const String segmentoEnviado = 'enviado';
  static const String segmentoAjuda = 'ajuda';

  /// TM04 Diário enviado — paciente; tela cheia, fora das abas.
  static const String pacienteDiarioEnviado =
      '$pacienteDiario/$segmentoEnviado';

  /// TM05 Ajuda imediata — paciente; tela cheia, fora das abas.
  static const String pacienteDiarioAjuda = '$pacienteDiario/$segmentoAjuda';

  /// TM06 Jornada (aba 3) — paciente.
  static const String pacienteJornada = '/paciente/jornada';

  /// TM07 Cuidadores (aba 4) — paciente.
  static const String pacienteCuidadores = '/paciente/cuidadores';

  /// TM08 Início do cuidador — cuidador.
  static const String cuidadorInicio = '/cuidador/inicio';

  /// TM11 Medicação — cuidador; empilhada sobre a TM08.
  static const String cuidadorMedicacao = '/cuidador/medicacao';

  /// TM12 Agenda e avisos — cuidador; empilhada sobre a TM08.
  static const String cuidadorAgenda = '/cuidador/agenda';

  /// Abrem sem sessão; com sessão, levam ao início do perfil ativo.
  static const Set<String> publicas = {
    boasVindas,
    entrar,
    cadastroPaciente,
    cadastroCuidador,
  };

  /// Só o papel paciente/família alcança.
  static const Set<String> doPaciente = {
    pacienteInicio,
    pacienteDiario,
    pacienteDiarioEnviado,
    pacienteDiarioAjuda,
    pacienteJornada,
    pacienteCuidadores,
  };

  /// Só o papel cuidador alcança.
  static const Set<String> doCuidador = {
    cuidadorInicio,
    cuidadorMedicacao,
    cuidadorAgenda,
  };

  static const Set<String> todas = {
    ...publicas,
    entrarPerfil,
    ...doPaciente,
    ...doCuidador,
  };

  /// Rota de cada tela, na ordem do §21 (TM01 aparece com a rota pública).
  static const Map<String, String> porTela = {
    'TM00': boasVindas,
    'TM01': entrar,
    'TM09': cadastroPaciente,
    'TM10': cadastroCuidador,
    'TM02': pacienteInicio,
    'TM03': pacienteDiario,
    'TM04': pacienteDiarioEnviado,
    'TM05': pacienteDiarioAjuda,
    'TM06': pacienteJornada,
    'TM07': pacienteCuidadores,
    'TM08': cuidadorInicio,
    'TM11': cuidadorMedicacao,
    'TM12': cuidadorAgenda,
  };
}
