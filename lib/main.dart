import 'package:flutter/widgets.dart';

import 'app.dart';
import 'dados/repositorios/repositorios.dart';
import 'nucleo/sessao/sessao.dart';
import 'nucleo/tempo/relogio.dart';

/// Entrada: cria os repositórios e inicia o [TeraeApp] (§24).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const relogio = RelogioSistema();
  final repositorios = await _criarRepositorios(relogio);
  runApp(
    TeraeApp(repositorios: repositorios, sessao: Sessao(), relogio: relogio),
  );
}

/// Único ponto que conhece a implementação dos contratos (§22: trocar a
/// fonte de dados não muda nenhuma tela). Onda 2: o agente `dados` troca este
/// corpo pela carga de `lib/dados/memoria/` com `assets/dados/demonstracao.json`.
Future<Repositorios> _criarRepositorios(Relogio relogio) async {
  throw UnimplementedError(
    'Implementação em memória ainda não existe (lib/dados/memoria/, onda 2).',
  );
}
