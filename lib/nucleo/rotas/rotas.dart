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

  /// TM13 Meus registros (Atividade 4) — paciente; lista e busca do diário,
  /// empilhada sobre as abas.
  static const String pacienteRegistros = '/paciente/registros';

  /// TM14 Registro (Atividade 4) — paciente; visualização de um registro,
  /// com o id na consulta: use [registro].
  static const String pacienteRegistro = '/paciente/registros/registro';

  /// TM15 Corrigir registro (Atividade 4) — paciente; edição no mesmo dia
  /// (D17), com o id na consulta: use [corrigirRegistro].
  static const String pacienteCorrigirRegistro = '/paciente/registros/corrigir';

  /// Caminho da TM14 para o registro [id].
  static String registro(String id) =>
      Uri(path: pacienteRegistro, queryParameters: {'id': id}).toString();

  /// Caminho da TM15 para o registro [id].
  static String corrigirRegistro(String id) => Uri(
    path: pacienteCorrigirRegistro,
    queryParameters: {'id': id},
  ).toString();

  /// TM16 Em casa (aba "Em casa") — paciente com terapia ocupacional (D21,
  /// D22): as atividades de casa combinadas com a terapeuta.
  static const String pacienteCasa = '/paciente/casa';

  /// TM17 Atividade (evolução de TO, F1) — paciente com terapia ocupacional;
  /// uma atividade de casa e o registro de hoje, empilhada sobre as abas, com
  /// o id na consulta: use [atividade].
  static const String pacienteAtividade = '/paciente/casa/atividade';

  /// Caminho da TM17 para a atividade [id].
  static String atividade(String id) =>
      Uri(path: pacienteAtividade, queryParameters: {'id': id}).toString();

  /// TM20 Meta (evolução de TO, F3) — paciente com terapia ocupacional; uma
  /// meta do plano, com as atividades de casa e os marcos ligados a ela,
  /// empilhada sobre as abas, com o id na consulta: use [meta].
  static const String pacienteMeta = '/paciente/meta';

  /// Caminho da TM20 para a meta [id].
  static String meta(String id) =>
      Uri(path: pacienteMeta, queryParameters: {'id': id}).toString();

  /// TM18 Sessões (evolução de TO, F2) — paciente; as sessões e consultas,
  /// com a confirmação de presença e "Falar com a clínica", empilhada sobre
  /// as abas (aberta pelo cartão da próxima sessão no Início).
  static const String pacienteSessoes = '/paciente/sessoes';

  /// TM19 Lembretes (evolução de TO, F2) — paciente; aberta pelo menu do
  /// Início, empilhada sobre as abas.
  static const String pacienteLembretes = '/paciente/lembretes';

  /// TM06 Jornada (aba 3) — paciente.
  static const String pacienteJornada = '/paciente/jornada';

  /// TM07 Cuidadores — paciente; desde a D22, empilhada sobre as abas e
  /// aberta pelo menu do Início (era a aba 4).
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
    pacienteCasa,
    pacienteAtividade,
    pacienteMeta,
    pacienteSessoes,
    pacienteLembretes,
    pacienteJornada,
    pacienteCuidadores,
    pacienteRegistros,
    pacienteRegistro,
    pacienteCorrigirRegistro,
  };

  /// D21 (F2) — só o perfil de paciente com acompanhamento clínico alcança
  /// (a medicação do cuidador); o roteador recusa para os demais.
  static const Set<String> doAcompanhamentoClinico = {cuidadorMedicacao};

  /// D22 — só o paciente com terapia ocupacional alcança (o roteador recusa
  /// para os demais, mesmo por link direto). As metas (F3) também.
  static const Set<String> daTerapiaOcupacional = {
    pacienteCasa,
    pacienteAtividade,
    pacienteMeta,
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
    'TM13': pacienteRegistros,
    'TM14': pacienteRegistro,
    'TM15': pacienteCorrigirRegistro,
    'TM16': pacienteCasa,
    'TM17': pacienteAtividade,
    'TM18': pacienteSessoes,
    'TM19': pacienteLembretes,
    'TM20': pacienteMeta,
  };
}
