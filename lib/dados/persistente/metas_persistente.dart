import '../modelos/meta_terapeutica.dart';
import '../regras/metas.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import '../repositorios/metas_repositorio.dart';
import 'leitura_com_copia.dart';

/// As metas da terapia ocupacional com Firestore e a cópia local (evolução de
/// TO, F3; D16, D35): `pacientes/{pid}/metas`, que só o titular lê (as regras
/// recusam o cuidador, D29). Sem conexão, a última cópia da
/// [LeituraComCopia].
class MetasPersistente implements RepositorioMetas {
  MetasPersistente({required this._leitura, required this._fonte});

  final LeituraComCopia _leitura;
  final FonteFirestore _fonte;

  static const String colecao = 'metas';

  @override
  Future<List<MetaTerapeutica>> metas(String pacienteId) async {
    final mapas = await _leitura.lista(
      colecao,
      pacienteId,
      // D25: a cópia local guarda só os campos do modelo, sem escore, nível
      // GAS ou peso que viessem no documento.
      () async => [
        for (final m in await _fonte.listar(
          _fonte.doPaciente(pacienteId, colecao),
        ))
          MetaTerapeutica.fromMap(m).toMap(),
      ],
    );
    return ordenarMetas([for (final m in mapas) MetaTerapeutica.fromMap(m)]);
  }

  @override
  Future<MetaTerapeutica> meta(String pacienteId, String metaId) async {
    for (final m in await metas(pacienteId)) {
      if (m.id == metaId) return m;
    }
    throw const RecusaDeRegra(MotivoRecusa.metaInexistente);
  }
}
