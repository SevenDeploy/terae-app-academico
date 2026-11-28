# Demonstração: o app integrado ao Terae web local (back + front)

Para cada ação feita no app (emulador), mostrar as duas pontas:
- **back:** o que chegou ao servidor, no banco `terae_app_local`, pelo **painel do back** (só leitura, atualiza a cada
  3 s);
- **front:** a mesma informação na **clínica web** (terapeuta em `:5201`, coordenação em `:5202`) e no **Mailpit**.

Tudo roda nesta máquina. Nunca a produção. Personas fictícias da homologação.

## 1. Antes de a banca entrar (~10 min antes)

Na pasta `terae_app`:

```powershell
.\ferramentas\terae-local\preparar-demo.ps1
```

Ele sobe o que faltar (Postgres, Mailpit, API, worker, `:5201` e `:5202`), liga o emulador, confere se o app instalado
é o da fonte local (só reinstala se não for), abre no navegador o Mailpit, o programa da Alice (`:5201`), a caixa da
terapeuta (`:5201`) e a da coordenação (`:5202`), abre o **painel do back** numa janela e mostra a cota de códigos.

Arrume a tela: o **emulador** à esquerda, o **navegador** no meio e o **painel do back** à direita.

## 2. Cota e ordem das personas

- Cada conta recebe **10 códigos em 24 h** e **5 por hora**, e toda tentativa gasta. Situação em 28/11, 00h10:

  | Persona | Livres | Mais a partir de |
  |---|---|---|
  | Laura | 3 | 16:30 |
  | Rosa | 4 | 16:33 |
  | Mariana | 0 | 13:36 (1) e 15:16 (6) |

- A **Rosa está confiável** neste emulador: entra só com a senha, sem código.
  - O app guarda **um único** "aparelho confiável", e **qualquer "Sair"** ou **troca de APK** o apaga.
  - Por isso a ordem é **Rosa primeiro**, Laura depois e, se houver, o Firebase por último.
  - Não toque em "Sair" antes do fim do bloco da Rosa.
- A Laura vai gastar 1 código. É ela que mostra o código chegando ao Mailpit.

## 3. Roteiro (back + front em cada passo)

| # | No app (emulador) | Back (painel) | Front (navegador) |
|---|---|---|---|
| 1 | **Rosa entra:** `.\ferramentas\terae-local\entrar-no-emulador.ps1 -Persona rosa` ("aparelho confiável: entrou só com a senha"). Faixa "Modo cuidador · acesso limitado" e 4 abas, sem Diário. | **ENTRADAS NO PORTAL:** uma linha nova da Rosa, `mfa`, ativa. | — |
| 2 | **Rosa registra o programa:** Início → **Registrar o de hoje** em "Botões grandes" → **Sim** → **Registrar**. | **PROGRAMA EM CASA:** `feito`, hoje, "Rosa". | `:5201`, **programa da Alice** (recarregar): em "Botões grandes", hoje = **Feito**. |
| 3 | **Web → app:** fique na aba **Em casa** da Rosa ("0 de 3"). | — | `:5201` → **Editar o programa** → **Nova orientação**: "Guardar os sapatos", com qualquer texto curto, a meta "Vestir a camiseta…" → **Publicar o programa** (fica a versão nova). |
| 4 | No app: aba **Início** e depois **Em casa**. Agora é "0 de **4**", com "Guardar os sapatos". | — | O programa mostra a versão nova, publicada pela Terapeuta Demonstração A. |
| 5 | **Rosa sai:** Conta → **Sair**. | **ENTRADAS:** a sessão da Rosa fica revogada (com hora). | — |
| 6 | **Laura entra:** `entrar-no-emulador.ps1 -Persona laura` (gasta 1 código). | **ENTRADAS:** `senha` e depois `mfa`; em "códigos em 24 h", +1 para a Laura (sem mostrar o código). | **Mailpit:** chega "Seu código de acesso" para a Laura. |
| 7 | **Diário novo:** Diário → **Novo registro** → **Fiz parte** → **Pouco** → **Enviar** → "Registro enviado." | **DIÁRIO:** Laura, `parcial`, `leve`, v1, aguardando. | `:5202` **caixa de entrada** (recarregar): "Laura · Respondido pelo paciente … · pelo portal · Adesão parcial". |
| 8 | **Corrigir:** **Corrigir agora** → **Mais ou menos** → **Salvar a correção** → **Ver a versão 1**. | **DIÁRIO:** a v1 fica `substituído` e a **v2** fica aguardando. | `:5202`: "corrigido pela família (versão 2)" e "Ver as versões anteriores". |
| 9 | **Retirar:** no mesmo registro → **Retirar** → **Enviei sem querer** → **Retirar o registro**. | **DIÁRIO:** `retirado`. | `:5202`: "Retirado pela família: Enviei sem querer". |
| 10 | **Crítico:** **Novo registro** → **Não deu para fazer** → **Muito** → **Enviar** → ajuda imediata e "A equipe da clínica foi avisada" → **Ciente**. | **DIÁRIO:** `AVISOU A EQUIPE`. | `:5202` **Início**: mais um cartão **"ALERTA CRÍTICO · Laura"**, e o sino passa de 1 para 2 (a página escuta `/api/v1/alertas/fluxo`; se não aparecer em 5 s, F5). |
| 11 | **Sem internet:** modo avião → **Novo registro** → **Fiz tudo** → **Enviar** → "Registro guardado neste aparelho." → **Ver no diário** ("Guardados neste aparelho"). | **DIÁRIO:** nada novo (o servidor não recebeu). | `:5202`: nada novo. |
| 12 | Desligar o modo avião → **Enviar agora**. | **DIÁRIO:** uma linha só, com **"escrito sem internet às HH:MM:SS"** (a hora em que foi escrito, antes da hora do recebimento). | `:5202`: o registro aparece **uma vez só**. |
| 13 | **Laura sai:** Conta → **Sair**. | **ENTRADAS:** a sessão da Laura fica revogada. | — |

**Frase de fechamento:** "O mesmo dado, três lugares: o app grava pela API do portal, o banco guarda, e a clínica vê.
No outro sentido, o que a terapeuta publica chega ao app."

## 4. O que não fazer

- Não toque em **"Avisar que não vamos"**: no Terae local o aviso não volta atrás (409).
- Toque um passo por vez, olhando a tela. Toque às cegas já caiu no botão do CVV 188.
- Não projete a tela da senha nem a do código.
- A revisão da terapeuta ("Marcar como revisada") **não serve para a Laura**: ela não tem terapeuta, e a coordenação
  só lê.
  - Para mostrar "Revisado pela terapeuta" no app, use a **Mariana** (Alice), que só tem cota à tarde: na `:5201`,
    caixa de entrada → **Marcar como revisada** num registro da Alice.
  - Ou mostre a captura `docs/evidencias-terae-local/assistido-27-11/J2-revisado-na-web-aparece-no-app.png`.

## 5. Se algo falhar

| Sintoma | O que fazer |
|---|---|
| O código não chega ao Mailpit | O worker caiu: `.\ferramentas\terae-local\subir-terae-local.ps1 -Subir`. Não insista no app: cada tentativa gasta código |
| `entrar-no-emulador.ps1` para por falta de cota | Troque de persona (a Rosa confiável não precisa de código) |
| O Gboard engoliu letras do e-mail | Volte à capa (botão voltar) e rode o script de novo: a validação local não gasta código |
| A web não mostra o novo | Recarregue a página (F5). O painel do back já mostra sozinho |
| O emulador travou | `.\ferramentas\terae-local\preparar-demo.ps1 -SemNavegador` liga de novo sem reinstalar o app |

## 6. Depois da demo (opcional)

No `:5201`, programa da Alice → **Editar o programa** → **Tirar a orientação 4** → **Publicar**, para voltar às 3
orientações.
