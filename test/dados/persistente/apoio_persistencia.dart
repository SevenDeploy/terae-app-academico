/// Apoio dos testes da persistência da Atividade 4: SQLite de verdade (FFI,
/// num arquivo temporário), Firestore e Authentication de mentira e uma
/// conexão que o teste liga e desliga.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:terae_app/dados/local/preferencias_locais.dart';
import 'package:terae_app/dados/persistente/composicao.dart';
import 'package:terae_app/dados/sincronizacao/monitor_conexao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

/// 2/10/2026 10:00 em Cuiabá.
DateTime get agoraDaPersistencia => instanteNaClinica(2026, 10, 2, 10);

/// Conexão de mentira: começa ligada; [desligar] e [ligar] avisam o monitor
/// como o `connectivity_plus` faria.
class ConexaoDeTeste {
  final StreamController<List<ConnectivityResult>> _mudancas =
      StreamController.broadcast();
  bool _ligada = true;

  late final MonitorConexao monitor = MonitorConexao(
    mudancas: _mudancas.stream,
    estadoInicial: () async => [
      _ligada ? ConnectivityResult.wifi : ConnectivityResult.none,
    ],
  );

  Future<void> desligar() => _mudar(false);
  Future<void> ligar() => _mudar(true);

  Future<void> _mudar(bool ligada) async {
    _ligada = ligada;
    _mudancas.add([ligada ? ConnectivityResult.wifi : ConnectivityResult.none]);
    // Deixa o monitor e o sincronizador reagirem.
    await Future<void>.delayed(Duration.zero);
  }
}

/// Tudo montado como no app, com as peças de mentira.
class Montagem {
  Montagem._(
    this.persistencia,
    this.firestore,
    this.auth,
    this.conexao,
    this.relogio,
  );

  final Persistencia persistencia;
  final FakeFirebaseFirestore firestore;
  final MockFirebaseAuth auth;
  final ConexaoDeTeste conexao;
  final RelogioFixo relogio;
}

/// Monta a persistência com SQLite num arquivo temporário novo.
Future<Montagem> montar({
  FakeFirebaseFirestore? firestore,
  MockFirebaseAuth? auth,
  RelogioFixo? relogio,
}) async {
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues({});
  final pasta = Directory.systemTemp.createTempSync('terae_app_teste_');
  final fs = firestore ?? FakeFirebaseFirestore();
  final autenticacao = auth ?? MockFirebaseAuth();
  final conexao = ConexaoDeTeste();
  final r = relogio ?? RelogioFixo(agoraDaPersistencia);
  final persistencia = await montarPersistencia(
    auth: autenticacao,
    firestore: fs,
    relogio: r,
    fabricaDoBanco: databaseFactoryFfi,
    caminhoDoBanco: '${pasta.path}${Platform.pathSeparator}terae.db',
    preferencias: await PreferenciasLocais.abrir(),
    monitor: conexao.monitor,
  );
  return Montagem._(persistencia, fs, autenticacao, conexao, r);
}
