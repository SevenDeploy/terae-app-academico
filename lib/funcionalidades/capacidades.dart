import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../dados/repositorios/repositorios.dart';

/// As [CapacidadesDaFonte] que o `TeraeApp` disponibiliza. Fora dele (teste
/// de uma tela solta), a fonte completa: a tela fica como sempre foi.
CapacidadesDaFonte capacidadesDaFonte(BuildContext context) {
  try {
    return Provider.of<CapacidadesDaFonte>(context, listen: false);
  } on ProviderNotFoundException {
    return CapacidadesDaFonte.completa;
  }
}
