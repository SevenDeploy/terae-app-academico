/// O que a fonte Terae local ainda não tem, devolvido vazio de forma
/// explícita. Cada um tem a sua `CapacidadesDaFonte` desligada, e a tela
/// esconde a seção (sem botão morto); estes dublês só garantem que nada
/// quebre se uma tela os ler.
library;

import '../modelos/meta_terapeutica.dart';
import '../repositorios/cuidadores_repositorio.dart';
import '../repositorios/demonstracao_repositorio.dart';
import '../repositorios/falhas.dart';
import '../repositorios/metas_repositorio.dart';

Future<T> _indisponivel<T>() =>
    Future.error(const RecusaDeRegra(MotivoRecusa.indisponivelNestaFonte));

/// Cuidadores pelo portal ficam atrás da chave `CUIDADOR_PELO_PORTAL`,
/// desligada no Terae local: lista vazia, convidar e revogar recusam.
class CuidadoresIndisponiveisNoTeraeLocal implements RepositorioCuidadores {
  const CuidadoresIndisponiveisNoTeraeLocal();

  @override
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId) async =>
      const [];

  @override
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  }) => _indisponivel();

  @override
  Future<CuidadorAutorizado> revogar(String vinculoId) => _indisponivel();
}

/// A API do portal não expõe as metas (`EsquemaMetaDaOrientacao` existe só
/// do lado da clínica): nenhuma meta.
class MetasIndisponiveisNoTeraeLocal implements RepositorioMetas {
  const MetasIndisponiveisNoTeraeLocal();

  @override
  Future<List<MetaTerapeutica>> metas(String pacienteId) async => const [];

  @override
  Future<MetaTerapeutica> meta(String pacienteId, String metaId) =>
      Future.error(const RecusaDeRegra(MotivoRecusa.metaInexistente));
}

/// Sem painel de demonstração no Terae local (`CapacidadesDaFonte
/// .demonstracao`): os dados são os do web, e a conexão é a de verdade.
class SemDemonstracaoNoTeraeLocal implements ControleDemonstracao {
  const SemDemonstracaoNoTeraeLocal();

  @override
  bool get semConexao => false;

  @override
  Future<void> definirSemConexao({required bool semConexao}) async {}

  @override
  Future<void> reiniciarDados() async {}
}
