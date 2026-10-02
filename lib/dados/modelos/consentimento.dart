import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/canal_autorizado.dart';
import '../enums/qualidade_consentimento.dart';

/// Aceite do termo na TM09 (RFM09; LGPD art. 8º § 2º, art. 11, I, art. 14
/// § 1º): versão do termo, data, canal autorizado (R05) e quem aceitou.
///
/// Termo novo gera registro novo; revogar preenche [revogadoEm] e não apaga.
@immutable
class Consentimento {
  Consentimento({
    required this.id,
    required this.pacienteId,
    required this.contaId,
    required this.qualidade,
    required this.versaoTermo,
    required this.canalAutorizado,
    required DateTime aceitoEm,
    DateTime? revogadoEm,
  }) : aceitoEm = aceitoEm.toUtc(),
       revogadoEm = revogadoEm?.toUtc();

  factory Consentimento.fromMap(Mapa mapa) => Consentimento(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    contaId: lerCampo<String>(mapa, 'contaId'),
    qualidade: lerEnum(mapa, 'qualidade', QualidadeConsentimento.values),
    versaoTermo: lerCampo<String>(mapa, 'versaoTermo'),
    canalAutorizado: lerEnum(mapa, 'canalAutorizado', CanalAutorizado.values),
    aceitoEm: lerInstante(mapa, 'aceitoEm'),
    revogadoEm: lerInstanteOpcional(mapa, 'revogadoEm'),
  );

  final String id;
  final String pacienteId;

  /// Conta que aceitou (a do titular ou a do responsável legal).
  final String contaId;
  final QualidadeConsentimento qualidade;
  final String versaoTermo;
  final CanalAutorizado canalAutorizado;
  final DateTime aceitoEm;

  /// Nulo enquanto vigente (LGPD art. 8º § 5º).
  final DateTime? revogadoEm;

  /// Só a revogação muda um consentimento.
  Consentimento copyWith({DateTime? revogadoEm}) => Consentimento(
    id: id,
    pacienteId: pacienteId,
    contaId: contaId,
    qualidade: qualidade,
    versaoTermo: versaoTermo,
    canalAutorizado: canalAutorizado,
    aceitoEm: aceitoEm,
    revogadoEm: revogadoEm ?? this.revogadoEm,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'contaId': contaId,
    'qualidade': qualidade.name,
    'versaoTermo': versaoTermo,
    'canalAutorizado': canalAutorizado.name,
    'aceitoEm': escreverInstante(aceitoEm),
    'revogadoEm': escreverInstanteOpcional(revogadoEm),
  };

  @override
  bool operator ==(Object other) =>
      other is Consentimento &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.contaId == contaId &&
      other.qualidade == qualidade &&
      other.versaoTermo == versaoTermo &&
      other.canalAutorizado == canalAutorizado &&
      other.aceitoEm == aceitoEm &&
      other.revogadoEm == revogadoEm;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    contaId,
    qualidade,
    versaoTermo,
    canalAutorizado,
    aceitoEm,
    revogadoEm,
  );

  @override
  String toString() => 'Consentimento${toMap()}';
}
