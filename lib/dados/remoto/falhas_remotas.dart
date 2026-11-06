/// Converte as falhas do Firebase nas recusas que as telas já sabem mostrar
/// (Atividade 4): rede caída ou lenta vira `semConexao` (RNFM03: ninguém
/// espera mais de 2 s), permissão negada vira `acessoNegado`.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../repositorios/falhas.dart';

/// Quanto uma chamada ao Firebase espera antes de desistir (RNFM03).
const Duration prazoDoServidor = Duration(seconds: 2);

/// Códigos do Firebase que significam "sem conexão com o servidor".
const Set<String> codigosDeRede = {
  'unavailable',
  'deadline-exceeded',
  'network-request-failed',
};

/// Roda [chamada] com [prazo] e traduz a falha em [RecusaDeRegra].
Future<T> comPrazo<T>(
  Future<T> Function() chamada, {
  Duration prazo = prazoDoServidor,
}) async {
  try {
    return await chamada().timeout(prazo);
  } on TimeoutException {
    throw const RecusaDeRegra(MotivoRecusa.semConexao);
  } on FirebaseException catch (e) {
    final motivo = motivoDaFalha(e);
    if (motivo == null) rethrow;
    throw RecusaDeRegra(motivo);
  }
}

/// O motivo simples de uma [FirebaseException] (inclusive a do
/// Authentication, que é subtipo dela); `null` para o que não é recusa
/// conhecida — aí a falha segue como está e a tela mostra a mensagem de
/// falha inesperada, sem esconder o defeito.
MotivoRecusa? motivoDaFalha(FirebaseException e) => switch (e.code) {
  final c when codigosDeRede.contains(c) => MotivoRecusa.semConexao,
  'permission-denied' => MotivoRecusa.acessoNegado,
  'not-found' => MotivoRecusa.acessoNegado,
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-login-credentials' => MotivoRecusa.credenciaisInvalidas,
  'user-disabled' => MotivoRecusa.contaInativa,
  'email-already-in-use' => MotivoRecusa.emailJaCadastrado,
  'invalid-email' => MotivoRecusa.emailInvalido,
  'weak-password' => MotivoRecusa.senhaFraca,
  'too-many-requests' => MotivoRecusa.muitasTentativas,
  _ => null,
};

/// A recusa é falta de conexão (o diário deixa na fila; a leitura cai na
/// cópia local)?
bool ehSemConexao(Object erro) =>
    erro is RecusaDeRegra && erro.motivo == MotivoRecusa.semConexao;
