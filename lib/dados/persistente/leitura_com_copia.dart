import '../conversao_mapa.dart';
import '../local/cache_dao.dart';
import '../remoto/falhas_remotas.dart';
import '../repositorios/falhas.dart';
import '../sincronizacao/monitor_conexao.dart';

/// Leitura das cópias da §23 (Atividade 4, D16): com conexão, pede ao
/// servidor (com o prazo de 2 s do RNFM03) e guarda a cópia no SQLite; sem
/// conexão — ou se o servidor não responder a tempo —, devolve a cópia
/// local. Sem cópia e sem conexão, recusa com `semConexao` (a tela mostra
/// "Tentar de novo").
class LeituraComCopia {
  LeituraComCopia({required this._cache, required this._monitor});

  final CacheDao _cache;
  final MonitorConexao _monitor;

  /// Marca de "esta coleção já foi copiada", para a cópia vazia valer.
  static const String _copias = '_copias';

  /// A coleção [colecao] do [dono].
  Future<List<Mapa>> lista(
    String colecao,
    String dono,
    Future<List<Mapa>> Function() remoto,
  ) async {
    if (_monitor.online) {
      try {
        final mapas = await remoto();
        await _cache.substituir(colecao, dono, {
          for (final m in mapas) lerCampo<String>(m, 'id'): m,
        });
        await _cache.salvar(_copias, '$colecao/$dono', dono, const {});
        return mapas;
      } on RecusaDeRegra catch (r) {
        if (!ehSemConexao(r)) rethrow;
      }
    }
    if (await _cache.ler(_copias, '$colecao/$dono') == null) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    return _cache.listar(colecao, dono);
  }

  /// Um documento [id] de [colecao]; `acessoNegado` se o servidor diz que
  /// não existe (ou não deixa ler).
  Future<Mapa> documento(
    String colecao,
    String id,
    String dono,
    Future<Mapa?> Function() remoto,
  ) async {
    if (_monitor.online) {
      try {
        final mapa = await remoto();
        if (mapa == null) {
          throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
        }
        await _cache.salvar(colecao, id, dono, mapa);
        return mapa;
      } on RecusaDeRegra catch (r) {
        if (!ehSemConexao(r)) rethrow;
      }
    }
    return await _cache.ler(colecao, id) ??
        (throw const RecusaDeRegra(MotivoRecusa.semConexao));
  }
}
