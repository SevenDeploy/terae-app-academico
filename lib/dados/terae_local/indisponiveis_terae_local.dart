/// O que a fonte Terae local ainda não tem, devolvido vazio de forma
/// explícita. Cada um tem a sua `CapacidadesDaFonte` desligada, e a tela
/// esconde a seção (sem botão morto); estes dublês só garantem que nada
/// quebre se uma tela os ler.
library;

import '../modelos/alerta.dart';
import '../modelos/meta_terapeutica.dart';
import '../modelos/registro_diario.dart';
import '../repositorios/cuidadores_repositorio.dart';
import '../repositorios/demonstracao_repositorio.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import '../repositorios/metas_repositorio.dart';

Future<T> _indisponivel<T>() =>
    Future.error(const RecusaDeRegra(MotivoRecusa.indisponivelNestaFonte));

/// Diário do Terae local: chega depois da P3. A sessão do diário refaz o
/// modelo (`RegistroDiario` com os nomes da API) em outra branch, e a
/// coordenação liga `/api/portal/diario` depois. Até lá a aba Diário mostra
/// "indisponível" (`CapacidadesDaFonte.diario`), a leitura é vazia e a
/// escrita recusa `indisponivelNestaFonte`.
class DiarioIndisponivelNoTeraeLocal implements RepositorioDiario {
  const DiarioIndisponivelNoTeraeLocal();

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) => _indisponivel();

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async => const [];

  @override
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) async =>
      const PaginaDoDiario(registros: [], haMais: false);

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async => const [];

  @override
  Future<RegistroDiario> registro(String registroId) =>
      Future.error(const RecusaDeRegra(MotivoRecusa.registroInexistente));

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async => null;

  @override
  Future<ResultadoEnvio> corrigir(String registroId, EntradaDoDiario entrada) =>
      _indisponivel();

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) => _indisponivel();
}

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
