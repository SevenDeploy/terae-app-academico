import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/uuid.dart';
import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../enums/situacao_envio.dart';
import '../local/registro_de_atividade_dao.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/registro_de_atividade.dart';
import '../regras/programa_em_casa.dart';
import '../remoto/falhas_remotas.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import '../repositorios/programa_em_casa_repositorio.dart';
import '../sincronizacao/fila_registros_casa.dart';
import '../sincronizacao/sincronizador.dart';
import 'leitura_com_copia.dart';

/// O programa em casa com SQLite + Firestore (evolução de TO, F1; D16, D26).
///
/// - Atividades: só leitura, de `pacientes/{pid}/atividadesCasa`, com a cópia
///   local da [LeituraComCopia] (sem conexão, a última cópia).
/// - Registros: toda gravação vai primeiro para o SQLite (`naFila`) e só
///   depois tenta o servidor pela [FilaRegistrosCasa]; sem conexão, fica na
///   fila e sai com o [Sincronizador]. Toda leitura é do SQLite.
class ProgramaEmCasaPersistente implements RepositorioProgramaEmCasa {
  ProgramaEmCasaPersistente({
    required this._fonte,
    required this._leitura,
    required this._dao,
    required this._fila,
    required Sincronizador sincronizador,
    required this._relogio,
    String Function()? gerarId,
  }) : _sinc = sincronizador,
       _gerarId = gerarId ?? gerarUuidV4;

  final FonteFirestore _fonte;
  final LeituraComCopia _leitura;
  final RegistroDeAtividadeDao _dao;
  final FilaRegistrosCasa _fila;
  final Sincronizador _sinc;
  final Relogio _relogio;
  final String Function() _gerarId;

  static const String _colecao = 'atividadesCasa';

  DataCivil get _hoje => DataCivil.hoje(_relogio);

  @override
  Future<List<AtividadeDeCasa>> atividades(String pacienteId) async {
    final mapas = await _leitura.lista(
      _colecao,
      pacienteId,
      () => _fonte.listar(_fonte.doPaciente(pacienteId, _colecao)),
    );
    return atividadesVigentes([
      for (final m in mapas) AtividadeDeCasa.fromMap(m),
    ], _hoje);
  }

  @override
  Future<AtividadeDeCasa> atividade(
    String pacienteId,
    String atividadeId,
  ) async {
    for (final a in await atividades(pacienteId)) {
      if (a.id == atividadeId) return a;
    }
    throw const RecusaDeRegra(MotivoRecusa.atividadeInexistente);
  }

  @override
  Future<List<RegistroDeAtividade>> registros(
    String pacienteId, {
    int dias = 14,
  }) => _dao.doPaciente(pacienteId, desde: _hoje.somarDias(-(dias - 1)));

  @override
  Future<RegistroDeAtividade> registrar({
    required String pacienteId,
    required String atividadeId,
    required AdesaoEmCasa adesao,
    String? reflexao,
    required QuemRegistrou quem,
  }) async {
    await atividade(pacienteId, atividadeId);
    final hoje = _hoje;
    final agora = _relogio.agora();
    final existente = await _dao.doDia(atividadeId, hoje);
    final novo =
        existente?.corrigido(
          adesao: adesao,
          reflexao: reflexao,
          quem: quem,
          em: agora,
        ) ??
        RegistroDeAtividade(
          id: _gerarId(),
          pacienteId: pacienteId,
          atividadeId: atividadeId,
          dia: hoje,
          adesao: adesao,
          reflexao: reflexao,
          quem: quem,
          registradoEm: agora,
          situacaoEnvio: SituacaoEnvio.naFila,
        );
    await _dao.salvar(novo);
    return _tentarEnviar(novo);
  }

  @override
  Future<RegistroDeAtividade> desfazer(
    String pacienteId,
    String registroId,
  ) async {
    final atual = await _dao.porId(registroId);
    if (atual == null || atual.pacienteId != pacienteId) {
      throw const RecusaDeRegra(MotivoRecusa.registroInexistente);
    }
    if (!podeAlterarRegistro(atual, _hoje)) {
      throw const RecusaDeRegra(MotivoRecusa.edicaoEncerrada);
    }
    final novo = atual.desfeitoAs(_relogio.agora());
    await _dao.salvar(novo);
    return _tentarEnviar(novo);
  }

  /// Envia as filas e busca o servidor pelo [Sincronizador] (que já trata
  /// "sem conexão"): o paciente ativo está entre os acompanhados dele.
  @override
  Future<void> atualizar(String pacienteId) => _sinc.sincronizar();

  /// Tenta o servidor; sem conexão, devolve o registro como está (na fila).
  Future<RegistroDeAtividade> _tentarEnviar(RegistroDeAtividade naFila) async {
    try {
      return await _fila.enviar(naFila);
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) rethrow;
      return naFila;
    } finally {
      await _sinc.atualizarSituacao();
    }
  }
}
