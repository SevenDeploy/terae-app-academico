import 'package:flutter/foundation.dart';

import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../enums/resposta_presenca.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../modelos/registro_de_atividade.dart';
import '../sincronizacao/situacao_sincronizacao.dart';
import 'autenticacao_repositorio.dart';
import 'cuidadores_repositorio.dart';
import 'demonstracao_repositorio.dart';
import 'diario_repositorio.dart';
import 'falhas.dart';
import 'paciente_repositorio.dart';
import 'presenca_repositorio.dart';
import 'programa_em_casa_repositorio.dart';
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
    this.programaEmCasa = const _ProgramaVazio(),
    this.presenca = const _PresencaVazia(),
    this.conexao = const _SempreOnline(),
  });

  final RepositorioAutenticacao autenticacao;
  final RepositorioPaciente paciente;
  final RepositorioDiario diario;
  final RepositorioCuidadores cuidadores;
  final RepositorioVisaoCuidador visaoCuidador;
  final ControleDemonstracao demonstracao;

  /// Evolução de TO (F1): as atividades de casa e o registro de cada dia. O
  /// padrão (sem atividades) serve aos dublês de teste que não o usam; a
  /// memória e a persistência montam o de verdade.
  final RepositorioProgramaEmCasa programaEmCasa;

  /// Evolução de TO (F2): a confirmação de presença nas sessões. O padrão
  /// (sem respostas) serve aos dublês de teste que não o usam.
  final RepositorioPresenca presenca;

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

/// Presença sem respostas (dublês de teste que não a usam).
class _PresencaVazia implements RepositorioPresenca {
  const _PresencaVazia();

  @override
  Future<Map<String, ConfirmacaoDePresenca>> respostas(
    String pacienteId,
  ) async => const {};

  @override
  Future<ConfirmacaoDePresenca> responder({
    required String pacienteId,
    required String agendamentoId,
    required RespostaPresenca resposta,
  }) => Future.error(const RecusaDeRegra(MotivoRecusa.agendamentoInexistente));
}

/// Programa sem atividades (dublês de teste que não o usam).
class _ProgramaVazio implements RepositorioProgramaEmCasa {
  const _ProgramaVazio();

  @override
  Future<List<AtividadeDeCasa>> atividades(String pacienteId) async => const [];

  @override
  Future<AtividadeDeCasa> atividade(String pacienteId, String atividadeId) =>
      Future.error(const RecusaDeRegra(MotivoRecusa.atividadeInexistente));

  @override
  Future<List<RegistroDeAtividade>> registros(
    String pacienteId, {
    int dias = 14,
  }) async => const [];

  @override
  Future<RegistroDeAtividade> registrar({
    required String pacienteId,
    required String atividadeId,
    required AdesaoEmCasa adesao,
    String? reflexao,
    required QuemRegistrou quem,
  }) => Future.error(const RecusaDeRegra(MotivoRecusa.atividadeInexistente));

  @override
  Future<RegistroDeAtividade> desfazer(String pacienteId, String registroId) =>
      Future.error(const RecusaDeRegra(MotivoRecusa.registroInexistente));

  @override
  Future<void> atualizar(String pacienteId) async {}
}
