import '../enums/resposta_presenca.dart';
import '../enums/situacao_envio.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../regras/presenca.dart';
import '../repositorios/falhas.dart';
import '../repositorios/presenca_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';

/// A confirmação de presença (evolução de TO, F2; D27; TM18) sobre a memória:
/// sem conexão, a resposta fica em [EstadoMemoria.filaPresenca] e sai quando
/// a conexão volta (`DemonstracaoMemoria`).
class PresencaMemoria implements RepositorioPresenca {
  PresencaMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<Map<String, ConfirmacaoDePresenca>> respostas(
    String pacienteId,
  ) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return Map.unmodifiable({
      for (final c in {..._e.confirmacoes, ..._e.filaPresenca}.values)
        if (c.pacienteId == pacienteId) c.agendamentoId: c,
    });
  }

  @override
  Future<void> atualizar(String pacienteId) async {
    await _memoria.esperar();
    if (_memoria.semConexao) return;
    _e
      ..receberFilaCasa()
      ..receberFilaPresenca();
    _memoria.atualizarConexao();
  }

  @override
  Future<ConfirmacaoDePresenca> responder({
    required String pacienteId,
    required String agendamentoId,
    required RespostaPresenca resposta,
  }) async {
    await _memoria.esperar();
    final agendamento = _e.agendamentos[agendamentoId];
    if (agendamento == null || agendamento.pacienteId != pacienteId) {
      throw const RecusaDeRegra(MotivoRecusa.agendamentoInexistente);
    }
    final agora = _memoria.agora();
    if (!podeResponder(agendamento, agora)) {
      throw const RecusaDeRegra(MotivoRecusa.sessaoEncerrada);
    }
    final nova = ConfirmacaoDePresenca(
      agendamentoId: agendamentoId,
      pacienteId: pacienteId,
      resposta: resposta,
      respondidaEm: agora,
      situacaoEnvio: SituacaoEnvio.naFila,
    );
    _e.filaPresenca[agendamentoId] = nova;
    if (!_memoria.semConexao) _e.receberFilaPresenca();
    _memoria.atualizarConexao();
    return _e.filaPresenca[agendamentoId] ?? _e.confirmacoes[agendamentoId]!;
  }
}
