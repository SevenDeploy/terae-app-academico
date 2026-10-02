import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/tipo_marco.dart';

/// Projeção da jornada montada pelo servidor em linguagem simples (RF02,
/// RNF06; TM06): reavaliações, orientações e próximos passos que não estão em
/// Agendamento nem em Receita. Existe para que queixa, hipótese e conduta da
/// evolução clínica nunca cheguem ao celular.
@immutable
class MarcoJornada {
  const MarcoJornada({
    required this.id,
    required this.pacienteId,
    required this.tipo,
    required this.data,
    required this.titulo,
    required this.textoSimples,
  });

  factory MarcoJornada.fromMap(Mapa mapa) => MarcoJornada(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    tipo: lerEnum(mapa, 'tipo', TipoMarco.values),
    data: lerDataCivil(mapa, 'data'),
    titulo: lerCampo<String>(mapa, 'titulo'),
    textoSimples: lerCampo<String>(mapa, 'textoSimples'),
  );

  final String id;
  final String pacienteId;
  final TipoMarco tipo;

  /// Dia do marco (passado ou futuro).
  final DataCivil data;
  final String titulo;
  final String textoSimples;

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'tipo': tipo.name,
    'data': data.paraIso(),
    'titulo': titulo,
    'textoSimples': textoSimples,
  };

  @override
  bool operator ==(Object other) =>
      other is MarcoJornada &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.tipo == tipo &&
      other.data == data &&
      other.titulo == titulo &&
      other.textoSimples == textoSimples;

  @override
  int get hashCode =>
      Object.hash(id, pacienteId, tipo, data, titulo, textoSimples);

  @override
  String toString() => 'MarcoJornada${toMap()}';
}
