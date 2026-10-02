import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/situacao_vinculo.dart';

/// A delegação do paciente a um cuidador (UC02, §7.4; TM07, TM08, TM10).
///
/// Nasce `pendente` no convite da TM07, sem conta; vira `ativo` no aceite da
/// TM10, que grava [contaCuidadorId] e [autorizadoEm]; revogar muda a
/// [situacao] e preenche [revogadoEm], sem apagar o histórico. No máximo dois
/// pendentes ou ativos por paciente, conferido ao convidar e ao aceitar (§23).
@immutable
class VinculoCuidador {
  VinculoCuidador({
    required this.id,
    required this.pacienteId,
    this.contaCuidadorId,
    required this.conviteId,
    required this.nome,
    required this.situacao,
    DateTime? autorizadoEm,
    DateTime? revogadoEm,
  }) : autorizadoEm = autorizadoEm?.toUtc(),
       revogadoEm = revogadoEm?.toUtc();

  factory VinculoCuidador.fromMap(Mapa mapa) => VinculoCuidador(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    contaCuidadorId: lerOpcional<String>(mapa, 'contaCuidadorId'),
    conviteId: lerCampo<String>(mapa, 'conviteId'),
    nome: lerCampo<String>(mapa, 'nome'),
    situacao: lerEnum(mapa, 'situacao', SituacaoVinculo.values),
    autorizadoEm: lerInstanteOpcional(mapa, 'autorizadoEm'),
    revogadoEm: lerInstanteOpcional(mapa, 'revogadoEm'),
  );

  final String id;
  final String pacienteId;

  /// Conta do cuidador; nula enquanto o convite está pendente.
  final String? contaCuidadorId;

  /// Convite (tipo cuidador) que originou o vínculo.
  final String conviteId;

  /// Nome informado pelo paciente na TM07.
  final String nome;
  final SituacaoVinculo situacao;

  /// Gravado no aceite do convite (TM10).
  final DateTime? autorizadoEm;
  final DateTime? revogadoEm;

  /// O que muda num vínculo: aceite (situação, conta, data) e revogação.
  VinculoCuidador copyWith({
    SituacaoVinculo? situacao,
    String? contaCuidadorId,
    DateTime? autorizadoEm,
    DateTime? revogadoEm,
  }) => VinculoCuidador(
    id: id,
    pacienteId: pacienteId,
    contaCuidadorId: contaCuidadorId ?? this.contaCuidadorId,
    conviteId: conviteId,
    nome: nome,
    situacao: situacao ?? this.situacao,
    autorizadoEm: autorizadoEm ?? this.autorizadoEm,
    revogadoEm: revogadoEm ?? this.revogadoEm,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'contaCuidadorId': contaCuidadorId,
    'conviteId': conviteId,
    'nome': nome,
    'situacao': situacao.name,
    'autorizadoEm': escreverInstanteOpcional(autorizadoEm),
    'revogadoEm': escreverInstanteOpcional(revogadoEm),
  };

  @override
  bool operator ==(Object other) =>
      other is VinculoCuidador &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.contaCuidadorId == contaCuidadorId &&
      other.conviteId == conviteId &&
      other.nome == nome &&
      other.situacao == situacao &&
      other.autorizadoEm == autorizadoEm &&
      other.revogadoEm == revogadoEm;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    contaCuidadorId,
    conviteId,
    nome,
    situacao,
    autorizadoEm,
    revogadoEm,
  );

  @override
  String toString() => 'VinculoCuidador${toMap()}';
}
