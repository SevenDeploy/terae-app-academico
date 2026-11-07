import '../modelos/meta_terapeutica.dart';
import '../regras/metas.dart';
import '../repositorios/falhas.dart';
import '../repositorios/metas_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';

/// As metas da terapia ocupacional (evolução de TO, F3; D35) sobre a memória:
/// só leitura, como no aparelho.
class MetasMemoria implements RepositorioMetas {
  MetasMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<List<MetaTerapeutica>> metas(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      ordenarMetas(_e.metas.values.where((m) => m.pacienteId == pacienteId)),
    );
  }

  @override
  Future<MetaTerapeutica> meta(String pacienteId, String metaId) async {
    await _memoria.esperar();
    final meta = _e.metas[metaId];
    if (meta == null || meta.pacienteId != pacienteId) {
      throw const RecusaDeRegra(MotivoRecusa.metaInexistente);
    }
    return meta;
  }
}
