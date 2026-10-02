import 'package:flutter/foundation.dart';

import 'autenticacao_repositorio.dart';
import 'cuidadores_repositorio.dart';
import 'demonstracao_repositorio.dart';
import 'diario_repositorio.dart';
import 'paciente_repositorio.dart';
import 'visao_cuidador_repositorio.dart';

/// Os contratos que o `TeraeApp` recebe e disponibiliza por provider (§22:
/// trocar a implementação em memória por uma que fale com a API não muda
/// nenhuma tela). Nenhuma implementação pode ser `Listenable` — o provider
/// recusa; quem precisa reagir a mudança é o controlador da tela.
@immutable
class Repositorios {
  const Repositorios({
    required this.autenticacao,
    required this.paciente,
    required this.diario,
    required this.cuidadores,
    required this.visaoCuidador,
    required this.demonstracao,
  });

  final RepositorioAutenticacao autenticacao;
  final RepositorioPaciente paciente;
  final RepositorioDiario diario;
  final RepositorioCuidadores cuidadores;
  final RepositorioVisaoCuidador visaoCuidador;
  final ControleDemonstracao demonstracao;
}
