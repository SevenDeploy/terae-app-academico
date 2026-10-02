/// Autenticação de mentira para os testes da TM01, TM09 e TM10: contas "no
/// aparelho", um código da clínica e um convite de cuidador válidos, e as
/// recusas que cada teste escolher. Anota todas as chamadas.
library;

import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/modelos/convite_acesso.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import '../../apoio/dubles.dart';

IdentidadeProvedor identidadeDe(
  String id,
  String nome, {
  Provedor provedor = Provedor.google,
}) => IdentidadeProvedor(
  provedor: provedor,
  idProvedor: '${provedor.name}-$id',
  email: '$id@exemplo.test',
  nomeExibicao: nome,
);

final IdentidadeProvedor idAna = identidadeDe('c-ana', 'Ana Lúcia');
final IdentidadeProvedor idRegina = identidadeDe('c-regina', 'Regina');
final IdentidadeProvedor idNova = identidadeDe('c-nova', 'Conta nova');

/// Código da clínica de Ana (TM09): CPF e nascimento de `pacienteDe`.
const String codigoDaClinica = 'K7Q2M9';
const String cpfDaPaciente = '52998224725';
final DataCivil nascimentoDaPaciente = DataCivil(2010, 3, 14);

/// Convite de cuidador de Paulo (TM10).
const String codigoDoConvite = 'P4UL07';
const String cpfDoCuidador = '11144477735';

/// Uma ativação pedida na TM09 (passo 3).
class Ativacao {
  Ativacao(this.qualidade, this.canal, this.versaoTermo, this.identidade);

  final QualidadeConsentimento qualidade;
  final CanalAutorizado canal;
  final String versaoTermo;
  final IdentidadeProvedor identidade;
}

class AutenticacaoFake extends AutenticacaoDuble {
  AutenticacaoFake({
    List<IdentidadeProvedor>? contas,
    this.recusaPorCodigo = const {},
    this.recusaNaEntrada = const {},
    this.recusaNoPasso3,
    DataCivil? nascimentoDoCadastro,
  }) : contas = contas ?? [idAna, idRegina, idNova],
       nascimentoDoCadastro = nascimentoDoCadastro ?? nascimentoDaPaciente;

  final List<IdentidadeProvedor> contas;

  /// Nascimento do paciente no cadastro da clínica (padrão: o de Ana, 16
  /// anos em 2/10/2026); o passo 1 só confere com ele.
  final DataCivil nascimentoDoCadastro;

  /// Recusa forçada por código (ex.: `codigoJaUsado`, `codigoExpirado`).
  final Map<String, MotivoRecusa> recusaPorCodigo;

  /// Recusa de `entrar` por `idProvedor` (ex.: `contaSemAcesso`).
  final Map<String, MotivoRecusa> recusaNaEntrada;

  /// Recusa só na conferência final (ativar/aceitar), como se o código
  /// tivesse sido usado entre o passo 1 e o 3.
  final MotivoRecusa? recusaNoPasso3;

  final List<Provedor> pedidosDeContas = [];
  final List<IdentidadeProvedor> entradas = [];
  final List<String> conferencias = [];
  final List<Ativacao> ativacoes = [];
  final List<IdentidadeProvedor> aceites = [];

  @override
  Future<List<IdentidadeProvedor>> identidadesNoAparelho(
    Provedor provedor,
  ) async {
    pedidosDeContas.add(provedor);
    return [
      for (final c in contas)
        if (c.provedor == provedor) c,
    ];
  }

  @override
  Future<VinculosDaConta> entrar(IdentidadeProvedor identidade) async {
    entradas.add(identidade);
    final recusa = recusaNaEntrada[identidade.idProvedor];
    if (recusa != null) throw RecusaDeRegra(recusa);
    return identidade == idRegina ? vinculosRegina() : vinculosAna();
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
    required IdentidadeProvedor identidade,
  }) async {
    ativacoes.add(
      Ativacao(qualidade, canalAutorizado, versaoTermo, identidade),
    );
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
    required IdentidadeProvedor identidade,
  }) async {
    aceites.add(identidade);
    final recusa = recusaNoPasso3;
    if (recusa != null) throw RecusaDeRegra(recusa);
    _conferir(codigo, cpf, TipoConvite.cuidador);
    return vinculosRegina();
  }
}
