import 'package:flutter/widgets.dart';

import 'app.dart';
import 'dados/memoria/memoria_demonstracao.dart';
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
/// fonte de dados não muda nenhuma tela): a memória carregada de
/// `assets/dados/demonstracao.json`, com as datas relativas a hoje (D9).
Future<Repositorios> _criarRepositorios(Relogio relogio) async {
  final memoria = await MemoriaDemonstracao.carregar(relogio: relogio);
  return memoria.repositorios;
}
