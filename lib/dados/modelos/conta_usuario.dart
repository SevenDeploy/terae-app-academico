import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/situacao_conta.dart';

/// Quem acessa o aplicativo (TM01, TM09, TM10), separado de quem é tratado.
///
/// Guarda o identificador do provedor federado e nenhuma senha (RFM01,
/// RNFM04). O perfil não é gravado aqui: decorre dos vínculos da conta — um
/// Paciente com `contaId` desta conta, ou um VinculoCuidador ativo com
/// `contaCuidadorId` desta conta (§19, §23).
@immutable
class ContaUsuario {
  ContaUsuario({
    required this.id,
    required this.nomeExibicao,
    required this.email,
    required this.idProvedor,
    required this.situacao,
    DateTime? ultimoAcessoEm,
  }) : ultimoAcessoEm = ultimoAcessoEm?.toUtc();

  factory ContaUsuario.fromMap(Mapa mapa) => ContaUsuario(
    id: lerCampo<String>(mapa, 'id'),
    nomeExibicao: lerCampo<String>(mapa, 'nomeExibicao'),
    email: lerCampo<String>(mapa, 'email'),
    idProvedor: lerCampo<String>(mapa, 'idProvedor'),
    situacao: lerEnum(mapa, 'situacao', SituacaoConta.values),
    ultimoAcessoEm: lerInstanteOpcional(mapa, 'ultimoAcessoEm'),
  );

  final String id;
  final String nomeExibicao;
  final String email;

  /// Identificador da conta no provedor (Google/Apple, OpenID Connect).
  final String idProvedor;
  final SituacaoConta situacao;

  /// Nulo até o primeiro acesso.
  final DateTime? ultimoAcessoEm;

  /// Só o que muda numa conta: a situação e o último acesso.
  ContaUsuario copyWith({SituacaoConta? situacao, DateTime? ultimoAcessoEm}) =>
      ContaUsuario(
        id: id,
        nomeExibicao: nomeExibicao,
        email: email,
        idProvedor: idProvedor,
        situacao: situacao ?? this.situacao,
        ultimoAcessoEm: ultimoAcessoEm ?? this.ultimoAcessoEm,
      );

  Mapa toMap() => {
    'id': id,
    'nomeExibicao': nomeExibicao,
    'email': email,
    'idProvedor': idProvedor,
    'situacao': situacao.name,
    'ultimoAcessoEm': escreverInstanteOpcional(ultimoAcessoEm),
  };

  @override
  bool operator ==(Object other) =>
      other is ContaUsuario &&
      other.id == id &&
      other.nomeExibicao == nomeExibicao &&
      other.email == email &&
      other.idProvedor == idProvedor &&
      other.situacao == situacao &&
      other.ultimoAcessoEm == ultimoAcessoEm;

  @override
  int get hashCode => Object.hash(
    id,
    nomeExibicao,
    email,
    idProvedor,
    situacao,
    ultimoAcessoEm,
  );

  @override
  String toString() => 'ContaUsuario${toMap()}';
}
