import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';

/// Profissional de referência, avisado na ajuda imediata (TM05), e o de cada
/// consulta na agenda do cuidador (TM12). Fica com o mínimo (RF08).
@immutable
class ProfissionalSaude {
  const ProfissionalSaude({
    required this.id,
    required this.nome,
    required this.registroConselho,
    required this.especialidade,
  });

  factory ProfissionalSaude.fromMap(Mapa mapa) => ProfissionalSaude(
    id: lerCampo<String>(mapa, 'id'),
    nome: lerCampo<String>(mapa, 'nome'),
    registroConselho: lerCampo<String>(mapa, 'registroConselho'),
    especialidade: lerCampo<String>(mapa, 'especialidade'),
  );

  final String id;
  final String nome;

  /// Ex.: `CRM-MT 12345`, `CREFITO-9 30125-TO`.
  final String registroConselho;

  /// Em linguagem simples (ex.: `Terapia ocupacional`).
  final String especialidade;

  /// F2 — atende em terapia ocupacional: o encontro se chama "sessão", não
  /// "consulta" (TM02, TM06, TM08, TM12, TM18).
  bool get ehTerapiaOcupacional =>
      especialidade.toLowerCase().contains('terapia ocupacional');

  Mapa toMap() => {
    'id': id,
    'nome': nome,
    'registroConselho': registroConselho,
    'especialidade': especialidade,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfissionalSaude &&
      other.id == id &&
      other.nome == nome &&
      other.registroConselho == registroConselho &&
      other.especialidade == especialidade;

  @override
  int get hashCode => Object.hash(id, nome, registroConselho, especialidade);

  @override
  String toString() => 'ProfissionalSaude${toMap()}';
}
