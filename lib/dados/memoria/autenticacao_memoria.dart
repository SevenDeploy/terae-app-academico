import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/validacao/cpf.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';
import '../enums/situacao_conta.dart';
import '../enums/situacao_vinculo.dart';
import '../enums/tipo_convite.dart';
import '../modelos/consentimento.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/paciente.dart';
import '../modelos/vinculo_cuidador.dart';
import '../regras/consentimento.dart';
import '../repositorios/autenticacao_repositorio.dart';
import '../repositorios/cuidadores_repositorio.dart';
import '../repositorios/falhas.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';

Never _recusa(MotivoRecusa motivo) => throw RecusaDeRegra(motivo);

/// Entrada simulada pelo provedor e primeiro acesso por convite (RFM01,
/// RFM09; TM01, TM09, TM10), com as regras de convite do §23.
///
/// Ordem das conferências (a primeira que falha decide a recusa): código →
/// tipo → uso → vínculo pendente (só cuidador) → validade → CPF → nascimento
/// (só paciente) → paciente ativo → qualidade de quem aceita (só na ativação
/// do paciente: criança só pelo responsável legal). O código vem antes do CPF para que quem só
/// sabe um CPF não descubra nada sobre o cadastro (§23); a revogação vem antes
/// da validade, porque explica melhor por que o convite parou de valer. Toda
/// conferência acontece antes de qualquer gravação: recusa não grava nada.
class AutenticacaoMemoria implements RepositorioAutenticacao {
  AutenticacaoMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<List<IdentidadeProvedor>> identidadesNoAparelho(
    Provedor provedor,
  ) async {
    await _memoria.esperar();
    return List.unmodifiable(
      _e.identidades.where((i) => i.provedor == provedor),
    );
  }

  @override
  Future<VinculosDaConta> entrar(IdentidadeProvedor identidade) async {
    await _memoria.esperar();
    final conta =
        _e.contaDoProvedor(identidade.idProvedor) ??
        _recusa(MotivoRecusa.contaSemAcesso);
    if (conta.situacao != SituacaoConta.ativa) {
      _recusa(MotivoRecusa.contaInativa);
    }
    final vinculos = _e.vinculosDaConta(conta);
    if (vinculos.pacientes.isEmpty && vinculos.acompanhados.isEmpty) {
      _recusa(MotivoRecusa.contaSemAcesso);
    }
    final atualizada = conta.copyWith(ultimoAcessoEm: _memoria.agora());
    _e.contas[conta.id] = atualizada;
    return _e.vinculosDaConta(atualizada);
  }

  @override
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  }) async {
    await _memoria.esperar();
    final (convite, paciente) = _conferirPaciente(codigo, cpf, dataNascimento);
    return ConviteConferido(convite: convite, nomePaciente: paciente.nome);
  }

  @override
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required IdentidadeProvedor identidade,
  }) async {
    await _memoria.esperar();
    if (versaoTermo.trim().isEmpty) {
      throw ArgumentError.value(versaoTermo, 'versaoTermo', 'vazia');
    }
    final (convite, paciente) = _conferirPaciente(codigo, cpf, dataNascimento);
    // Criança só pelo responsável legal (ECA art. 2º; LGPD art. 14, § 1º).
    // O nascimento já conferiu com o do cadastro.
    if (!qualidadePermitida(
      qualidade,
      nascimento: dataNascimento,
      hoje: _memoria.hoje(),
    )) {
      _recusa(MotivoRecusa.criancaComoTitular);
    }
    final agora = _memoria.agora();
    final conta = _contaQueEntra(identidade);
    // Daqui em diante só grava: nenhuma recusa possível.
    _e.contas[conta.id] = conta;
    _e.pacientes[paciente.id] = paciente.copyWith(contaId: conta.id);
    // Termo novo gera registro novo (§23): o consentimento anterior, se
    // houver, fica como está.
    final consentimento = Consentimento(
      id: _memoria.novoId(),
      pacienteId: paciente.id,
      contaId: conta.id,
      qualidade: qualidade,
      versaoTermo: versaoTermo.trim(),
      canalAutorizado: canalAutorizado,
      aceitoEm: agora,
    );
    _e.consentimentos[consentimento.id] = consentimento;
    _e.convites[convite.id] = convite.copyWith(usadoEm: agora);
    return _e.vinculosDaConta(conta);
  }

  @override
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  }) async {
    await _memoria.esperar();
    final (convite, _, paciente) = _conferirCuidador(codigo, cpf);
    return ConviteConferido(convite: convite, nomePaciente: paciente.nome);
  }

  @override
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required IdentidadeProvedor identidade,
  }) async {
    await _memoria.esperar();
    final (convite, vinculo, paciente) = _conferirCuidador(codigo, cpf);
    // §23 — o limite é conferido de novo no aceite: depois dele, o paciente
    // continua com no máximo dois pendentes ou ativos.
    if (_e.vinculosNoLimite(
          paciente.id,
          agora: _memoria.agora(),
          exceto: vinculo.id,
        ) >=
        limiteCuidadores) {
      _recusa(MotivoRecusa.limiteDeCuidadores);
    }
    final agora = _memoria.agora();
    final conta = _contaQueEntra(identidade);
    _e.contas[conta.id] = conta;
    _e.vinculos[vinculo.id] = vinculo.copyWith(
      situacao: SituacaoVinculo.ativo,
      contaCuidadorId: conta.id,
      autorizadoEm: agora,
    );
    _e.convites[convite.id] = convite.copyWith(usadoEm: agora);
    return _e.vinculosDaConta(conta);
  }

  /// TM09 — conferências do código da clínica, sem gravar nada.
  (ConviteAcesso, Paciente) _conferirPaciente(
    String codigo,
    String cpf,
    DataCivil dataNascimento,
  ) {
    final convite = _conviteUtilizavel(codigo, TipoConvite.paciente);
    _conferirValidadeECpf(convite, cpf);
    final paciente = _e.pacientes[convite.pacienteId]!;
    if (paciente.dataNascimento != dataNascimento) {
      _recusa(MotivoRecusa.nascimentoNaoConfere);
    }
    if (!paciente.ativo) _recusa(MotivoRecusa.pacienteInativo);
    return (convite, paciente);
  }

  /// TM10 — conferências do convite de cuidador, sem gravar nada. O vínculo
  /// tem de estar pendente: revogar um convite em aberto o invalida (§23).
  (ConviteAcesso, VinculoCuidador, Paciente) _conferirCuidador(
    String codigo,
    String cpf,
  ) {
    final convite = _conviteUtilizavel(codigo, TipoConvite.cuidador);
    final vinculo = _e.vinculoDoConvite(convite.id);
    if (vinculo.situacao != SituacaoVinculo.pendente) {
      _recusa(MotivoRecusa.conviteRevogado);
    }
    _conferirValidadeECpf(convite, cpf);
    final paciente = _e.pacientes[convite.pacienteId]!;
    if (!paciente.ativo) _recusa(MotivoRecusa.pacienteInativo);
    return (convite, vinculo, paciente);
  }

  /// Código existe, é do [tipo] pedido e não foi usado (`usadoEm` encerra).
  ConviteAcesso _conviteUtilizavel(String codigo, TipoConvite tipo) {
    final convite =
        _e.conviteDoCodigo(codigo) ?? _recusa(MotivoRecusa.codigoInexistente);
    if (convite.tipo != tipo) _recusa(MotivoRecusa.tipoDeCodigoErrado);
    if (convite.usadoEm != null) _recusa(MotivoRecusa.codigoJaUsado);
    return convite;
  }

  /// Convite expirado não ativa nada; o CPF tem de ser o `cpfConvidado`.
  void _conferirValidadeECpf(ConviteAcesso convite, String cpf) {
    if (!_memoria.agora().isBefore(convite.expiraEm)) {
      _recusa(MotivoRecusa.codigoExpirado);
    }
    if (!cpfValido(cpf)) _recusa(MotivoRecusa.cpfInvalido);
    if (somenteDigitos(cpf) != convite.cpfConvidado) {
      _recusa(MotivoRecusa.cpfNaoConfere);
    }
  }

  /// A conta do mesmo `idProvedor`, com o último acesso de agora, ou uma
  /// nova — sem gravar. Conta inativa recusa.
  ContaUsuario _contaQueEntra(IdentidadeProvedor identidade) {
    final agora = _memoria.agora();
    final existente = _e.contaDoProvedor(identidade.idProvedor);
    if (existente != null) {
      if (existente.situacao != SituacaoConta.ativa) {
        _recusa(MotivoRecusa.contaInativa);
      }
      return existente.copyWith(ultimoAcessoEm: agora);
    }
    return ContaUsuario(
      id: _memoria.novoId(),
      nomeExibicao: identidade.nomeExibicao,
      email: identidade.email,
      idProvedor: identidade.idProvedor,
      situacao: SituacaoConta.ativa,
      ultimoAcessoEm: agora,
    );
  }
}
