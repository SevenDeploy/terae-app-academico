import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../lembretes/lembrete.dart';

/// Preferências do aparelho em SharedPreferences (Atividade 4, D16): valores
/// pequenos, sem dado de saúde, que só servem para o app abrir como estava.
///
/// - `perfil_ativo`: a `Perfil.chave` (`papel:pacienteId`) do último perfil,
///   para a conta com vários perfis não ter de escolher de novo;
/// - `ultima_sincronizacao`: instante ISO da última sincronização completa;
/// - `filtro_intensidades`: o último filtro da TM13;
/// - `lembretes`: as escolhas da TM19 (F2, D28), em JSON.
///
/// A senha nunca passa por aqui (RNFM04), e a sessão é do Firebase.
class PreferenciasLocais {
  PreferenciasLocais(this._prefs);

  static Future<PreferenciasLocais> abrir() async =>
      PreferenciasLocais(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String chavePerfil = 'perfil_ativo';
  static const String chaveSincronizacao = 'ultima_sincronizacao';
  static const String chaveFiltro = 'filtro_intensidades';
  static const String chaveLembretes = 'lembretes';

  String? get perfilAtivo => _prefs.getString(chavePerfil);

  /// Grava (ou apaga, com `null`) o perfil ativo. Não espera o disco.
  void guardarPerfil(String? chave) {
    if (chave == null) {
      _prefs.remove(chavePerfil);
    } else {
      _prefs.setString(chavePerfil, chave);
    }
  }

  DateTime? get ultimaSincronizacao {
    final texto = _prefs.getString(chaveSincronizacao);
    return texto == null ? null : DateTime.tryParse(texto)?.toUtc();
  }

  Future<void> guardarSincronizacao(DateTime quando) =>
      _prefs.setString(chaveSincronizacao, quando.toUtc().toIso8601String());

  List<String> get filtroIntensidades =>
      _prefs.getStringList(chaveFiltro) ?? const [];

  Future<void> guardarFiltro(List<String> intensidades) =>
      _prefs.setStringList(chaveFiltro, intensidades);

  /// F2 (D28) — as escolhas de lembrete; sem nada gravado (ou gravado
  /// errado), tudo desligado.
  PreferenciasDeLembrete get lembretes {
    final texto = _prefs.getString(chaveLembretes);
    if (texto == null) return const PreferenciasDeLembrete();
    try {
      return PreferenciasDeLembrete.fromMap(
        jsonDecode(texto) as Map<String, Object?>,
      );
    } on Object {
      return const PreferenciasDeLembrete();
    }
  }

  Future<void> guardarLembretes(PreferenciasDeLembrete p) =>
      _prefs.setString(chaveLembretes, jsonEncode(p.toMap()));

  Future<void> apagarLembretes() => _prefs.remove(chaveLembretes);

  /// D20 — "Sair" apaga as preferências da conta.
  Future<void> limpar() async {
    for (final chave in [
      chavePerfil,
      chaveSincronizacao,
      chaveFiltro,
      chaveLembretes,
    ]) {
      await _prefs.remove(chave);
    }
  }
}
