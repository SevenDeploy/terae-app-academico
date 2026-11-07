import '../modelos/meta_terapeutica.dart';

/// As metas do plano de terapia ocupacional (evolução de TO, F3; D25, D35;
/// TM06, TM16, TM17, TM20). Só leitura: a clínica cria e muda, a família lê.
/// O cuidador não vê metas (D29). Toda recusa é `RecusaDeRegra`
/// (`falhas.dart`).
abstract interface class RepositorioMetas {
  /// As metas do paciente, em qualquer situação, na ordem de `ordenarMetas`
  /// (`dados/regras/metas.dart`).
  Future<List<MetaTerapeutica>> metas(String pacienteId);

  /// Uma meta do paciente. Recusa `metaInexistente` se ela não existe ou é de
  /// outro paciente.
  Future<MetaTerapeutica> meta(String pacienteId, String metaId);
}
