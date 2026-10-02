# Terae — app do paciente (projeto acadêmico)

> **Projeto acadêmico — UNEMAT 2026, disciplina Dispositivos Móveis.** Este aplicativo Flutter é uma forma de ver,
> de outro jeito, o app do paciente do Terae. **Não é o app do Terae produção**: o Terae produção é um SaaS web, e o
> canal dos pacientes no produto é um PWA publicado na Play Store. Este app usa só dados fictícios de demonstração,
> não se conecta a nenhum servidor e não é publicado em loja.

Equipe: Izabely Kamila Martins Barbosa, Lucas da Silva Gonçalves, Willian dos Santos Lira e Walyson dos Santos Medeiros.

Especificação: Atividade 3 v3.0 — Implementação Inicial e Modelo de Dados (02/10/2026).

## Como acessar localmente

Tudo roda nesta máquina, sem internet depois da instalação. Os comandos são do PowerShell, a partir da pasta
`C:\Users\willi\Projetos\Terae\terae_app`. O Flutter está em `C:\src\flutter\bin` (os scripts o encontram mesmo
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

Toque em **Entrar → Continuar com Google** e escolha a conta na folha "Escolha uma conta" (simulada, sem senha).

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

_Decisões do projeto (D1–D11), rastreabilidade e ajustes da Atividade 3 entram ao fim da implementação._
