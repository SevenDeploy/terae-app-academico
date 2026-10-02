import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/situacao_agendamento.dart';

/// Consulta: próxima consulta no Início, consultas da linha do tempo e agenda
/// do cuidador (RF05; TM02, TM06, TM08, TM12).
///
/// RNFM05 — a agenda do cuidador recebe data, hora e profissional, mas não o
/// motivo do retorno: por isso [motivoRetorno] é anulável e [paraCuidador] o
/// remove.
@immutable
class Agendamento {
  Agendamento({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required DateTime dataHora,
    this.motivoRetorno,
    required this.situacao,
  }) : dataHora = dataHora.toUtc();

  factory Agendamento.fromMap(Mapa mapa) => Agendamento(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    profissionalId: lerCampo<String>(mapa, 'profissionalId'),
    dataHora: lerInstante(mapa, 'dataHora'),
    motivoRetorno: lerOpcional<String>(mapa, 'motivoRetorno'),
    situacao: lerEnum(mapa, 'situacao', SituacaoAgendamento.values),
  );

  final String id;
  final String pacienteId;
  final String profissionalId;
  final DateTime dataHora;

  /// Nulo na cópia do cuidador (RNFM05).
  final String? motivoRetorno;
  final SituacaoAgendamento situacao;

  /// Só a situação muda (agendado → realizado ou cancelado).
  Agendamento copyWith({SituacaoAgendamento? situacao}) => Agendamento(
    id: id,
    pacienteId: pacienteId,
    profissionalId: profissionalId,
    dataHora: dataHora,
    motivoRetorno: motivoRetorno,
    situacao: situacao ?? this.situacao,
  );

  /// RNFM05 — cópia para o aparelho do cuidador, sem o motivo do retorno.
  Agendamento paraCuidador() => Agendamento(
    id: id,
    pacienteId: pacienteId,
    profissionalId: profissionalId,
    dataHora: dataHora,
    situacao: situacao,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'profissionalId': profissionalId,
    'dataHora': escreverInstante(dataHora),
    'motivoRetorno': motivoRetorno,
    'situacao': situacao.name,
  };

  @override
  bool operator ==(Object other) =>
      other is Agendamento &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.profissionalId == profissionalId &&
      other.dataHora == dataHora &&
      other.motivoRetorno == motivoRetorno &&
      other.situacao == situacao;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    profissionalId,
    dataHora,
    motivoRetorno,
    situacao,
  );

  @override
  String toString() => 'Agendamento${toMap()}';
}
