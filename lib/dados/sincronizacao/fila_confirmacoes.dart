import '../enums/situacao_envio.dart';
import '../local/confirmacao_de_presenca_dao.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import 'fila_de_entidade.dart';
import 'monitor_conexao.dart';

/// A fila das respostas de presença (evolução de TO, F2; D16, D27): cada uma
/// vai a `pacientes/{pid}/confirmacoes/{agendamentoId}` como `enviado` (um
/// `set` do documento inteiro); só depois o SQLite passa a `enviado`. Como a
/// fila das atividades de casa, uma recusa que não seja "sem conexão" deixa
/// só aquele item pendente (D33).
class FilaConfirmacoes implements FilaDeEntidade {
  FilaConfirmacoes({
    required this._dao,
    required this._fonte,
    required this._monitor,
  });

  final ConfirmacaoDePresencaDao _dao;
  final FonteFirestore _fonte;
  final MonitorConexao _monitor;

  static const String colecao = 'confirmacoes';

  @override
  Future<int> contarPendentes() => _dao.contarPendentes();

  /// Envia uma resposta agora; sem rede ou sem confirmação no prazo, lança
  /// `RecusaDeRegra(semConexao)` e ela continua na fila.
  Future<ConfirmacaoDePresenca> enviar(ConfirmacaoDePresenca c) async {
    if (!_monitor.online) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final enviada = c.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
    final lote = _fonte.db.batch()
      ..set(
        _fonte.doPaciente(c.pacienteId, colecao).doc(c.agendamentoId),
        enviada.toMap(),
      );
    await _fonte.gravar(lote);
    await _dao.marcarEnviada(enviada);
    return enviada;
  }

  @override
  Future<void> enviarPendentes() async {
    if (!_monitor.online) return;
    RecusaDeRegra? primeiraRecusa;
    for (final c in await _dao.pendentes()) {
      try {
        await enviar(c);
      } on RecusaDeRegra catch (recusa) {
        if (recusa.motivo == MotivoRecusa.semConexao) rethrow;
        primeiraRecusa ??= recusa;
      }
    }
    if (primeiraRecusa != null) throw primeiraRecusa;
  }

  @override
  Future<void> buscar(String pacienteId) async {
    final mapas = await _fonte.listar(_fonte.doPaciente(pacienteId, colecao));
    await _dao.mesclarDoServidor([
      for (final m in mapas) ConfirmacaoDePresenca.fromMap(m),
    ]);
  }
}
