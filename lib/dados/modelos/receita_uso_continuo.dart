import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';

/// Receita vigente: orientação no Início e na Jornada, data de renovação
/// avisada também ao cuidador (RF03; TM02, TM06, TM11, TM12). O aplicativo só
/// exibe: não há emissão nem assinatura nele, por isso não há `copyWith`.
///
/// RNFM05 — na cópia que vai para o aparelho do cuidador ([paraCuidador]),
/// [orientacao] e [profissionalId] vêm nulos, porque a TM08, a TM11 e a TM12
/// não os mostram; por isso são anuláveis aqui. Na cópia do paciente/família
/// os dois estão sempre preenchidos.
@immutable
class ReceitaUsoContinuo {
  const ReceitaUsoContinuo({
    required this.id,
    required this.pacienteId,
    this.profissionalId,
    this.orientacao,
    required this.vigenciaInicio,
    required this.vigenciaFim,
    required this.dataRenovacao,
  });

  factory ReceitaUsoContinuo.fromMap(Mapa mapa) => ReceitaUsoContinuo(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    profissionalId: lerOpcional<String>(mapa, 'profissionalId'),
    orientacao: lerOpcional<String>(mapa, 'orientacao'),
    vigenciaInicio: lerDataCivil(mapa, 'vigenciaInicio'),
    vigenciaFim: lerDataCivil(mapa, 'vigenciaFim'),
    dataRenovacao: lerDataCivil(mapa, 'dataRenovacao'),
  );

  final String id;
  final String pacienteId;

  /// Quem prescreveu. Nulo na cópia do cuidador (RNFM05).
  final String? profissionalId;

  /// Orientação em linguagem simples, somente leitura. Nula na cópia do
  /// cuidador (RNFM05).
  final String? orientacao;
  final DataCivil vigenciaInicio;
  final DataCivil vigenciaFim;

  /// Quando pedir a nova receita (lembrete no Início e aviso na TM12).
  final DataCivil dataRenovacao;

  /// Vigente no dia [hoje] (início e fim inclusos).
  bool vigenteEm(DataCivil hoje) =>
      !hoje.ehAntesDe(vigenciaInicio) && !hoje.ehDepoisDe(vigenciaFim);

  /// RNFM05 — cópia para o aparelho do cuidador: vigência e renovação (TM08,
  /// TM11, TM12), sem a orientação nem o profissional que prescreveu.
  ReceitaUsoContinuo paraCuidador() => ReceitaUsoContinuo(
    id: id,
    pacienteId: pacienteId,
    vigenciaInicio: vigenciaInicio,
    vigenciaFim: vigenciaFim,
    dataRenovacao: dataRenovacao,
  );

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
