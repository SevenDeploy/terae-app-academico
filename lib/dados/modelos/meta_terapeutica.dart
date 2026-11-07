import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/ocupacao.dart';
import '../enums/situacao_meta.dart';

/// Uma meta do plano de terapia ocupacional (evolução de TO, F3; D25, D35),
/// como o Terae web mostra à família: o que se quer alcançar, na língua da
/// família, em que área da vida, até quando, com quem foi combinada e em que
/// pé está.
///
/// O que a família nunca vê (D25): escore, nível GAS, peso ou interpretação.
/// O modelo nem tem esses campos, e o que mais vier no documento é ignorado.
/// No aplicativo é somente leitura: só a clínica cria e muda (a semente faz o
/// papel dela). Nada é apagado (§23): a meta que sai de cena fica como
/// interrompida ou substituída.
@immutable
class MetaTerapeutica {
  MetaTerapeutica({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.ocupacao,
    required this.descricao,
    required this.combinadaCom,
    required this.prazo,
    required this.situacao,
  }) {
    if (descricao.trim().isEmpty ||
        descricao.length > tamanhoMaximoDaDescricao) {
      throw ArgumentError.value(
        descricao,
        'descricao',
        'vazia ou longa demais',
      );
    }
    if (combinadaCom.trim().isEmpty ||
        combinadaCom.length > tamanhoMaximoDeCombinadaCom) {
      throw ArgumentError.value(
        combinadaCom,
        'combinadaCom',
        'vazio ou longo demais',
      );
    }
  }

  factory MetaTerapeutica.fromMap(Mapa mapa) => MetaTerapeutica(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    profissionalId: lerCampo<String>(mapa, 'profissionalId'),
    ocupacao: lerEnum(mapa, 'ocupacao', Ocupacao.values),
    descricao: lerCampo<String>(mapa, 'descricao'),
    combinadaCom: lerCampo<String>(mapa, 'combinadaCom'),
    prazo: lerDataCivil(mapa, 'prazo'),
    situacao: lerEnum(mapa, 'situacao', SituacaoMeta.values),
  );

  static const int tamanhoMaximoDaDescricao = 200;
  static const int tamanhoMaximoDeCombinadaCom = 120;

  final String id;
  final String pacienteId;

  /// Quem acompanha a meta (a terapeuta ou o terapeuta ocupacional).
  final String profissionalId;

  /// A área da vida (OTPF-4 simplificado, como nas atividades de casa).
  final Ocupacao ocupacao;

  /// Na língua da família ("Vestir a camiseta sozinho").
  final String descricao;

  /// Com quem da família foi combinada ("Patrícia e Miguel").
  final String combinadaCom;

  /// Até quando foi combinada (dia civil da clínica).
  final DataCivil prazo;
  final SituacaoMeta situacao;

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'profissionalId': profissionalId,
    'ocupacao': ocupacao.name,
    'descricao': descricao,
    'combinadaCom': combinadaCom,
    'prazo': prazo.paraIso(),
    'situacao': situacao.name,
  };

  @override
  bool operator ==(Object other) =>
      other is MetaTerapeutica &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.profissionalId == profissionalId &&
      other.ocupacao == ocupacao &&
      other.descricao == descricao &&
      other.combinadaCom == combinadaCom &&
      other.prazo == prazo &&
      other.situacao == situacao;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    profissionalId,
    ocupacao,
    descricao,
    combinadaCom,
    prazo,
    situacao,
  );

  @override
  String toString() => 'MetaTerapeutica${toMap()}';
}
