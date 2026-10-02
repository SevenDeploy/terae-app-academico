import '../enums/situacao_agendamento.dart';
import '../modelos/agendamento.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../repositorios/falhas.dart';
import '../repositorios/visao_cuidador_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// Visão do cuidador (RFM08; TM08, TM11, TM12) com o RNFM05 na camada de
/// dados: toda chamada confere o vínculo ativo entre a conta e o paciente
/// (sem ele, `acessoNegado`) e devolve só as cópias reduzidas — Paciente sem
/// CPF nem nascimento, Agendamento sem motivo do retorno, alerta como
/// [AvisoDeAlerta]. Registro do diário, marco e consentimento não saem daqui.
class VisaoCuidadorMemoria implements RepositorioVisaoCuidador {
  VisaoCuidadorMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  Future<Paciente> _autorizado(
    String contaCuidadorId,
    String pacienteId,
  ) async {
    await _memoria.esperar();
    if (!_e.cuidadorAutorizado(contaCuidadorId, pacienteId)) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    return _e.pacientes[pacienteId]!;
  }

  @override
  Future<Paciente> pacienteAcompanhado({
    required String contaCuidadorId,
    required String pacienteId,
  }) async => (await _autorizado(contaCuidadorId, pacienteId)).paraCuidador();

  @override
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    final inicioDeHoje = _memoria.hoje().inicioNaClinica;
    return List.unmodifiable([
      for (final a in ordenar(
        _e.agendamentos.values.where(
          (a) =>
              a.pacienteId == pacienteId &&
              a.situacao != SituacaoAgendamento.realizado &&
              !a.dataHora.isBefore(inicioDeHoje),
        ),
        (a, b) => a.dataHora.compareTo(b.dataHora),
      ))
        a.paraCuidador(),
    ]);
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async {
    await _memoria.esperar();
    return _e.profissionais[profissionalId] ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
  }

  @override
  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    return _e.receitaVigente(pacienteId, _memoria.hoje());
  }

  @override
  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    if (_e.receitas[receitaId]?.pacienteId != pacienteId) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    return _e.itensDaReceita(receitaId);
  }

  @override
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    final doPaciente = _e.alertas.values.where(
      (a) => _e.registros[a.registroId]!.pacienteId == pacienteId,
    );
    return List.unmodifiable([
      for (final a in ordenar(
        doPaciente,
        (a, b) => b.emitidoEm.compareTo(a.emitidoEm),
      ))
        AvisoDeAlerta.doAlerta(a),
    ]);
  }
}
