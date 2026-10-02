/// O app inteiro (`TeraeApp`) com os dublês de `dubles.dart`.
library;

import 'package:flutter/widgets.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/widgets/faixa_emergencia.dart';

import 'dubles.dart';

/// O app inteiro com dublês, partindo de [em].
Widget appDeTeste({
  required Sessao sessao,
  String em = Rotas.boasVindas,
  LancadorExterno? lancador,
}) => TeraeApp(
  repositorios: repositoriosDuble(),
  sessao: sessao,
  relogio: RelogioFixo(agoraDeTeste),
  lancador: lancador ?? LancadorDuble(),
  localInicial: em,
);
