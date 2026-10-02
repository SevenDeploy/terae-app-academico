import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/tipo_convite.dart';

/// Código de uso único, com validade e preso a um CPF, que liga uma conta a um
/// registro que já existe (RFM09; TM07, TM09, TM10).
///
/// Regras (§23): [usadoEm] preenchido encerra o código; convite expirado não
/// ativa nada; o CPF informado no cadastro tem de coincidir com
/// [cpfConvidado]; no tipo cuidador, o vínculo ainda tem de estar pendente.
@immutable
class ConviteAcesso {
  ConviteAcesso({
    required this.id,
    required this.pacienteId,
    required this.codigo,
    required this.tipo,
    required this.cpfConvidado,
    required DateTime expiraEm,
    DateTime? usadoEm,
  }) : expiraEm = expiraEm.toUtc(),
       usadoEm = usadoEm?.toUtc();

  factory ConviteAcesso.fromMap(Mapa mapa) => ConviteAcesso(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    codigo: lerCampo<String>(mapa, 'codigo'),
    tipo: lerEnum(mapa, 'tipo', TipoConvite.values),
    cpfConvidado: lerCampo<String>(mapa, 'cpfConvidado'),
    expiraEm: lerInstante(mapa, 'expiraEm'),
    usadoEm: lerInstanteOpcional(mapa, 'usadoEm'),
  );

  final String id;
  final String pacienteId;

  /// Seis caracteres, único (TM09 e TM10, passo 1).
  final String codigo;
  final TipoConvite tipo;

  /// Só os 11 dígitos: o do paciente (tipo paciente) ou o do cuidador
  /// informado pelo paciente na TM07 (tipo cuidador).
  final String cpfConvidado;
  final DateTime expiraEm;

  /// Nulo até o uso; preenchido, o código não vale mais.
  final DateTime? usadoEm;

  /// Só o uso muda um convite.
  ConviteAcesso copyWith({DateTime? usadoEm}) => ConviteAcesso(
    id: id,
    pacienteId: pacienteId,
    codigo: codigo,
    tipo: tipo,
    cpfConvidado: cpfConvidado,
    expiraEm: expiraEm,
    usadoEm: usadoEm ?? this.usadoEm,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'codigo': codigo,
    'tipo': tipo.name,
    'cpfConvidado': cpfConvidado,
    'expiraEm': escreverInstante(expiraEm),
    'usadoEm': escreverInstanteOpcional(usadoEm),
  };

  @override
  bool operator ==(Object other) =>
      other is ConviteAcesso &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.codigo == codigo &&
      other.tipo == tipo &&
      other.cpfConvidado == cpfConvidado &&
      other.expiraEm == expiraEm &&
      other.usadoEm == usadoEm;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    codigo,
    tipo,
    cpfConvidado,
    expiraEm,
    usadoEm,
  );

  @override
  String toString() => 'ConviteAcesso${toMap()}';
}
