# Casos de teste — Atividade 5 (versão 5.0)

Projeto acadêmico (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção.

## Como o roteiro foi feito

- **Data:** 26/11/2026, das 15h45 às 16h15 no fuso da clínica (−04:00), longe da virada do dia, por causa da regra
  do mesmo dia (D17).
- **Aparelho:** emulador `Terae_Pixel` (Android 16, 1080×2400).
- **App:** APK de depuração do branch `atividade-5`.
  - O roteiro começou no `389b7b8` (a main da F3).
  - Depois das correções, foi reinstalado no `29a9920` para conferir de novo o CT06 e o CT16.
  - Antes de instalar, o `pm clear` limpou os dados do app.
- **Servidor:** o Firebase acadêmico real, `terae-app-academico`.
  - Com o ok do dono, a semente rodou com `node ferramentas/semear-firebase.mjs --reiniciar` antes do roteiro.
  - As regras do Firestore não foram publicadas de novo.
- **Toques:** um passo por vez, com `adb shell input`. Cada tela foi lida pelo `uiautomator` antes do toque
  seguinte.
- **Evidências:** ficam em [`docs/evidencias-a5/`](evidencias-a5/).
  - `.png` é captura da tela.
  - `.txt` é o texto da tela lido pelo `uiautomator`, ou a saída de `node ferramentas/conferir-firebase.mjs`, ou a
    contagem do SQLite no aparelho (`run-as … sqlite3`).
  - **Nenhuma captura mostra a tela de login nem o passo da senha**, porque o Android mostra por um instante o
    último caractere digitado. Nesses casos a evidência é o texto da tela, sem o campo de senha.
- **Senhas:** a senha de demonstração vem do `.env` (fora do git), digitada direto no campo pelo `adb`. Ela nunca vai
  para o repositório nem para as evidências.
- **Testes automatizados:** a coluna "Teste automatizado" aponta o arquivo em `test/` (e o nome do teste) que cobre o
  mesmo caso na suíte. O CT08–CT11 também é coberto, ponta a ponta no aparelho, por
  `integration_test/jornada_principal_test.dart`.

### Requisitos

Os requisitos citados foram conferidos no código: os comentários de documentação citam `RFM01`–`RFM10` e
`RNFM01`–`RNFM05`. A tabela do v4.0 acrescentou:
- `RFM11` — CRUD do diário;
- `RFM12` — funcionar sem conexão;
- `RFM13` — atividades de casa.

Sessões e presença, lembretes e metas (evolução de TO, F2 e F3) **ainda não têm número de RFM**: o v4.0 é anterior a
elas. Aqui elas aparecem pela decisão que as rege (D27, D28 e D35), com a sugestão **RFM14–RFM16** para o documento
v5.0.

### Personas

| Persona | Conta | Linhas de cuidado |
|---|---|---|
| Ana Lúcia Martins (16) | `ana.lucia.martins@exemplo.test` | acompanhamento clínico e TO, titular |
| Antônio Carlos Ribeiro (71) | `antonio.ribeiro@exemplo.test` | só TO, titular |
| João Pedro Assis (27) | primeiro acesso no roteiro | acompanhamento clínico |
| Carla Ribeiro (fictícia) | criada no roteiro (`carla.ribeiro@exemplo.test`) | cuidadora do Antônio, pelo convite que ele gerou |
| Patrícia Andrade Neves | `patricia.neves@exemplo.test` | só no CT03, para o bloqueio não atingir as outras contas |

## Resumo

| CT | Funcionalidade | Resultado |
|---|---|---|
| CT01 | Login válido | Aprovado |
| CT02 | Login inválido e validação do formulário | Aprovado |
| CT03 | Bloqueio por muitas tentativas | Aprovado |
| CT04 | Primeiro acesso do paciente com código válido (TM09) | Aprovado |
| CT05 | Primeiro acesso com código inexistente e com código usado | Aprovado |
| CT06 | Convite e primeiro acesso do cuidador (TM07 → TM10) | **Reprovado → corrigido → aprovado** (`29a9920`) |
| CT07 | "Sair" zera os dados do aparelho (D20) | Aprovado |
| CT08 | Diário: criar registro em até 5 toques (TM03 → TM04) | Aprovado |
| CT09 | Meus registros: listar e buscar (TM13) | Aprovado |
| CT10 | Corrigir no mesmo dia; outro dia só leitura (D17) | Aprovado |
| CT11 | Excluir (lógico) | Aprovado |
| CT12 | Sem conexão: fila, aviso e envio sozinho | Aprovado |
| CT13 | Registro crítico: ajuda imediata e alerta | Aprovado |
| CT14 | Em casa: registrar a atividade do dia (TM16/TM17) | Aprovado |
| CT15 | Sessões e presença (TM18) | Aprovado |
| CT16 | Lembretes locais (TM19) | **Reprovado → corrigido → aprovado** (`2f389fa`) |
| CT17 | Metas: Jornada e TM20 | Aprovado |
| CT18 | Indicador de carregamento e mensagem de erro | Aprovado |
| CT19 | Cuidador sem conteúdo clínico (RNFM05) | Aprovado |
| CT20 | Validação de formulário (diário e cadastro) | Aprovado |

São 20 casos: 18 aprovados de primeira e 2 reprovados. Os 2 reprovados foram corrigidos com teste de regressão e
aprovados no reteste, no aparelho.

## Casos

### CT01 — Login válido

- **Requisito:** RFM01 (D14).
- **Persona:** Ana.
- **Pré-condição:** semente aplicada; app recém-instalado, na TM00.
- **Passos:**
  1. Tocar em "Entrar".
  2. Digitar `ana.lucia.martins@exemplo.test` e a senha de demonstração.
  3. Tocar em "Entrar".
- **Resultado esperado:** abre a TM02 com "Olá, Ana", o atalho do diário, "Atividades de casa", a próxima consulta e
  as abas Início, Diário, Em casa e Jornada.
- **Resultado obtido:** como esperado. A TM02 mostrou "Olá, Ana", "Hoje: 0 de 2 registradas" e "Sua próxima consulta
  — Dra. Helena Prado — Terça-feira, 1 de dezembro às 14:00".
- **Evidência:** `ct01-inicio-ana.png`.
- **Teste automatizado:**
  - `test/funcionalidades/autenticacao/entrar_tela_test.dart`, "e-mail e senha entram com a conta (D14)";
  - `test/funcionalidades/roteador_test.dart`, "entrar leva ao Início com a barra de abas";
  - `integration_test/jornada_principal_test.dart`.

### CT02 — Login inválido e validação do formulário

- **Requisito:** RFM01, RNFM01.
- **Persona:** Ana.
- **Pré-condição:** TM01 aberta.
- **Passos:**
  1. Tocar em "Entrar" com os dois campos vazios.
  2. Digitar `ana.lucia.martins`, sem o domínio, e tocar em "Entrar".
  3. Completar o e-mail, digitar uma senha errada e tocar em "Entrar".
- **Resultado esperado:**
  1. "Digite o e-mail." e "Digite a senha.", sem chamar o servidor.
  2. "Confira o e-mail: ele precisa ter @ e um domínio."
  3. "E-mail ou senha não conferem. Confira e tente de novo.", e a sessão não abre.
- **Resultado obtido:** como esperado, nos três passos.
- **Evidência:** `ct02a-campos-vazios.txt`, `ct02b-email-mal-formado.txt`, `ct02c-senha-errada.txt`.
- **Teste automatizado:** `test/funcionalidades/autenticacao/entrar_tela_test.dart`:
  - "campo vazio ou e-mail mal formado: erro no campo, sem chamar o repositório";
  - "senha errada mostra a recusa e não abre sessão".

### CT03 — Bloqueio por muitas tentativas

- **Requisito:** RFM01. É a falha 3 do roteiro da A4.
- **Persona:** Patrícia.
- **Pré-condição:** TM01 com o e-mail da Patrícia e uma senha errada.
- **Passos:** tocar em "Entrar" seguidas vezes, lendo a mensagem a cada vez.
- **Resultado esperado:** primeiro "E-mail ou senha não conferem…". Quando o Firebase Authentication bloqueia
  (`too-many-requests`), aparece "Muitas tentativas seguidas. Espere alguns minutos e tente de novo." no lugar de
  "Sem internet".
- **Resultado obtido:** da 1ª à 6ª tentativa, "E-mail ou senha não conferem…". Na 7ª, "Muitas tentativas seguidas.
  Espere alguns minutos e tente de novo."
- **Evidência:** `ct03-muitas-tentativas.txt`.
- **Teste automatizado:**
  - `test/dados/persistente/falhas_remotas_test.dart`, "cada código conhecido vira a recusa certa"
    (`too-many-requests` → `muitasTentativas`);
  - `test/funcionalidades/autenticacao/entrar_tela_test.dart`, "muitas tentativas mostram a espera, não "sem
    internet" (A5, CT03)" (novo nesta rodada).

### CT04 — Primeiro acesso do paciente com código válido (TM09)

- **Requisito:** RFM09 (D14).
- **Persona:** João.
- **Pré-condição:** código `K7M4QX` da semente, sem uso.
- **Passos:**
  1. TM00 → "Primeiro acesso" → "Recebi um código da clínica".
  2. Código `K7M4QX`, CPF e nascimento do João.
  3. "Sou o próprio paciente" → "Continuar".
  4. Resumos "Aqui no aplicativo" e "Li e aceito o termo de consentimento" → "Continuar".
  5. Tocar em "Criar acesso e entrar" com os campos vazios.
  6. Preencher e-mail, senha e confirmação → "Criar acesso e entrar".
- **Resultado esperado:**
  - o passo 2 mostra "Encontramos o cadastro de João Pedro Assis.";
  - o passo 5 recusa no campo, sem chamar o servidor;
  - o passo 6 cria a conta, consome o código, liga o paciente e abre a TM02 do João.
- **Resultado obtido:** como esperado. No passo 5 apareceram "Digite o e-mail." e "A senha precisa ter pelo menos 8
  caracteres.". No servidor, a conta `joao.pedro.assis@exemplo.test` passou a existir.
- **Evidência:** `ct04a-passo2-cadastro-encontrado.png`, `ct04b-passo3-termo-aceito.png`,
  `ct04c-passo4-validacao-campos.txt`, `ct04d-inicio-joao-cadastrado.png`, `ct04e-servidor-conta-joao.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/autenticacao/cadastro_paciente_tela_test.dart`, "avança pelos quatro passos e ativa com
    termo, canal e acesso";
  - `test/dados/persistente/autenticacao_firebase_test.dart`, grupo "primeiro acesso com o código da clínica (TM09,
    D14)".

### CT05 — Primeiro acesso com código inexistente e com código usado

- **Requisito:** RFM09.
- **Persona:** João (código inexistente) e Miguel (código usado).
- **Pré-condição:** TM09, passo 1.
- **Passos:**
  1. Código `ZZ9ZZ9`, com CPF e nascimento do João → "Continuar".
  2. Código `M5C2TG` (já usado pela Patrícia), com CPF e nascimento do Miguel → "Continuar".
- **Resultado esperado:**
  1. "Não encontramos esse código. Confira as letras e os números."
  2. "Este código já foi usado. Se precisar, peça um novo."

  Nos dois casos o app fica no passo 1 e nada é gravado.
- **Resultado obtido:** como esperado.
- **Evidência:** `ct05a-codigo-inexistente.png`, `ct05b-codigo-ja-usado.png`.
- **Teste automatizado:**
  - `test/funcionalidades/autenticacao/cadastro_paciente_tela_test.dart`, grupo "recusas do passo 1 viram mensagem
    simples" (`codigoJaUsado`, `codigoExpirado`);
  - `test/dados/memoria_autenticacao_test.dart`, "recusas do passo 1, cada uma com o motivo certo".

### CT06 — Convite e primeiro acesso do cuidador (TM07 → TM10)

- **Requisito:** RFM07, RFM09, RNFM05 (D29).
- **Persona:** Antônio, que convida, e Carla, que aceita.
- **Pré-condição:** Antônio sem cuidadores ("0 de 2").
- **Passos:**
  1. Antônio: Início → menu → "Cuidadores" → nome "Carla Ribeiro" e CPF `529.982.247-25` (fictício, válido) →
     "Gerar convite".
  2. "Sair" → "Primeiro acesso" → "Recebi um convite de cuidador" → o código gerado e o CPF.
  3. Ler o passo 2, "O que você verá".
  4. Aceitar o termo → criar o acesso → "Criar acesso e entrar".
- **Resultado esperado:**
  - o convite aparece como "Convite em aberto" com o código, e a contagem fica em "1 de 2";
  - o passo 2 descreve o que o cuidador do Antônio vai ver. Antônio só faz TO, e pela D29 o cuidador dele não vê
    medicação;
  - no fim, abre a TM08 da Carla.
- **Resultado obtido (1ª rodada) — reprovado:**
  - o convite `PX3EZT` foi gerado e a Carla entrou na TM08;
  - mas o passo 2 prometia "A medicação: os horários dos remédios e a data de renovação da receita" e falava de "cada
    consulta". O termo dizia "Você vai ver a agenda, os remédios e os avisos de Antônio". A TM08 dela, corretamente,
    não mostra medicação.
- **Correção:** `29a9920`.
  - O convite público só traz o nome do paciente. Antes da conta existir, a TM10 não sabe as linhas de cuidado, e pôr
    as linhas no convite exporia dado de saúde a quem tem só o código.
  - Os textos passaram a servir às duas linhas: "cada sessão ou consulta", "Se houver remédios no tratamento: …" e "a
    agenda, os avisos e, se houver, os horários dos remédios".
- **Reteste (APK `29a9920`) — aprovado:** novo convite `TBWCUN` do Antônio. O passo 2 mostrou os textos novos.
- **Evidência:** `ct06a-convite-gerado-tm07.png`, `ct06b-passo2-o-que-vera-falha-to.png` (a falha),
  `ct06c-passo2-texto-corrigido.png` (o reteste) e `ct19a-inicio-cuidadora-sem-clinico.png` (a TM08 da Carla).
- **Teste automatizado:** `test/funcionalidades/autenticacao/cadastro_cuidador_tela_test.dart`:
  - "o quadro e o termo servem a quem só faz TO: falam de sessão ou consulta e só prometem remédios "se houver""
    (regressão);
  - "avança pelos quatro passos e aceita com o acesso criado".

### CT07 — "Sair" zera os dados do aparelho

- **Requisito:** RNFM04 (D20, D16).
- **Persona:** Ana.
- **Pré-condição:** Ana com a sessão aberta, depois do CT08 ao CT13.
- **Passos:**
  1. Contar as linhas das tabelas do SQLite e as chaves do SharedPreferences.
  2. Início → menu → "Sair".
  3. Contar de novo.
- **Resultado esperado:** o app volta à TM00. O SQLite fica sem linhas e as preferências da conta são apagadas.
- **Resultado obtido:**
  - **antes:** `registros_diario` 16, `alertas` 2, `cache_documentos` 14, `registros_casa` 13,
    `confirmacoes_presenca` 1, e as chaves `perfil_ativo` e `ultima_sincronizacao`;
  - **depois:** todas as tabelas com 0 linhas e nenhuma chave, com a TM00 na tela.
- **Evidência:** `ct07a-antes-de-sair.txt`, `ct07b-boas-vindas-depois-de-sair.png`, `ct07c-depois-de-sair.txt`.
- **Teste automatizado:**
  - `test/dados/persistente/autenticacao_firebase_test.dart`, "sair encerra o Firebase e apaga o SQLite e as
    preferências";
  - `test/dados/persistente/lembretes_locais_test.dart`, ""Sair": cancela no Android e apaga as escolhas";
  - `test/dados/persistente/programa_em_casa_persistente_test.dart`, ""Sair" apaga também os registros das
    atividades (D20)".

### CT08 — Diário: criar registro em até 5 toques

- **Requisito:** RFM03, RFM05, RNFM02.
- **Persona:** Ana.
- **Pré-condição:** TM02, com conexão.
- **Passos:**
  1. Tocar no atalho "Como você está hoje?".
  2. "Tomei tudo".
  3. "Leve".
  4. "Cansaço".
  5. Rolar e tocar em "Enviar meu registro".
- **Resultado esperado:** a TM04 mostra "Registro enviado!" com o resumo, e a tela inicial volta sozinha. São 5
  toques, sem texto obrigatório.
- **Resultado obtido:** como esperado, em 5 toques e uma rolagem. O resumo foi "Remédios: Tomei tudo · Intensidade:
  Leve · O que mais incomoda: Cansaço".
- **Evidência:** `ct08a-diario-preenchido.png`, `ct08b-registro-enviado.png`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/diario_test.dart`, "do Início ao diário enviado, contando os toques";
  - `integration_test/jornada_principal_test.dart`.

### CT09 — Meus registros: listar e buscar (TM13)

- **Requisito:** RFM11.
- **Persona:** Ana.
- **Pré-condição:** o registro do CT08 enviado.
- **Passos:**
  1. Aba Diário → "Meus registros".
  2. Digitar "ansiedade" na busca → "Buscar".
- **Resultado esperado:** a lista vem do mais recente, com o registro de hoje no topo. A busca, sem acento nem
  maiúscula, filtra pelo sintoma.
- **Resultado obtido:** "14 registros", com o de hoje (15:48, Cansaço, Leve, Enviado) primeiro. A busca resultou em
  "4 registros", todos de Ansiedade.
- **Evidência:** `ct09a-meus-registros.png`, `ct09b-busca-ansiedade.png`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/registros_test.dart`, "TM03 → TM13: lista do mais recente, busca e filtro";
  - `test/dados/memoria_diario_crud_test.dart`, "busca sem acento nem maiúscula".
- **Observação:** a busca só se aplica ao tocar em "Buscar" ou no "concluído" do teclado. Fechar o teclado com o
  voltar não busca. É o comportamento do código (`onSubmitted`), não falha.

### CT10 — Corrigir no mesmo dia; outro dia só leitura

- **Requisito:** RFM11 (D17).
- **Persona:** Ana.
- **Pré-condição:** um registro de hoje e outros de dias anteriores.
- **Passos:**
  1. Abrir o registro de 23/11.
  2. Voltar e abrir o de hoje → "Corrigir" → "Moderada" e "Sono ruim" → "Salvar correção".
- **Resultado esperado:**
  1. O de 23/11 não tem "Corrigir" nem "Excluir" e explica "Este registro é de outro dia e não pode mais ser mudado.
     Se precisar, conte na próxima consulta."
  2. O de hoje volta à TM14 com "Registro corrigido." e "Registrado às 15:48 · corrigido às 15:50".
- **Resultado obtido:** como esperado. No servidor, o registro mostra `corrigido 2026-11-26T19:50:28Z`.
- **Evidência:** `ct10b-outro-dia-so-leitura.png`, `ct10a-registro-corrigido.png`, `ct11c-servidor-excluido-em.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/registros_test.dart`, "TM15: corrigir o de hoje volta à TM14 com as respostas
    novas" e "TM14 de outro dia: só leitura, sem Corrigir nem Excluir";
  - `test/dados/persistente/diario_persistente_test.dart`, "registro de ontem não muda: edicaoEncerrada".

### CT11 — Excluir (lógico)

- **Requisito:** RFM11 (D17; "nenhuma exclusão física").
- **Persona:** Ana.
- **Pré-condição:** o registro de hoje, corrigido no CT10.
- **Passos:** TM14 → "Excluir" → "Excluir" no diálogo.
- **Resultado esperado:**
  - o diálogo diz "Excluir este registro? Ele sai da sua lista. Se a equipe já foi avisada por causa dele, o aviso
    continua valendo.";
  - depois, a TM13 com "Registro excluído." e um registro a menos;
  - no servidor, o documento continua, com `excluidoEm`.
- **Resultado obtido:** como esperado. A lista passou de 14 para 13 registros, e o servidor mostra o registro
  "EXCLUÍDO 2026-11-26T19:50:44Z".
- **Evidência:** `ct11a-confirmar-exclusao.png`, `ct11b-registro-excluido.png`, `ct11c-servidor-excluido-em.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/registros_test.dart`, "TM14 de hoje: excluir pede confirmação e some da TM13";
  - `test/dados/persistente/diario_persistente_test.dart`, "excluir é lógico: some da lista e o servidor guarda
    excluidoEm";
  - `integration_test/jornada_principal_test.dart`.

### CT12 — Sem conexão: fila, aviso e envio sozinho

- **Requisito:** RFM12, RNFM03 (D16).
- **Persona:** Ana.
- **Pré-condição:** modo avião ligado (`cmd connectivity airplane-mode enable`).
- **Passos:**
  1. Diário: "Tomei uma parte", "Grave", "Ansiedade" → "Enviar meu registro".
  2. Abrir "Meus registros".
  3. Desligar o modo avião sem tocar em nada e esperar 15 s.
- **Resultado esperado:**
  1. O registro é guardado no aparelho, e o aviso diz "Sem conexão — 1 registro aguardando envio. Ele sai sozinho
     quando a conexão voltar."
  2. A TM13 mostra o selo "Aguardando conexão para enviar".
  3. Com a conexão de volta, a fila sai sozinha, o selo vira "Enviado" e o aviso some.
- **Resultado obtido:** como esperado nos três passos. O servidor recebeu o registro "grave Ansiedade enviado".
- **Evidência:** `ct12a-registro-guardado-sem-conexao.png`, `ct12b-meus-registros-aguardando-envio.png`,
  `ct12c-fila-enviada-ao-voltar-conexao.png`, `ct13b-servidor-alerta.txt`.
- **Teste automatizado:**
  - `test/dados/persistente/diario_persistente_test.dart`, "sem conexão fica na fila; a conexão volta e a fila sai
    sozinha";
  - `test/funcionalidades/paciente/registros_test.dart`, "sem conexão: a TM13 avisa e o selo mostra a fila";
  - `test/dados/persistente/sincronizador_filas_test.dart`, "o aviso de conexão soma o diário e todas as filas".

### CT13 — Registro crítico: ajuda imediata e alerta

- **Requisito:** RFM04 (§7.1, D18).
- **Persona:** Ana.
- **Pré-condição:** com conexão.
- **Passos:** Diário: "Não tomei", "Crítica", "Tristeza" → "Enviar meu registro" → "Ciente".
- **Resultado esperado:**
  - antes de enviar, o aviso "Ao enviar, vamos mostrar na hora os contatos de ajuda.";
  - a TM05 abre na hora com "Procure ajuda agora", ligação para o CVV 188 e para o SAMU 192, e "Seu profissional foi
    avisado. O aviso chegou para Dra. Helena Prado.";
  - no servidor, um alerta novo e o aviso do cuidador;
  - "Ciente" volta ao Início.
- **Resultado obtido:** como esperado. O servidor passou a "Alertas: 2; avisos do cuidador: 2" (a semente tinha 1),
  com o registro "critica Tristeza enviado".
- **Evidência:** `ct13a-ajuda-imediata-profissional-avisado.png`, `ct13b-servidor-alerta.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/diario_test.dart`, "abre a TM05 na hora mesmo com envio lento";
  - `test/dados/memoria_diario_test.dart`, "crítica: o servidor cria o alerta…";
  - `test/dados/regras_test.dart`, "(a) crítica dispara mesmo sem histórico".

### CT14 — Em casa: registrar a atividade do dia

- **Requisito:** RFM13 (D26, D31).
- **Persona:** Antônio.
- **Pré-condição:** "Hoje: 1 de 2 atividades registradas" (o copo, pela semente).
- **Passos:** aba Em casa → "Abotoar a camisa com a mão mais fraca" → "Sim" → "Registrar" → voltar.
- **Resultado esperado:**
  - a TM17 mostra "Registrado. Obrigado por contar!" só depois que o servidor confirma;
  - de volta, a TM16 mostra "Hoje: 2 de 2 atividades registradas" e "Tudo contado por hoje. Obrigado!".
- **Resultado obtido:** como esperado. O servidor mostra os dois registros de 26/11 como "feito", enviados.
- **Evidência:** `ct14a-em-casa-1-de-2.png`, `ct14b-atividade-registrada.png`, `ct14c-em-casa-2-de-2.png`,
  `ct14d-servidor-registro-casa.txt`.
- **Teste automatizado:** `test/funcionalidades/paciente/em_casa_test.dart`:
  - "registrar "Em parte" com reflexão; corrigir para "Sim"; desfazer";
  - "sem conexão: guardado no aparelho e na fila".

### CT15 — Sessões e presença

- **Requisito:** D27. Sugestão para o v5.0: RFM14.
- **Persona:** Antônio.
- **Pré-condição:** a sessão de 03/12 às 08:00 com o Tiago, sem resposta.
- **Passos:** Início → cartão "Sua próxima sessão" → TM18 → "Sim, vou" → voltar ao Início.
- **Resultado esperado:**
  - a TM18 mostra "Você vai?" (voz do titular, D24) e, depois da resposta, "Sim, vou — A clínica recebeu sua
    resposta." com "Mudar a resposta";
  - o Início mostra "Presença confirmada";
  - "Falar com a clínica" usa o número fictício.
- **Resultado obtido:** como esperado. O servidor gravou a sessão `…0012` com "vamos", enviado.
- **Evidência:** `ct15a-sessoes-sim-vou.png`, `ct15b-servidor-presenca.txt`, `ct15c-inicio-presenca-confirmada.png`.
- **Teste automatizado:** `test/funcionalidades/paciente/sessoes_test.dart`:
  - "o titular lê "Você vai?" e "Sim, vou"; sem conexão, a resposta fica guardada";
  - "a mãe responde "Sim, vamos" e depois muda para "Não vamos conseguir"; a sessão continua marcada".

### CT16 — Lembretes locais

- **Requisito:** D28. Sugestão para o v5.0: RFM15.
- **Persona:** Antônio.
- **Pré-condição:** TM19 sem lembretes e notificação ainda não permitida.
- **Passos:**
  1. Menu → "Lembretes" → ligar "Na véspera de cada sessão ou consulta" → 19:00 → "Salvar".
  2. Permitir as notificações no diálogo do Android.
  3. "Mandar um lembrete de teste".
  4. Abrir a barra de notificações.
- **Resultado esperado:**
  - o Android pergunta a permissão ao salvar;
  - aparecem "Lembretes salvos." e o próximo, "Quarta-feira, 2 de dezembro às 19:00 — Amanhã às 08:00 tem compromisso
    na clínica.";
  - o lembrete de teste aparece na barra e fica lá até a pessoa tirar.
- **Resultado obtido (1ª rodada) — reprovado:**
  - a permissão, o "Lembretes salvos.", o próximo lembrete e 4 alarmes do app no sistema saíram como esperado;
  - mas **o lembrete de teste não estava na barra** quando ela foi aberta, segundos depois.
  - A causa: o reagendamento, que roda ao fim de cada sincronização e na volta ao app, chamava `cancelAll()`. No
    Android, essa chamada também tira as notificações já mostradas. Um lembrete de véspera já entregue sumiria do
    mesmo jeito.
- **Correção:** `2f389fa`. O reagendamento passou a usar `cancelAllPendingNotifications()`, e o "Sair" continua
  tirando tudo.
- **Reteste (APK `29a9920`) — aprovado:** "Mandar um lembrete de teste" → app ao fundo → app aberto de novo (o que
  reagenda) → a barra mostra "Terae — Os lembretes do Terae estão ligados neste celular.".
- **Evidência:** `ct16a-permissao-do-android.png`, `ct16b-lembretes-salvos-proximos.png`, `ct16d-alarmes.txt`,
  `ct16c-lembrete-de-teste-na-barra.png` (o reteste).
- **Teste automatizado:**
  - `test/dados/persistente/lembretes_locais_test.dart`, "reagendar troca só os agendados: o lembrete já mostrado
    fica na barra (roteiro da A5, CT16)" (regressão);
  - `test/funcionalidades/paciente/lembretes_test.dart`, "Antônio abre pelo menu, liga a véspera às 20:00 e as
    atividades; salva e vê os próximos".

### CT17 — Metas: Jornada e TM20

- **Requisito:** RFM06, D35. Sugestão para o v5.0: RFM16.
- **Persona:** Antônio.
- **Pré-condição:** as 3 metas da semente.
- **Passos:** aba Jornada → "Vestir a camisa de botão sozinho".
- **Resultado esperado:**
  - "Nossas metas" em Autocuidado: as em andamento com o prazo e a alcançada por último, sem escore;
  - a TM20 mostra com quem a meta foi combinada, quem acompanha, a atividade ligada, o próximo marco e "Para mudar
    uma meta, fale com a clínica.".
- **Resultado obtido:** como esperado. A TM20 mostrou:
  - "Combinada com Antônio e a família";
  - "Acompanhada por Tiago Moreira";
  - "Prazo: 10/01/2027";
  - a atividade "Abotoar a camisa com a mão mais fraca";
  - o marco "Vestir a camisa sozinho".
- **Evidência:** `ct17a-jornada-nossas-metas.png`, `ct17b-meta-tm20.png`.
- **Teste automatizado:** `test/funcionalidades/paciente/metas_test.dart`:
  - "Jornada do Antônio: "Nossas metas" por área da vida, com a situação e o prazo, sem escore (D25)";
  - "a meta abre a TM20: …".

### CT18 — Indicador de carregamento e mensagem de erro

- **Requisito:** RNFM01, RNFM03.
- **Persona:** Antônio.
- **Pré-condição:** sessão guardada no aparelho.
- **Passos:**
  1. Fechar o app à força e abri-lo de novo, com capturas seguidas.
  2. "Sair", ligar o modo avião e tentar entrar com e-mail e senha.
- **Resultado esperado:**
  1. Enquanto o resumo do dia carrega, o Início mostra o indicador (`CircularProgressIndicator`, rótulo
     "Carregando").
  2. Uma mensagem simples, sem jargão: "Sem internet agora. Tente de novo quando a conexão voltar."
- **Resultado obtido:** como esperado nos dois passos.
- **Evidência:** `ct18a-carregando-inicio.png`, `ct18b-erro-sem-internet-ao-entrar.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/inicio_test.dart` e `jornada_test.dart`, "falha ao carregar oferece "Tentar de
    novo"";
  - `test/funcionalidades/paciente/diario_test.dart`, "TM04: enquanto o envio não resolve diz "Enviando…" …";
  - `test/dados/persistente/autenticacao_firebase_test.dart`, "sem conexão, entrar recusa semConexao".

### CT19 — Cuidador sem conteúdo clínico

- **Requisito:** RFM08, RNFM05 (D29).
- **Persona:** Carla, cuidadora do Antônio.
- **Pré-condição:** CT06 concluído.
- **Passos:** TM08 → "Agenda e avisos".
- **Resultado esperado:**
  - "Você está no modo cuidador: acesso limitado.", a próxima sessão com "Presença confirmada" e "Conteúdo clínico —
    Bloqueado para cuidadores";
  - sem "Medicação" (o Antônio só faz TO), sem diário, sem metas, CPF ou nascimento.
- **Resultado obtido:** como esperado. "Agenda e avisos" mostra a sessão e "Nenhum aviso agora.".
- **Evidência:** `ct19a-inicio-cuidadora-sem-clinico.png`, `ct19b-agenda-avisos-cuidadora.png`.
- **Teste automatizado:**
  - `test/funcionalidades/cuidador/inicio_cuidador_tela_test.dart`, "não mostra CPF, nascimento, motivo nem
    conteúdo de registro";
  - `test/funcionalidades/paciente/registros_test.dart`, "a cuidadora não chega à TM13 nem por link direto
    (RNFM05)";
  - `test/funcionalidades/roteador_test.dart`, "link direto para /paciente/diario cai em /cuidador/inicio".

### CT20 — Validação de formulário

- **Requisito:** RNFM01, RNFM02.
- **Persona:** Ana (diário) e João (cadastro).
- **Pré-condição:** formulários abertos.
- **Passos:**
  1. Diário com só a intensidade marcada.
  2. Passo 4 da TM09 com os campos vazios (CT04).
  3. Login com os campos vazios (CT02).
- **Resultado esperado:**
  1. "Enviar meu registro" fica desabilitado e diz o que falta: "Para enviar, escolha os remédios e o sintoma."
  2. e 3. Os erros aparecem no próprio campo, e nada vai ao servidor.
- **Resultado obtido:** como esperado nos três formulários.
  - No passo 4 da TM09, uma confirmação de senha digitada errado pelo teclado do emulador mostrou "As duas senhas não
    são iguais." e não deixou criar a conta.
- **Evidência:** `ct20-diario-validacao.png`, `ct04c-passo4-validacao-campos.txt`, `ct02a-campos-vazios.txt`.
- **Teste automatizado:**
  - `test/funcionalidades/paciente/diario_test.dart`, "sem as três escolhas, Enviar fica desabilitado";
  - `test/funcionalidades/autenticacao/cadastro_paciente_tela_test.dart`, "erros locais ficam no campo e não chamam o
    repositório";
  - `test/funcionalidades/autenticacao/campos_cadastro_test.dart`.

## Falhas encontradas e corrigidas

| # | Caso | Falha | Correção | Teste de regressão |
|---|---|---|---|---|
| 1 | CT16 | O reagendamento dos lembretes (fim de cada sincronização, volta ao app) chamava `cancelAll()`, que no Android também tira da barra as notificações já mostradas: o lembrete de teste, e um lembrete de véspera já entregue, sumiam | `2f389fa` — `cancelAllPendingNotifications()` no reagendamento; o "Sair" continua tirando tudo (D20) | `test/dados/persistente/lembretes_locais_test.dart` |
| 2 | CT06 | A TM10 prometia "A medicação…" e falava só de "consulta" ao cuidador de quem só faz TO, que pela D29 não vê medicação | `29a9920` — textos que servem às duas linhas ("sessão ou consulta", remédios "se houver"), sem expor as linhas no convite público | `test/funcionalidades/autenticacao/cadastro_cuidador_tela_test.dart` |

## Estado do Firebase depois do roteiro

Com o ok do dono, a semente rodou de novo com `--reiniciar` às 16h20 de 26/11. No Firestore não ficou nada do
roteiro. Ficaram livres para a demonstração (conferido no servidor):
- `K7M4QX`: paciente João; CPF 583.049.216-42; nascimento 19/07/1999. Vale até 08/12/2026, 23:59.
- `P4X9RC`: cuidador da Ana; CPF 847.120.563-71. Vale até 01/12/2026, 23:59.

Para uma demonstração depois de 01/12, rode a semente de novo, porque as datas são relativas ao dia em que ela roda
(D9).

Sobrou no Authentication a conta de teste `carla.ribeiro@exemplo.test`, criada no CT06. A semente só apaga os e-mails
que conhece. Como o Firestore foi zerado, a conta entra sem nenhum vínculo ("Esta conta ainda não tem acesso"). Apagá-la
é decisão do dono.
