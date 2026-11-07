import 'package:flutter/foundation.dart';

import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/modelos/marco_jornada.dart';
import '../../../dados/modelos/meta_terapeutica.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';

/// Estado da TM20 Meta (evolução de TO, F3; D25, D35): a meta, quem a
/// acompanha, as atividades de casa que ajudam nela e os marcos ligados.
/// Quem acompanha, as atividades e os marcos são extras: se a leitura deles
/// falhar, a meta aparece do mesmo jeito.
class MetaControlador extends ChangeNotifier {
  MetaControlador({
    required this.metas,
    required this.programa,
    required this.paciente,
    required this.pacienteId,
    required this.metaId,
  });

  final RepositorioMetas metas;
  final RepositorioProgramaEmCasa programa;
  final RepositorioPaciente paciente;
  final String pacienteId;
  final String metaId;

  bool _carregando = true;
  bool _falhou = false;
  bool _naoEncontrada = false;
  bool _descartado = false;
  MetaTerapeutica? _meta;
  String _profissional = '';
  List<AtividadeDeCasa>? _atividades = const [];
  List<MarcoJornada> _marcos = const [];

  bool get carregando => _carregando;
  bool get falhou => _falhou;

  /// A meta não existe ou não é deste paciente.
  bool get naoEncontrada => _naoEncontrada;
  MetaTerapeutica? get meta => _meta;

  /// Quem acompanha a meta (vazio se a leitura falhou).
  String get profissional => _profissional;

  /// As atividades de casa de agora que ajudam nesta meta; `null` se a
  /// leitura falhou (a tela diz isso, em vez de "nenhuma").
  List<AtividadeDeCasa>? get atividades => _atividades;

  /// Os marcos da meta, do mais recente ao mais antigo.
  List<MarcoJornada> get marcos => _marcos;

  Future<void> carregar() async {
    _carregando = true;
    _falhou = false;
    _naoEncontrada = false;
    _avisar();
    try {
      final meta = await metas.meta(pacienteId, metaId);
      _meta = meta;
      _profissional = await _ou<String>(
        '',
        () async => (await paciente.profissional(meta.profissionalId)).nome,
      );
      _atividades = await _ou<List<AtividadeDeCasa>?>(
        null,
        () async => [
          for (final a in await programa.atividades(pacienteId))
            if (a.metaId == metaId) a,
        ],
      );
      _marcos = await _ou<List<MarcoJornada>>(
        const [],
        () async => [
          for (final m in await paciente.marcos(pacienteId))
            if (m.metaId == metaId) m,
        ]..sort((a, b) => b.data.compareTo(a.data)),
      );
    } on RecusaDeRegra catch (r) {
      if (r.motivo == MotivoRecusa.metaInexistente) {
        _naoEncontrada = true;
      } else {
        _falhou = true;
      }
    } on Object {
      _falhou = true;
    }
    _carregando = false;
    _avisar();
  }

  /// Lê um extra; se a leitura falhar, fica com [padrao].
  static Future<T> _ou<T>(T padrao, Future<T> Function() ler) async {
    try {
      return await ler();
    } on Object {
      return padrao;
    }
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
