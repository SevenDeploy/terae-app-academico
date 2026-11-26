# Terae — app do paciente (projeto acadêmico)

> **Projeto acadêmico — UNEMAT 2026, disciplina Desenvolvimento de Sistemas para Dispositivos Móveis.**
>
> Este app Flutter mostra, de outro jeito, o app do paciente do Terae. **Ele não é o app do Terae em produção**: o Terae
> é um SaaS web, e o canal do paciente no produto é um PWA. Este app usa só dados fictícios e só se conecta ao Firebase
> acadêmico `terae-app-academico`. Ele não é publicado em loja. Sem o Firebase configurado, e sempre na web, ele roda
> com os dados de demonstração na memória.

**Equipe:** Izabely Kamila Martins Barbosa, Lucas da Silva Gonçalves, Willian dos Santos Lira e Walyson dos Santos
Medeiros.

**Versão 5.0 (Atividade 5):** MVP final, testes e defesa técnica. O documento consolidado, em PDF, é entregue à parte.

## O que o app faz

O app acompanha a família entre as sessões de terapia ocupacional e as consultas.

| Área | Telas | Resumo |
|---|---|---|
| Autenticação | TM00, TM01, TM09, TM10 | entrar com e-mail e senha; primeiro acesso por código de convite em 4 passos, com consentimento; "Sair" apaga os dados do aparelho |
| Diário (CRUD) | TM03, TM13–TM15 | registrar, listar e buscar, corrigir e excluir (exclusão lógica, só no mesmo dia); intensidade crítica leva à ajuda imediata (CVV 188 / SAMU 192) e avisa o profissional |
| Em casa (TO) | TM16, TM17 | atividades combinadas com a terapeuta, com registro do dia |
| Sessões e lembretes | TM18, TM19 | próximas sessões com "Você vai?" e lembretes locais |
| Jornada e metas | TM06, TM20 | linha do tempo, marcos e metas combinadas, sem escore |
| Cuidador | TM07, TM08, TM11, TM12 | convite de até 2 cuidadores, que veem agenda, medicação e avisos, sem conteúdo clínico |

## Arquitetura

O app tem quatro camadas:

- **Interface:** telas (`*_tela.dart`) com controladores `ChangeNotifier`, ligados pelo `provider`. A navegação usa o
  `go_router`, com uma guarda de perfil.
- **Repositórios:** contratos em `lib/dados/repositorios/`, com duas implementações. A **memória** atende a web e os
  testes; a **persistente** junta o Firebase e o SQLite.
- **Local:** SQLite (`sqflite`) é a fonte local da verdade, e é nele que fica a fila de envio. O SharedPreferences
  guarda as preferências.
- **Remoto:** Firebase Authentication e Cloud Firestore, protegidos pelas `firestore.rules`. O `Sincronizador` envia a
  fila quando a conexão volta.

As pastas são estas:
- `lib/nucleo/`: tema, rotas, sessão, relógio e widgets comuns;
- `lib/dados/`: modelos, enums, regras, memória, local, remoto, persistente e sincronização;
- `lib/funcionalidades/`: as telas, separadas por perfil.

## Instalação e execução

Pré-requisitos:
- Flutter 3.47 ou mais novo, com Dart 3.13.5 ou mais novo (o `pubspec.lock` exige isso);
- Android SDK, com um emulador ou um aparelho Android 8 ou mais novo;
- Node 20 ou mais novo, só para a semente do Firebase.

```powershell
git clone https://github.com/SevenDeploy/terae-app-academico.git
cd terae-app-academico
flutter pub get
flutter run              # emulador ou aparelho conectado
```

Para gerar o APK:

```powershell
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

Os arquivos `lib/firebase_options.dart` e `android/app/google-services.json` têm só identificadores públicos do
projeto Firebase acadêmico. A proteção dos dados está nas `firestore.rules`.

> **Windows:** compile numa pasta **fora do OneDrive** e com caminho **sem acento**. O Gradle falha nos dois casos.

### Firebase próprio (opcional)

Para apontar o app para outro projeto Firebase:

1. Crie o projeto e ative o provedor "E-mail/senha" em Authentication.
2. Rode `flutterfire configure --project=<projeto> --platforms=android`.
3. Publique as regras com `firebase deploy --only firestore:rules`.
4. Copie o `.env.exemplo` para `.env` e preencha o caminho da chave da conta de serviço e a senha das contas de
   demonstração. O `.env` nunca vai para o git.
5. Rode a semente:
   ```powershell
   cd ferramentas; npm install; cd ..
   node ferramentas/semear-firebase.mjs --reiniciar
   ```
   Para conferir o que está no servidor, rode `node ferramentas/conferir-firebase.mjs [pacienteId]`.

### Contas da demonstração (dados fictícios)

Para entrar, use o e-mail da persona com a senha de demonstração:
- **No modo memória:** a constante `senhaDeDemonstracao`, em `lib/dados/memoria/estado_memoria.dart`.
- **No Firebase acadêmico:** a senha combinada com a equipe, que fica fora do git.

| Persona | E-mail | O que mostra |
|---|---|---|
| Ana Lúcia Martins (16, titular) | `ana.lucia.martins@exemplo.test` | psiquiatria e TO; diário com a ajuda imediata, Em casa, Jornada, cuidadores |
| Patrícia Andrade Neves (mãe) | `patricia.neves@exemplo.test` | dois perfis (Miguel, 7, e Laura, 4, só TO), com seleção de perfil |
| Antônio Carlos Ribeiro (71, titular) | `antonio.ribeiro@exemplo.test` | TO depois de um AVC: Em casa, sessões com "Você vai?", lembretes e metas |
| Regina Martins (cuidadora da Ana) | `regina.martins@exemplo.test` | visão do cuidador, sem conteúdo clínico |

Primeiro acesso, pela tela inicial:

| Caso | Código | CPF (fictício) | Nascimento |
|---|---|---|---|
| Paciente João Pedro Assis | `K7M4QX` | 583.049.216-42 | 19/07/1999 |
| Cuidador Paulo Martins | `P4X9RC` | 847.120.563-71 | — |
| Recusas de propósito | `H3T9WB` (expirado), `R2D8NZ` e `G8B5VA` (usados) | — | — |

No modo depuração, o ícone de ajustes da tela inicial abre o painel da demonstração. Ele tem "sem conexão", para ver
o registro ficar na fila, e "reiniciar dados".

## Testes

```powershell
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test                                              # 733 testes (unidade, widget, acessibilidade, capturas)
flutter test integration_test/jornada_principal_test.dart # precisa de emulador ou aparelho
```

- Os casos de teste funcionais da Atividade 5, rodados no emulador com o Firebase real, estão em
  [`docs/casos-de-teste-a5.md`](docs/casos-de-teste-a5.md). As evidências estão em
  [`docs/evidencias-a5/`](docs/evidencias-a5/).
- As decisões (D1–D37), as limitações e o histórico das fases estão em [`docs/estado.md`](docs/estado.md).
- Os contratos internos estão em [`docs/contratos.md`](docs/contratos.md), e as capturas das telas em
  [`docs/capturas/`](docs/capturas/).

## Limitações conhecidas

- "Sair" apaga do aparelho também o que ainda estava na fila de envio, sem avisar antes.
- As regras do Firestore de metas, atividades de casa e confirmações não têm teste automático, porque o projeto não
  usa o emulador de regras. Elas foram provadas nos roteiros no emulador.
- O SQLite não é cifrado.
- O Firestore ficou na região `nam5`. Os dados são fictícios.
- Dois aparelhos que registrarem a mesma atividade no mesmo dia ficam com o registro mais recente (D31).
- O app não foi testado no iOS.
