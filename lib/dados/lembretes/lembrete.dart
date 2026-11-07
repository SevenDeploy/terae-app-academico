import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';

/// Um lembrete agendado no próprio aparelho (evolução de TO, F2; D28).
///
/// Só título e texto genéricos: a notificação aparece na tela bloqueada e
/// nunca diz o nome do profissional, da atividade nem do paciente.
@immutable
class Lembrete {
  Lembrete({
    required this.id,
    required this.titulo,
    required this.texto,
    required DateTime quando,
  }) : quando = quando.toUtc();

  /// Estável entre um reagendamento e outro (o plugin troca pelo id).
  final int id;
  final String titulo;
  final String texto;
  final DateTime quando;

  @override
  bool operator ==(Object other) =>
      other is Lembrete &&
      other.id == id &&
      other.titulo == titulo &&
      other.texto == texto &&
      other.quando == quando;

  @override
  int get hashCode => Object.hash(id, titulo, texto, quando);

  @override
  String toString() => 'Lembrete($id, $quando, $texto)';
}

/// Horários que a TM19 oferece para o lembrete da véspera (escolher, não
/// digitar: RNFM02). A hora padrão está entre eles.
const List<int> horasDaVespera = [18, 19, 20, 21];

/// Horários que a TM19 oferece para o lembrete das atividades de casa. A hora
/// padrão está entre eles.
const List<int> horasDasAtividades = [8, 12, 18, 20];

/// O que a pessoa escolheu na TM19 (D28): guardado só no aparelho e apagado
/// no "Sair" (D20).
@immutable
class PreferenciasDeLembrete {
  const PreferenciasDeLembrete({
    this.vesperaDaSessao = false,
    this.horaDaVespera = 19,
    this.atividadesDeCasa = false,
    this.horaDasAtividades = 18,
  });

  /// Hora guardada que não está entre as oferecidas (versão antiga do app)
  /// volta à padrão, para a TM19 sempre mostrar uma marcada.
  factory PreferenciasDeLembrete.fromMap(Mapa mapa) {
    const padrao = PreferenciasDeLembrete();
    final vespera = lerCampo<int>(mapa, 'horaDaVespera');
    final atividades = lerCampo<int>(mapa, 'horaDasAtividades');
    return PreferenciasDeLembrete(
      vesperaDaSessao: lerCampo<bool>(mapa, 'vesperaDaSessao'),
      horaDaVespera: horasDaVespera.contains(vespera)
          ? vespera
          : padrao.horaDaVespera,
      atividadesDeCasa: lerCampo<bool>(mapa, 'atividadesDeCasa'),
      horaDasAtividades: horasDasAtividades.contains(atividades)
          ? atividades
          : padrao.horaDasAtividades,
    );
  }

  /// Avisar na véspera de cada sessão ou consulta, à [horaDaVespera].
  final bool vesperaDaSessao;
  final int horaDaVespera;

  /// Lembrar das atividades de casa todo dia, à [horaDasAtividades].
  final bool atividadesDeCasa;
  final int horaDasAtividades;

  bool get algumLigado => vesperaDaSessao || atividadesDeCasa;

  PreferenciasDeLembrete copyWith({
    bool? vesperaDaSessao,
    int? horaDaVespera,
    bool? atividadesDeCasa,
    int? horaDasAtividades,
  }) => PreferenciasDeLembrete(
    vesperaDaSessao: vesperaDaSessao ?? this.vesperaDaSessao,
    horaDaVespera: horaDaVespera ?? this.horaDaVespera,
    atividadesDeCasa: atividadesDeCasa ?? this.atividadesDeCasa,
    horaDasAtividades: horaDasAtividades ?? this.horaDasAtividades,
  );

  Mapa toMap() => {
    'vesperaDaSessao': vesperaDaSessao,
    'horaDaVespera': horaDaVespera,
    'atividadesDeCasa': atividadesDeCasa,
    'horaDasAtividades': horaDasAtividades,
  };

  @override
  bool operator ==(Object other) =>
      other is PreferenciasDeLembrete &&
      other.vesperaDaSessao == vesperaDaSessao &&
      other.horaDaVespera == horaDaVespera &&
      other.atividadesDeCasa == atividadesDeCasa &&
      other.horaDasAtividades == horaDasAtividades;

  @override
  int get hashCode => Object.hash(
    vesperaDaSessao,
    horaDaVespera,
    atividadesDeCasa,
    horaDasAtividades,
  );
}
