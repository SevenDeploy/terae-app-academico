import 'package:flutter/foundation.dart';

import '../../../dados/enums/intensidade.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';

/// Estado da TM13 — Meus registros (Atividade 4: listagem e busca do item
/// principal, D13). Lê pelo [RepositorioDiario]; na implementação
/// persistente a lista vem do SQLite, sem esperar a rede (D16).
class RegistrosControlador extends ChangeNotifier {
  RegistrosControlador({required this.repositorio, required this.pacienteId});

  final RepositorioDiario repositorio;
  final String pacienteId;

  List<RegistroDiario> _registros = const [];
  bool _carregando = true;
  bool _falhou = false;
  String _texto = '';
  Set<Intensidade> _intensidades = const {};
  bool _descartado = false;
  int _consulta = 0;

  List<RegistroDiario> get registros => _registros;
  bool get carregando => _carregando;
  bool get falhou => _falhou;
  String get texto => _texto;
  Set<Intensidade> get intensidades => _intensidades;

  /// Há busca ou filtro ligado (muda o texto da lista vazia).
  bool get filtrando => _texto.trim().isNotEmpty || _intensidades.isNotEmpty;

  /// Busca de novo com o filtro atual.
  Future<void> carregar() async {
    final consulta = ++_consulta;
    _carregando = true;
    _falhou = false;
    _avisar();
    try {
      final achados = await repositorio.buscar(
        pacienteId,
        texto: _texto,
        intensidades: _intensidades,
      );
      if (consulta != _consulta) return;
      _registros = achados;
    } on Exception {
      if (consulta != _consulta) return;
      _falhou = true;
    }
    _carregando = false;
    _avisar();
  }

  /// "Puxar para atualizar": tenta enviar a fila e busca de novo. Sem conexão
  /// a fila fica como está e a lista continua vindo do aparelho.
  Future<void> atualizar() async {
    try {
      await repositorio.reenviarFila();
    } on Exception {
      // Sem conexão: a lista local continua valendo.
    }
    await carregar();
  }

  Future<void> buscarTexto(String texto) {
    _texto = texto;
    return carregar();
  }

  Future<void> alternarIntensidade(Intensidade intensidade) {
    final novas = {..._intensidades};
    if (!novas.remove(intensidade)) novas.add(intensidade);
    _intensidades = Set.unmodifiable(novas);
    return carregar();
  }

  Future<void> limparFiltros() {
    _texto = '';
    _intensidades = const {};
    return carregar();
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
