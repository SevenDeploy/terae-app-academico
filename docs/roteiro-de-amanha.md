# Roteiro de amanhã (28/11/2026): rodar o app com o Terae local

Tudo aqui é **local** (esta máquina, o emulador `Terae_Pixel`, o Terae web em `..\terae`). Nada toca a produção nem o
Firebase real. Os horários são de **Cuiabá (UTC−4)**, o relógio da clínica; o emulador mostra UTC (2:42 no emulador = 22:42
em Cuiabá). Branch: `portal-paridade` (commit `961f6c8` e os que vierem depois), **sem push**.

## 1. Em um minuto

- O app Flutter está igual ao portal da família (visual, abas, Início, Diário, Conta) e fala com o Terae local por
  `--dart-define=TERAE_FONTE=local`. O padrão continua o Firebase acadêmico (a entrega da A5).
- Passou: format, analyze e **959 testes**; o teste das regras do Firestore no emulador (22 casos); o roteiro assistido
  no emulador e a comparação com o portal web (`docs/paridade-com-portal.md`, `docs/evidencias-terae-local/`).
- **Limite de código por e-mail:** cada conta só recebe **10 códigos por 24 h** (e 5 por hora). É o que mais atrapalha
  uma segunda rodada. A seção 3 diz quanto cada persona ainda tem e quando volta.

## 2. Ligar e conferir o ambiente

Conferir o que está de pé (não muda nada):

```powershell
.\ferramentas\terae-local\subir-terae-local.ps1
```

Subir o que faltar (liga `infra-postgres-1` e `infra-mailpit-1` e abre cada processo faltante numa janela do Git Bash):

```powershell
.\ferramentas\terae-local\subir-terae-local.ps1 -Subir
```

O que deve estar de pé: API `:3000`, o **worker** (sem ele o código por e-mail não sai), Mailpit `:8025`, portal web
`:5175`. A clínica com login de verdade (`:5173`, pede TOTP) costuma ficar desligada; use o atalho sem senha abaixo.

**Clínica sem senha (terapeuta), `:5201`.** Em um terminal do Git Bash:

```bash
cd /c/Users/willi/Projetos/Terae/terae && set -a && . ./.env && set +a && PORTA_WEB=5201 TERAE_DEV_SESSAO="01a219cd-71a9-7000-9a62-0890d691a86e:39c33119-c392-4ec9-b45f-adc97d924418:terapeuta:mfa" VITE_MODO=api pnpm --filter @terae/web dev
```

Abra `http://[::1]:5201/` (o Vite escuta só em IPv6; `127.0.0.1` não responde). Caixa de entrada = o que a família
mandou; Agenda = as sessões e a presença.

## 3. Cota de códigos (confira antes de planejar o dia)

Situação ao fim de 27/11 (cada persona; o script de entrada confere isso sozinho e **para sem gastar nada** se não
houver cota):

| Persona | Gastos em 24 h | Quando volta cota |
|---|---|---|
| **Mariana** (mãe da Alice) | 10 de 10 | 1 código às **13:36**; **6** às **15:16**; 7 às 17:42; todos às 22:30 |
| **Laura** (paciente adulta) | 6 | 4 livres agora; mais a partir das **16:30** |
| **Rosa** (cuidadora) | 4 | 6 livres agora; mais a partir das **16:33** |

Dicas para gastar menos:

- De manhã use **Rosa** e **Laura**. A **Mariana** só à tarde (a partir das 15:16 ela tem 6).
- **`-Confiar`** (marca "Confiar neste aparelho por 30 dias"): a próxima entrada nesse emulador pede só e-mail e
  senha, sem código. Testado em 28/11 com a Rosa. **"Sair" esquece o aparelho**, então não toque em Sair se quiser
  reentrar sem código.
- A **Rosa já está confiável** neste emulador (entra sem código até tocar em Sair).
- Conferir a cota à mão:

```powershell
docker exec infra-postgres-1 psql -X -At -U postgres -d terae_app_local -c "select count(*), to_char((min(criado_em)+interval '24 hours') at time zone 'America/Cuiaba','DD/MM HH24:MI') from codigo_de_acesso where id_usuario=(select id from usuario where email='responsavel-alice@homologacao.terae.invalid') and criado_em>now()-interval '24 hours';"
```

## 4. Abrir o app e entrar

Compilar e instalar no emulador, fonte local (a primeira vez leva uns 3 minutos):

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'; C:\src\flutter\bin\flutter.bat run -d emulator-5554 --dart-define=TERAE_FONTE=local --dart-define=TERAE_LOCAL_URL=http://10.0.2.2:3000
```

Se o app já está instalado (o `flutter run` de ontem deixou a versão da fonte local), **não precisa compilar**: o script
de entrada abre o app sozinho. Para ligar o emulador: `.\ferramentas\app-android.ps1`.

Entrar como uma persona (abre o app, digita e-mail e senha, espera o e-mail, lê o código no Mailpit e digita; **senha e
código não aparecem em lugar nenhum**; a captura só é tirada depois do login):

```powershell
.\ferramentas\terae-local\entrar-no-emulador.ps1 -Persona rosa
```

Outras: `-Persona laura`, `-Persona mariana`, e `-Confiar` junto. A captura vai para `$env:TEMP\terae-entrada.png`.
As coordenadas do script são do `Terae_Pixel` (1080x2400); em outro aparelho, ajuste a tabela `$toque` no topo.

Ver o que o emulador mostra agora (sem estragar binário no pipe do PowerShell):

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"; & $adb shell screencap -p /sdcard/t.png; & $adb pull /sdcard/t.png "$env:TEMP\agora.png"; & $adb shell rm /sdcard/t.png
```

Toques úteis (px de 1080x2400): abas do paciente Início 108,2268 · Diário 324,2268 · Em casa 540,2268 · Agenda 756,2268 ·
Conta 972,2268 (o cuidador tem 4 abas: Início 135, Em casa 405, Agenda 675, Conta 945 em x). Um toque por vez, com captura;
toques às cegas já caíram no botão CVV 188.

## 5. Roteiro assistido (marque PASSOU / FALHOU)

**De manhã, com a Rosa (cuidadora)**

- Entrada: capa, "Etapa 1 de 2", senha errada (mensagem genérica), código errado, código certo.
- Faixa "Modo cuidador · acesso limitado"; 4 abas (sem Diário); não há como abrir diário, metas, jornada, lembretes ou
  cuidadores.
- Início: "Registrar o de hoje" na orientação que falta ("Botões grandes"); conferir no banco e na clínica (`:5201`).
  Agenda: "A clínica ainda não liberou a agenda para esta conta" (esperado).
- Conta: seus dados, "Quem você acompanha" (nome inteiro, selo embaixo), Sair.

**De manhã, com a Laura (titular adulta)**

- Diário: novo registro (só a adesão é obrigatória), registro com nível crítico (ajuda imediata, "A equipe foi avisada"),
  voltar ao início e a aba já mostra o novo; corrigir (versão 2), "Ver a versão 1", retirar com motivo.
- Sem internet: ligue o modo avião do emulador, escreva um registro ("Guardar e enviar depois"), desligue e confira que
  sai **uma vez só** (ontem foi com o modo avião; se um comando de `adb` não funcionar, deslize a barra de status).

**À tarde, com a Mariana (a partir das 15:16; entre com `-Confiar`)**

- Início: iniciais "AF" e nome inteiro, "Presença confirmada", "2 de 3 orientações registradas" com a lista; Agenda por
  semana.
- Presença: "Confirmar presença" numa sessão ainda "Marcada" (04/12 14:00). **Não toque em "Avisar que não vamos"** se
  quiser manter a demonstração: no Terae local o aviso não desfaz (a API devolve 409).
- Web para o app: na clínica (`:5201`, Caixa de entrada) clique em "Marcar como revisada" num registro da Alice e confira
  no app o selo "Revisado pela terapeuta" e "Não dá mais para corrigir nem retirar".
- App para a web: o que a Mariana enviou aparece na Caixa de entrada; a presença, na Agenda ("Confirmada por Portal da
  família").

## 6. Comparar com o portal web (lado a lado)

1. Num terminal, ligue o ajudante (serve a senha e o código só à página do portal, por 5 minutos):

```powershell
node .\ferramentas\terae-local\ajudante-login-do-portal.mjs mariana
```

2. Abra `http://portal.localhost:5175/portal/entrar` numa janela de 360×800, abra o console (F12) e cole:

```js
const c = await (await fetch('http://127.0.0.1:47831/cred')).json();
const set = (el, v) => { Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, v); el.dispatchEvent(new Event('input', { bubbles: true })); };
const campos = [...document.querySelectorAll('input')];
set(campos.find(i => i.type === 'email' || /e-?mail/i.test(i.name + i.id + (i.autocomplete || ''))), c.email);
set(campos.find(i => i.type === 'password'), c.senha);
```

3. Clique em "Continuar". Quando chegar a tela do código, cole no console:

```js
const { codigo } = await (await fetch('http://127.0.0.1:47831/codigo')).json();
[...document.querySelectorAll('input')].filter(i => i.type !== 'checkbox').slice(0, 6).forEach((el, i) => { el.focus(); Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(el, codigo[i]); el.dispatchEvent(new Event('input', { bubbles: true })); });
```

4. Clique em "Entrar" e compare com o app (Início, Diário). Sair no portal ao terminar. Cada login no portal gasta um
   código. O ajudante desliga sozinho; para desligar antes, feche o terminal dele (Ctrl+C).

## 7. Testes automáticos

Portão do app (format, análise e testes; leva uns 2 minutos):

```powershell
$env:Path = 'C:\src\flutter\bin;' + $env:Path; dart format --set-exit-if-changed lib test; flutter analyze; flutter test
```

Regenerar as capturas (só quando mudar o visual de propósito; depois, reverta as que não deveriam mudar com
`git checkout -- docs/capturas/<arquivo>.png`):

```powershell
flutter test --update-goldens test/capturas
```

Regras do Firestore no emulador local (projeto `demo-*`; não toca o Firebase real). Em Git Bash:

```bash
cd /c/Users/willi/Projetos/Terae/terae_app/ferramentas/regras-firestore && export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" PATH="$JAVA_HOME/bin:$PATH" && npm install && npm run testar
```

Fumaça do diário contra a API de verdade (fora do portão; **gasta 2 códigos** da persona, um por teste; o código e a senha
nunca são impressos):

```powershell
$env:TERAE_LOCAL_EMAIL = node .\ferramentas\terae-local\credenciais-da-persona.mjs email laura; $env:TERAE_LOCAL_SENHA = node .\ferramentas\terae-local\credenciais-da-persona.mjs senha laura; flutter test ferramentas/fumaca_repositorios_terae_local_test.dart; Remove-Item Env:TERAE_LOCAL_SENHA
```

## 8. Armadilhas (já custaram tempo)

- **Vite só em IPv6**: use `http://[::1]:5201/` ou `localhost`, não `127.0.0.1`.
- **Nunca ponha `head`** num pipe de servidor de fundo (mata o servidor). Ao desligar um processo, desligue **por porta**
  (`netstat -ano | findstr :47831`), nunca com `taskkill /IM node.exe`: há vários node do Terae rodando.
- **A tela do código mostra o código digitado**: não guarde captura dela. A da senha idem (o Android mostra o último
  caractere).
- **O Gboard às vezes engole o `input text`**: confira com captura e digite de novo. O primeiro login depois de instalar o
  app pode passar de 10 s.
- **Cota de código**: cada tentativa que falha também gasta. Rode a fumaça e o login uma vez só por vez.
- **`adb` e PowerShell**: não passe `exec-out screencap` por pipe (estraga binário); use `shell screencap` + `pull`.
- O instalador `flutter run` deixa a versão com `--dart-define=TERAE_FONTE=local`. Sem esse define o app abre no
  Firebase acadêmico.
- Os segredos TOTP das contas **da equipe** (operador, coordenação, terapeuta-a) foram impressos por engano no terminal
  em 27/11. São só do banco local, mas regenere-os se isso importar (`semear-contas-de-demonstracao`).

## 9. Não faça sem decidir

**Publicar as regras e a semente da P3 no Firebase real (`terae-app-academico`).** O app da A5 entregue (v5.0.1) usa o
formato antigo do diário nesse mesmo Firebase; as regras novas quebram a demonstração dele. Só depois que a A5 for
avaliada, e com o teste das regras (seção 7) verde:

```powershell
firebase deploy --only firestore:rules --project terae-app-academico
```

e, se for o caso, `node ferramentas/semear-firebase.mjs --reiniciar` (veja `docs/estado.md`). Isso pede o seu ok.

## 10. Pendências abertas (todas em `docs/estado.md`)

- Depois da hora da sessão sem resposta, o selo diz "Falta confirmar a presença" e não há botão (D27).
- A escala do texto do topo e da barra para em 1,15× (troca consciente de acessibilidade).
- "Ver a Jornada" do programa encerrado não confere a capacidade da fonte (inalcançável no modo local hoje).
- Falta teste do topo a 360 dp com fonte 2×.
- "Esqueci a senha", a sala da sessão e o layout de computador não existem no app (`docs/paridade-com-portal.md`).
- Registro marcado como recebido pelo 409 de chave em uso, formato antigo: sem recibo (só aparelho de desenvolvimento).

## 11. Onde está cada coisa

| O quê | Onde |
|---|---|
| Ambiente local (subir, personas, contrato HTTP) | `ferramentas/terae-local/LEIA-ME.md` |
| Entrar no emulador, ajudantes | `ferramentas/terae-local/entrar-no-emulador.ps1`, `credenciais-da-persona.mjs`, `ajudante-login-do-portal.mjs` |
| Mapa app ↔ portal e divergências | `docs/paridade-com-portal.md` |
| Decisões (PV1–PV10, TL1–TL8) e pendências | `docs/estado.md` |
| Ideias do app para o portal | `docs/ideias-para-o-portal.md` (tarefas 578–585 no `terae/`) |
| Capturas e tabelas dos testes assistidos | `docs/evidencias-terae-local/assistido-27-11/LEIA-ME.md` |
| Teste das regras do Firestore | `ferramentas/regras-firestore/LEIA-ME.md` |
| Senhas das personas | `..\terae\.credenciais\contas-de-dev.json` (fora dos repositórios; nunca copie) |
