import '../../nucleo/tempo/relogio.dart';
import '../enums/intensidade.dart';
import '../enums/situacao_envio.dart';
import '../local/registro_diario_dao.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import '../remoto/falhas_remotas.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import '../sincronizacao/sincronizador.dart';

/// O diário com SQLite + Firestore (Atividade 4, D13, D16, D17).
///
/// Toda gravação vai primeiro para o SQLite (`naFila`) e só depois tenta o
/// servidor: sem conexão, o registro fica na fila e a tela segue (TM04 diz
/// que será enviado). Toda leitura é do SQLite, que o [Sincronizador] mantém
/// em dia com o servidor — a TM13 funciona igual com e sem conexão.
class DiarioPersistente implements RepositorioDiario {
  DiarioPersistente({
    required this._dao,
    required Sincronizador sincronizador,
    required this._relogio,
  }) : _sinc = sincronizador;

  final RegistroDiarioDao _dao;
  final Sincronizador _sinc;
  final Relogio _relogio;

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    final existente = await _dao.porId(registro.id);
    if (existente != null && existente.situacaoEnvio == SituacaoEnvio.enviado) {
      // Idempotente: reenviar o mesmo registro não duplica nem cria alerta.
      return ResultadoEnvio(
        registro: existente,
        alerta: await _dao.alertaDoRegistro(existente.id),
      );
    }
    final naFila =
        existente ?? registro.copyWith(situacaoEnvio: SituacaoEnvio.naFila);
    if (existente == null) await _dao.salvar(naFila);
    return _tentarEnviar(naFila);
  }

  /// Tenta o servidor; sem conexão, devolve o registro como está (na fila).
  Future<ResultadoEnvio> _tentarEnviar(RegistroDiario naFila) async {
    try {
      return await _sinc.enviar(naFila);
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) rethrow;
      await _sinc.atualizarSituacao();
      return ResultadoEnvio(registro: naFila);
    }
  }

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async {
    final saidas = await _sinc.enviarFila();
    try {
      await _sinc.buscarDoServidor();
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) rethrow;
    }
    return saidas;
  }

  @override
  Future<List<RegistroDiario>> registros(String pacienteId) =>
      _dao.doPaciente(pacienteId);

  @override
  Future<List<RegistroDiario>> buscar(
    String pacienteId, {
    String texto = '',
    Set<Intensidade> intensidades = const {},
  }) => _dao.doPaciente(pacienteId, texto: texto, intensidades: intensidades);

  @override
  Future<RegistroDiario> registro(String registroId) async =>
      await _dao.porId(registroId) ??
      (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) =>
      _dao.alertaDoRegistro(registroId);

  @override
  Future<ResultadoEnvio> atualizar(RegistroDiario corrigido) async {
    final atual = await _alteravel(corrigido.id);
    final novo = atual.corrigido(
      adesao: corrigido.adesao,
      intensidade: corrigido.intensidade,
      sintomaPredominante: corrigido.sintomaPredominante,
      observacao: corrigido.observacao,
      em: _relogio.agora(),
    );
    await _dao.salvar(novo);
    return _tentarEnviar(novo);
  }

  @override
  Future<RegistroDiario> excluir(String registroId) async {
    final atual = await _alteravel(registroId);
    final novo = atual.excluidoAs(_relogio.agora());
    await _dao.salvar(novo);
    return (await _tentarEnviar(novo)).registro;
  }

  /// D17 — existe e ainda é do dia; senão recusa.
  Future<RegistroDiario> _alteravel(String registroId) async {
    final atual =
        await _dao.porId(registroId) ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
    if (!podeAlterar(atual, _relogio.agora())) {
      throw const RecusaDeRegra(MotivoRecusa.edicaoEncerrada);
    }
    return atual;
  }
}
