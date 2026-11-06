import 'package:flutter/foundation.dart';

/// O que o aviso de conexão mostra (Atividade 4, D16): se há conexão, quantos
/// registros do diário esperam envio e quando foi a última sincronização.
///
/// É o único objeto da sincronização que as telas enxergam
/// (`test/arquitetura_test.dart`): chega por provider como
/// `ValueListenable<SituacaoSincronizacao>`.
@immutable
class SituacaoSincronizacao {
  const SituacaoSincronizacao({
    this.online = true,
    this.pendentes = 0,
    this.sincronizando = false,
    this.ultimaSincronizacao,
  });

  /// A rede do aparelho está ligada e a última tentativa de falar com o
  /// servidor deu certo.
  final bool online;

  /// Registros do diário (novos, corrigidos ou excluídos) na fila.
  final int pendentes;

  /// Envio ou busca em andamento.
  final bool sincronizando;

  /// Último instante (UTC) em que a fila e as cópias foram sincronizadas.
  final DateTime? ultimaSincronizacao;

  SituacaoSincronizacao copyWith({
    bool? online,
    int? pendentes,
    bool? sincronizando,
    DateTime? ultimaSincronizacao,
  }) => SituacaoSincronizacao(
    online: online ?? this.online,
    pendentes: pendentes ?? this.pendentes,
    sincronizando: sincronizando ?? this.sincronizando,
    ultimaSincronizacao: ultimaSincronizacao ?? this.ultimaSincronizacao,
  );

  @override
  bool operator ==(Object other) =>
      other is SituacaoSincronizacao &&
      other.online == online &&
      other.pendentes == pendentes &&
      other.sincronizando == sincronizando &&
      other.ultimaSincronizacao == ultimaSincronizacao;

  @override
  int get hashCode =>
      Object.hash(online, pendentes, sincronizando, ultimaSincronizacao);

  @override
  String toString() =>
      'SituacaoSincronizacao(online: $online, pendentes: $pendentes)';
}

/// Embrulho imutável da situação para o provider, que recusa `Listenable`
/// direto (contrato de `Repositorios`). O aviso de conexão escuta
/// [situacao] com um `ValueListenableBuilder`.
@immutable
class ConexaoDoApp {
  const ConexaoDoApp(this.situacao);

  final ValueListenable<SituacaoSincronizacao> situacao;
}
