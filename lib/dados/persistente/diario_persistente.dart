import '../../nucleo/tempo/relogio.dart';
import '../enums/situacao_envio.dart';
import '../local/registro_diario_dao.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import '../remoto/falhas_remotas.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import '../sincronizacao/sincronizador.dart';

/// O diário com SQLite + Firestore (Atividade 4, D13, D16; P3, D17 revista).
///
/// O registro novo vai primeiro para o SQLite (`naFila`) e só depois tenta o
/// servidor: sem conexão, fica na fila ("Guardar e enviar depois") e a tela
/// segue. Corrigir e retirar pedem a internet na hora, como no portal: o
/// servidor grava primeiro (as `firestore.rules` recusam o registro revisado
/// ou que avisou a equipe, e isso vira `registroNaoMudaMais`, o 409 do
/// portal), e só a versão confirmada chega ao SQLite. Toda leitura é do
/// SQLite, que o [Sincronizador] mantém em dia com o servidor.
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
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) async {
    final lida = await _dao.pagina(pacienteId, antes: antes);
    return PaginaDoDiario(
      registros: List.unmodifiable(lida.registros),
      haMais: lida.haMais,
    );
  }

  /// Esta fonte não tem validade na fila (só o Terae local tem).
  @override
  Future<List<RegistroDiario>> vencidos(String pacienteId) async => const [];

  @override
  Future<void> descartarVencido(String registroId) async =>
      throw const RecusaDeRegra(MotivoRecusa.registroInexistente);

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async =>
      List.unmodifiable(await _dao.pendentes(pacienteId: pacienteId));

  @override
  Future<RegistroDiario> registro(String registroId) async =>
      await _dao.porId(registroId) ??
      (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) =>
      _dao.alertaDoRegistro(registroId);

  @override
  Future<ResultadoEnvio> corrigir(
    String registroId,
    EntradaDoDiario entrada,
  ) async {
    final atual = await _alteravel(registroId);
    return _noServidor(atual.corrigido(entrada, em: _relogio.agora()));
  }

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) async {
    final atual = await _alteravel(registroId);
    final resultado = await _noServidor(
      atual.retiradoCom(motivo, em: _relogio.agora()),
    );
    return resultado.registro;
  }

  /// D17 revista — existe, chegou ao servidor e ainda pode mudar.
  Future<RegistroDiario> _alteravel(String registroId) async {
    final atual =
        await _dao.porId(registroId) ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
    if (!podeAlterar(atual)) {
      throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
    }
    return atual;
  }

  /// Grava [novo] no servidor; só a versão confirmada chega ao SQLite. A
  /// recusa das regras (a terapeuta revisou no servidor, e a cópia local
  /// ainda não sabia) é o 409 do portal.
  Future<ResultadoEnvio> _noServidor(RegistroDiario novo) async {
    try {
      return await _sinc.enviar(novo);
    } on RecusaDeRegra catch (r) {
      if (r.motivo == MotivoRecusa.acessoNegado) {
        // A cópia local estava velha (revisado no servidor, ou a correção
        // anterior chegou depois do prazo): traz a do servidor, para a lista
        // mostrar o que vale, e diz que este registro não muda mais.
        try {
          await _sinc.buscarDoServidor();
        } on RecusaDeRegra {
          // Sem a busca, a lista se acerta na próxima sincronização.
        }
        throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
      }
      if (ehSemConexao(r)) {
        throw const RecusaDeRegra(MotivoRecusa.semConexao);
      }
      rethrow;
    }
  }
}
