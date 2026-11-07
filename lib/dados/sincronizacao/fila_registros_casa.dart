import '../enums/situacao_envio.dart';
import '../local/registro_de_atividade_dao.dart';
import '../modelos/registro_de_atividade.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import 'fila_de_entidade.dart';
import 'monitor_conexao.dart';

/// A fila dos registros das atividades de casa (evolução de TO, F1; D16,
/// D26): o SQLite guarda primeiro, e cada registro vai ao Firestore em
/// `pacientes/{pid}/registrosCasa/{id}` como `enviado` (um `set` do documento
/// inteiro, idempotente pelo UUID). Só depois da confirmação o SQLite passa a
/// `enviado`.
class FilaRegistrosCasa implements FilaDeEntidade {
  FilaRegistrosCasa({
    required this._dao,
    required this._fonte,
    required this._monitor,
  });

  final RegistroDeAtividadeDao _dao;
  final FonteFirestore _fonte;
  final MonitorConexao _monitor;

  static const String colecao = 'registrosCasa';

  @override
  Future<int> contarPendentes() => _dao.contarPendentes();

  /// Envia um registro agora. Sem rede ou sem confirmação no prazo, lança
  /// `RecusaDeRegra(semConexao)` e ele continua na fila.
  Future<RegistroDeAtividade> enviar(RegistroDeAtividade registro) async {
    if (!_monitor.online) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final enviado = registro.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
    final lote = _fonte.db.batch()
      ..set(
        _fonte.doPaciente(registro.pacienteId, colecao).doc(registro.id),
        enviado.toMap(),
      );
    await _fonte.gravar(lote);
    await _dao.salvar(enviado);
    return enviado;
  }

  /// Envia a fila do mais antigo ao mais novo. "Sem conexão" para tudo (o
  /// resto fica na fila). Uma recusa do servidor por outro motivo deixa só
  /// aquele item pendente e segue com os próximos; no fim, a primeira recusa
  /// é relançada para o sincronizador registrar (D33).
  @override
  Future<void> enviarPendentes() async {
    if (!_monitor.online) return;
    RecusaDeRegra? primeiraRecusa;
    for (final r in await _dao.pendentes()) {
      try {
        await enviar(r);
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
      for (final m in mapas) RegistroDeAtividade.fromMap(m),
    ]);
  }
}
