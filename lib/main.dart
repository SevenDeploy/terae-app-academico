import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'dados/memoria/memoria_demonstracao.dart';
import 'dados/persistente/composicao.dart';
import 'firebase_options.dart';
import 'nucleo/sessao/sessao.dart';
import 'nucleo/tempo/relogio.dart';

/// Entrada: monta os repositórios, reabre a sessão guardada e inicia o
/// [TeraeApp] (§24). Único ponto que conhece a implementação dos contratos
/// (§22: trocar a fonte de dados não muda nenhuma tela).
///
/// - Android/iOS com o Firebase configurado (Atividade 4): SQLite +
///   SharedPreferences + Firebase (D12, D16). A sessão do Firebase sobrevive
///   ao fechar o app; o perfil ativo vem das preferências.
/// - Web, ou sem `firebase_options.dart` configurado: a memória de
///   demonstração, como na Atividade 3 (D19).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const relogio = RelogioSistema();
  final opcoes = _opcoesDoFirebase();
  if (opcoes == null) {
    final memoria = await MemoriaDemonstracao.carregar(relogio: relogio);
    runApp(
      TeraeApp(
        repositorios: memoria.repositorios,
        // D20/D28 — na demonstração também: a persona seguinte não herda os
        // lembretes da anterior.
        sessao: Sessao(aoSair: memoria.repositorios.lembretes.cancelarTudo),
        relogio: relogio,
      ),
    );
    return;
  }

  await Firebase.initializeApp(options: opcoes);
  // D16 — o SQLite é a cópia local; sem um segundo cache do Firestore.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  final persistencia = await montarPersistencia(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    relogio: relogio,
  );
  final repositorios = persistencia.repositorios;
  final sessao = Sessao(
    aoMudarPerfil: persistencia.preferencias.guardarPerfil,
    // D20 — "Sair" encerra a conta e, desde a F2 (D28), cancela os lembretes.
    aoSair: () async {
      await repositorios.autenticacao.sair();
      await repositorios.lembretes.cancelarTudo();
    },
  );
  final perfilGuardado = persistencia.preferencias.perfilAtivo;
  final guardada = await repositorios.autenticacao.sessaoGuardada();
  if (guardada != null) {
    sessao.entrar(guardada, perfilGuardado: perfilGuardado);
  }
  await persistencia.sincronizador.iniciar();
  runApp(
    TeraeApp(repositorios: repositorios, sessao: sessao, relogio: relogio),
  );
}

/// As opções do Firebase desta plataforma, ou `null` na web e enquanto o
/// `flutterfire configure` não gerou o `firebase_options.dart` de verdade.
FirebaseOptions? _opcoesDoFirebase() {
  if (kIsWeb) return null;
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    return null;
  }
}
