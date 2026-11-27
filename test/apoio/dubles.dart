/// Dublês simples dos contratos e personas fictícias para teste de navegação.
///
/// Os dublês não guardam estado: todo método lança [UnimplementedError] até o
/// teste sobrescrever (estenda a classe). As telas-stub da fundação não chamam
/// repositório nenhum.
library;

import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/linha_de_cuidado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_conta.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/alerta.dart';
import 'package:terae_app/dados/modelos/conta_usuario.dart';
import 'package:terae_app/dados/modelos/item_medicacao.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/paciente.dart';
import 'package:terae_app/dados/modelos/profissional_saude.dart';
import 'package:terae_app/dados/modelos/receita_uso_continuo.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/cuidadores_repositorio.dart';
import 'package:terae_app/dados/repositorios/demonstracao_repositorio.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/paciente_repositorio.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/dados/repositorios/visao_cuidador_repositorio.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/widgets/faixa_emergencia.dart';

Never _naoUsado() => throw UnimplementedError('dublê: método não usado');

class AutenticacaoDuble implements RepositorioAutenticacao {
  @override
  Future<VinculosDaConta> entrar({
    required String email,
    required String senha,
  }) => _naoUsado();

  @override
  Future<VinculosDaConta?> sessaoGuardada() => _naoUsado();

  @override
  Future<void> sair() => _naoUsado();

  @override
  Future<ConviteConferido> conferirCodigoPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
  }) => _naoUsado();

  @override
  Future<VinculosDaConta> ativarPaciente({
    required String codigo,
    required String cpf,
    required DataCivil dataNascimento,
    required QualidadeConsentimento qualidade,
    required CanalAutorizado canalAutorizado,
    required String versaoTermo,
    required NovoAcesso acesso,
  }) => _naoUsado();

  @override
  Future<ConviteConferido> conferirConviteCuidador({
    required String codigo,
    required String cpf,
  }) => _naoUsado();

  @override
  Future<VinculosDaConta> aceitarConviteCuidador({
    required String codigo,
    required String cpf,
    required NovoAcesso acesso,
  }) => _naoUsado();
}

class PacienteDuble implements RepositorioPaciente {
  @override
  Future<Paciente> paciente(String pacienteId) => _naoUsado();

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) => _naoUsado();

  @override
  Future<Agendamento?> proximaConsulta(String pacienteId) => _naoUsado();

  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) => _naoUsado();

  @override
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId) => _naoUsado();

  @override
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId) => _naoUsado();

  @override
  Future<List<MarcoJornada>> marcos(String pacienteId) => _naoUsado();
}

class DiarioDuble implements RepositorioDiario {
  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) => _naoUsado();

  @override
  Future<List<ResultadoEnvio>> reenviarFila() => _naoUsado();

  /// A aba Diário lê a lista ao abrir (P3): sem registros, por padrão.
  @override
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) async =>
      const PaginaDoDiario(registros: [], haMais: false);

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async => const [];

  @override
  Future<List<RegistroDiario>> vencidos(String pacienteId) async => const [];

  @override
  Future<void> descartarVencido(String registroId) => _naoUsado();

  @override
  Future<RegistroDiario> registro(String registroId) => _naoUsado();

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) => _naoUsado();

  @override
  Future<ResultadoEnvio> corrigir(String registroId, EntradaDoDiario entrada) =>
      _naoUsado();

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) => _naoUsado();
}

class CuidadoresDuble implements RepositorioCuidadores {
  @override
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId) => _naoUsado();

  @override
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  }) => _naoUsado();

  @override
  Future<CuidadorAutorizado> revogar(String vinculoId) => _naoUsado();
}

class VisaoCuidadorDuble implements RepositorioVisaoCuidador {
  @override
  Future<Paciente> pacienteAcompanhado({
    required String contaCuidadorId,
    required String pacienteId,
  }) => _naoUsado();

  @override
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  }) => _naoUsado();

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) => _naoUsado();

  @override
  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  }) => _naoUsado();

  @override
  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  }) => _naoUsado();

  @override
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  }) => _naoUsado();

  /// F2 — sem respostas de presença (o controlador do cuidador sempre lê).
  @override
  Future<Map<String, RespostaPresenca>> respostasDePresenca({
    required String contaCuidadorId,
    required String pacienteId,
  }) async => const {};
}

class DemonstracaoDuble implements ControleDemonstracao {
  @override
  bool semConexao = false;

  @override
  Future<void> definirSemConexao({required bool semConexao}) async =>
      this.semConexao = semConexao;

  @override
  Future<void> reiniciarDados() async {}
}

Repositorios repositoriosDuble() => Repositorios(
  autenticacao: AutenticacaoDuble(),
  paciente: PacienteDuble(),
  diario: DiarioDuble(),
  cuidadores: CuidadoresDuble(),
  visaoCuidador: VisaoCuidadorDuble(),
  demonstracao: DemonstracaoDuble(),
);

/// Lançador que só anota o que abriria (tel:188, tel:192).
class LancadorDuble extends LancadorExterno {
  final List<Uri> abertos = [];

  @override
  Future<bool> abrir(Uri uri) async {
    abertos.add(uri);
    return true;
  }
}

/// 2/10/2026 10:00 em Cuiabá.
final DateTime agoraDeTeste = instanteNaClinica(2026, 10, 2, 10);

ContaUsuario contaDe(String id, String nome) => ContaUsuario(
  id: id,
  nomeExibicao: nome,
  email: '$id@exemplo.test',
  idProvedor: 'uid-$id',
  situacao: SituacaoConta.ativa,
);

Paciente pacienteDe(
  String id,
  String nome, {
  String? contaId,
  Set<LinhaDeCuidado> linhas = Paciente.linhasPadrao,
}) => Paciente(
  id: id,
  contaId: contaId,
  profissionalRefId: 'pr-helena',
  nome: nome,
  cpf: '52998224725',
  dataNascimento: DataCivil(2010, 3, 14),
  ativo: true,
  linhasDeCuidado: linhas,
);

/// Terapia ocupacional só (D21): Miguel, Laura, Antônio.
const Set<LinhaDeCuidado> soTerapiaOcupacional = {
  LinhaDeCuidado.terapiaOcupacional,
};

/// As duas linhas (D21): Ana na demonstração.
const Set<LinhaDeCuidado> asDuasLinhas = {
  LinhaDeCuidado.acompanhamentoClinico,
  LinhaDeCuidado.terapiaOcupacional,
};

/// Ana Lúcia: titular, um perfil paciente/família. Com [linhas], o
/// acompanhamento que o teste quiser (D21; padrão: só o clínico).
VinculosDaConta vinculosAna({
  Set<LinhaDeCuidado> linhas = Paciente.linhasPadrao,
}) => VinculosDaConta(
  conta: contaDe('c-ana', 'Ana Lúcia'),
  pacientes: [
    pacienteDe('p-ana', 'Ana Lúcia Martins', contaId: 'c-ana', linhas: linhas),
  ],
  qualidades: const {'p-ana': QualidadeConsentimento.titular},
);

/// Antônio: titular, só terapia ocupacional (D21, D23).
VinculosDaConta vinculosAntonio() => VinculosDaConta(
  conta: contaDe('c-antonio', 'Antônio'),
  pacientes: [
    pacienteDe(
      'p-antonio',
      'Antônio Carlos Ribeiro',
      contaId: 'c-antonio',
      linhas: soTerapiaOcupacional,
    ),
  ],
  qualidades: const {'p-antonio': QualidadeConsentimento.titular},
);

/// Regina: cuidadora de Ana, um perfil cuidador (cópia sem CPF/nascimento).
VinculosDaConta vinculosRegina() => VinculosDaConta(
  conta: contaDe('c-regina', 'Regina'),
  acompanhados: [pacienteDe('p-ana', 'Ana Lúcia Martins').paraCuidador()],
);

/// Patrícia: mãe (responsável legal) de Miguel e de Laura, dois perfis
/// paciente/família, só terapia ocupacional (D21, D24).
VinculosDaConta vinculosPatricia() => VinculosDaConta(
  conta: contaDe('c-patricia', 'Patrícia'),
  pacientes: [
    pacienteDe(
      'p-miguel',
      'Miguel Andrade Neves',
      contaId: 'c-patricia',
      linhas: soTerapiaOcupacional,
    ),
    pacienteDe(
      'p-laura',
      'Laura Andrade Neves',
      contaId: 'c-patricia',
      linhas: soTerapiaOcupacional,
    ),
  ],
  qualidades: const {
    'p-miguel': QualidadeConsentimento.responsavelLegal,
    'p-laura': QualidadeConsentimento.responsavelLegal,
  },
);

/// Conta com os dois papéis: família de Miguel e cuidadora de Ana.
VinculosDaConta vinculosMistos() => VinculosDaConta(
  conta: contaDe('c-misto', 'Conta mista'),
  pacientes: [
    pacienteDe(
      'p-miguel',
      'Miguel Andrade Neves',
      contaId: 'c-misto',
      linhas: soTerapiaOcupacional,
    ),
  ],
  acompanhados: [pacienteDe('p-ana', 'Ana Lúcia Martins').paraCuidador()],
  qualidades: const {'p-miguel': QualidadeConsentimento.responsavelLegal},
);
