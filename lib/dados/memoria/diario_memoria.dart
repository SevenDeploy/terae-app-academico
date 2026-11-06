import '../enums/intensidade.dart';
import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
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
///   duas vezes nem cria segundo alerta.
/// - D17: correção e exclusão lógica só no mesmo dia; as duas passam pela
///   mesma fila, e o alerta que já existe nunca some.
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
  Future<List<RegistroDiario>> registros(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(_doPaciente(pacienteId));
  }

  @override
  Future<List<RegistroDiario>> buscar(
    String pacienteId, {
    String texto = '',
    Set<Intensidade> intensidades = const {},
  }) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      _doPaciente(pacienteId).where(
        (r) => passaNoFiltro(r, texto: texto, intensidades: intensidades),
      ),
    );
  }

  @override
  Future<RegistroDiario> registro(String registroId) async {
    await _memoria.esperar();
    return _versaoAtual(registroId) ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
  }

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async {
    await _memoria.esperar();
    return _e.alertaDoRegistro(registroId);
  }

  @override
  Future<ResultadoEnvio> atualizar(RegistroDiario corrigido) async {
    await _memoria.esperar();
    final atual = _alteravel(corrigido.id);
    final novo = atual.corrigido(
      adesao: corrigido.adesao,
      intensidade: corrigido.intensidade,
      sintomaPredominante: corrigido.sintomaPredominante,
      observacao: corrigido.observacao,
      em: _memoria.agora(),
    );
    return _enfileirarOuEnviar(novo);
  }

  @override
  Future<RegistroDiario> excluir(String registroId) async {
    await _memoria.esperar();
    final atual = _alteravel(registroId);
    final resultado = _enfileirarOuEnviar(atual.excluidoAs(_memoria.agora()));
    return resultado.registro;
  }

  /// Registros do paciente na última versão (a da fila vence a do servidor),
  /// sem os excluídos, do mais recente para o mais antigo.
  List<RegistroDiario> _doPaciente(String pacienteId) =>
      ordenar<RegistroDiario>(
        {
          ..._e.registros,
          ..._e.fila,
        }.values.where((r) => r.pacienteId == pacienteId && !r.excluido),
        (a, b) => b.registradoEm.compareTo(a.registradoEm),
      );

  RegistroDiario? _versaoAtual(String registroId) =>
      _e.fila[registroId] ?? _e.registros[registroId];

  /// D17 — o registro existe e ainda pode mudar hoje; senão recusa.
  RegistroDiario _alteravel(String registroId) {
    final atual =
        _versaoAtual(registroId) ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
    if (!podeAlterar(atual, _memoria.agora())) {
      throw const RecusaDeRegra(MotivoRecusa.edicaoEncerrada);
    }
    return atual;
  }

  /// Correção ou exclusão: sem conexão, a nova versão fica na fila; com
  /// conexão, o servidor recebe a fila e depois ela.
  ResultadoEnvio _enfileirarOuEnviar(RegistroDiario novo) {
    _e.fila[novo.id] = novo;
    if (_memoria.semConexao) {
      _memoria.atualizarConexao();
      return ResultadoEnvio(registro: novo);
    }
    final saidas = _esvaziarFila();
    _memoria.atualizarConexao();
    return saidas.lastWhere((r) => r.registro.id == novo.id);
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
  /// avalia o §7.1 sobre a sequência que já tem. Registro excluído não cria
  /// alerta, e quem já tem alerta não ganha outro (D17: o que já foi emitido
  /// fica como está).
  ResultadoEnvio _receber(RegistroDiario registro) {
    final enviado = registro.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
    _e.registros[enviado.id] = enviado;
    _e.fila.remove(enviado.id);
    final existente = _e.alertaDoRegistro(enviado.id);
    if (existente != null || enviado.excluido) {
      return ResultadoEnvio(registro: enviado, alerta: existente);
    }
    final regra = regraDoAlerta(
      nova: enviado.intensidade,
      anterior: _e.registroAnterior(enviado)?.intensidade,
    );
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
