import '../repositorios/demonstracao_repositorio.dart';
import 'memoria_demonstracao.dart';

/// D11 — painel de demonstração sobre a memória: "sem conexão" e reiniciar.
class DemonstracaoMemoria implements ControleDemonstracao {
  DemonstracaoMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  @override
  bool get semConexao => _memoria.semConexao;

  /// Só muda o interruptor: religar não reenvia a fila sozinho.
  @override
  Future<void> definirSemConexao({required bool semConexao}) async {
    _memoria.semConexao = semConexao;
  }

  /// Volta às personas iniciais, com as datas relativas ao hoje do relógio, a
  /// fila vazia e a conexão ligada.
  @override
  Future<void> reiniciarDados() async {
    await _memoria.esperar();
    _memoria.reiniciar();
  }
}
