import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/paciente.dart';

/// Provedor de identidade federado (RFM01; §19 TM01).
enum Provedor {
  google('Continuar com Google'),

  /// Só no iOS (diretriz 4.8 da App Store).
  apple('Continuar com Apple');

  const Provedor(this.rotulo);

  final String rotulo;
}

/// Uma conta do provedor (D5: simulada, "já no aparelho"). O Terae não recebe
/// nem guarda senha (RNFM04).
@immutable
class IdentidadeProvedor {
  const IdentidadeProvedor({
    required this.provedor,
    required this.idProvedor,
    required this.email,
    required this.nomeExibicao,
  });

  final Provedor provedor;
  final String idProvedor;
  final String email;
  final String nomeExibicao;

  @override
  bool operator ==(Object other) =>
      other is IdentidadeProvedor &&
      other.provedor == provedor &&
      other.idProvedor == idProvedor &&
      other.email == email &&
      other.nomeExibicao == nomeExibicao;

  @override
  int get hashCode => Object.hash(provedor, idProvedor, email, nomeExibicao);
}

/// A conta autenticada e os vínculos de onde a `Sessao` deriva os perfis
/// (§19: o perfil decorre dos vínculos, não é escolhido livremente).
@immutable
class VinculosDaConta {
  const VinculosDaConta({
    required this.conta,
    this.pacientes = const [],
    this.acompanhados = const [],
  });

  final ContaUsuario conta;

  /// Pacientes com `contaId` desta conta → perfil paciente/família.
  final List<Paciente> pacientes;

  /// Pacientes com VinculoCuidador ativo desta conta → perfil cuidador. Cópia
  /// do cuidador, sem CPF nem nascimento (`Paciente.paraCuidador`, RNFM05).
  final List<Paciente> acompanhados;
}

/// Código conferido no passo 1 da TM09/TM10, ainda não consumido.
@immutable
class ConviteConferido {
  const ConviteConferido({required this.convite, required this.nomePaciente});

  final ConviteAcesso convite;

  /// Para a TM09/TM10 dizer de quem é o cadastro ("Ana Lúcia convidou você").
  final String nomePaciente;
}

/// Autenticação e ativação por convite (RFM01, RFM09; TM01, TM09, TM10).
///
/// Nesta etapa sem servidor, a entrada pelo provedor e a validação dos códigos
/// são simuladas pela implementação em memória (§22). Toda recusa é
/// [RecusaDeRegra] (`falhas.dart`); nada é gravado quando recusa.
abstract interface class RepositorioAutenticacao {
  /// D5 — contas do [provedor] "no aparelho", para a folha "Escolha uma conta".
  Future<List<IdentidadeProvedor>> identidadesNoAparelho(Provedor provedor);

  /// RFM01 — entra com a identidade escolhida e atualiza `ultimoAcessoEm`.
  /// Recusa: `contaSemAcesso` (nenhuma conta ou nenhum vínculo ativo),
  /// `contaInativa`.
  Future<VinculosDaConta> entrar(IdentidadeProvedor identidade);

  /// TM09 passo 1 — confere código (tipo paciente), CPF e nascimento, sem
  /// consumir o código. Recusa: `codigoInexistente`, `tipoDeCodigoErrado`,
  /// `codigoJaUsado`, `codigoExpirado`, `cpfInvalido`, `cpfNaoConfere`,
  /// `nascimentoNaoConfere`, `pacienteInativo`.
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  });

  /// TM09 passo 3 — confere de novo e ativa: reaproveita a ContaUsuario do
  /// mesmo `idProvedor` ou cria uma, liga `Paciente.contaId`, grava um
  /// Consentimento novo e preenche `usadoEm` do convite.
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required IdentidadeProvedor identidade,
  });

  /// TM10 passo 1 — confere código (tipo cuidador) e CPF do cuidador, sem
  /// consumir. Recusa também `conviteRevogado` (vínculo não está pendente).
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  });

  /// TM10 passo 3 — confere de novo (inclusive o limite de dois, §7.4) e
  /// aceita: vínculo pendente → ativo, com `contaCuidadorId` e
  /// `autorizadoEm`; preenche `usadoEm`. Recusa também `limiteDeCuidadores`.
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required IdentidadeProvedor identidade,
  });
}
