import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/adesao.dart';
import '../enums/intensidade.dart';
import '../enums/situacao_envio.dart';

/// O dado que o aplicativo produz: o diário entre consultas (RFM03; TM03,
/// TM04, TM05).
///
/// O [id] é UUID gerado no aparelho (`gerarUuidV4`), o que permite criar sem
/// rede e reenviar sem duplicar. [situacaoEnvio] sustenta a fila em conexão
/// instável; enquanto `naFila`, nenhuma tela diz que a equipe foi avisada.
/// Depois de enviado, o registro não é editado (§23).
@immutable
class RegistroDiario {
  RegistroDiario({
    required this.id,
    required this.pacienteId,
    required DateTime registradoEm,
    required this.adesao,
    required this.intensidade,
    required this.sintomaPredominante,
    this.observacao,
    required this.situacaoEnvio,
  }) : registradoEm = registradoEm.toUtc();

  factory RegistroDiario.fromMap(Mapa mapa) => RegistroDiario(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    registradoEm: lerInstante(mapa, 'registradoEm'),
    adesao: lerEnum(mapa, 'adesao', Adesao.values),
    intensidade: lerEnum(mapa, 'intensidade', Intensidade.values),
    sintomaPredominante: lerCampo<String>(mapa, 'sintomaPredominante'),
    observacao: lerOpcional<String>(mapa, 'observacao'),
    situacaoEnvio: lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values),
  );

  final String id;
  final String pacienteId;
  final DateTime registradoEm;
  final Adesao adesao;
  final Intensidade intensidade;

  /// Escolhido, não digitado (RNFM02: nenhum texto livre obrigatório).
  final String sintomaPredominante;

  /// Observação livre, opcional.
  final String? observacao;
  final SituacaoEnvio situacaoEnvio;

  /// Só a situação de envio muda (`naFila` → `enviado`).
  RegistroDiario copyWith({SituacaoEnvio? situacaoEnvio}) => RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: registradoEm,
    adesao: adesao,
    intensidade: intensidade,
    sintomaPredominante: sintomaPredominante,
    observacao: observacao,
    situacaoEnvio: situacaoEnvio ?? this.situacaoEnvio,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'registradoEm': escreverInstante(registradoEm),
    'adesao': adesao.name,
    'intensidade': intensidade.name,
    'sintomaPredominante': sintomaPredominante,
    'observacao': observacao,
    'situacaoEnvio': situacaoEnvio.name,
  };

  @override
  bool operator ==(Object other) =>
      other is RegistroDiario &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.registradoEm == registradoEm &&
      other.adesao == adesao &&
      other.intensidade == intensidade &&
      other.sintomaPredominante == sintomaPredominante &&
      other.observacao == observacao &&
      other.situacaoEnvio == situacaoEnvio;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    registradoEm,
    adesao,
    intensidade,
    sintomaPredominante,
    observacao,
    situacaoEnvio,
  );

  @override
  String toString() => 'RegistroDiario${toMap()}';
}
