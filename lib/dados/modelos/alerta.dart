import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/regra_alerta.dart';

/// Aviso à equipe, criado pelo servidor por regra determinística (§7.1) e
/// endereçado ao profissional de referência; o aplicativo não decide alerta
/// (RF14; TM05, TM12).
///
/// O cuidador não recebe esta classe: recebe só data, hora e ciência
/// (`AvisoDeAlerta`, RNFM05).
@immutable
class Alerta {
  Alerta({
    required this.id,
    required this.registroId,
    required this.regraDisparada,
    required DateTime emitidoEm,
    DateTime? cienteEm,
  }) : emitidoEm = emitidoEm.toUtc(),
       cienteEm = cienteEm?.toUtc();

  factory Alerta.fromMap(Mapa mapa) => Alerta(
    id: lerCampo<String>(mapa, 'id'),
    registroId: lerCampo<String>(mapa, 'registroId'),
    regraDisparada: lerEnum(mapa, 'regraDisparada', RegraAlerta.values),
    emitidoEm: lerInstante(mapa, 'emitidoEm'),
    cienteEm: lerInstanteOpcional(mapa, 'cienteEm'),
  );

  final String id;

  /// RegistroDiario que disparou o alerta (zero ou um alerta por registro).
  final String registroId;
  final RegraAlerta regraDisparada;
  final DateTime emitidoEm;

  /// Quando o profissional tomou ciência; nulo até lá.
  final DateTime? cienteEm;

  /// Só a ciência do profissional muda um alerta.
  Alerta copyWith({DateTime? cienteEm}) => Alerta(
    id: id,
    registroId: registroId,
    regraDisparada: regraDisparada,
    emitidoEm: emitidoEm,
    cienteEm: cienteEm ?? this.cienteEm,
  );

  Mapa toMap() => {
    'id': id,
    'registroId': registroId,
    'regraDisparada': regraDisparada.name,
    'emitidoEm': escreverInstante(emitidoEm),
    'cienteEm': escreverInstanteOpcional(cienteEm),
  };

  @override
  bool operator ==(Object other) =>
      other is Alerta &&
      other.id == id &&
      other.registroId == registroId &&
      other.regraDisparada == regraDisparada &&
      other.emitidoEm == emitidoEm &&
      other.cienteEm == cienteEm;

  @override
  int get hashCode =>
      Object.hash(id, registroId, regraDisparada, emitidoEm, cienteEm);

  @override
  String toString() => 'Alerta${toMap()}';
}
