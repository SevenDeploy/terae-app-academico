import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../dados/repositorios/repositorios.dart';

/// As [CapacidadesDaFonte] que o `TeraeApp` disponibiliza.
///
/// Sem o provider, só no modo de depuração (os testes de uma tela solta) a
/// tela fica com a fonte completa. No app de verdade (profile/release) a
/// falta do provider é um erro: cair na fonte completa reabriria botões que
/// a fonte local não tem (revisão da P4).
CapacidadesDaFonte capacidadesDaFonte(BuildContext context) {
  try {
    return Provider.of<CapacidadesDaFonte>(context, listen: false);
  } on ProviderNotFoundException {
    if (kDebugMode) return CapacidadesDaFonte.completa;
    rethrow;
  }
}
