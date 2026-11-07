import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/resposta_presenca.dart';
import '../modelos/agendamento.dart';
import '../modelos/alerta.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';

/// O que o cuidador sabe de um alerta: só data, hora e ciência do
/// profissional — nunca a regra nem o registro (RNFM05; §20 TM12).
@immutable
class AvisoDeAlerta {
  AvisoDeAlerta({required DateTime emitidoEm, DateTime? cienteEm})
    : emitidoEm = emitidoEm.toUtc(),
      cienteEm = cienteEm?.toUtc();

  /// Projeção do [alerta] para o aparelho do cuidador.
  factory AvisoDeAlerta.doAlerta(Alerta alerta) =>
      AvisoDeAlerta(emitidoEm: alerta.emitidoEm, cienteEm: alerta.cienteEm);

  final DateTime emitidoEm;
  final DateTime? cienteEm;

  Mapa toMap() => {
    'emitidoEm': escreverInstante(emitidoEm),
    'cienteEm': escreverInstanteOpcional(cienteEm),
  };

  @override
  bool operator ==(Object other) =>
      other is AvisoDeAlerta &&
      other.emitidoEm == emitidoEm &&
      other.cienteEm == cienteEm;

  @override
  int get hashCode => Object.hash(emitidoEm, cienteEm);
}

/// Visão do cuidador (RFM08; TM08, TM11, TM12): somente leitura de agenda,
/// medicação e avisos, para quem tem VinculoCuidador ativo com o paciente.
///
/// RNFM05 na camada de dados: tudo sai já como cópia do cuidador — Paciente
/// sem CPF nem nascimento (`paraCuidador`), Agendamento sem motivo do retorno
/// (`paraCuidador`), receita sem orientação nem prescritor (`paraCuidador`),
/// alerta como [AvisoDeAlerta]. Sem vínculo ativo entre
/// [contaCuidadorId] e [pacienteId], recusa com `acessoNegado`. Não existe
/// método que devolva registro do diário, marco da jornada nem consentimento.
abstract interface class RepositorioVisaoCuidador {
  Future<Paciente> pacienteAcompanhado({
    required String contaCuidadorId,
    required String pacienteId,
  });

  /// Consultas de hoje em diante, agendadas e canceladas, por `dataHora`.
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  });

  /// Nome, registro e especialidade do profissional da consulta (TM12).
  Future<ProfissionalSaude> profissional(String profissionalId);

  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  });

  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  });

  /// Alertas enviados à equipe, os mais recentes primeiro.
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  });

  /// F2, D29 — a resposta de presença dada pela família, por id do
  /// agendamento (só as já confirmadas pelo servidor). Não traz quem
  /// respondeu nem quando: só "vamos" ou "não vamos conseguir".
  Future<Map<String, RespostaPresenca>> respostasDePresenca({
    required String contaCuidadorId,
    required String pacienteId,
  });
}
