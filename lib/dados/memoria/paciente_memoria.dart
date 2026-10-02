import '../enums/situacao_agendamento.dart';
import '../modelos/agendamento.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../repositorios/falhas.dart';
import '../repositorios/paciente_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// Leitura do paciente e da jornada para o perfil paciente/família (RFM02,
/// RFM06; TM02, TM05, TM06). Devolve as cópias completas, só de leitura.
class PacienteMemoria implements RepositorioPaciente {
  PacienteMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<Paciente> paciente(String pacienteId) async {
    await _memoria.esperar();
    return _e.exigirPaciente(pacienteId);
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async {
    await _memoria.esperar();
    return _e.profissionais[profissionalId] ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
  }

  @override
  Future<Agendamento?> proximaConsulta(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    final agora = _memoria.agora();
    final futuras = ordenar(
      _e.agendamentos.values.where(
        (a) =>
            a.pacienteId == pacienteId &&
            a.situacao == SituacaoAgendamento.agendado &&
            !a.dataHora.isBefore(agora),
      ),
      (a, b) => a.dataHora.compareTo(b.dataHora),
    );
    return futuras.isEmpty ? null : futuras.first;
  }

  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      ordenar<Agendamento>(
        _e.agendamentos.values.where((a) => a.pacienteId == pacienteId),
        (a, b) => a.dataHora.compareTo(b.dataHora),
      ),
    );
  }

  @override
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return _e.receitaVigente(pacienteId, _memoria.hoje());
  }

  @override
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId) async {
    await _memoria.esperar();
    if (!_e.receitas.containsKey(receitaId)) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    return _e.itensDaReceita(receitaId);
  }

  @override
  Future<List<MarcoJornada>> marcos(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      ordenar<MarcoJornada>(
        _e.marcos.values.where((m) => m.pacienteId == pacienteId),
        (a, b) => a.data.compareTo(b.data),
      ),
    );
  }
}
