import 'package:flutter/foundation.dart';

import 'relogio.dart';

/// Dia do calendário, sem hora nem fuso: data de nascimento, vigência e
/// renovação da receita, data do marco da jornada.
///
/// Existe para que uma data "pura" nunca seja formatada como instante — um
/// `DateTime.utc(2010, 3, 14)` exibido no fuso da clínica viraria 13/03. No
/// mapa é `AAAA-MM-DD`.
@immutable
class DataCivil implements Comparable<DataCivil> {
  /// Lança [ArgumentError] se o dia não existir (ex.: 30/02).
  DataCivil(this.ano, this.mes, this.dia) {
    final utc = DateTime.utc(ano, mes, dia);
    if (utc.year != ano || utc.month != mes || utc.day != dia) {
      throw ArgumentError('Data inexistente: $ano-$mes-$dia');
    }
  }

  /// Lê `AAAA-MM-DD`; lança [FormatException] em qualquer outro formato.
  factory DataCivil.parse(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (m == null) {
      throw FormatException('Data civil fora do formato AAAA-MM-DD', iso);
    }
    try {
      return DataCivil(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    } on ArgumentError {
      throw FormatException('Data civil inexistente', iso);
    }
  }

  /// Dia civil do [instante] no horário da clínica: 01:30Z de 2/10 ainda é
  /// 1/10 em Cuiabá.
  factory DataCivil.doInstante(DateTime instante) {
    final c = naClinica(instante);
    return DataCivil(c.year, c.month, c.day);
  }

  /// Hoje, no horário da clínica.
  factory DataCivil.hoje(Relogio relogio) =>
      DataCivil.doInstante(relogio.agora());

  final int ano;
  final int mes;
  final int dia;

  DateTime get _utc => DateTime.utc(ano, mes, dia);

  /// `DateTime.monday` (1) … `DateTime.sunday` (7).
  int get diaDaSemana => _utc.weekday;

  /// Instante (UTC) da meia-noite deste dia na clínica.
  DateTime get inicioNaClinica => _utc.subtract(deslocamentoClinica);

  DataCivil somarDias(int dias) {
    final d = _utc.add(Duration(days: dias));
    return DataCivil(d.year, d.month, d.day);
  }

  /// Dias de `this` até [outra] (negativo se [outra] vem antes).
  int diasAte(DataCivil outra) => outra._utc.difference(_utc).inDays;

  bool ehAntesDe(DataCivil outra) => compareTo(outra) < 0;

  bool ehDepoisDe(DataCivil outra) => compareTo(outra) > 0;

  /// `AAAA-MM-DD`.
  String paraIso() =>
      '${ano.toString().padLeft(4, '0')}-'
      '${mes.toString().padLeft(2, '0')}-'
      '${dia.toString().padLeft(2, '0')}';

  @override
  int compareTo(DataCivil outra) => _utc.compareTo(outra._utc);

  @override
  bool operator ==(Object other) =>
      other is DataCivil &&
      other.ano == ano &&
      other.mes == mes &&
      other.dia == dia;

  @override
  int get hashCode => Object.hash(ano, mes, dia);

  @override
  String toString() => paraIso();
}
