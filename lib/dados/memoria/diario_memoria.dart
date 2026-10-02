import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../repositorios/diario_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// Diário entre consultas (RFM03–RFM05; TM03–TM05) com a fila do aparelho e
/// o "servidor simulado" que cria o alerta (§7.1, §19, §23).
///
/// - Sem conexão ([MemoriaDemonstracao.semConexao]): o registro fica na fila,
///   `naFila`, sem alerta — nenhuma tela pode dizer que a equipe foi avisada.
/// - Com conexão: o servidor recebe primeiro o que estava na fila e depois o
///   registro novo, sempre na ordem do aparelho, e avalia as duas regras do
///   §7.1 contra o registro imediatamente anterior do mesmo paciente. O
///   alerta vai para a caixa do profissional de referência. Religar a
///   conexão pelo painel já reenvia a fila (`DemonstracaoMemoria`).
/// - Idempotente pelo `id` gerado no aparelho: o mesmo registro não entra
///   duas vezes nem cria segundo alerta, e o que já foi enviado não é editado.
class DiarioMemoria implements RepositorioDiario {
  DiarioMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    await _memoria.esperar();
    final jaRecebido = _resultadoNoServidor(registro.id);
    if (jaRecebido != null) return jaRecebido;
    _e.exigirPaciente(registro.pacienteId);
    if (_memoria.semConexao) {
      final naFila = _e.fila.putIfAbsent(
        registro.id,
        () => registro.copyWith(situacaoEnvio: SituacaoEnvio.naFila),
      );
      return ResultadoEnvio(registro: naFila);
    }
    _esvaziarFila();
    return _resultadoNoServidor(registro.id) ?? _receber(registro);
  }

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async {
    await _memoria.esperar();
    if (_memoria.semConexao) return const [];
    return List.unmodifiable(_esvaziarFila());
  }

  @override
  Future<List<RegistroDiario>> registros(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      ordenar<RegistroDiario>(
        [
          ..._e.registros.values,
          ..._e.fila.values,
        ].where((r) => r.pacienteId == pacienteId),
        (a, b) => b.registradoEm.compareTo(a.registradoEm),
      ),
    );
  }

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async {
    await _memoria.esperar();
    return _e.alertaDoRegistro(registroId);
  }

  ResultadoEnvio? _resultadoNoServidor(String registroId) {
    final recebido = _e.registros[registroId];
    if (recebido == null) return null;
    return ResultadoEnvio(
      registro: recebido,
      alerta: _e.alertaDoRegistro(registroId),
    );
  }

  /// Envia a fila inteira, do registro mais antigo ao mais novo.
  List<ResultadoEnvio> _esvaziarFila() => [
    for (final r in ordenar(
      _e.fila.values,
      (a, b) => a.registradoEm.compareTo(b.registradoEm),
    ))
      _receber(r),
  ];

  /// O servidor recebe [registro]: grava como `enviado`, tira da fila e
  /// avalia o §7.1 sobre a sequência que já tem.
  ResultadoEnvio _receber(RegistroDiario registro) {
    final enviado = registro.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
    final regra = regraDoAlerta(
      nova: enviado.intensidade,
      anterior: _e.registroAnterior(enviado)?.intensidade,
    );
    _e.registros[enviado.id] = enviado;
    _e.fila.remove(enviado.id);
    if (regra == null) return ResultadoEnvio(registro: enviado);
    final alerta = Alerta(
      id: _memoria.novoId(),
      registroId: enviado.id,
      regraDisparada: regra,
      emitidoEm: _memoria.agora(),
    );
    _e.guardarAlerta(alerta);
    return ResultadoEnvio(registro: enviado, alerta: alerta);
  }
}
