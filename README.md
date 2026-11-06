# Terae — app do paciente (projeto acadêmico)

> **Projeto acadêmico — UNEMAT 2026, disciplina Dispositivos Móveis.** Este aplicativo Flutter é uma forma de ver,
> de outro jeito, o app do paciente do Terae. **Não é o app do Terae produção**: o Terae produção é um SaaS web, e o
> canal dos pacientes no produto é um PWA publicado na Play Store. Este app usa só dados fictícios de demonstração,
> conecta-se só ao Firebase acadêmico `terae-app-academico` (Atividade 4) e não é publicado em loja. Sem o Firebase
> configurado — e sempre na web —, roda com os dados de demonstração na memória.

Equipe: Izabely Kamila Martins Barbosa, Lucas da Silva Gonçalves, Willian dos Santos Lira e Walyson dos Santos Medeiros.

Especificação: Atividade 3 v3.0 — Implementação Inicial e Modelo de Dados (02/10/2026), e Atividade 4 —
Persistência Local e Integração com API/Nuvem (decisões D12–D20 em [`docs/estado.md`](docs/estado.md)).

## Atividade 4 em uma tela

| O que pede o enunciado | Onde está |
|---|---|
| Cadastro de usuários | TM09/TM10, passo 4 "Crie seu acesso" (e-mail e senha no Firebase Authentication); TM01 entra com e-mail e senha |
| CRUD do item principal (registro do diário) | TM03 cadastra · TM13 lista e busca · TM14 mostra e exclui (lógico) · TM15 corrige — corrigir e excluir só no mesmo dia (D17) |
| Persistência local | SQLite (`lib/dados/local/`: diário, alertas, cópias de leitura em JSON) e SharedPreferences (perfil ativo, última sincronização) |
| API/nuvem | Cloud Firestore + Firebase Authentication (`lib/dados/remoto/`, `lib/dados/persistente/`, `firestore.rules`) |
| Objeto ↔ JSON | `toMap`/`fromMap` dos modelos → documento do Firestore e `jsonEncode` no SQLite |
| Carregamento e erros | indicador de carregando, "Tentar de novo", recusas em linguagem simples, prazo de 2 s (RNFM03) |
| Online/offline | fila no SQLite, aviso "Sem conexão — N registros aguardando envio", envio automático quando a conexão volta (`lib/dados/sincronizacao/`) |

## Como acessar localmente

Tudo roda nesta máquina, sem internet depois da instalação. Os comandos são do PowerShell, a partir da pasta
`C:\Users\willi\Projetos\Terae\terae_app` (fora do OneDrive e com caminho sem acento: o Gradle não compila em
"Dispositivos Móveis" nem dentro do OneDrive). O Flutter está em `C:\src\flutter\bin` (os scripts o encontram mesmo
fora do PATH).

| O quê | Comando | Onde abre |
|---|---|---|
| **App no emulador Android** (recomendado) | `.\ferramentas\app-android.ps1` | janela do emulador `Terae_Pixel`, com hot reload (`r` recarrega, `q` sai) |
| App no emulador, sem compilar de novo | `.\ferramentas\app-android.ps1 -Apk` | instala e abre o APK de depuração |
| **App no navegador** (só para ver) | `.\ferramentas\app-web.ps1` | `http://localhost:8090` — estreite a janela ou use o modo dispositivo do DevTools (F12) |
| App no Chrome com hot reload | `.\ferramentas\app-web.ps1 -Desenvolvimento` | Chrome aberto pelo Flutter |
| App num celular Android de verdade | copie `build\app\outputs\flutter-apk\app-debug.apk` para o aparelho e instale (permita "fontes desconhecidas") | o próprio celular |

O alvo do app é o Android; o navegador serve só para visualização rápida (a ligação para 188/192 e o botão voltar
do Android só fazem sentido no aparelho). No Claude Code, a configuração `terae-app-web` do `.claude/launch.json`
da pasta `Terae/` abre a versão web no navegador embutido.

### Contas e códigos da demonstração

Toque em **Entrar** e use o e-mail da persona e a senha de demonstração: no modo memória (web, testes ou sem
Firebase), a `senhaDeDemonstracao` de `lib/dados/memoria/estado_memoria.dart`; no Firebase, a `TERAE_APP_SENHA_DEMO`
do `.env` usada na semente (combinada com a equipe, fora do git).

| Persona | Conta simulada | O que mostra |
|---|---|---|
| Ana Lúcia Martins (16, titular) | `ana.lucia.martins@exemplo.test` | Início, diário (crítica → ajuda imediata), jornada, cuidadores 2/2 |
| Patrícia Andrade Neves (mãe) | `patricia.neves@exemplo.test` | dois perfis (Miguel, 7, e Laura, 4) → seleção de perfil |
| Regina Martins (cuidadora da Ana) | `regina.martins@exemplo.test` | início do cuidador, medicação, agenda e avisos, sem conteúdo clínico |

**Primeiro acesso** (na tela inicial):

| Caso | Código | CPF | Nascimento |
|---|---|---|---|
| Paciente João Pedro Assis ("Recebi um código da clínica") | `K7M4QX` | 583.049.216-42 | 19/07/1999 |
| Cuidador Paulo Martins ("Recebi um convite de cuidador") | `P4X9RC` | 847.120.563-71 | — |
| Recusas de propósito | `H3T9WB` (expirado), `R2D8NZ` e `G8B5VA` (já usados) | — | — |

Todos os nomes, CPFs e códigos são fictícios. Em modo depuração, o ícone de ajustes no canto da tela inicial abre o
painel da demonstração: "sem conexão" (para ver o registro ficar na fila) e "reiniciar dados".

### O Terae web (produto) — não é este app

O Terae web é o SaaS da clínica, em outro repositório (`C:\Users\willi\Projetos\Terae\terae`). Para vê-lo em modo
demonstração, sem servidor nem banco:

```powershell
cd C:\Users\willi\Projetos\Terae\terae
pnpm install   # só na primeira vez
pnpm dev       # abre em http://localhost:5173
```

Use `http://localhost:5173` no navegador (o Vite desta máquina escuta só em IPv6, então `127.0.0.1` não conecta).
No login (simulado), clique em **Entrar com Google Workspace**, digite **qualquer código de 6 dígitos** na
verificação em duas etapas e escolha o perfil: **Médico / Terapeuta** (Dra. Helena Prado), **Paciente** (Ana Lúcia
— o portal do paciente aparece num celular simulado, que é o protótipo que este app reproduz em Flutter),
**Cuidador** (Regina Martins), **Gestão & Faturamento** (Sandra Oliveira) ou **DPO** (Dr. Márcio Teles). O roteiro
completo está em `terae/apps/web/README.md`. No Claude Code, a configuração `terae-web` abre essa tela no navegador embutido.

## Verificação

```powershell
C:\src\flutter\bin\dart.bat format --set-exit-if-changed lib test
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat build apk --debug
```

Estado, decisões (D1–D11 e as da revisão) e pendências: [`docs/estado.md`](docs/estado.md). Contratos internos:
[`docs/contratos.md`](docs/contratos.md). Capturas das telas: [`docs/capturas/`](docs/capturas/).

## Firebase acadêmico (Atividade 4)

Projeto `terae-app-academico`, plano gratuito Spark, só da disciplina. Passos, uma vez:

1. `firebase login` (conta Google do dono) e criação do projeto, com Firestore em `southamerica-east1` e o provedor
   "E-mail/senha" ativado em Authentication.
2. `flutterfire configure --project=terae-app-academico --platforms=android` — gera `lib/firebase_options.dart` e
   `android/app/google-services.json` (troca o arquivo provisório, que faz o app cair no modo memória).
3. `firebase deploy --only firestore:rules` — publica `firestore.rules`.
4. Copie `.env.exemplo` para `.env` e preencha a chave da conta de serviço (guardada fora do OneDrive e do git) e a
   senha de demonstração; depois `cd ferramentas && npm install && cd ..` e
   `node ferramentas/semear-firebase.mjs --reiniciar` (apaga e grava de novo as personas e os códigos).
5. Para conferir o que chegou ao servidor: `node ferramentas/conferir-firebase.mjs [pacienteId]` (só leitura).

Feito em 06/11/2026: projeto criado, regras publicadas, semente rodada e roteiro conferido no emulador
(capturas em [`docs/evidencias-a4/`](docs/evidencias-a4/)). O banco ficou na região `nam5`.

Sem conexão o app continua: o diário vai para a fila no SQLite e sai sozinho quando a conexão volta; as telas de
leitura usam a última cópia. No modo depuração, o painel da tela inicial força "sem conexão" sem modo avião.
