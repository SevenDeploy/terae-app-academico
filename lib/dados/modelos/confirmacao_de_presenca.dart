import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/resposta_presenca.dart';
import '../enums/situacao_envio.dart';

/// A resposta da família ou do paciente a uma sessão marcada (evolução de TO,
/// F2; D27; inspirada no "confirmar sessão" do Terae web).
///
/// Uma por agendamento: o documento tem o id do [agendamentoId], e responder
/// de novo troca a resposta até o horário da sessão. Nunca cancela a sessão:
/// "não vamos conseguir" só avisa a clínica. Gravada primeiro no aparelho,
/// com [situacaoEnvio] para a fila sem conexão.
@immutable
class ConfirmacaoDePresenca {
  ConfirmacaoDePresenca({
    required this.agendamentoId,
    required this.pacienteId,
    required this.resposta,
    required DateTime respondidaEm,
    required this.situacaoEnvio,
  }) : respondidaEm = respondidaEm.toUtc();

  factory ConfirmacaoDePresenca.fromMap(Mapa mapa) => ConfirmacaoDePresenca(
    agendamentoId: lerCampo<String>(mapa, 'agendamentoId'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    resposta: lerEnum(mapa, 'resposta', RespostaPresenca.values),
    respondidaEm: lerInstante(mapa, 'respondidaEm'),
    situacaoEnvio: lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values),
  );

  /// O agendamento respondido; também é o id do documento.
  final String agendamentoId;
  final String pacienteId;
  final RespostaPresenca resposta;

  /// Quando a pessoa respondeu (a regra do servidor confere que foi antes da
  /// sessão, mesmo que a resposta chegue depois pela fila).
  final DateTime respondidaEm;
  final SituacaoEnvio situacaoEnvio;

  /// Só a situação de envio muda (`naFila` → `enviado`).
  ConfirmacaoDePresenca copyWith({SituacaoEnvio? situacaoEnvio}) =>
      ConfirmacaoDePresenca(
        agendamentoId: agendamentoId,
        pacienteId: pacienteId,
        resposta: resposta,
        respondidaEm: respondidaEm,
        situacaoEnvio: situacaoEnvio ?? this.situacaoEnvio,
      );

  /// No mapa vai também `id` (= [agendamentoId]), o id do documento, que a
  /// leitura com cópia local usa como chave.
  Mapa toMap() => {
    'id': agendamentoId,
    'agendamentoId': agendamentoId,
    'pacienteId': pacienteId,
    'resposta': resposta.name,
    'respondidaEm': escreverInstante(respondidaEm),
    'situacaoEnvio': situacaoEnvio.name,
  };

  @override
  bool operator ==(Object other) =>
      other is ConfirmacaoDePresenca &&
      other.agendamentoId == agendamentoId &&
      other.pacienteId == pacienteId &&
      other.resposta == resposta &&
      other.respondidaEm == respondidaEm &&
      other.situacaoEnvio == situacaoEnvio;

  @override
  int get hashCode => Object.hash(
    agendamentoId,
    pacienteId,
    resposta,
    respondidaEm,
    situacaoEnvio,
  );

  @override
  String toString() => 'ConfirmacaoDePresenca${toMap()}';
}
