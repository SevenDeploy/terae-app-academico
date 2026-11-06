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
///
/// D17 (Atividade 4) — o registro pode ser corrigido ou excluído só no mesmo
/// dia civil da clínica em que foi feito (`dados/regras/diario.dart`). A
/// exclusão é lógica: [excluidoEm] preenchido tira o registro das listas, mas
/// ele continua guardado (§23: nenhuma exclusão física).
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
    DateTime? atualizadoEm,
    DateTime? excluidoEm,
  }) : registradoEm = registradoEm.toUtc(),
       atualizadoEm = atualizadoEm?.toUtc(),
       excluidoEm = excluidoEm?.toUtc();

  factory RegistroDiario.fromMap(Mapa mapa) => RegistroDiario(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    registradoEm: lerInstante(mapa, 'registradoEm'),
    adesao: lerEnum(mapa, 'adesao', Adesao.values),
    intensidade: lerEnum(mapa, 'intensidade', Intensidade.values),
    sintomaPredominante: lerCampo<String>(mapa, 'sintomaPredominante'),
    observacao: lerOpcional<String>(mapa, 'observacao'),
    situacaoEnvio: lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values),
    atualizadoEm: lerInstanteOpcional(mapa, 'atualizadoEm'),
    excluidoEm: lerInstanteOpcional(mapa, 'excluidoEm'),
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

  /// Última correção feita pelo paciente (D17); `null` se nunca mudou.
  final DateTime? atualizadoEm;

  /// Exclusão lógica (D17); `null` enquanto o registro vale.
  final DateTime? excluidoEm;

  bool get excluido => excluidoEm != null;

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
    atualizadoEm: atualizadoEm,
    excluidoEm: excluidoEm,
  );

  /// D17 — a correção feita [em] um instante: troca as respostas (a
  /// [observacao] pode virar `null`) e volta para a fila até o servidor
  /// confirmar. Mantém `id`, paciente e `registradoEm`.
  RegistroDiario corrigido({
    required Adesao adesao,
    required Intensidade intensidade,
    required String sintomaPredominante,
    required String? observacao,
    required DateTime em,
  }) => RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: registradoEm,
    adesao: adesao,
    intensidade: intensidade,
    sintomaPredominante: sintomaPredominante,
    observacao: observacao,
    situacaoEnvio: SituacaoEnvio.naFila,
    atualizadoEm: em,
    excluidoEm: excluidoEm,
  );

  /// D17 — a exclusão lógica feita [em] um instante; volta para a fila até o
  /// servidor confirmar.
  RegistroDiario excluidoAs(DateTime em) => RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: registradoEm,
    adesao: adesao,
    intensidade: intensidade,
    sintomaPredominante: sintomaPredominante,
    observacao: observacao,
    situacaoEnvio: SituacaoEnvio.naFila,
    atualizadoEm: atualizadoEm,
    excluidoEm: em,
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
    'atualizadoEm': escreverInstanteOpcional(atualizadoEm),
    'excluidoEm': escreverInstanteOpcional(excluidoEm),
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
      other.situacaoEnvio == situacaoEnvio &&
      other.atualizadoEm == atualizadoEm &&
      other.excluidoEm == excluidoEm;

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
    atualizadoEm,
    excluidoEm,
  );

  @override
  String toString() => 'RegistroDiario${toMap()}';
}
