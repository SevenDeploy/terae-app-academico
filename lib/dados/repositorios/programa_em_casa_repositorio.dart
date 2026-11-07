import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/registro_de_atividade.dart';

/// O programa em casa da terapia ocupacional (evolução de TO, F1; D26; TM16,
/// TM17): as atividades combinadas, só leitura, e o registro de como foi cada
/// dia, que a família grava.
///
/// Como o diário, o registro vai primeiro para o aparelho e depois para o
/// servidor: sem conexão fica na fila (`naFila`) e sai sozinho quando a
/// conexão volta. Toda recusa é `RecusaDeRegra` (`falhas.dart`).
abstract interface class RepositorioProgramaEmCasa {
  /// As atividades que valem hoje, na ordem em que foram publicadas.
  Future<List<AtividadeDeCasa>> atividades(String pacienteId);

  /// TM17 — uma atividade que vale hoje; recusa `atividadeInexistente`.
  Future<AtividadeDeCasa> atividade(String pacienteId, String atividadeId);

  /// Os registros que valem (sem os desfeitos) dos últimos [dias] dias, hoje
  /// incluído, do mais recente ao mais antigo, com os que estão na fila.
  Future<List<RegistroDeAtividade>> registros(
    String pacienteId, {
    int dias = 14,
  });

  /// D26 — registra como foi a atividade hoje. Se já houver registro dela
  /// hoje (mesmo desfeito), corrige o mesmo (mesmo id): no máximo um por
  /// atividade e por dia. Recusa `atividadeInexistente`.
  Future<RegistroDeAtividade> registrar({
    required String pacienteId,
    required String atividadeId,
    required AdesaoEmCasa adesao,
    String? reflexao,
    required QuemRegistrou quem,
  });

  /// D26 — "Desfazer" o registro de hoje (exclusão lógica). Recusa
  /// `registroInexistente` e `edicaoEncerrada` (de outro dia).
  Future<RegistroDeAtividade> desfazer(String pacienteId, String registroId);

  /// "Puxar para atualizar" da TM16: envia a fila e traz do servidor o que
  /// houver de novo (inclusive de outro aparelho). Sem conexão, não faz nada:
  /// a tela continua com o que está no aparelho.
  Future<void> atualizar(String pacienteId);
}
