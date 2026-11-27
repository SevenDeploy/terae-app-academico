# Terae web local para o app (`TERAE_FONTE=local`)

O app acadêmico fala com o Firebase `terae-app-academico` por padrão. Para a apresentação, o dono decidiu (26/11/2026)
ligá-lo **também** ao Terae web rodando **nesta máquina**, pela API do portal da família. Isso é só para a demonstração:
**nunca** aponte o app para a produção (terae.com.br, VPS). O app do Terae produção será em React Native.

Tudo abaixo é dado fictício da semeadura do terae (`homologacao.terae.invalid`, `demonstracao.terae.test`): nenhum
e-mail sai da máquina, tudo cai no Mailpit.

## O que fica de pé

| O quê | Endereço | Para quê |
|---|---|---|
| Postgres | `infra-postgres-1`, 127.0.0.1:5432, banco **`terae_app_local`** | banco só desta frente |
| Mailpit | http://127.0.0.1:8025 | onde chega o código de acesso do portal |
| API | http://127.0.0.1:3000 (escuta em 0.0.0.0 e ::) | o que o app consome; no emulador, `http://10.0.2.2:3000` |
| worker | sem porta | entrega os e-mails da fila; **sem ele o código não chega** |
| SPA da clínica | http://localhost:5173 | a TO e a coordenação, com login de verdade (senha + TOTP) |
| Portal web da família | http://portal.localhost:5175 | o mesmo portal no navegador, para comparar com o app |
| Atalhos de dev (opcionais) | http://localhost:5201 (TO) e http://localhost:5202 (coordenação) | a SPA já autenticada, sem senha nem TOTP |

Conferir tudo de uma vez:

```powershell
.\ferramentas\terae-local\subir-terae-local.ps1
```

Com `-Subir`, liga os dois contêineres do terae (só eles; os de outros projetos não são tocados) e abre numa janela do
Git Bash cada processo que faltar. O script não guarda nem imprime segredo.

## Subir do zero (uma vez por máquina)

Os comandos do terae são de Git Bash, dentro de `..\terae` (o monorepo). A API, o worker e os Vite leem **só o
ambiente do shell**: todo terminal começa com `set -a; . ./.env; set +a`.

1. **Docker.** Abra o Docker Desktop e `docker start infra-postgres-1 infra-mailpit-1`.
2. **Banco próprio.** O banco `terae` padrão é o da integração (tem centenas de clínicas de teste, e a semeadura o
   recusa). Crie o `terae_app_local` com os privilégios por banco de `infra/postgres/init/00{1,2,3}-*.sql`
   (`docs/operacao/desenvolvimento-local.md`, "Banco novo no Postgres de todos"):

   ```bash
   docker exec -i infra-postgres-1 psql -X -v ON_ERROR_STOP=1 -U postgres <<'SQL'
   CREATE DATABASE terae_app_local OWNER terae_migracao;
   \c terae_app_local
   ALTER SCHEMA public OWNER TO terae_migracao;
   GRANT CONNECT ON DATABASE terae_app_local TO terae_app, terae_portal, terae_copia, terae_familia;
   GRANT USAGE ON SCHEMA public TO terae_app, terae_portal, terae_copia, terae_familia;
   ALTER DEFAULT PRIVILEGES FOR ROLE terae_migracao IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO terae_app;
   ALTER DEFAULT PRIVILEGES FOR ROLE terae_migracao IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO terae_app;
   ALTER DEFAULT PRIVILEGES FOR ROLE terae_migracao GRANT USAGE ON SCHEMAS TO terae_copia;
   ALTER DEFAULT PRIVILEGES FOR ROLE terae_migracao GRANT SELECT ON TABLES TO terae_copia;
   ALTER DEFAULT PRIVILEGES FOR ROLE terae_migracao GRANT SELECT ON SEQUENCES TO terae_copia;
   SQL
   ```

   O `.env` do terae nasce do `.env.exemplo` (fora do git). Preencha `CHAVE_DADOS_V1` (o comando que gera está no
   próprio arquivo) e `SENHA_DAS_CONTAS_DE_DEMONSTRACAO` (uma frase longa só para isso), e troque o banco das
   `DATABASE_URL`, `DATABASE_URL_MIGRACAO`, `DATABASE_URL_PORTAL` e `DATABASE_URL_FAMILIA` para `terae_app_local`
   (deixe a `DATABASE_URL_TESTE` no `terae`). Gere a chave com Node e grave com um editor: um `sed` com a chave
   na substituição já estragou o valor uma vez.
3. **Migrar e semear** (Git Bash, em `..\terae`, com o `.env` carregado):

   ```bash
   pnpm --filter @terae/api db:migrar
   pnpm --filter @terae/api exec tsx src/semear-homologacao.ts
   pnpm --filter @terae/api semear-contas-de-demonstracao --marcar-banco-de-desenvolvimento
   ```

   A última grava as senhas em `..\terae\.credenciais\contas-de-dev.json` (fora do git). Rode-a **antes** de subir o
   worker: ela lê o convite e o código da fila de e-mail.
4. **Processos**, cada um no seu terminal com o `.env` carregado (ou `subir-terae-local.ps1 -Subir`):

   ```bash
   pnpm --filter @terae/api dev                 # API :3000
   pnpm --filter @terae/api worker              # e-mails
   VITE_MODO=api pnpm --filter @terae/web dev   # clínica :5173
   pnpm --filter @terae/portal dev              # portal :5175
   ```

   O Vite pode escutar só em IPv6 (`[::1]`): abra por `localhost`, não por `127.0.0.1`. Nunca ponha `head` num
   pipe de servidor de fundo (mata o servidor).

### Atalho sem senha (a TO e a coordenação na demonstração)

A SPA tem o caminho de desenvolvimento documentado em `..\terae\docs\operacao\api.md` §1: com `TERAE_DEV_SESSAO`, o
proxy do Vite injeta o usuário e a SPA abre autenticada, sem senha nem TOTP. Ele só existe no `vite dev` e a API o
ignora em produção. Os ids saem do banco (`usuario` + `membro_instituicao` do `terae_app_local`):

```bash
# TO (Terapeuta Demonstração A) em :5201
PORTA_WEB=5201 TERAE_DEV_SESSAO="<idUsuario>:<idInstituicao>:terapeuta:mfa" VITE_MODO=api pnpm --filter @terae/web dev
# Coordenação em :5202
PORTA_WEB=5202 TERAE_DEV_SESSAO="<idUsuario>:<idInstituicao>:coordenacao:mfa" VITE_MODO=api pnpm --filter @terae/web dev
```

Sem o atalho, entre em http://localhost:5173 com o e-mail e a senha do `contas-de-dev.json` e o código de um
aplicativo autenticador com o `segredoTotp` da conta.

## Personas (clínica fictícia "Clínica Fictícia da Homologação")

| Persona | Conta no portal | Quem é | O que vê no app |
|---|---|---|---|
| **Mariana** | `responsavel-alice@homologacao.terae.invalid` | mãe e responsável legal da **Alice** (7 anos, TO) | Início, programa em casa, agenda (liberada), diário |
| **Rosa** | `cuidador-alice@homologacao.terae.invalid` | avó da Alice, cuidadora sem a guarda, autorizada pela Mariana | Início e programa; **sem diário** (`GET /diario` dá 403 `perfil_sem_recurso`: o app esconde a aba); agenda só se a clínica liberar para ela (hoje: não) |
| **Laura** | `paciente-adulta@homologacao.terae.invalid` | paciente adulta, titular de si | o próprio Início, diário e agenda (a titular já a vê liberada); sem programa nem sessões marcadas por enquanto |

Na clínica: `terapeuta-a@demonstracao.terae.test` (Terapeuta Demonstração A, TO da Alice) e
`coordenacao@demonstracao.terae.test`.

**As senhas** estão só em `..\terae\.credenciais\contas-de-dev.json` (linhas `UC` = família, com
`"segundoFator": "codigo_por_email"`; linhas `UE`/`UP` = equipe, com `segredoTotp`). Nunca as copie para este
repositório, para o `.env` do app nem para o chat.

## Como ler o código no Mailpit

O login do portal tem 2º fator por código de e-mail (6 dígitos, assunto **"Seu código de acesso"**).

- Na mão: http://127.0.0.1:8025, a mensagem mais recente para o e-mail da persona.
- Pela API do Mailpit:
  `GET http://127.0.0.1:8025/api/v1/search?query=to:responsavel-alice@homologacao.terae.invalid subject:"Seu código de acesso"&limit=1`
  e depois `GET /api/v1/message/<ID>`; o código está no campo `Text`.

Tetos: um código a cada 60 s, 5 por hora, 10 por dia por conta; login 10 por minuto. Na demonstração, marque
"confiar neste dispositivo" (`confiarNesteDispositivo: true`): o cookie `__Host-terae_dispositivo` (30 dias) pula o
código nas próximas entradas.

## O contrato visto por HTTP (o que o cliente do app precisa fazer)

Todas as chamadas vão para `http://10.0.2.2:3000/api/portal/...` com:

- **`Host: portal.localhost`** — sem o prefixo `portal.`, toda rota `/api/portal/*` responde **404**.
- **`X-Terae-Cliente: <qualquer valor>`** em toda escrita (POST/PUT) — sem ele, **403 `origem_nao_confirmada`**.
- **Cookie à mão.** Os cookies vêm `__Host-terae_familia=...; Path=/; HttpOnly; Secure; SameSite=Strict`, com `Secure`
  mesmo em http local. Guarde o par `nome=valor` do `Set-Cookie` e reenvie no `Cookie`; um cookie jar que respeite
  `Secure` não reenviaria em `http://10.0.2.2`. O cookie **gira** no `POST /sessoes/codigo` (e ao trocar de clínica):
  sempre substitua pelo último.

Sequência, conferida em 26/11 contra esta máquina:

1. `POST /api/portal/sessoes` `{email, senha}` → 201 `{"etapa":"codigo", "emailMascarado", "codigoEnviado", "reenviarAPartirDe"}`.
2. `POST /api/portal/sessoes/codigo` `{codigo, confiarNesteDispositivo}` → 200 `{"etapa":"concluida"}`.
3. `GET /api/portal/eu` → `pacientes[]` (`idPaciente`, `nome`, `nomeDaClinica`, `fusoHorario`, `perfil`, `agendaLiberada`, `acessoTerminaEm`).
4. **`PUT /api/portal/sessoes/paciente` `{idPaciente}`** — obrigatório antes do resto: sem ele `/inicio`, `/programa` e
   `/agenda` dão **409 "Escolha o paciente primeiro."** e `/diario` dá **403 `perfil_sem_recurso`**.
5. `GET /inicio`, `/programa` (`orientacoes[]`), `/agenda` (`liberada`, `sessoes[]`), `/diario` (`registros[]`, `haMais`).
6. `POST /api/portal/diario` `{idPaciente, adesao: total|parcial|nenhuma, observacoes?, sintomas?, intensidadeSintoma?}`
   com `Idempotency-Key` (8 a 255 caracteres) → 201 `{id, versao, recebidoEm, ajudaImediata}`.
   Depois da revisão da TO, o registro volta em `/diario` com `"situacao":"revisado"` e `revisadoEm`.

Os instantes vêm em UTC; exiba no `fusoHorario` do paciente (`America/Cuiaba`, −04:00): a sessão marcada às 14:00
chega como `18:00Z`.

## Rodar o app contra o Terae local

```powershell
flutter run -d emulator-5554 --dart-define=TERAE_FONTE=local --dart-define=TERAE_LOCAL_URL=http://10.0.2.2:3000
```

`10.0.2.2` é o loopback do Windows visto de dentro do emulador; a API escuta em `0.0.0.0:3000`, então não há
firewall no caminho. A trava só aceita os literais `10.0.2.2`, `127.0.0.1`, `::1` e `localhost` (nunca `*.localhost`
nem IP da rede): num aparelho físico pelo cabo, rode `adb reverse tcp:3000 tcp:3000` e use
`TERAE_LOCAL_URL=http://127.0.0.1:3000`. O `Host: portal.localhost` o app põe sozinho no cabeçalho.

## Estado deixado pela preparação (26/11/2026)

- Plano terapêutico da Alice publicado (v1) com a meta "Vestir a camiseta sozinha antes da escola".
- Programa em casa da Alice publicado (v1) com três orientações: "Camiseta no espelho", "Corrida das meias" e "Botões
  grandes" (todos os dias).
- Agenda no portal **liberada para a Mariana** (a Rosa segue sem agenda).
- Duas sessões futuras com a Terapeuta Demonstração A: terça 01/12 e sexta 04/12, às 14:00 (mais a quinta 03/12 às
  08:00 da semeadura).
- Um registro de ensaio no diário da Mariana, já **revisado** pela TO.
- A Terapeuta Demonstração A ganhou cadastro de profissional (Equipe → Profissionais), feito pela coordenação: a
  semeadura das contas a deixa sem ele, e sem ele a TO não publica plano.

## Roteiro da demonstração

1. **Abertura.** `subir-terae-local.ps1` verde. Emulador com o app em `TERAE_FONTE=local`; navegador com a SPA da
   clínica na TO (:5201, ou :5173 com login) e o Mailpit numa aba.
2. **A família entra.** No app, Mariana: e-mail e senha → o código chega ao Mailpit → digita o código (marque confiar
   neste dispositivo) → escolhe a Alice. O Início mostra a próxima sessão (01/12, 14:00) e o programa de hoje.
3. **TO publica → app vê.** Na SPA, como TO: Prontuário da Alice → **Programa em casa** → **Editar o programa** →
   acrescente uma orientação (ex.: "Escova no pente grande") → **Publicar o programa** (cria a versão 2; a 1 fica no
   histórico). No app, puxe para atualizar o Programa: a orientação nova aparece.
4. **Agenda.** No app, a agenda mostra as sessões; se quiser, a coordenação (:5202) marca mais uma em Agenda →
   **Marcar sessão** e o app a vê ao atualizar. Mostre a Rosa (cuidadora) sem agenda: a clínica decide quem vê onde a
   criança estará.
5. **App envia diário → TO revisa → selo "Revisado".** No app, Mariana registra o dia (adesão parcial, uma
   observação). Na SPA, como TO: **Caixa de entrada** → o registro "Acompanhamento em casa · Alice … pelo portal" →
   **Marcar como revisada**. No app, atualize o diário: o registro passa a `revisado` e o app mostra o selo
   **"Revisado"**; depois da revisão a família não pode mais editar nem retirar (`podeAlterar: false`).
6. **Fecho.** O mesmo dado no portal web (http://portal.localhost:5175) e no app: uma fonte, dois clientes.

## Quando algo falha

| Sintoma | Causa provável |
|---|---|
| 404 em toda rota do portal | faltou `Host: portal.localhost` |
| 403 `origem_nao_confirmada` | faltou `X-Terae-Cliente` na escrita |
| 409 "Escolha o paciente primeiro." | faltou o `PUT /sessoes/paciente` depois do login |
| 401 logo depois do código | o cliente reenviou o cookie antigo; o cookie gira no `/sessoes/codigo` |
| código não chega | worker parado, ou teto de envios (60 s / 5 por hora / 10 por dia) |
| `adb shell` não responde | emulador travado; feche-o e reabra pelo `app-android.ps1` (em 26/11 ele não respondia nem a `echo`, então o `curl` de dentro do emulador não foi feito) |
