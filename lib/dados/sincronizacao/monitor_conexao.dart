import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Se o aparelho está com rede (Atividade 4, D16).
///
/// Junta o que o sistema diz (`connectivity_plus`: Wi-Fi, dados móveis ou
/// nada) com o "sem conexão" do painel de demonstração (D11), que força o
/// modo offline sem precisar do modo avião. Rede ligada não garante que o
/// servidor responda: o sincronizador trata a falha de cada chamada.
class MonitorConexao extends ChangeNotifier {
  /// [mudancas] e [estadoInicial] vêm do `connectivity_plus` no app; o teste
  /// passa um `StreamController` e um valor.
  MonitorConexao({
    Stream<List<ConnectivityResult>>? mudancas,
    Future<List<ConnectivityResult>> Function()? estadoInicial,
  }) : _mudancas = mudancas ?? Connectivity().onConnectivityChanged,
       _estadoInicial =
           estadoInicial ?? (() => Connectivity().checkConnectivity());

  final Stream<List<ConnectivityResult>> _mudancas;
  final Future<List<ConnectivityResult>> Function() _estadoInicial;
  StreamSubscription<List<ConnectivityResult>>? _assinatura;

  bool _redeLigada = true;
  bool _forcadoSemConexao = false;

  /// Tem rede e o painel não forçou o offline.
  bool get online => _redeLigada && !_forcadoSemConexao;

  /// D11 — o interruptor "sem conexão" do painel de demonstração.
  bool get forcadoSemConexao => _forcadoSemConexao;

  set forcadoSemConexao(bool valor) {
    if (_forcadoSemConexao == valor) return;
    _forcadoSemConexao = valor;
    notifyListeners();
  }

  /// Lê o estado atual e passa a escutar as mudanças.
  Future<void> iniciar() async {
    try {
      _redeLigada = _temRede(await _estadoInicial());
    } on Exception {
      _redeLigada = true;
    }
    _assinatura ??= _mudancas.listen((resultado) {
      final agora = _temRede(resultado);
      if (agora == _redeLigada) return;
      _redeLigada = agora;
      notifyListeners();
    });
  }

  static bool _temRede(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);

  @override
  void dispose() {
    unawaited(_assinatura?.cancel());
    super.dispose();
  }
}
