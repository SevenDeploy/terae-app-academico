import 'package:flutter/foundation.dart';

import '../enums/intensidade.dart';
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
/// na fila; com conexão, vira `enviado` e as duas regras do §7.1 são
/// avaliadas sobre a sequência completa — só depois da confirmação do
/// servidor (D18).
///
/// Atividade 4 — CRUD do item principal (D13, D17): além de cadastrar
/// ([enviar]), consultar ([registros], [buscar], [registro]), corrigir
/// ([atualizar]) e excluir ([excluir], lógico) no mesmo dia. Correção e
/// exclusão seguem a mesma fila do envio.
abstract interface class RepositorioDiario {
  /// Envia ou enfileira. Idempotente pelo `id`: reenviar o mesmo registro não
  /// duplica nem cria segundo alerta.
  Future<ResultadoEnvio> enviar(RegistroDiario registro);

  /// Tenta enviar a fila (`naFila` → `enviado`); devolve os que saíram dela.
  Future<List<ResultadoEnvio>> reenviarFila();

  /// Registros do paciente que valem (sem os excluídos), do mais recente
  /// para o mais antigo, incluindo os que ainda estão na fila.
  Future<List<RegistroDiario>> registros(String pacienteId);

  /// TM13 — os [registros] que passam no filtro: [texto] no sintoma ou na
  /// observação (sem acento nem maiúscula) e intensidade em [intensidades]
  /// (vazio = todas).
  Future<List<RegistroDiario>> buscar(
    String pacienteId, {
    String texto = '',
    Set<Intensidade> intensidades = const {},
  });

  /// TM14 — o registro pelo id, mesmo excluído; recusa `registroInexistente`.
  Future<RegistroDiario> registro(String registroId);

  /// Alerta do registro, se o servidor criou um.
  Future<Alerta?> alertaDoRegistro(String registroId);

  /// D17 — corrige um registro do mesmo dia (feito com
  /// `RegistroDiario.corrigido`). Vai para a fila e é enviado como no
  /// [enviar]; se a correção o tornar crítico ou grave consecutivo e ainda
  /// não houver alerta, o alerta nasce na confirmação. Um alerta já emitido
  /// nunca some. Recusa: `registroInexistente`, `edicaoEncerrada`.
  Future<ResultadoEnvio> atualizar(RegistroDiario corrigido);

  /// D17 — exclusão lógica (`excluidoEm`) de um registro do mesmo dia; segue
  /// a fila como o [enviar]. Devolve o registro excluído. Recusa:
  /// `registroInexistente`, `edicaoEncerrada`.
  Future<RegistroDiario> excluir(String registroId);
}
