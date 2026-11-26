import 'package:shared_preferences/shared_preferences.dart';

import 'cliente_do_portal.dart';

/// [GuardaDoDispositivo] em SharedPreferences (D16).
class GuardaDoDispositivoEmPreferencias implements GuardaDoDispositivo {
  GuardaDoDispositivoEmPreferencias(this._prefs);

  static const String chave = 'terae_local.dispositivo_confiavel';

  final SharedPreferences _prefs;

  @override
  Future<String?> ler() async => _prefs.getString(chave);

  @override
  Future<void> gravar(String token) => _prefs.setString(chave, token);

  @override
  Future<void> apagar() => _prefs.remove(chave);
}
