/// Apoio dos testes de tela da entrada (TM00, TM01, TM09, TM10) e do cuidador
/// (TM08, TM11, TM12): o app inteiro com os repositórios que o teste escolher
/// (o resto fica com os dublês de `test/apoio/dubles.dart`), tela de 360×800
/// com fonte grande, guias de alvo de toque e uma sessão espiã.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/demonstracao_repositorio.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/dados/repositorios/visao_cuidador_repositorio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/widgets/faixa_emergencia.dart';

import '../../apoio/dubles.dart';

/// O `TeraeApp` com roteador e providers de verdade, partindo de [em].
Widget montarApp({
  required Sessao sessao,
  String em = Rotas.boasVindas,
  RepositorioAutenticacao? autenticacao,
  RepositorioVisaoCuidador? visaoCuidador,
  ControleDemonstracao? demonstracao,
  LancadorExterno? lancador,
  Relogio? relogio,
}) => TeraeApp(
  repositorios: Repositorios(
    autenticacao: autenticacao ?? AutenticacaoDuble(),
    paciente: PacienteDuble(),
    diario: DiarioDuble(),
    cuidadores: CuidadoresDuble(),
    visaoCuidador: visaoCuidador ?? VisaoCuidadorDuble(),
    demonstracao: demonstracao ?? DemonstracaoDuble(),
  ),
  sessao: sessao,
  relogio: relogio ?? RelogioFixo(agoraDeTeste),
  lancador: lancador ?? LancadorDuble(),
  localInicial: em,
);

/// Celular pequeno (360×800 lógicos) com a fonte do aparelho em [escala]
/// (RNFM01). Desfaz tudo no fim do teste.
void telaPequena(WidgetTester tester, {double escala = 2.0}) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Nenhum erro de layout (estouro de `RenderFlex`) desde o último pump.
void semEstouro(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

/// Alvos de toque de 48×48 (Android) e todo alvo com rótulo falado.
Future<void> conferirAlvosDeToque(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

/// Sessão que só anota [entrar] e [escolherPerfil], sem notificar — o roteador
/// fica parado na tela sob teste. [abrir] faz a entrada de verdade (preparo).
class SessaoEspia extends Sessao {
  final List<VinculosDaConta> entradas = [];
  final List<Perfil> escolhidos = [];

  void abrir(VinculosDaConta vinculos) => super.entrar(vinculos);

  @override
  void entrar(VinculosDaConta vinculos, {String? perfilGuardado}) =>
      entradas.add(vinculos);

  @override
  void escolherPerfil(Perfil perfil) => escolhidos.add(perfil);
}

/// Controle da demonstração que conta os reinícios.
class DemonstracaoEspia extends DemonstracaoDuble {
  int reinicios = 0;

  @override
  Future<void> reiniciarDados() async => reinicios++;
}
