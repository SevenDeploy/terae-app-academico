import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';

final RegExp _formatoHorario = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Um medicamento da receita, com posologia e horários — decomposição da
/// receita para o cronograma por horário do cuidador (RF03, §7.4; TM08, TM11).
@immutable
class ItemMedicacao {
  /// [horarios] em `HH:mm`, no horário da clínica; lista vazia = "quando
  /// precisar".
  ItemMedicacao({
    required this.id,
    required this.receitaId,
    required this.medicamento,
    required this.posologia,
    required List<String> horarios,
  }) : horarios = List.unmodifiable(horarios) {
    for (final h in horarios) {
      if (!_formatoHorario.hasMatch(h)) {
        throw FormatException('Horário fora do formato HH:mm', h);
      }
    }
  }

  factory ItemMedicacao.fromMap(Mapa mapa) => ItemMedicacao(
    id: lerCampo<String>(mapa, 'id'),
    receitaId: lerCampo<String>(mapa, 'receitaId'),
    medicamento: lerCampo<String>(mapa, 'medicamento'),
    posologia: lerCampo<String>(mapa, 'posologia'),
    horarios: lerTextos(mapa, 'horarios'),
  );

  final String id;
  final String receitaId;

  /// Ex.: `Sertralina`.
  final String medicamento;

  /// Ex.: `50 mg, 1 comprimido`.
  final String posologia;

  /// `HH:mm` no horário da clínica, imutável.
  final List<String> horarios;

  Mapa toMap() => {
    'id': id,
    'receitaId': receitaId,
    'medicamento': medicamento,
    'posologia': posologia,
    'horarios': [...horarios],
  };

  @override
  bool operator ==(Object other) =>
      other is ItemMedicacao &&
      other.id == id &&
      other.receitaId == receitaId &&
      other.medicamento == medicamento &&
      other.posologia == posologia &&
      listEquals(other.horarios, horarios);

  @override
  int get hashCode => Object.hash(
    id,
    receitaId,
    medicamento,
    posologia,
    Object.hashAll(horarios),
  );

  @override
  String toString() => 'ItemMedicacao${toMap()}';
}
