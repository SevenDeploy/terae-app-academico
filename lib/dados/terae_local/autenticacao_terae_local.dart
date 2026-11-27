import '../../nucleo/tempo/data_civil.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';
import '../repositorios/autenticacao_repositorio.dart';
import '../repositorios/falhas.dart';
import 'cliente_do_portal.dart';
import 'contexto_do_portal.dart';
import 'mapeadores_do_portal.dart';
import 'sessao_do_portal.dart';

/// Recado do portal quando as 5 tentativas do código acabam (`Entrar.tsx`).
const String recadoDasTentativas =
    'Você usou as 5 tentativas deste código. Por segurança, entre de novo com '
    'a sua senha.';

/// Recado do portal quando a sessão provisória venceu (`Entrar.tsx`).
const String recadoDaSessaoVencida =
    'Por segurança, entre de novo com a sua senha.';

/// Entrar no portal da família do Terae local (fonte `local`): senha →
/// código por e-mail → sessão; o `/eu` vira a conta e os perfis.
///
/// A sessão fica só em memória (fechar o app encerra, como fechar o
/// navegador): [sessaoGuardada] é sempre `null`. O primeiro acesso por
/// código de convite do app não existe no portal (lá é por link do e-mail):
/// recusa `indisponivelNestaFonte`, e a tela nem o oferece
/// (`CapacidadesDaFonte.primeiroAcesso`).
class AutenticacaoTeraeLocal implements AutenticacaoComCodigo {
  AutenticacaoTeraeLocal(this._contexto);

  final ContextoDoPortal _contexto;

  SessaoDoPortal get _sessao => _contexto.sessao;

  @override
  Future<PassoDaEntrada> iniciarEntrada({
    required String email,
    required String senha,
  }) async {
    final EtapaDoLogin etapa;
    try {
      etapa = await _sessao.entrar(normalizarEmail(email), senha);
    } on SessaoDoPortalAcabou {
      // E-mail sem conta e senha errada respondem igual (401).
      throw const RecusaDeRegra(MotivoRecusa.credenciaisInvalidas);
    } on FalhaDoPortal catch (falha) {
      throw _recusaDaEntrada(falha);
    }
    return switch (etapa) {
      CodigoPedido() => _codigoPedido(etapa),
      LoginConcluido() => EntradaConcluida(await _concluir()),
    };
  }

  @override
  Future<VinculosDaConta> confirmarCodigo(
    String codigo, {
    required bool confiarNesteAparelho,
  }) async {
    try {
      await _sessao.enviarCodigo(
        codigo,
        confiarNesteDispositivo: confiarNesteAparelho,
      );
    } on SessaoDoPortalAcabou catch (e) {
      if (e.tentativasRestantes == 0) {
        throw const VoltarParaASenha(recadoDasTentativas);
      }
      throw CodigoNaoConfere(tentativasRestantes: e.tentativasRestantes);
    } on FalhaDoPortal catch (falha) {
      throw _recusaDaEntrada(falha);
    }
    return _concluir();
  }

  @override
  Future<CodigoDeAcessoPedido> reenviarCodigo() async {
    final EtapaDoLogin etapa;
    try {
      etapa = await _sessao.reenviarCodigo();
    } on SessaoDoPortalAcabou {
      throw const VoltarParaASenha(recadoDaSessaoVencida);
    } on FalhaDoPortal catch (falha) {
      throw _recusaDaEntrada(falha);
    }
    return switch (etapa) {
      CodigoPedido() => _codigoPedido(etapa),
      LoginConcluido() => throw const RespostaInesperadaDoPortal(
        detalhe: 'O reenvio do código concluiu a entrada.',
      ),
    };
  }

  /// Só para quem não conhece a etapa do código: com aparelho confiável
  /// entra direto; senão recusa (a TM01 do modo local usa [iniciarEntrada]).
  @override
  Future<VinculosDaConta> entrar({
    required String email,
    required String senha,
  }) async {
    final etapa = await iniciarEntrada(email: email, senha: senha);
    return switch (etapa) {
      EntradaConcluida(:final vinculos) => vinculos,
      CodigoDeAcessoPedido() => throw StateError(
        'A entrada pede o código do e-mail: use iniciarEntrada.',
      ),
    };
  }

  @override
  Future<VinculosDaConta?> sessaoGuardada() async => null;

  /// D20 — revoga a sessão no servidor (`DELETE /portal/sessoes`) e esquece
  /// tudo, o aparelho confiável também.
  @override
  Future<void> sair() async {
    _contexto.esquecer();
    await _sessao.sair();
  }

  @override
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  }) => _indisponivel();

  @override
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required NovoAcesso acesso,
  }) => _indisponivel();

  @override
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  }) => _indisponivel();

  @override
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required NovoAcesso acesso,
  }) => _indisponivel();

  Future<T> _indisponivel<T>() =>
      Future.error(const RecusaDeRegra(MotivoRecusa.indisponivelNestaFonte));

  /// O `/eu` depois da sessão aberta. Conta sem paciente nenhum não tem o
  /// que ver: encerra e recusa `contaSemAcesso`.
  Future<VinculosDaConta> _concluir() async {
    final EuDoPortal eu;
    try {
      eu = await _sessao.eu();
    } on SessaoDoPortalAcabou {
      throw const VoltarParaASenha(recadoDaSessaoVencida);
    } on FalhaDoPortal catch (falha) {
      throw _recusaDaEntrada(falha);
    }
    if (eu.pacientes.isEmpty) {
      await _sessao.sair(manterAparelhoConfiavel: true);
      throw const RecusaDeRegra(MotivoRecusa.contaSemAcesso);
    }
    _contexto.lembrarEu(eu);
    return vinculosDoPortal(eu);
  }

  static CodigoDeAcessoPedido _codigoPedido(CodigoPedido c) =>
      CodigoDeAcessoPedido(
        emailMascarado: c.emailMascarado,
        codigoEnviado: c.codigoEnviado,
        reenviarAPartirDe: c.reenviarAPartirDe,
      );

  static Exception _recusaDaEntrada(FalhaDoPortal falha) => switch (falha) {
    FalhaDeRedeNoPortal() => const RecusaDeRegra(MotivoRecusa.semConexao),
    LimiteDoPortalExcedido() => const RecusaDeRegra(
      MotivoRecusa.muitasTentativas,
    ),
    AcessoRecusadoNoPortal() => const RecusaDeRegra(MotivoRecusa.contaInativa),
    _ => falha,
  };
}
