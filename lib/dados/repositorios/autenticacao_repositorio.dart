import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/paciente.dart';

/// Tamanho mínimo da senha (D14). O Firebase Authentication aceita 6; o
/// Terae pede 8.
const int tamanhoMinimoDaSenha = 8;

/// Quem cria o acesso no primeiro acesso (D14; TM09 e TM10, passo 4): nome
/// para exibição, e-mail e senha.
///
/// A senha só passa por aqui a caminho do provedor (Firebase Authentication,
/// que guarda só o hash); o aparelho nunca a grava (RNFM04).
@immutable
class NovoAcesso {
  const NovoAcesso({
    required this.nome,
    required this.email,
    required this.senha,
  });

  final String nome;
  final String email;
  final String senha;

  /// O e-mail como é comparado: sem espaços e minúsculo.
  String get emailNormalizado => normalizarEmail(email);

  @override
  bool operator ==(Object other) =>
      other is NovoAcesso &&
      other.nome == nome &&
      other.email == email &&
      other.senha == senha;

  @override
  int get hashCode => Object.hash(nome, email, senha);

  /// Nunca mostra a senha (log, mensagem de teste).
  @override
  String toString() => 'NovoAcesso($nome, $emailNormalizado)';
}

/// E-mail como é comparado e gravado: sem espaços nas pontas e minúsculo.
String normalizarEmail(String email) => email.trim().toLowerCase();

final RegExp _formatoDeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// O texto tem a forma de um e-mail (`alguem@dominio.algo`)?
bool emailBemFormado(String email) =>
    _formatoDeEmail.hasMatch(normalizarEmail(email));

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

/// Autenticação por e-mail e senha e ativação por convite (RFM01, RFM09;
/// TM01, TM09, TM10).
///
/// Atividade 4 (D14): a conta é do Firebase Authentication, com e-mail e
/// senha; o aparelho guarda só a sessão (o token do Firebase), nunca a senha
/// (RNFM04). A memória simula o mesmo contrato para a web e os testes (D19).
/// Toda recusa é [RecusaDeRegra] (`falhas.dart`); nada é gravado quando
/// recusa.
abstract interface class RepositorioAutenticacao {
  /// RFM01 — entra com e-mail e senha e atualiza `ultimoAcessoEm`. Recusa:
  /// `credenciaisInvalidas`, `contaSemAcesso` (nenhum vínculo ativo),
  /// `contaInativa`, `semConexao`.
  Future<VinculosDaConta> entrar({
    required String email,
    required String senha,
  });

  /// A sessão que ficou no aparelho ao fechar o app (o Firebase guarda o
  /// token); `null` se não houver. Sem conexão, devolve os vínculos da cópia
  /// local (D16).
  Future<VinculosDaConta?> sessaoGuardada();

  /// "Sair": encerra a sessão no provedor e apaga os dados locais da conta
  /// (D20: o celular pode ser emprestado).
  Future<void> sair();

  /// TM09 passo 1 — confere código (tipo paciente), CPF e nascimento, sem
  /// consumir o código. Recusa: `codigoInexistente`, `tipoDeCodigoErrado`,
  /// `codigoJaUsado`, `codigoExpirado`, `cpfInvalido`, `cpfNaoConfere`,
  /// `nascimentoNaoConfere`, `pacienteInativo`.
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  });

  /// TM09 passo 4 — confere de novo e ativa: cria a conta do [acesso] (ou
  /// reaproveita a do mesmo e-mail, se a senha confere — a mãe que ativa o
  /// segundo filho), liga `Paciente.contaId`, grava um Consentimento novo e
  /// preenche `usadoEm` do convite. Além das recusas do passo 1,
  /// `criancaComoTitular` (paciente com menos de 12 anos na data de hoje da
  /// clínica só ativa com `responsavelLegal` — ECA art. 2º; LGPD art. 14,
  /// § 1º; regra em `dados/regras/consentimento.dart`), `emailInvalido`,
  /// `senhaFraca`, `emailJaCadastrado` (e-mail com outra senha) e
  /// `semConexao`.
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required NovoAcesso acesso,
  });

  /// TM10 passo 1 — confere código (tipo cuidador) e CPF do cuidador, sem
  /// consumir. Recusa também `conviteRevogado` (vínculo não está pendente).
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  });

  /// TM10 passo 4 — confere de novo (inclusive o limite de dois, §7.4) e
  /// aceita: cria (ou reaproveita) a conta do [acesso]; vínculo pendente →
  /// ativo, com `contaCuidadorId` e `autorizadoEm`; preenche `usadoEm`.
  /// Recusa também `limiteDeCuidadores` e as do [acesso], como na ativação
  /// do paciente.
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required NovoAcesso acesso,
  });
}
