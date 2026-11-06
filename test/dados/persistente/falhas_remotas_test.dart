/// Falhas do Firebase → recusas simples (Atividade 4). Conferido no emulador
/// em 06/11: o bloqueio por muitas tentativas aparecia como "sem internet".
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/remoto/falhas_remotas.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';

FirebaseException _falha(String codigo) =>
    FirebaseException(plugin: 'teste', code: codigo);

void main() {
  test('cada código conhecido vira a recusa certa', () {
    expect(motivoDaFalha(_falha('unavailable')), MotivoRecusa.semConexao);
    expect(
      motivoDaFalha(_falha('network-request-failed')),
      MotivoRecusa.semConexao,
    );
    expect(
      motivoDaFalha(_falha('too-many-requests')),
      MotivoRecusa.muitasTentativas,
    );
    expect(
      motivoDaFalha(_falha('invalid-credential')),
      MotivoRecusa.credenciaisInvalidas,
    );
    expect(
      motivoDaFalha(_falha('email-already-in-use')),
      MotivoRecusa.emailJaCadastrado,
    );
    expect(
      motivoDaFalha(_falha('permission-denied')),
      MotivoRecusa.acessoNegado,
    );
  });

  test(
    'código desconhecido não vira recusa: a falha segue como está',
    () async {
      expect(motivoDaFalha(_falha('internal')), isNull);
      await expectLater(
        comPrazo<void>(() => Future.error(_falha('internal'))),
        throwsA(isA<FirebaseException>()),
      );
    },
  );

  test('passar do prazo vira semConexao (RNFM03)', () async {
    await expectLater(
      comPrazo<void>(
        () => Completer<void>().future,
        prazo: const Duration(milliseconds: 10),
      ),
      throwsA(
        isA<RecusaDeRegra>().having(
          (r) => r.motivo,
          'motivo',
          MotivoRecusa.semConexao,
        ),
      ),
    );
  });
}
