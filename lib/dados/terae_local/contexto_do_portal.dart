/// O estado compartilhado pelos repositórios do Terae local: a sessão do
/// portal, o paciente escolhido no servidor e a tradução das falhas HTTP em
/// recusas de regra (`falhas.dart`).
///
/// A API do portal guarda o paciente atual **na sessão** (`PUT
/// /portal/sessoes/paciente`); sem ele, `/inicio`, `/programa` e `/agenda`
/// respondem 409 "Escolha o paciente primeiro". Como o app troca de perfil a
/// qualquer momento e duas telas podem ler ao mesmo tempo, toda chamada passa
/// por [comPaciente], que roda uma de cada vez e escolhe o paciente antes
/// quando ele muda.
library;

import 'dart:async';

import '../modelos/profissional_saude.dart';
import '../repositorios/falhas.dart';
import 'cliente_do_portal.dart';
import 'sessao_do_portal.dart';

/// Contexto dos repositórios do Terae local.
class ContextoDoPortal {
  ContextoDoPortal({required this.cliente, SessaoDoPortal? sessao})
    : sessao = sessao ?? SessaoDoPortal(cliente);

  final ClienteDoPortal cliente;
  final SessaoDoPortal sessao;

  /// Chamado quando o servidor diz que a sessão acabou (401) fora da
  /// entrada: a composição liga à `Sessao.sair` (o roteador volta ao Entrar).
  void Function()? aoSessaoAcabar;

  EuDoPortal? _eu;
  String? _pacienteNoServidor;
  Future<void> _fila = Future.value();

  /// Os profissionais vistos nas sessões e orientações, pelo id sintético de
  /// [idDoProfissional] (a API só manda primeiro nome e especialidade).
  final Map<String, ProfissionalSaude> _profissionais = {};

  /// O último `GET /portal/eu`.
  EuDoPortal? get eu => _eu;

  /// Guarda o Eu lido na entrada (e o paciente que ele já traz escolhido).
  void lembrarEu(EuDoPortal eu) {
    _eu = eu;
    _pacienteNoServidor = eu.idPacienteAtual;
  }

  /// Esquece tudo da conta (Sair ou sessão acabada).
  void esquecer() {
    _eu = null;
    _pacienteNoServidor = null;
    _profissionais.clear();
  }

  /// O paciente da conta, como o `/eu` o trouxe.
  PacienteDaConta? pacienteDaConta(String idPaciente) =>
      _eu?.pacientes.where((p) => p.idPaciente == idPaciente).firstOrNull;

  /// Registra o profissional de uma sessão ou orientação e devolve o id.
  String lembrarProfissional({
    required String primeiroNome,
    String? especialidade,
  }) {
    final id = idDoProfissional(primeiroNome, especialidade);
    _profissionais[id] = ProfissionalSaude(
      id: id,
      nome: primeiroNome,
      // O portal não expõe o registro no conselho (só o primeiro nome).
      registroConselho: '',
      especialidade: especialidade ?? '',
    );
    return id;
  }

  /// O profissional já visto; `null` se ainda não apareceu.
  ProfissionalSaude? profissional(String id) => _profissionais[id];

  /// Roda [chamada] com [idPaciente] escolhido no servidor, uma chamada por
  /// vez, e traduz a falha HTTP em [RecusaDeRegra]:
  /// - sem rede → `semConexao`; 401 → `sessaoTerminou` (e [aoSessaoAcabar]);
  /// - 403 → `acessoNegado`; 404 → [seNaoExiste]; 409 → [seConflito];
  /// - 429 → `muitasTentativas`; o resto sobe como está.
  Future<T> comPaciente<T>(
    String idPaciente,
    Future<T> Function() chamada, {
    MotivoRecusa seNaoExiste = MotivoRecusa.acessoNegado,
    MotivoRecusa seConflito = MotivoRecusa.acessoNegado,
  }) {
    final resultado = _fila.then(
      (_) => _traduzir(
        () async {
          await _escolher(idPaciente);
          try {
            return await chamada();
          } on ConflitoNoPortal catch (e) {
            // A sessão perdeu o paciente (outra aba, sessão girada): de novo.
            if (!(e.detalhe ?? '').contains('Escolha o paciente')) rethrow;
            _pacienteNoServidor = null;
            await _escolher(idPaciente);
            return chamada();
          }
        },
        seNaoExiste: seNaoExiste,
        seConflito: seConflito,
      ),
    );
    _fila = resultado.then<void>((_) {}, onError: (Object _) {});
    return resultado;
  }

  Future<void> _escolher(String idPaciente) async {
    if (_pacienteNoServidor == idPaciente) return;
    final eu = await sessao.escolherPaciente(idPaciente);
    _eu = eu;
    _pacienteNoServidor = eu.idPacienteAtual ?? idPaciente;
  }

  Future<T> _traduzir<T>(
    Future<T> Function() chamada, {
    required MotivoRecusa seNaoExiste,
    required MotivoRecusa seConflito,
  }) async {
    try {
      return await chamada();
    } on FalhaDeRedeNoPortal {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    } on SessaoDoPortalAcabou {
      esquecer();
      cliente.esquecerSessao();
      aoSessaoAcabar?.call();
      throw const RecusaDeRegra(MotivoRecusa.sessaoTerminou);
    } on AcessoRecusadoNoPortal {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    } on NaoEncontradoNoPortal {
      throw RecusaDeRegra(seNaoExiste);
    } on ConflitoNoPortal {
      throw RecusaDeRegra(seConflito);
    } on LimiteDoPortalExcedido {
      throw const RecusaDeRegra(MotivoRecusa.muitasTentativas);
    }
  }
}

/// Id estável de um profissional que o portal só mostra pelo primeiro nome e
/// pela especialidade (`Ana|terapia ocupacional`).
String idDoProfissional(String primeiroNome, String? especialidade) =>
    'portal:$primeiroNome|${especialidade ?? ''}';
