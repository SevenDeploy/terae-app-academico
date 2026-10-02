import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';

/// Receita vigente: orientação no Início e na Jornada, data de renovação
/// avisada também ao cuidador (RF03; TM02, TM06, TM11, TM12). O aplicativo só
/// exibe: não há emissão nem assinatura nele, por isso não há `copyWith`.
@immutable
class ReceitaUsoContinuo {
  const ReceitaUsoContinuo({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.orientacao,
    required this.vigenciaInicio,
    required this.vigenciaFim,
    required this.dataRenovacao,
  });

  factory ReceitaUsoContinuo.fromMap(Mapa mapa) => ReceitaUsoContinuo(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    profissionalId: lerCampo<String>(mapa, 'profissionalId'),
    orientacao: lerCampo<String>(mapa, 'orientacao'),
    vigenciaInicio: lerDataCivil(mapa, 'vigenciaInicio'),
    vigenciaFim: lerDataCivil(mapa, 'vigenciaFim'),
    dataRenovacao: lerDataCivil(mapa, 'dataRenovacao'),
  );

  final String id;
  final String pacienteId;
  final String profissionalId;

  /// Orientação em linguagem simples, somente leitura.
  final String orientacao;
  final DataCivil vigenciaInicio;
  final DataCivil vigenciaFim;

  /// Quando pedir a nova receita (lembrete no Início e aviso na TM12).
  final DataCivil dataRenovacao;

  /// Vigente no dia [hoje] (início e fim inclusos).
  bool vigenteEm(DataCivil hoje) =>
      !hoje.ehAntesDe(vigenciaInicio) && !hoje.ehDepoisDe(vigenciaFim);

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'profissionalId': profissionalId,
    'orientacao': orientacao,
    'vigenciaInicio': vigenciaInicio.paraIso(),
    'vigenciaFim': vigenciaFim.paraIso(),
    'dataRenovacao': dataRenovacao.paraIso(),
  };

  @override
  bool operator ==(Object other) =>
      other is ReceitaUsoContinuo &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.profissionalId == profissionalId &&
      other.orientacao == orientacao &&
      other.vigenciaInicio == vigenciaInicio &&
      other.vigenciaFim == vigenciaFim &&
      other.dataRenovacao == dataRenovacao;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    profissionalId,
    orientacao,
    vigenciaInicio,
    vigenciaFim,
    dataRenovacao,
  );

  @override
  String toString() => 'ReceitaUsoContinuo${toMap()}';
}
