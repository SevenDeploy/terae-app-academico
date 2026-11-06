import 'package:flutter/foundation.dart';

import '../sincronizacao/situacao_sincronizacao.dart';
import 'autenticacao_repositorio.dart';
import 'cuidadores_repositorio.dart';
import 'demonstracao_repositorio.dart';
import 'diario_repositorio.dart';
import 'paciente_repositorio.dart';
import 'visao_cuidador_repositorio.dart';

/// Os contratos que o `TeraeApp` recebe e disponibiliza por provider (§22:
/// trocar a implementação em memória por uma que fale com a API não muda
/// nenhuma tela). Nenhuma implementação pode ser `Listenable` — o provider
/// recusa; quem precisa reagir a mudança é o controlador da tela. A exceção
/// é a [conexao] (Atividade 4), um `ValueListenable` só de leitura para o
/// aviso "Sem conexão".
@immutable
class Repositorios {
  const Repositorios({
    required this.autenticacao,
    required this.paciente,
    required this.diario,
    required this.cuidadores,
    required this.visaoCuidador,
    required this.demonstracao,
    this.conexao = const _SempreOnline(),
  });

  final RepositorioAutenticacao autenticacao;
  final RepositorioPaciente paciente;
  final RepositorioDiario diario;
  final RepositorioCuidadores cuidadores;
  final RepositorioVisaoCuidador visaoCuidador;
  final ControleDemonstracao demonstracao;

  /// Situação da conexão e da fila do diário (D16), para o aviso das telas.
  final ValueListenable<SituacaoSincronizacao> conexao;
}

/// Conexão sempre ligada e fila vazia (dublês de teste que não a usam).
class _SempreOnline implements ValueListenable<SituacaoSincronizacao> {
  const _SempreOnline();

  @override
  SituacaoSincronizacao get value => const SituacaoSincronizacao();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
