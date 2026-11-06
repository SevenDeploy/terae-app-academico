/// Autenticação de mentira para os testes da TM01, TM09 e TM10: contas com
/// e-mail e senha (D14), um código da clínica e um convite de cuidador
/// válidos, e as recusas que cada teste escolher. Anota todas as chamadas.
library;

import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/modelos/convite_acesso.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import '../../apoio/dubles.dart';

/// Senha de fixture das contas de teste.
const String senhaDeTeste = 'senha-de-teste';

NovoAcesso acessoDe(String id, String nome) =>
    NovoAcesso(nome: nome, email: '$id@exemplo.test', senha: senhaDeTeste);

final NovoAcesso idAna = acessoDe('c-ana', 'Ana Lúcia');
final NovoAcesso idRegina = acessoDe('c-regina', 'Regina');
final NovoAcesso idNova = acessoDe('c-nova', 'Conta nova');

/// Código da clínica de Ana (TM09): CPF e nascimento de `pacienteDe`.
const String codigoDaClinica = 'K7Q2M9';
const String cpfDaPaciente = '52998224725';
final DataCivil nascimentoDaPaciente = DataCivil(2010, 3, 14);

/// Convite de cuidador de Paulo (TM10).
const String codigoDoConvite = 'P4UL07';
const String cpfDoCuidador = '11144477735';

/// Uma ativação pedida na TM09 (passo 4).
class Ativacao {
  Ativacao(this.qualidade, this.canal, this.versaoTermo, this.acesso);

  final QualidadeConsentimento qualidade;
  final CanalAutorizado canal;
  final String versaoTermo;
  final NovoAcesso acesso;
}

class AutenticacaoFake extends AutenticacaoDuble {
  AutenticacaoFake({
    List<NovoAcesso>? contas,
    this.recusaPorCodigo = const {},
    this.recusaNaEntrada = const {},
    this.recusaNoPasso3,
    DataCivil? nascimentoDoCadastro,
  }) : contas = contas ?? [idAna, idRegina, idNova],
       nascimentoDoCadastro = nascimentoDoCadastro ?? nascimentoDaPaciente;

  /// Contas que existem (e-mail e senha).
  final List<NovoAcesso> contas;

  /// Nascimento do paciente no cadastro da clínica (padrão: o de Ana, 16
  /// anos em 2/10/2026); o passo 1 só confere com ele.
  final DataCivil nascimentoDoCadastro;

  /// Recusa forçada por código (ex.: `codigoJaUsado`, `codigoExpirado`).
  final Map<String, MotivoRecusa> recusaPorCodigo;

  /// Recusa de `entrar` por e-mail (ex.: `contaSemAcesso`).
  final Map<String, MotivoRecusa> recusaNaEntrada;

  /// Recusa só na conferência final (ativar/aceitar), como se o código
  /// tivesse sido usado entre o passo 1 e o 4.
  final MotivoRecusa? recusaNoPasso3;

  /// E-mails com que se tentou entrar.
  final List<String> entradas = [];
  final List<String> conferencias = [];
  final List<Ativacao> ativacoes = [];
  final List<NovoAcesso> aceites = [];

  @override
  Future<VinculosDaConta> entrar({
    required String email,
    required String senha,
  }) async {
    entradas.add(email);
    final recusa = recusaNaEntrada[email];
    if (recusa != null) throw RecusaDeRegra(recusa);
    final existe = contas.any((c) => c.email == email && c.senha == senha);
    if (!existe) throw const RecusaDeRegra(MotivoRecusa.credenciaisInvalidas);
    return email == idRegina.email ? vinculosRegina() : vinculosAna();
  }

  ConviteConferido _conferir(
    String codigo,
    String cpf,
    TipoConvite tipo, {
    DataCivil? nascimento,
  }) {
    final forcada = recusaPorCodigo[codigo];
    if (forcada != null) throw RecusaDeRegra(forcada);
    final esperado = tipo == TipoConvite.paciente
        ? codigoDaClinica
        : codigoDoConvite;
    if (codigo != esperado) {
      throw RecusaDeRegra(
        codigo == codigoDaClinica || codigo == codigoDoConvite
            ? MotivoRecusa.tipoDeCodigoErrado
            : MotivoRecusa.codigoInexistente,
      );
    }
    final cpfEsperado = tipo == TipoConvite.paciente
        ? cpfDaPaciente
        : cpfDoCuidador;
    if (cpf != cpfEsperado) {
      throw const RecusaDeRegra(MotivoRecusa.cpfNaoConfere);
    }
    if (tipo == TipoConvite.paciente && nascimento != nascimentoDoCadastro) {
      throw const RecusaDeRegra(MotivoRecusa.nascimentoNaoConfere);
    }
    return ConviteConferido(
      convite: ConviteAcesso(
        id: 'cv-$codigo',
        pacienteId: 'p-ana',
        codigo: codigo,
        tipo: tipo,
        cpfConvidado: cpfEsperado,
        expiraEm: agoraDeTeste.add(const Duration(days: 5)),
      ),
      nomePaciente: 'Ana Lúcia Martins',
    );
  }

  @override
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  }) async {
    conferencias.add('$codigo|$cpf|$dataNascimento');
    return _conferir(
      codigo,
      cpf,
      TipoConvite.paciente,
      nascimento: dataNascimento,
    );
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
    ativacoes.add(Ativacao(qualidade, canalAutorizado, versaoTermo, acesso));
    final recusa = recusaNoPasso3;
    if (recusa != null) throw RecusaDeRegra(recusa);
    _conferir(codigo, cpf, TipoConvite.paciente, nascimento: dataNascimento);
    return vinculosAna();
  }

  @override
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  }) async {
    conferencias.add('$codigo|$cpf');
    return _conferir(codigo, cpf, TipoConvite.cuidador);
  }

  @override
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required NovoAcesso acesso,
  }) async {
    aceites.add(acesso);
    final recusa = recusaNoPasso3;
    if (recusa != null) throw RecusaDeRegra(recusa);
    _conferir(codigo, cpf, TipoConvite.cuidador);
    return vinculosRegina();
  }
}
