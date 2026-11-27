/// Os repositórios de leitura e escrita do Terae local: paciente e agenda,
/// presença, programa em casa e a visão do cuidador, sobre
/// `/api/portal/{inicio,agenda,programa}`.
///
/// Diferença de propósito em relação ao Firebase: sem cópia no aparelho e
/// sem fila. O portal da família é online (como o web): sem rede, a escrita
/// recusa `semConexao` e a tela oferece de novo.
library;

import '../conversao_mapa.dart';
import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../enums/resposta_presenca.dart';
import '../enums/situacao_agendamento.dart';
import '../enums/situacao_envio.dart';
import '../modelos/agendamento.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../modelos/registro_de_atividade.dart';
import '../repositorios/falhas.dart';
import '../repositorios/paciente_repositorio.dart';
import '../repositorios/presenca_repositorio.dart';
import '../repositorios/programa_em_casa_repositorio.dart';
import '../repositorios/visao_cuidador_repositorio.dart';
import 'cliente_do_portal.dart';
import 'contexto_do_portal.dart';
import 'mapeadores_do_portal.dart';
import 'sessao_do_portal.dart';

/// Lê a agenda do paciente (vazia se a clínica não a liberou no portal).
Future<AgendaNoPortal> _agenda(ContextoDoPortal c, String pacienteId) =>
    c.comPaciente(
      pacienteId,
      () async => lerAgenda((await c.cliente.get('agenda')).objeto),
    );

List<Agendamento> _agendamentos(
  ContextoDoPortal c,
  String pacienteId,
  AgendaNoPortal agenda,
) {
  if (!agenda.liberada) return const [];
  return [
    for (final s in agenda.sessoes)
      agendamentoDoPortal(
        s,
        pacienteId: pacienteId,
        profissionalId: c.lembrarProfissional(
          primeiroNome: s.primeiroNomeDoTerapeuta,
          especialidade: s.especialidade,
        ),
      ),
  ]..sort((a, b) => a.dataHora.compareTo(b.dataHora));
}

ProfissionalSaude _profissional(ContextoDoPortal c, String id) =>
    c.profissional(id) ??
    (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));

/// Paciente e agenda (RFM02, RFM06) no Terae local. Receita e marcos não
/// existem no portal: `null` e lista vazia (a linha é só TO, D21; a Jornada
/// some pela `CapacidadesDaFonte.jornada`).
class PacienteTeraeLocal implements RepositorioPaciente {
  PacienteTeraeLocal(this._contexto);

  final ContextoDoPortal _contexto;

  @override
  Future<Paciente> paciente(String pacienteId) async {
    final p = _contexto.pacienteDaConta(pacienteId);
    if (p == null) throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    return pacienteDoPortal(p);
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async =>
      _profissional(_contexto, profissionalId);

  /// A próxima sessão do `GET /portal/inicio` (só com a agenda liberada).
  @override
  Future<Agendamento?> proximaConsulta(String pacienteId) async {
    final c = _contexto;
    final inicio = await c.comPaciente(
      pacienteId,
      () async => lerInicio((await c.cliente.get('inicio')).objeto),
    );
    final s = inicio.proximaSessao;
    if (s == null) return null;
    final agendamento = agendamentoDoPortal(
      s,
      pacienteId: pacienteId,
      profissionalId: c.lembrarProfissional(
        primeiroNome: s.primeiroNomeDoTerapeuta,
        especialidade: s.especialidade,
      ),
    );
    return agendamento.situacao == SituacaoAgendamento.agendado
        ? agendamento
        : null;
  }

  /// As sessões das próximas 8 semanas (`GET /portal/agenda`).
  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) async =>
      _agendamentos(
        _contexto,
        pacienteId,
        await _agenda(_contexto, pacienteId),
      );

  @override
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId) async => null;

  @override
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId) async =>
      const [];

  @override
  Future<List<MarcoJornada>> marcos(String pacienteId) async => const [];
}

/// Confirmar presença e avisar ausência (TM18) no Terae local:
/// `POST /portal/agenda/{id}/confirmacao` e `/ausencia`.
///
/// Como no portal, "Não vamos conseguir" depois de confirmar ainda avisa a
/// clínica, mas "Sim, vamos" depois do aviso não volta (409 →
/// `sessaoEncerrada`). Sem fila: sem rede, recusa `semConexao`.
class PresencaTeraeLocal implements RepositorioPresenca {
  PresencaTeraeLocal(this._contexto);

  final ContextoDoPortal _contexto;

  /// O instante de cada recibo recebido neste aparelho, por sessão.
  final Map<String, DateTime> _recibos = {};

  @override
  Future<Map<String, ConfirmacaoDePresenca>> respostas(
    String pacienteId,
  ) async {
    final agenda = await _agenda(_contexto, pacienteId);
    if (!agenda.liberada) return const {};
    final agora = _contexto.cliente.relogio.agora();
    return {
      for (final s in agenda.sessoes)
        s.idSessao: ?confirmacaoDoPortal(
          s,
          pacienteId: pacienteId,
          respondidaEm: _recibos[s.idSessao] ?? agora,
        ),
    };
  }

  /// Nada a enviar (sem fila); a próxima leitura já vem do servidor.
  @override
  Future<void> atualizar(String pacienteId) async {}

  @override
  Future<ConfirmacaoDePresenca> responder({
    required String pacienteId,
    required String agendamentoId,
    required RespostaPresenca resposta,
  }) async {
    final c = _contexto;
    final (caminho, campo) = switch (resposta) {
      RespostaPresenca.vamos => ('confirmacao', 'confirmadoEm'),
      RespostaPresenca.naoVamos => ('ausencia', 'avisadoEm'),
    };
    final recibo = await c.comPaciente(
      pacienteId,
      () async =>
          (await c.cliente.post('agenda/$agendamentoId/$caminho')).objeto,
      seNaoExiste: MotivoRecusa.agendamentoInexistente,
      seConflito: MotivoRecusa.sessaoEncerrada,
    );
    final em = _lerRecibo(() => lerInstante(recibo, campo));
    _recibos[agendamentoId] = em;
    return ConfirmacaoDePresenca(
      agendamentoId: agendamentoId,
      pacienteId: pacienteId,
      resposta: resposta,
      respondidaEm: em,
      situacaoEnvio: SituacaoEnvio.enviado,
    );
  }
}

/// O programa em casa (TM16, TM17) no Terae local: `GET`/`POST
/// /portal/programa`.
///
/// O portal guarda um registro por orientação e dia (vale o primeiro;
/// quem registrou corrige o próprio, outra conta recebe 409 →
/// `registroDeOutraConta`) e só mostra o de hoje: [registros] devolve no
/// máximo o dia de hoje, e a faixa dos 14 dias some
/// (`CapacidadesDaFonte.faixaDosDias`). "Desfazer" não existe na API.
class ProgramaTeraeLocal implements RepositorioProgramaEmCasa {
  ProgramaTeraeLocal(this._contexto);

  final ContextoDoPortal _contexto;

  Future<ProgramaNoPortal> _programa(String pacienteId) {
    final c = _contexto;
    return c.comPaciente(
      pacienteId,
      () async => lerPrograma((await c.cliente.get('programa')).objeto),
    );
  }

  AtividadeDeCasa _atividade(String pacienteId, OrientacaoNoPortal o) =>
      atividadeDoPortal(
        o,
        pacienteId: pacienteId,
        profissionalId: _contexto.lembrarProfissional(
          primeiroNome: o.primeiroNomeDoTerapeuta,
          especialidade: o.especialidade,
        ),
      );

  /// Titular registra por si; responsável legal e cuidador, por quem cuida.
  QuemRegistrou _quem(String pacienteId) =>
      _contexto.pacienteDaConta(pacienteId)?.perfil == PerfilDoPortal.titular
      ? QuemRegistrou.paciente
      : QuemRegistrou.responsavel;

  @override
  Future<List<AtividadeDeCasa>> atividades(String pacienteId) async => [
    for (final o in (await _programa(pacienteId)).orientacoes)
      _atividade(pacienteId, o),
  ];

  @override
  Future<AtividadeDeCasa> atividade(
    String pacienteId,
    String atividadeId,
  ) async =>
      (await atividades(pacienteId))
          .where((a) => a.id == atividadeId)
          .firstOrNull ??
      (throw const RecusaDeRegra(MotivoRecusa.atividadeInexistente));

  @override
  Future<List<RegistroDeAtividade>> registros(
    String pacienteId, {
    int dias = 14,
  }) async {
    if (dias < 1) return const [];
    final programa = await _programa(pacienteId);
    final quem = _quem(pacienteId);
    return [
      for (final o in programa.orientacoes)
        if (o.registroDeHoje case final r?)
          registroDoPortal(
            o,
            r,
            pacienteId: pacienteId,
            dia: programa.dia,
            quem: r.registradoPor == RegistradoPor.estaConta
                ? quem
                : QuemRegistrou.responsavel,
          ),
    ]..sort((a, b) => b.registradoEm.compareTo(a.registradoEm));
  }

  @override
  Future<RegistroDeAtividade> registrar({
    required String pacienteId,
    required String atividadeId,
    required AdesaoEmCasa adesao,
    String? reflexao,
    required QuemRegistrou quem,
  }) async {
    final c = _contexto;
    final texto = reflexao?.trim();
    final recibo = await c.comPaciente(
      pacienteId,
      () async => (await c.cliente.post(
        'programa',
        corpo: {
          'registros': [
            {
              'idOrientacao': atividadeId,
              'adesao': adesaoParaOPortal(adesao),
              if (texto != null && texto.isNotEmpty) 'reflexao': texto,
            },
          ],
        },
      )).objeto,
      seNaoExiste: MotivoRecusa.atividadeInexistente,
      seConflito: MotivoRecusa.registroDeOutraConta,
    );
    final (recebidoEm, dia) = _lerRecibo(
      () => (lerInstante(recibo, 'recebidoEm'), lerDataCivil(recibo, 'dia')),
    );
    return RegistroDeAtividade(
      id: idDoRegistroDeHoje(atividadeId, dia),
      pacienteId: pacienteId,
      atividadeId: atividadeId,
      dia: dia,
      adesao: adesao,
      reflexao: texto,
      quem: quem,
      registradoEm: recebidoEm,
      situacaoEnvio: SituacaoEnvio.enviado,
    );
  }

  @override
  Future<RegistroDeAtividade> desfazer(String pacienteId, String registroId) =>
      Future.error(const RecusaDeRegra(MotivoRecusa.indisponivelNestaFonte));

  /// Nada a enviar (sem fila); a próxima leitura já vem do servidor.
  @override
  Future<void> atualizar(String pacienteId) async {}
}

/// A visão do cuidador (RFM08) no Terae local: o paciente e a agenda, se a
/// clínica a liberou para ele. Medicação e alertas não existem no portal:
/// vazio (a linha é só TO, e a tela do cuidador esconde o clínico).
class VisaoCuidadorTeraeLocal implements RepositorioVisaoCuidador {
  VisaoCuidadorTeraeLocal(this._contexto);

  final ContextoDoPortal _contexto;

  PacienteDaConta _doCuidador(String pacienteId) {
    final p = _contexto.pacienteDaConta(pacienteId);
    if (p == null || p.perfil != PerfilDoPortal.cuidador) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    return p;
  }

  @override
  Future<Paciente> pacienteAcompanhado({
    required String contaCuidadorId,
    required String pacienteId,
  }) async => pacienteDoPortal(_doCuidador(pacienteId)).paraCuidador();

  @override
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    _doCuidador(pacienteId);
    final agenda = await _agenda(_contexto, pacienteId);
    return [
      for (final a in _agendamentos(_contexto, pacienteId, agenda))
        a.paraCuidador(),
    ];
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async =>
      _profissional(_contexto, profissionalId);

  @override
  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  }) async => null;

  @override
  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  }) async => const [];

  @override
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async => const [];

  @override
  Future<Map<String, RespostaPresenca>> respostasDePresenca({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    _doCuidador(pacienteId);
    final agenda = await _agenda(_contexto, pacienteId);
    if (!agenda.liberada) return const {};
    final agora = _contexto.cliente.relogio.agora();
    return {
      for (final s in agenda.sessoes)
        if (confirmacaoDoPortal(s, pacienteId: pacienteId, respondidaEm: agora)
            case final c?)
          s.idSessao: c.resposta,
    };
  }
}

T _lerRecibo<T>(T Function() leitura) {
  try {
    return leitura();
  } on FormatException catch (e) {
    throw RespostaInesperadaDoPortal(detalhe: e.message);
  }
}
