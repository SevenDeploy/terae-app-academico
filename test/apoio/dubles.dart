/// Dublês simples dos contratos e personas fictícias para teste de navegação.
///
/// Os dublês não guardam estado: todo método lança [UnimplementedError] até o
/// teste sobrescrever (estenda a classe). As telas-stub da fundação não chamam
/// repositório nenhum.
library;

import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
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
  Future<List<IdentidadeProvedor>> identidadesNoAparelho(Provedor provedor) =>
      _naoUsado();

  @override
  Future<VinculosDaConta> entrar(IdentidadeProvedor identidade) => _naoUsado();

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
    required IdentidadeProvedor identidade,
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
    required IdentidadeProvedor identidade,
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

  @override
  Future<List<RegistroDiario>> registros(String pacienteId) => _naoUsado();

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) => _naoUsado();
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
  idProvedor: 'google-$id',
  situacao: SituacaoConta.ativa,
);

Paciente pacienteDe(String id, String nome, {String? contaId}) => Paciente(
  id: id,
  contaId: contaId,
  profissionalRefId: 'pr-helena',
  nome: nome,
  cpf: '52998224725',
  dataNascimento: DataCivil(2010, 3, 14),
  ativo: true,
);

/// Ana Lúcia: titular, um perfil paciente/família.
VinculosDaConta vinculosAna() => VinculosDaConta(
  conta: contaDe('c-ana', 'Ana Lúcia'),
  pacientes: [pacienteDe('p-ana', 'Ana Lúcia Martins', contaId: 'c-ana')],
);

/// Regina: cuidadora de Ana, um perfil cuidador (cópia sem CPF/nascimento).
VinculosDaConta vinculosRegina() => VinculosDaConta(
  conta: contaDe('c-regina', 'Regina'),
  acompanhados: [pacienteDe('p-ana', 'Ana Lúcia Martins').paraCuidador()],
);

/// Patrícia: mãe de Miguel e de Laura, dois perfis paciente/família.
VinculosDaConta vinculosPatricia() => VinculosDaConta(
  conta: contaDe('c-patricia', 'Patrícia'),
  pacientes: [
    pacienteDe('p-miguel', 'Miguel Andrade Neves', contaId: 'c-patricia'),
    pacienteDe('p-laura', 'Laura Andrade Neves', contaId: 'c-patricia'),
  ],
);

/// Conta com os dois papéis: família de Miguel e cuidadora de Ana.
VinculosDaConta vinculosMistos() => VinculosDaConta(
  conta: contaDe('c-misto', 'Conta mista'),
  pacientes: [
    pacienteDe('p-miguel', 'Miguel Andrade Neves', contaId: 'c-misto'),
  ],
  acompanhados: [pacienteDe('p-ana', 'Ana Lúcia Martins').paraCuidador()],
);
