import '../repositorios/demonstracao_repositorio.dart';
import 'memoria_demonstracao.dart';

/// D11 — painel de demonstração sobre a memória: "sem conexão" e reiniciar.
class DemonstracaoMemoria implements ControleDemonstracao {
  DemonstracaoMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  @override
  bool get semConexao => _memoria.semConexao;

  /// Muda o interruptor. Com a conexão de volta, a fila do aparelho sai
  /// sozinha, do registro mais antigo ao mais novo (§19): o alerta de um
  /// registro crítico que estava na fila nasce neste momento, no servidor. A
  /// fila das atividades de casa (F1) sai junto.
  @override
  Future<void> definirSemConexao({required bool semConexao}) async {
    _memoria.semConexao = semConexao;
    if (semConexao) return;
    await _memoria.repositorios.diario.reenviarFila();
    _memoria.estado.receberFilaCasa();
    _memoria.atualizarConexao();
  }

  /// Volta às personas iniciais, com as datas relativas ao hoje do relógio, a
  /// fila vazia e a conexão ligada.
  @override
  Future<void> reiniciarDados() async {
    await _memoria.esperar();
    _memoria.reiniciar();
  }
}
