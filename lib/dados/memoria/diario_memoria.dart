import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// O diário da família (RFM03–RFM05; P3; TM03–TM05, TM13–TM15) com a fila do
/// aparelho e o "servidor simulado" que cria o alerta (§7.1, §19, §23).
///
/// - Sem conexão ([MemoriaDemonstracao.semConexao]): o registro novo fica na
///   fila, `naFila`, sem alerta — nenhuma tela pode dizer que a equipe foi
///   avisada. Corrigir e retirar recusam `semConexao`, como no portal.
/// - Com conexão: o servidor recebe primeiro o que estava na fila e depois o
///   registro novo, sempre na ordem do aparelho, e avalia as duas regras do
///   §7.1 contra o registro imediatamente anterior do mesmo paciente. O
///   alerta vai para a caixa do profissional de referência. Religar a
///   conexão pelo painel já reenvia a fila (`DemonstracaoMemoria`).
/// - Idempotente pelo `id` gerado no aparelho: o mesmo registro não entra
///   duas vezes nem cria segundo alerta.
/// - D17 revista: corrigir cria a versão seguinte e retirar guarda o motivo,
///   só antes da revisão e nunca no registro que avisou a equipe.
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
      _memoria.atualizarConexao();
      return ResultadoEnvio(registro: naFila);
    }
    _esvaziarFila();
    final resultado = _resultadoNoServidor(registro.id) ?? _receber(registro);
    _memoria.atualizarConexao();
    return resultado;
  }

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async {
    await _memoria.esperar();
    if (_memoria.semConexao) return const [];
    final saidas = _esvaziarFila();
    _memoria.atualizarConexao();
    return List.unmodifiable(saidas);
  }

  @override
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    final todos = ordenar<RegistroDiario>(
      _e.registros.values.where(
        (r) =>
            r.pacienteId == pacienteId &&
            (antes == null || momentoNaLista(r).isBefore(antes)),
      ),
      maisNovoPrimeiro,
    );
    return PaginaDoDiario(
      registros: List.unmodifiable(todos.take(registrosPorPagina)),
      haMais: todos.length > registrosPorPagina,
    );
  }

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      ordenar<RegistroDiario>(
        _e.fila.values.where((r) => r.pacienteId == pacienteId),
        (a, b) => a.registradoEm.compareTo(b.registradoEm),
      ),
    );
  }

  @override
  Future<RegistroDiario> registro(String registroId) async {
    await _memoria.esperar();
    return _e.registros[registroId] ??
        _e.fila[registroId] ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
  }

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async {
    await _memoria.esperar();
    return _e.alertaDoRegistro(registroId);
  }

  @override
  Future<ResultadoEnvio> corrigir(
    String registroId,
    EntradaDoDiario entrada,
  ) async {
    await _memoria.esperar();
    final atual = _alteravel(registroId);
    final novo = atual.corrigido(entrada, em: _memoria.agora());
    return _avaliarAlerta(novo);
  }

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) async {
    await _memoria.esperar();
    final atual = _alteravel(registroId);
    final retirado = atual.retiradoCom(motivo, em: _memoria.agora());
    _e.registros[retirado.id] = retirado;
    return retirado;
  }

  /// D17 revista — o registro chegou ao servidor e ainda pode mudar; sem
  /// conexão, recusa antes de olhar (corrigir e retirar pedem a internet).
  RegistroDiario _alteravel(String registroId) {
    if (_memoria.semConexao) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final atual =
        _e.registros[registroId] ??
        (_e.fila.containsKey(registroId)
            ? throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais)
            : throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
    if (!podeAlterar(atual)) {
      throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
    }
    return atual;
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

  /// O servidor recebe [registro]: grava como `enviado` (com o instante do
  /// recebimento), tira da fila e avalia o §7.1.
  ResultadoEnvio _receber(RegistroDiario registro) {
    _e.fila.remove(registro.id);
    return _avaliarAlerta(
      registro.copyWith(
        situacaoEnvio: SituacaoEnvio.enviado,
        enviadoEm: _memoria.agora(),
      ),
    );
  }

  /// Grava [registro] como o servidor e avalia o §7.1 sobre a sequência que
  /// ele já tem. Quem já tem alerta não ganha outro: o que já foi emitido
  /// fica como está.
  ResultadoEnvio _avaliarAlerta(RegistroDiario registro) {
    final existente = _e.alertaDoRegistro(registro.id);
    final regra = existente != null
        ? null
        : regraDoAlerta(
            nova: registro.intensidadeSintoma,
            anterior: _e.registroAnterior(registro)?.intensidadeSintoma,
          );
    if (regra == null) {
      _e.registros[registro.id] = registro;
      return ResultadoEnvio(registro: registro, alerta: existente);
    }
    final comAlerta = registro.copyWith(alertouAEquipe: true);
    _e.registros[comAlerta.id] = comAlerta;
    final alerta = Alerta(
      id: _memoria.novoId(),
      registroId: comAlerta.id,
      regraDisparada: regra,
      emitidoEm: _memoria.agora(),
    );
    _e.guardarAlerta(alerta);
    return ResultadoEnvio(registro: comAlerta, alerta: alerta);
  }
}
