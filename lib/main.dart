import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'dados/memoria/memoria_demonstracao.dart';
import 'dados/persistente/composicao.dart';
import 'dados/terae_local/composicao_terae_local.dart';
import 'dados/terae_local/configuracao_terae_local.dart';
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
/// - `--dart-define=TERAE_FONTE=local`: a API do portal da família de um
///   Terae web que roda nesta máquina (`TERAE_LOCAL_URL`, padrão
///   `http://10.0.2.2:3000`), sem Firebase. A trava recusa qualquer endereço
///   que não seja local antes de montar qualquer coisa.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Trava na partida (26/11): TERAE_LOCAL_URL só aponta para esta máquina.
  final terae = ConfiguracaoTeraeLocal.doAmbiente();
  const relogio = RelogioSistema();
  if (terae.fonte == FonteDeDados.local) {
    // Decisão do dono de 26/11/2026: o Terae web LOCAL, nunca a produção.
    // O Firebase nem inicializa.
    final local = await montarTeraeLocal(configuracao: terae, relogio: relogio);
    final sessao = Sessao(aoSair: local.aoSair);
    // 401 fora da entrada: a sessão acabou no servidor; volta à TM01.
    local.contexto.aoSessaoAcabar = sessao.sair;
    runApp(
      TeraeApp(
        repositorios: local.repositorios,
        sessao: sessao,
        relogio: relogio,
      ),
    );
    return;
  }
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
