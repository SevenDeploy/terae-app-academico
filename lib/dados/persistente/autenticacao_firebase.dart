import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/uuid.dart';
import '../../nucleo/validacao/cpf.dart';
import '../conversao_mapa.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';
import '../enums/situacao_conta.dart';
import '../enums/situacao_vinculo.dart';
import '../enums/tipo_convite.dart';
import '../local/banco_local.dart';
import '../local/cache_dao.dart';
import '../local/preferencias_locais.dart';
import '../memoria/regras.dart' show normalizarCodigo;
import '../modelos/consentimento.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/paciente.dart';
import '../regras/consentimento.dart';
import '../remoto/falhas_remotas.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/autenticacao_repositorio.dart';
import '../repositorios/falhas.dart';
import '../sincronizacao/monitor_conexao.dart';
import '../sincronizacao/sincronizador.dart';

Never _recusa(MotivoRecusa motivo) => throw RecusaDeRegra(motivo);

/// Prazo das chamadas ao Firebase Authentication, que fazem mais de uma ida
/// ao servidor (a tela mostra "Entrando…" enquanto isso).
const Duration prazoDaAutenticacao = Duration(seconds: 10);

/// Entrada e cadastro com o Firebase Authentication (e-mail e senha, D14) e
/// o Firestore (D12), com a cópia local da conta para abrir sem conexão.
///
/// A senha vai direto para o Firebase, que guarda só o hash; o aparelho fica
/// só com o token da sessão (o próprio SDK o guarda), nunca com a senha
/// (RNFM04). As conferências do convite seguem a mesma ordem da memória.
class AutenticacaoFirebase implements RepositorioAutenticacao {
  AutenticacaoFirebase({
    required this._auth,
    required this._fonte,
    required this._banco,
    required this._cache,
    required this._preferencias,
    required this._monitor,
    required Sincronizador sincronizador,
    required this._relogio,
    String Function()? gerarId,
  }) : _sinc = sincronizador,
       _gerarId = gerarId ?? gerarUuidV4;

  final FirebaseAuth _auth;
  final FonteFirestore _fonte;
  final BancoLocal _banco;
  final CacheDao _cache;
  final PreferenciasLocais _preferencias;
  final MonitorConexao _monitor;
  final Sincronizador _sinc;
  final Relogio _relogio;
  final String Function() _gerarId;

  void _exigirConexao() {
    if (!_monitor.online) _recusa(MotivoRecusa.semConexao);
  }

  // ------------------------------------------------------------------ TM01

  @override
  Future<VinculosDaConta> entrar({
    required String email,
    required String senha,
  }) async {
    _exigirConexao();
    final credencial = await comPrazo(
      () => _auth.signInWithEmailAndPassword(
        email: normalizarEmail(email),
        password: senha,
      ),
      prazo: prazoDaAutenticacao,
    );
    return _abrirSessao(credencial.user!.uid, atualizarAcesso: true);
  }

  @override
  Future<VinculosDaConta?> sessaoGuardada() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return null;
    if (_monitor.online) {
      try {
        return await _abrirSessao(usuario.uid, atualizarAcesso: false);
      } on RecusaDeRegra catch (r) {
        if (!ehSemConexao(r)) {
          await _auth.signOut();
          return null;
        }
      }
    }
    // Sem conexão: a última cópia local da conta (D16).
    final copia = await _cache.ler(_colecaoDaSessao, usuario.uid);
    if (copia == null) return null;
    final vinculos = vinculosDoMapa(copia);
    _acompanhar(vinculos);
    return vinculos;
  }

  @override
  Future<void> sair() async {
    _sinc.acompanhar(const []);
    await _auth.signOut();
    await _banco.apagarTudo();
    await _preferencias.limpar();
    await _sinc.atualizarSituacao();
  }

  /// Lê a conta e os vínculos no servidor, guarda a cópia local e passa os
  /// pacientes ao sincronizador. Sem vínculo ativo ou com conta inativa,
  /// encerra a sessão do provedor e recusa.
  Future<VinculosDaConta> _abrirSessao(
    String uid, {
    required bool atualizarAcesso,
  }) async {
    try {
      final contaMapa =
          await _fonte.ler(_fonte.contas.doc(uid)) ??
          _recusa(MotivoRecusa.contaSemAcesso);
      var conta = ContaUsuario.fromMap(contaMapa);
      if (conta.situacao != SituacaoConta.ativa) {
        _recusa(MotivoRecusa.contaInativa);
      }
      if (atualizarAcesso) {
        conta = conta.copyWith(ultimoAcessoEm: _relogio.agora());
        await comPrazo(
          () => _fonte.contas.doc(uid).update({
            'ultimoAcessoEm': conta.toMap()['ultimoAcessoEm'],
          }),
        );
      }
      final vinculos = await _vinculosDoServidor(conta);
      if (vinculos.pacientes.isEmpty && vinculos.acompanhados.isEmpty) {
        _recusa(MotivoRecusa.contaSemAcesso);
      }
      await _cache.salvar(
        _colecaoDaSessao,
        uid,
        uid,
        vinculosParaMapa(vinculos),
      );
      _acompanhar(vinculos);
      return vinculos;
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) await _auth.signOut();
      rethrow;
    }
  }

  /// §19 — o perfil decorre dos vínculos: pacientes ativos com `contaId`
  /// desta conta (cópia completa) e pacientes ativos com o uid em
  /// `cuidadoresAtivos` (cópia do cuidador, RNFM05).
  Future<VinculosDaConta> _vinculosDoServidor(ContaUsuario conta) async {
    final titulares = <Paciente>[];
    for (final publico in await _fonte.listar(
      _fonte.pacientes.where('contaId', isEqualTo: conta.id),
    )) {
      final pid = lerCampo<String>(publico, 'id');
      final privado = await _fonte.ler(_fonte.identificacao(pid));
      final p = Paciente.fromMap({...publico, ...?privado});
      if (p.ativo) titulares.add(p);
    }
    final acompanhados = [
      for (final publico in await _fonte.listar(
        _fonte.pacientes.where('cuidadoresAtivos', arrayContains: conta.id),
      ))
        Paciente.fromMap(publico),
    ].where((p) => p.ativo).map((p) => p.paraCuidador()).toList();
    // D24 — a qualidade do termo vigente de cada paciente desta conta.
    final qualidades = <String, QualidadeConsentimento>{
      for (final mapa in await _fonte.listar(
        _fonte.consentimentos.where('contaId', isEqualTo: conta.id),
      ))
        if (Consentimento.fromMap(mapa) case final c when c.revogadoEm == null)
          c.pacienteId: c.qualidade,
    };
    return VinculosDaConta(
      conta: conta,
      pacientes: List.unmodifiable(titulares),
      acompanhados: List.unmodifiable(acompanhados),
      qualidades: Map.unmodifiable(qualidades),
    );
  }

  /// Passa os pacientes ao sincronizador e já busca o histórico do servidor
  /// (conferido no emulador em 06/11: sem isto, a TM13 só mostrava o que foi
  /// registrado no aparelho até a próxima sincronização).
  void _acompanhar(VinculosDaConta v) {
    _sinc.acompanhar(v.pacientes.map((p) => p.id));
    unawaited(_sinc.sincronizar().catchError((Object _) {}));
  }

  // ------------------------------------------------------------ TM09, TM10

  @override
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  }) async {
    _exigirConexao();
    final (convite, nome) = await _conferirPaciente(
      codigo,
      cpf,
      dataNascimento,
    );
    return ConviteConferido(convite: convite, nomePaciente: nome);
  }

  @override
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required NovoAcesso acesso,
  }) async {
    _exigirConexao();
    if (versaoTermo.trim().isEmpty) {
      throw ArgumentError.value(versaoTermo, 'versaoTermo', 'vazia');
    }
    final (convite, _) = await _conferirPaciente(codigo, cpf, dataNascimento);
    if (!qualidadePermitida(
      qualidade,
      nascimento: dataNascimento,
      hoje: DataCivil.hoje(_relogio),
    )) {
      _recusa(MotivoRecusa.criancaComoTitular);
    }
    final conta = await _contaDoAcesso(acesso);
    final agora = _relogio.agora();
    final consentimento = Consentimento(
      id: _gerarId(),
      pacienteId: convite.pacienteId,
      contaId: conta.id,
      qualidade: qualidade,
      versaoTermo: versaoTermo.trim(),
      canalAutorizado: canalAutorizado,
      aceitoEm: agora,
    );
    final lote = _fonte.db.batch()
      ..set(_fonte.contas.doc(conta.id), conta.toMap(), SetOptions(merge: true))
      ..update(_fonte.paciente(convite.pacienteId), {
        'contaId': conta.id,
        'ativadoPorConvite': convite.codigo,
      })
      ..set(_fonte.consentimentos.doc(consentimento.id), consentimento.toMap())
      ..update(_fonte.convites.doc(convite.codigo), {
        'usadoEm': escreverInstante(agora),
      });
    await _gravarCadastro(lote);
    return _abrirSessao(conta.id, atualizarAcesso: false);
  }

  @override
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  }) async {
    _exigirConexao();
    final (convite, nome, _) = await _conferirCuidador(codigo, cpf);
    return ConviteConferido(convite: convite, nomePaciente: nome);
  }

  @override
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required NovoAcesso acesso,
  }) async {
    _exigirConexao();
    final (convite, _, vinculoId) = await _conferirCuidador(codigo, cpf);
    final conta = await _contaDoAcesso(acesso);
    final agora = escreverInstante(_relogio.agora());
    final lote = _fonte.db.batch()
      ..set(_fonte.contas.doc(conta.id), conta.toMap(), SetOptions(merge: true))
      ..update(_fonte.vinculos.doc(vinculoId), {
        'situacao': SituacaoVinculo.ativo.name,
        'contaCuidadorId': conta.id,
        'autorizadoEm': agora,
      })
      // §7.4 — a regra do Firestore recusa um terceiro cuidador ativo.
      ..update(_fonte.paciente(convite.pacienteId), {
        'cuidadoresAtivos': FieldValue.arrayUnion([conta.id]),
        'ativadoPorConvite': convite.codigo,
      })
      ..update(_fonte.convites.doc(convite.codigo), {'usadoEm': agora});
    try {
      await _gravarCadastro(lote);
    } on RecusaDeRegra catch (r) {
      if (r.motivo == MotivoRecusa.acessoNegado) {
        _recusa(MotivoRecusa.limiteDeCuidadores);
      }
      rethrow;
    }
    return _abrirSessao(conta.id, atualizarAcesso: false);
  }

  /// Grava o lote do cadastro; se o servidor recusar, desfaz a sessão do
  /// provedor (a conta do Authentication fica sem vínculo, como quem nunca
  /// terminou o cadastro).
  Future<void> _gravarCadastro(WriteBatch lote) async {
    try {
      await _fonte.gravar(lote);
    } on RecusaDeRegra {
      await _auth.signOut();
      rethrow;
    }
  }

  /// D14 — cria o usuário do [acesso] no Authentication ou, se o e-mail já
  /// existe, entra com a mesma senha (a mãe que ativa o segundo filho). Senha
  /// diferente: `emailJaCadastrado`.
  Future<ContaUsuario> _contaDoAcesso(NovoAcesso acesso) async {
    if (!emailBemFormado(acesso.email)) _recusa(MotivoRecusa.emailInvalido);
    if (acesso.senha.length < tamanhoMinimoDaSenha) {
      _recusa(MotivoRecusa.senhaFraca);
    }
    final email = acesso.emailNormalizado;
    UserCredential credencial;
    try {
      credencial = await comPrazo(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: acesso.senha,
        ),
        prazo: prazoDaAutenticacao,
      );
    } on RecusaDeRegra catch (r) {
      if (r.motivo != MotivoRecusa.emailJaCadastrado) rethrow;
      try {
        credencial = await comPrazo(
          () => _auth.signInWithEmailAndPassword(
            email: email,
            password: acesso.senha,
          ),
          prazo: prazoDaAutenticacao,
        );
      } on RecusaDeRegra catch (r) {
        if (r.motivo == MotivoRecusa.credenciaisInvalidas) {
          _recusa(MotivoRecusa.emailJaCadastrado);
        }
        rethrow;
      }
    }
    final uid = credencial.user!.uid;
    final existente = await _fonte.ler(_fonte.contas.doc(uid));
    if (existente != null) {
      final conta = ContaUsuario.fromMap(existente);
      if (conta.situacao != SituacaoConta.ativa) {
        await _auth.signOut();
        _recusa(MotivoRecusa.contaInativa);
      }
      return conta.copyWith(ultimoAcessoEm: _relogio.agora());
    }
    final nome = acesso.nome.trim();
    return ContaUsuario(
      id: uid,
      nomeExibicao: nome.isEmpty ? email : nome,
      email: email,
      idProvedor: uid,
      situacao: SituacaoConta.ativa,
      ultimoAcessoEm: _relogio.agora(),
    );
  }

  /// O convite público pelo código, conferido até a validade e o CPF (a
  /// ordem da memória: código → tipo → uso → revogação → validade → CPF).
  Future<(Mapa, ConviteAcesso)> _conviteConferido(
    String codigo,
    String cpf,
    TipoConvite tipo,
  ) async {
    final normalizado = normalizarCodigo(codigo);
    final mapa =
        await _fonte.ler(_fonte.convites.doc(normalizado)) ??
        _recusa(MotivoRecusa.codigoInexistente);
    final tipoDoConvite = lerEnum(mapa, 'tipo', TipoConvite.values);
    if (tipoDoConvite != tipo) _recusa(MotivoRecusa.tipoDeCodigoErrado);
    final usadoEm = lerInstanteOpcional(mapa, 'usadoEm');
    if (usadoEm != null) _recusa(MotivoRecusa.codigoJaUsado);
    if (mapa['revogado'] == true) _recusa(MotivoRecusa.conviteRevogado);
    final expiraEm = lerInstante(mapa, 'expiraEm');
    if (!_relogio.agora().isBefore(expiraEm)) {
      _recusa(MotivoRecusa.codigoExpirado);
    }
    if (!cpfValido(cpf)) _recusa(MotivoRecusa.cpfInvalido);
    final digitos = somenteDigitos(cpf);
    if (hashDoConvite(normalizado, digitos) != mapa['cpfHash']) {
      _recusa(MotivoRecusa.cpfNaoConfere);
    }
    final convite = ConviteAcesso(
      id: lerCampo<String>(mapa, 'id'),
      pacienteId: lerCampo<String>(mapa, 'pacienteId'),
      codigo: normalizado,
      tipo: tipoDoConvite,
      cpfConvidado: digitos,
      expiraEm: expiraEm,
    );
    return (mapa, convite);
  }

  Future<(ConviteAcesso, String)> _conferirPaciente(
    String codigo,
    String cpf,
    DataCivil nascimento,
  ) async {
    final (mapa, convite) = await _conviteConferido(
      codigo,
      cpf,
      TipoConvite.paciente,
    );
    if (hashDoConvite(convite.codigo, nascimento.paraIso()) !=
        mapa['nascimentoHash']) {
      _recusa(MotivoRecusa.nascimentoNaoConfere);
    }
    if (mapa['pacienteAtivo'] == false) _recusa(MotivoRecusa.pacienteInativo);
    return (convite, lerCampo<String>(mapa, 'nomePaciente'));
  }

  Future<(ConviteAcesso, String, String)> _conferirCuidador(
    String codigo,
    String cpf,
  ) async {
    final (mapa, convite) = await _conviteConferido(
      codigo,
      cpf,
      TipoConvite.cuidador,
    );
    if (mapa['pacienteAtivo'] == false) _recusa(MotivoRecusa.pacienteInativo);
    return (
      convite,
      lerCampo<String>(mapa, 'nomePaciente'),
      lerCampo<String>(mapa, 'vinculoId'),
    );
  }
}

/// Coleção da cópia local da sessão (D16).
const String _colecaoDaSessao = 'vinculosDaConta';

/// [VinculosDaConta] → mapa da cópia local.
Mapa vinculosParaMapa(VinculosDaConta v) => {
  'conta': v.conta.toMap(),
  'pacientes': [for (final p in v.pacientes) p.toMap()],
  'acompanhados': [for (final p in v.acompanhados) p.toMap()],
  'qualidades': {
    for (final MapEntry(key: pid, value: q) in v.qualidades.entries)
      pid: q.name,
  },
};

/// Mapa da cópia local → [VinculosDaConta]. Cópia anterior à D24 (sem
/// `qualidades`) volta sem nenhuma, e todo perfil fala como titular.
VinculosDaConta vinculosDoMapa(Mapa m) {
  List<Paciente> lista(String chave) => [
    for (final item in (m[chave] as List<Object?>? ?? const []))
      Paciente.fromMap(item! as Mapa),
  ];
  final qualidades = (m['qualidades'] as Map<String, Object?>?) ?? const {};
  return VinculosDaConta(
    conta: ContaUsuario.fromMap(m['conta']! as Mapa),
    pacientes: lista('pacientes'),
    acompanhados: lista('acompanhados'),
    qualidades: Map.unmodifiable({
      for (final pid in qualidades.keys)
        pid: lerEnum(qualidades, pid, QualidadeConsentimento.values),
    }),
  );
}
