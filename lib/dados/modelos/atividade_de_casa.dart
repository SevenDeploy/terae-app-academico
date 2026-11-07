import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/ocupacao.dart';

/// Uma atividade de casa combinada na terapia ocupacional (evolução de TO, F1;
/// inspirada na `OrientacaoDomiciliar` do Terae web): o que fazer, com as
/// palavras da terapeuta, e quantas vezes por semana.
///
/// No aplicativo é somente leitura: só a clínica publica e encerra (a semente
/// faz o papel dela). Encerrar preenche [encerradaEm] e não apaga (§23).
@immutable
class AtividadeDeCasa {
  AtividadeDeCasa({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.titulo,
    required this.texto,
    required this.vezesPorSemana,
    required this.ocupacao,
    required DateTime publicadaEm,
    DateTime? encerradaEm,
  }) : publicadaEm = publicadaEm.toUtc(),
       encerradaEm = encerradaEm?.toUtc() {
    if (titulo.trim().isEmpty || titulo.length > tamanhoMaximoDoTitulo) {
      throw ArgumentError.value(titulo, 'titulo', 'vazio ou longo demais');
    }
    if (texto.length > tamanhoMaximoDoTexto) {
      throw ArgumentError.value(texto.length, 'texto', 'longo demais');
    }
    if (vezesPorSemana < 1 || vezesPorSemana > 7) {
      throw ArgumentError.value(vezesPorSemana, 'vezesPorSemana', '1 a 7');
    }
  }

  factory AtividadeDeCasa.fromMap(Mapa mapa) => AtividadeDeCasa(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    profissionalId: lerCampo<String>(mapa, 'profissionalId'),
    titulo: lerCampo<String>(mapa, 'titulo'),
    texto: lerCampo<String>(mapa, 'texto'),
    vezesPorSemana: lerCampo<int>(mapa, 'vezesPorSemana'),
    ocupacao: lerEnum(mapa, 'ocupacao', Ocupacao.values),
    publicadaEm: lerInstante(mapa, 'publicadaEm'),
    encerradaEm: lerInstanteOpcional(mapa, 'encerradaEm'),
  );

  /// Como no programa em casa do Terae web.
  static const int tamanhoMaximoDoTitulo = 120;
  static const int tamanhoMaximoDoTexto = 1500;

  final String id;
  final String pacienteId;

  /// Quem combinou (a terapeuta ou o terapeuta ocupacional).
  final String profissionalId;
  final String titulo;

  /// O que fazer, nas palavras da terapeuta, para a família ler.
  final String texto;

  /// De 1 a 7.
  final int vezesPorSemana;
  final Ocupacao ocupacao;
  final DateTime publicadaEm;

  /// Nula enquanto vale.
  final DateTime? encerradaEm;

  /// Vale no [dia] civil da clínica: publicada até esse dia e não encerrada
  /// antes dele.
  bool vigenteEm(DataCivil dia) =>
      !DataCivil.doInstante(publicadaEm).ehDepoisDe(dia) &&
      (encerradaEm == null ||
          DataCivil.doInstante(encerradaEm!).ehDepoisDe(dia));

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'profissionalId': profissionalId,
    'titulo': titulo,
    'texto': texto,
    'vezesPorSemana': vezesPorSemana,
    'ocupacao': ocupacao.name,
    'publicadaEm': escreverInstante(publicadaEm),
    'encerradaEm': escreverInstanteOpcional(encerradaEm),
  };

  @override
  bool operator ==(Object other) =>
      other is AtividadeDeCasa &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.profissionalId == profissionalId &&
      other.titulo == titulo &&
      other.texto == texto &&
      other.vezesPorSemana == vezesPorSemana &&
      other.ocupacao == ocupacao &&
      other.publicadaEm == publicadaEm &&
      other.encerradaEm == encerradaEm;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    profissionalId,
    titulo,
    texto,
    vezesPorSemana,
    ocupacao,
    publicadaEm,
    encerradaEm,
  );

  @override
  String toString() => 'AtividadeDeCasa${toMap()}';
}
