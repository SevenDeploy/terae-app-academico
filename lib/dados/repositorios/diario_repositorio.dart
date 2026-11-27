import 'package:flutter/foundation.dart';

import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';

/// Resultado do envio de um registro do diário (RFM05; TM04, TM05): o recibo
/// do portal (`ReciboDoDiarioNoPortal`: id, versão, instante, ajuda
/// imediata) com o registro inteiro.
@immutable
class ResultadoEnvio {
  const ResultadoEnvio({required this.registro, this.alerta});

  /// O registro com a situação final (`naFila` ou `enviado`).
  final RegistroDiario registro;

  /// Alerta criado pelo servidor (§7.1), só quando enviado.
  final Alerta? alerta;

  bool get enviado => registro.situacaoEnvio == SituacaoEnvio.enviado;

  /// A ajuda imediata diz "A equipe da clínica foi avisada" só quando isto é
  /// verdadeiro: envio confirmado e alerta criado (§19, §23; o
  /// `ajudaImediata` do recibo do portal). Na fila, mostra "envio pendente".
  bool get equipeAvisada => enviado && alerta != null;
}

/// Uma página da lista do diário (`PaginaDoDiarioNoPortal`): os registros que
/// chegaram ao servidor, do mais novo ao mais antigo, e se há mais antigos.
@immutable
class PaginaDoDiario {
  const PaginaDoDiario({required this.registros, required this.haMais});

  final List<RegistroDiario> registros;

  /// Liga o "Ver registros mais antigos".
  final bool haMais;
}

/// O diário da família (RFM03–RFM05; P3; quadros 18e e 18f; TM03–TM05,
/// TM13–TM15), com as operações da API do portal (`/portal/diario`).
///
/// O registro novo chega pronto do aparelho, com UUID próprio e `naFila`.
/// Sem conexão, fica na fila ("Guardar e enviar depois"); com conexão, vira
/// `enviado` e a regra do §7.1 é avaliada só depois da confirmação do
/// servidor (D18).
///
/// Corrigir e retirar (D17 revista) pedem a internet na hora, como no
/// portal: sem ela recusam `semConexao`, e nada muda no aparelho.
abstract interface class RepositorioDiario {
  /// Envia ou enfileira. Idempotente pelo `id`: reenviar o mesmo registro não
  /// duplica nem cria segundo alerta.
  Future<ResultadoEnvio> enviar(RegistroDiario registro);

  /// Tenta enviar a fila (`naFila` → `enviado`); devolve os que saíram dela.
  Future<List<ResultadoEnvio>> reenviarFila();

  /// TM03 — os registros que chegaram ao servidor (os retirados também, com
  /// o motivo), do mais novo ao mais antigo, [registrosPorPagina] por vez:
  /// sem [antes], os mais novos; com ele, os que chegaram antes desse
  /// instante (o da lista do último que a tela já tem).
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes});

  /// TM03 — "Guardados neste aparelho": os registros na fila, do mais antigo
  /// ao mais novo.
  Future<List<RegistroDiario>> pendentes(String pacienteId);

  /// TM14 — o registro pelo id, com as versões; recusa `registroInexistente`.
  Future<RegistroDiario> registro(String registroId);

  /// Alerta do registro, se o servidor criou um.
  Future<Alerta?> alertaDoRegistro(String registroId);

  /// TM15 — corrige o registro: a [entrada] vira a versão seguinte. Se a
  /// correção o tornar crítico (ou grave depois de grave) e ainda não houver
  /// alerta, o alerta nasce na confirmação. Recusa: `registroInexistente`,
  /// `registroNaoMudaMais` (o 409 do portal) e `semConexao`.
  Future<ResultadoEnvio> corrigir(String registroId, EntradaDoDiario entrada);

  /// Retira o registro com o [motivo] (nada é apagado). Devolve o registro
  /// retirado. Recusa: `registroInexistente`, `registroNaoMudaMais` e
  /// `semConexao`.
  Future<RegistroDiario> retirar(String registroId, RetiradaDoRegistro motivo);
}
