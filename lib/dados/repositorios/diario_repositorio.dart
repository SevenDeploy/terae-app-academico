import 'package:flutter/foundation.dart';

import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';

/// Resultado do envio de um registro do diário (RFM05; TM04, TM05).
@immutable
class ResultadoEnvio {
  const ResultadoEnvio({required this.registro, this.alerta});

  /// O registro com a situação final (`naFila` ou `enviado`).
  final RegistroDiario registro;

  /// Alerta criado pelo servidor (§7.1), só quando enviado.
  final Alerta? alerta;

  bool get enviado => registro.situacaoEnvio == SituacaoEnvio.enviado;

  /// A TM05 só diz "seu profissional foi avisado" quando isto é verdadeiro:
  /// envio confirmado e alerta criado (§19, §23). Na fila, mostra "envio
  /// pendente".
  bool get equipeAvisada => enviado && alerta != null;
}

/// Diário entre consultas (RFM03, RFM04, RFM05; TM03, TM04, TM05).
///
/// O registro chega pronto do aparelho, com UUID próprio e `naFila`. A
/// implementação decide o resto como o servidor decidiria: sem conexão, fica
/// na fila; com conexão, vira `enviado` e o servidor avalia as duas regras do
/// §7.1 sobre a sequência completa. O aparelho nunca cria Alerta.
abstract interface class RepositorioDiario {
  /// Envia ou enfileira. Idempotente pelo `id`: reenviar o mesmo registro não
  /// duplica nem cria segundo alerta.
  Future<ResultadoEnvio> enviar(RegistroDiario registro);

  /// Tenta enviar a fila (`naFila` → `enviado`); devolve os que saíram dela.
  Future<List<ResultadoEnvio>> reenviarFila();

  /// Registros do paciente, do mais recente para o mais antigo.
  Future<List<RegistroDiario>> registros(String pacienteId);

  /// Alerta do registro, se o servidor criou um.
  Future<Alerta?> alertaDoRegistro(String registroId);
}
