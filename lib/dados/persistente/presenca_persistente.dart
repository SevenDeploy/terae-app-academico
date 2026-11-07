import '../../nucleo/tempo/relogio.dart';
import '../enums/resposta_presenca.dart';
import '../enums/situacao_envio.dart';
import '../local/confirmacao_de_presenca_dao.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../regras/presenca.dart';
import '../remoto/falhas_remotas.dart';
import '../repositorios/falhas.dart';
import '../repositorios/paciente_repositorio.dart';
import '../repositorios/presenca_repositorio.dart';
import '../sincronizacao/fila_confirmacoes.dart';
import '../sincronizacao/sincronizador.dart';

/// A confirmação de presença com SQLite + Firestore (evolução de TO, F2;
/// D16, D27): a resposta vai primeiro ao SQLite (`naFila`) e depois tenta o
/// servidor pela [FilaConfirmacoes]; sem conexão, sai com o [Sincronizador].
/// A sessão é conferida nos agendamentos do paciente (com a cópia local).
class PresencaPersistente implements RepositorioPresenca {
  PresencaPersistente({
    required this._dao,
    required this._fila,
    required this._paciente,
    required Sincronizador sincronizador,
    required this._relogio,
  }) : _sinc = sincronizador;

  final ConfirmacaoDePresencaDao _dao;
  final FilaConfirmacoes _fila;
  final RepositorioPaciente _paciente;
  final Sincronizador _sinc;
  final Relogio _relogio;

  @override
  Future<Map<String, ConfirmacaoDePresenca>> respostas(String pacienteId) =>
      _dao.doPaciente(pacienteId);

  @override
  Future<ConfirmacaoDePresenca> responder({
    required String pacienteId,
    required String agendamentoId,
    required RespostaPresenca resposta,
  }) async {
    final agendamento = (await _paciente.agendamentos(pacienteId))
        .where((a) => a.id == agendamentoId)
        .firstOrNull;
    if (agendamento == null) {
      throw const RecusaDeRegra(MotivoRecusa.agendamentoInexistente);
    }
    final agora = _relogio.agora();
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
    await _dao.salvar(nova);
    try {
      return await _fila.enviar(nova);
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) rethrow;
      return nova;
    } finally {
      await _sinc.atualizarSituacao();
    }
  }
}
