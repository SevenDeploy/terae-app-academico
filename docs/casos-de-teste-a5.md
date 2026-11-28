# Casos de teste — Atividade 5 (versão 5.0, entrega final)

Projeto acadêmico (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção.

Esta é a rodada final, feita com o app da paridade com o portal (commit `e1ebdb9`). Ela substitui a rodada de 26/11
(CT01–CT20 da v5.0.1, no histórico do git deste arquivo), que usava o diário antigo.

## Como o roteiro foi feito

- **Data:** 27/11/2026, das 22h50 às 23h41 no fuso da clínica (−04:00).
- **Aparelho:** emulador `Terae_Pixel` (Android 16, 1080×2400).
- **App:** commit `e1ebdb9`, em dois APKs de depuração:
  - **Firebase** (padrão): para o CT01–CT19;
  - **Terae local** (`--dart-define=TERAE_FONTE=local --dart-define=TERAE_LOCAL_URL=http://10.0.2.2:3000`): para o
    CT20–CT27.
- **Servidores:**
  - o Firebase acadêmico real `terae-app-academico`, com as regras e a semente do diário novo publicadas em 27/11;
  - o Terae web local desta máquina: API `:3000`, banco `terae_app_local`, Mailpit e clínica em `:5201`. Nunca a
    produção.
- **Toques:** um passo por vez, com `adb shell input`. Cada tela foi lida pelo `uiautomator` antes do toque seguinte.
- **Evidências:** ficam em [`docs/evidencias-a5-final/`](evidencias-a5-final/).
  - `.png` é a captura da tela.
  - `.txt` é o texto da tela, a saída de `node ferramentas/conferir-firebase.mjs`, a contagem do SQLite no aparelho
    ou uma consulta de só leitura ao banco local.
  - O CT25 e o CT26 (Mariana) usam as capturas do teste assistido de 27/11, em
    [`evidencias-terae-local/assistido-27-11/`](evidencias-terae-local/assistido-27-11/LEIA-ME.md). A Mariana estava
    sem cota de código nesta rodada.
- **Senhas e códigos:** a senha de demonstração do Firebase vem do `.env`. No Terae local, o
  `ferramentas/terae-local/entrar-no-emulador.ps1` lê a senha de `terae/.credenciais/` e o código no Mailpit. Nenhum
  dos dois aparece em evidência: nenhuma captura mostra a tela de senha nem a de código.

### Cota de códigos gasta nesta rodada (Terae local)

| Persona | Códigos gastos | Total em 24 h | Observação |
|---|---|---|---|
| Rosa (cuidadora) | 1 | 5 de 10 | o APK do Firebase instalado por cima apagou a confiança do aparelho; a Rosa voltou a pedir código |
| Laura (paciente adulta) | 1 | 7 de 10 | mais cota a partir das 16:30 de 28/11 |
| Mariana (mãe da Alice) | 0 | 10 de 10 | 1 código às 13:36 de 28/11 e 6 às 15:16 |

### Personas

| Persona | Fonte | Papel |
|---|---|---|
| Ana Lúcia Martins (16) | Firebase | titular; acompanhamento clínico e TO |
| João Pedro Assis (27) | Firebase | primeiro acesso pelo código `K7M4QX` (consumido nesta rodada) |
| Regina Martins | Firebase | cuidadora da Ana |
| Laura Fictícia Nogueira | Terae local | titular adulta |
| Rosa Fictícia Duarte | Terae local | avó, cuidadora da Alice |
| Mariana Fictícia Duarte | Terae local | responsável legal da Alice |

## Resumo

| CT | Fonte | Funcionalidade (requisito) | Resultado |
|---|---|---|---|
| CT01 | Firebase | Login válido (RFM01) | Aprovado |
| CT02 | Firebase | Login inválido e validação do formulário (RFM01, RNFM01) | Aprovado |
| CT03 | Firebase | "Sair" zera os dados do aparelho (RNFM04, D20) | Aprovado |
| CT04 | Firebase | Diário: só a primeira pergunta é obrigatória (RFM03) | Aprovado |
| CT05 | Firebase | Diário: novo registro e recibo (RFM03, RFM05) | Aprovado |
| CT06 | Firebase | Diário: lista com selos de versão e retirado (RFM11) | Aprovado |
| CT07 | Firebase | Diário: corrigir cria a versão 2; "Ver a versão 1" (RFM11) | Aprovado |
| CT08 | Firebase | Diário: retirar com motivo, sem apagar (RFM11) | Aprovado |
| CT09 | Firebase | Revisado pela terapeuta não muda mais (RFM11) | Aprovado |
| CT10 | Firebase | Sem internet: guardar, "Enviar agora" e envio sozinho (RFM12) | Aprovado |
| CT11 | Firebase | Sem internet: corrigir e retirar ficam travados (RFM12) | Aprovado |
| CT12 | Firebase | Registro crítico: ajuda imediata e equipe avisada (RFM04) | Aprovado |
| CT13 | Firebase | Primeiro acesso com código inexistente e com código usado (RFM09) | Aprovado |
| CT14 | Firebase | Primeiro acesso do paciente com código válido (RFM09) | Aprovado |
| CT15 | Firebase | Presença e agenda (RFM14) | Aprovado |
| CT16 | Firebase | Lembretes locais; o "Sair" cancela (RFM15) | Aprovado |
| CT17 | Firebase | Em casa: registrar a atividade do dia (RFM13) | Aprovado |
| CT18 | Firebase | Metas: TM20 só de leitura (RFM16) | Aprovado |
| CT19 | Firebase | Cuidadora sem conteúdo clínico (RFM08, RNFM05) | Aprovado |
| CT20 | Terae local | Entrar em duas etapas: senha e código do e-mail (RFM01) | Aprovado |
| CT21 | Terae local | Diário no Terae web: novo, crítico, corrigir, versões, retirar (RFM03, RFM11) | Aprovado |
| CT22 | Terae local | Sem internet: guardado visível e enviado uma vez só (RFM12) | Aprovado |
| CT23 | Terae local | Cuidadora: 4 abas, sem diário, registra o programa (RFM08, RFM13) | Aprovado |
| CT24 | Terae local | "Sair" revoga a sessão no servidor (RNFM04) | Aprovado |
| CT25 | Terae local | Confirmar presença grava no Terae web (RFM14) | Aprovado (27/11, teste assistido) |
| CT26 | Terae local | Web ↔ app: revisado na clínica aparece no app (RFM05, RFM11) | Aprovado (27/11, teste assistido) |
| CT27 | Terae local | Trava: o app só fala com endereço local, nunca a produção | Aprovado (teste automatizado) |

**27 casos, 27 aprovados.** Nesta rodada final nenhum caso reprovou. Os defeitos achados antes dela, no teste
assistido e nas revisões, estão em "Falhas encontradas e corrigidas".

## Casos — Firebase

### CT01 — Login válido
- **Passos:** TM00 → "Entrar" → e-mail e senha da Ana → "Entrar".
- **Esperado:** abre o Início da Ana com a próxima consulta, o programa em casa de hoje e as 5 abas.
- **Obtido:** como esperado.
- **Evidência:** `ct01-inicio-ana.png`.
- **Teste automatizado:** `test/funcionalidades/autenticacao/entrar_tela_test.dart`.

### CT02 — Login inválido e validação do formulário
- **Passos:** (a) "Entrar" com os campos vazios; (b) e-mail sem domínio; (c) senha errada.
- **Esperado:** (a) "Digite o e-mail." e "Digite a senha.", sem chamar o servidor; (b) "Confira o e-mail: ele
  precisa ter @ e um domínio."; (c) "E-mail ou senha não conferem…", sem dizer qual dos dois errou.
- **Obtido:** como esperado.
- **Evidência:** `ct02a-campos-vazios.txt`, `ct02b-email-mal-formado.txt`, `ct02c-senha-errada.txt`.
- **Teste automatizado:** `entrar_tela_test.dart`, `test/dados/memoria_autenticacao_test.dart`.

### CT03 — "Sair" zera os dados do aparelho
- **Passos:** contar as tabelas do SQLite e as chaves do SharedPreferences → Conta → "Sair" → contar de novo.
- **Esperado:** volta à capa, com o SQLite sem linhas e sem as chaves da conta.
- **Obtido:** antes, `registros_diario` 17, `cache_documentos` 14, `registros_casa` 13, `alertas` 2,
  `confirmacoes_presenca` 1, mais `perfil_ativo` e `ultima_sincronizacao`. Depois, tudo com 0 e nenhuma chave.
- **Evidência:** `ct03a-antes-de-sair.txt`, `ct03b-conta-com-sair.png`, `ct03c-capa-depois-de-sair.png`,
  `ct03d-depois-de-sair.txt`.
- **Teste automatizado:** `test/dados/persistente/autenticacao_firebase_test.dart` ("sair encerra o Firebase e apaga
  o SQLite e as preferências").

### CT04 — Diário: só a primeira pergunta é obrigatória
- **Passos:** Diário → "Novo registro" → tentar enviar sem responder à primeira pergunta.
- **Esperado:** o envio fica bloqueado e a tela mostra o que falta. As demais perguntas aparecem como opcionais.
- **Obtido:** como esperado.
- **Evidência:** `ct04a-novo-registro-falta-a-primeira.png`.
- **Teste automatizado:** `test/funcionalidades/paciente/diario_test.dart`.

### CT05 — Diário: novo registro e recibo
- **Passos:** responder às perguntas → "Enviar".
- **Esperado:** recibo "Registro enviado." com o resumo e a opção de corrigir. No Firestore, a versão 1 enviada.
- **Obtido:** como esperado.
- **Evidência:** `ct05a-novo-registro-preenchido.png`, `ct05b-recibo-registro-enviado.png`, `ct10e-servidor-registros.txt`.
- **Teste automatizado:** `diario_test.dart`, `test/dados/persistente/diario_persistente_test.dart`.

### CT06 — Diário: lista com selos
- **Passos:** aba Diário.
- **Esperado:** cada registro com o seu selo ("Aguardando a terapeuta", "Corrigido", "Retirado por você", "Revisado
  pela terapeuta").
- **Obtido:** como esperado.
- **Evidência:** `ct06a-lista-selos-versao2-retirado.png`.
- **Teste automatizado:** `test/dados/memoria_diario_crud_test.dart`.

### CT07 — Diário: corrigir cria a versão 2
- **Passos:** num registro do dia, "Corrigir" → mudar a resposta → "Salvar a correção" → "Ver a versão 1".
- **Esperado:** o registro passa à versão 2, e a versão 1 continua visível, só para leitura.
- **Obtido:** como esperado. No servidor, `v2 enviado`.
- **Evidência:** `ct07a-correcao-enviada.png`, `ct07b-ver-a-versao-1.png`.
- **Teste automatizado:** `memoria_diario_crud_test.dart`, `diario_persistente_test.dart`; as regras ficam em
  `ferramentas/regras-firestore/` (22 casos).

### CT08 — Diário: retirar com motivo
- **Passos:** "Retirar" → motivo "Outro" sem detalhe (recusa) → motivo com detalhe → confirmar.
- **Esperado:** pede o detalhe quando o motivo é "Outro". O registro fica "Retirado" com o motivo, e "Nada foi
  apagado".
- **Obtido:** como esperado. No servidor, `RETIRADO … (outro)`.
- **Evidência:** `ct08a-retirar-outro-sem-detalhe.png`, `ct08b-registro-retirado-com-motivo.png`.
- **Teste automatizado:** `memoria_diario_crud_test.dart`.

### CT09 — Revisado pela terapeuta não muda mais
- **Passos:** abrir um registro revisado pela semente.
- **Esperado:** o selo "Revisado pela terapeuta" e "Não dá mais para corrigir nem retirar", sem botões.
- **Obtido:** como esperado.
- **Evidência:** `ct09-revisado-nao-muda-mais.png`.
- **Teste automatizado:** `memoria_diario_crud_test.dart`; as regras recusam no servidor (`regras.test.mjs`).

### CT10 — Sem internet: fila e envio sozinho
- **Passos:** ligar o modo avião → novo registro → "Enviar" → ver no Diário → desligar o modo avião.
- **Esperado:** recibo "Registro guardado neste aparelho". O Diário mostra "Guardados neste aparelho" com "Enviar
  agora". Ao voltar a conexão, a fila sai sozinha, uma vez só.
- **Obtido:** como esperado. No servidor, um único `v1 enviado` (`nenhuma`).
- **Evidência:** `ct10a-novo-registro-sem-internet.png`, `ct10b-recibo-guardado-neste-aparelho.png`,
  `ct10c-guardados-neste-aparelho-enviar-agora.png`, `ct10d-fila-saiu-sozinha.png`, `ct10e-servidor-registros.txt`.
- **Teste automatizado:** `test/dados/persistente/sincronizador_filas_test.dart`, `diario_persistente_test.dart`.

### CT11 — Sem internet: corrigir e retirar travados
- **Passos:** com o modo avião ligado, abrir "Corrigir" e "Retirar" num registro enviado.
- **Esperado:** botão "… · precisa de internet" desabilitado, com a explicação. Nada vai para a fila.
- **Obtido:** como esperado.
- **Evidência:** `ct11a-corrigir-travado-sem-internet.png`, `ct11b-retirar-travado-sem-internet.png`.
- **Teste automatizado:** `diario_test.dart`.

### CT12 — Registro crítico
- **Passos:** novo registro com "Muito — precisamos de ajuda" → "Enviar".
- **Esperado:** ajuda imediata (SAMU 192, CVV 188) e "A equipe da clínica foi avisada". No servidor, um alerta. O
  registro que avisou a equipe não se corrige nem se retira.
- **Obtido:** como esperado (`critico … AVISOU A EQUIPE`; 2 alertas).
- **Evidência:** `ct12a-muito-ajuda-imediata-equipe-avisada.png`, `ct12b-lista-a-equipe-foi-avisada.png`,
  `ct12c-servidor-alerta.txt`.
- **Teste automatizado:** `test/dados/memoria_diario_test.dart`, `diario_test.dart`.

### CT13 — Primeiro acesso com código inexistente e com código usado
- **Passos:** "Primeiro acesso" → código `ZZ9ZZ9`; depois, um código já usado.
- **Esperado:** "Não encontramos esse código…" e "Este código já foi usado…". O app fica no passo 1 e nada é
  gravado.
- **Obtido:** como esperado.
- **Evidência:** `ct13a-codigo-inexistente.png`, `ct13b-codigo-ja-usado.png`.
- **Teste automatizado:** `test/funcionalidades/autenticacao/cadastro_paciente_tela_test.dart`.

### CT14 — Primeiro acesso do paciente com código válido
- **Passos:** código `K7M4QX` com o CPF e o nascimento do João → "Sou o próprio paciente" → aceitar o termo →
  "Criar acesso e entrar" com os campos vazios → preencher → "Criar acesso e entrar".
- **Esperado:** "Encontramos o cadastro de João Pedro Assis". Os campos vazios são recusados no próprio campo. No fim,
  a conta é criada, o código é consumido e abre o Início do João.
- **Obtido:** como esperado. O Authentication passou a ter `joao.pedro.assis@exemplo.test`.
- **Evidência:** `ct14a-cadastro-encontrado.png`, `ct14b-termo-aceito.png`, `ct14e-cadastro-campos-vazios.txt`,
  `ct14c-inicio-joao-cadastrado.png`, `ct14d-servidor-conta-joao.txt`.
- **Observação:** quem toca em "Criar acesso" com os campos vazios e só depois digita o e-mail continua vendo
  "Digite o e-mail." até o próximo toque, porque o formulário revalida ao enviar. Não impede o cadastro.
- **Teste automatizado:** `cadastro_paciente_tela_test.dart`, `autenticacao_firebase_test.dart`.

### CT15 — Presença e agenda
- **Passos:** Início do João → "Confirmar presença" → aba Agenda.
- **Esperado:** "Presença confirmada", só com "Mudar a resposta". A Agenda agrupa por semana e mostra "Falar com a
  clínica" (número fictício). No servidor, a resposta `vamos`.
- **Obtido:** como esperado (`sessão ad…09 vamos … enviado`).
- **Evidência:** `ct15a-presenca-confirmada-joao.png`, `ct15b-agenda-joao.png`, `ct15c-servidor-presenca-joao.txt`.
- **Teste automatizado:** `test/dados/regras_presenca_test.dart`, `test/dados/memoria_presenca_test.dart`.

### CT16 — Lembretes locais
- **Passos:** Conta → "Lembretes neste aparelho" → ligar "Na véspera de cada sessão" → "Salvar" (o Android pede a
  permissão de notificação) → ver "Próximos lembretes" → "Sair" → ver os alarmes.
- **Esperado:** "Lembretes salvos." O próximo lembrete fica no sábado, 28/11, às 19:00, com um texto sem dado
  clínico. Depois do "Sair", nenhum alarme pendente.
- **Obtido:** como esperado ("Amanhã às 10:00 tem compromisso na clínica."). O `dumpsys alarm` mostra as 2 entradas
  do app com `alarm_cancelled`.
- **Evidência:** `ct16a-lembrete-da-vespera-agendado.png`, `ct16b-alarmes-depois-de-sair.txt`.
- **Teste automatizado:** `test/dados/persistente/lembretes_locais_test.dart`, `test/dados/regras_lembretes_test.dart`.

### CT17 — Em casa: registrar a atividade do dia
- **Passos:** Ana → aba Em casa → "Rotina para dormir" → "Sim" → "Registrar".
- **Esperado:** "Registrado. Obrigado por contar!", "Esta semana" passa de 5 para 6 de 7, e o registro chega ao
  Firestore.
- **Obtido:** como esperado (`2026-11-27 feito paciente enviado`).
- **Evidência:** `ct17a-em-casa-ana.png`, `ct17b-atividade-registrada.png`, `ct17c-servidor-atividade.txt`.
- **Teste automatizado:** `test/funcionalidades/paciente/em_casa_test.dart`,
  `test/dados/persistente/programa_em_casa_persistente_test.dart`.

### CT18 — Metas: TM20 só de leitura
- **Passos:** na atividade, "Esta atividade ajuda na meta".
- **Esperado:** a meta com a situação, a área, o prazo e quem acompanha, mais "O que ajuda em casa". Não há escore
  nem edição.
- **Obtido:** como esperado.
- **Evidência:** `ct18a-meta-tm20.png`.
- **Teste automatizado:** `test/funcionalidades/paciente/metas_test.dart`, `test/dados/regras_metas_test.dart`.

### CT19 — Cuidadora sem conteúdo clínico
- **Passos:** entrar como Regina → Início → Conta.
- **Esperado:** a faixa "Modo cuidador · acesso limitado", 3 abas (Início, Agenda, Conta), sem Diário, metas nem
  jornada. Aparecem a medicação (a Ana faz acompanhamento clínico), a próxima consulta e a presença.
- **Obtido:** como esperado.
- **Evidência:** `ct19a-inicio-cuidadora-regina.png`, `ct19b-conta-cuidadora-sem-diario.png`.
- **Observação:** a Conta diz "Você é cuidador" também para a Regina e a Rosa. É um texto sem gênero que fica para a
  próxima versão.
- **Teste automatizado:** `test/dados/memoria_visao_cuidador_test.dart`,
  `test/funcionalidades/cuidador/inicio_cuidador_tela_test.dart`.

## Casos — Terae local

### CT20 — Entrar em duas etapas
- **Passos:** capa → "Entrar" ("Etapa 1 de 2") → e-mail e senha → "Continuar" → código de 6 dígitos que chega por
  e-mail (Mailpit) → "Entrar".
- **Esperado:** abre o Início da Laura com a clínica ao lado da data, "Boa noite, Laura." e 5 abas. A senha errada
  dá uma mensagem genérica. O código errado diz quantas tentativas restam.
- **Obtido:** como esperado (Laura, 1 código).
- **Evidência:** `ct20a-inicio-laura-local.png`. A senha errada, o código errado e o código certo ficaram registrados
  no assistido de 27/11 (`A2-senha-errada.png`, `A5-codigo-errado.png`, `A4-codigo-do-email.png`).
- **Teste automatizado:** `test/funcionalidades/autenticacao/entrar_codigo_test.dart`,
  `test/dados/terae_local/sessao_do_portal_test.dart`.

### CT21 — Diário no Terae web
- **Passos:** Diário → "Novo registro" → "Fiz parte" e "Pouco" → "Enviar".
- **Esperado:** recibo "Registro enviado. A sua terapeuta vai ler com atenção.", com a opção de corrigir. No banco
  `registro_diario`, a versão 1 com `parcial`/`leve`.
- **Obtido:** como esperado (`27/11 23:37:55 | parcial | leve | 1`).
- **Evidência:** `ct21a-recibo-registro-enviado-local.png`, `ct21b-servidor-registro-laura.txt`. O crítico com
  "A equipe foi avisada", a correção (versão 2), "Ver a versão 1" e a retirada com motivo, todos na mesma API, estão
  no assistido de 27/11 (`F3`, `F4`, `F5`–`F9`).
- **Teste automatizado:** `test/dados/terae_local/diario_terae_local_test.dart`; a fumaça contra a API real fica em
  `ferramentas/fumaca_repositorios_terae_local_test.dart`.

### CT22 — Sem internet no Terae local
- **Passos:** modo avião → Diário (a lista dá erro) → novo registro "Fiz tudo" → "Enviar" → "Ver no diário" →
  desligar o modo avião → "Enviar agora".
- **Esperado:** "Registro guardado neste aparelho." O guardado aparece no Diário mesmo com a lista fora do ar. Ao
  voltar a conexão, ele sai uma vez só.
- **Obtido:** como esperado. No banco, uma única linha nova, guardada às 23:39:05 e criada às 23:39:58 (o
  `guardado_em` mostra que foi escrita sem internet).
- **Evidência:** `ct22a-guardado-neste-aparelho-local.png`, `ct22b-diario-guardado-visivel-sem-internet.png`,
  `ct22d-fila-enviada-ao-voltar.png`, `ct22c-servidor-uma-vez-so.txt`.
- **Teste automatizado:** `diario_terae_local_test.dart` (fila com dona e validade de 7 dias, TL8).

### CT23 — Cuidadora no Terae local
- **Passos:** entrar como Rosa → Início → "Registrar o de hoje" em "Botões grandes" → "Sim" → "Registrar" → Conta.
- **Esperado:** a faixa "Modo cuidador · acesso limitado. Você vê o programa em casa e a agenda de Alice." e 4 abas,
  sem Diário. A agenda mostra "A clínica ainda não liberou a agenda para esta conta." O registro chega a
  `registro_programa_domiciliar` em nome da Rosa.
- **Obtido:** como esperado (`2026-11-27 | feito | 27/11 23:35 | cuidador-alice@…`).
- **Evidência:** `ct23a-inicio-rosa-cuidadora-local.png`, `ct23b-rosa-registrou-botoes-grandes.png`,
  `ct23c-servidor-registro-rosa.txt`, `ct23d-conta-rosa-sem-diario.png`.
- **Teste automatizado:** `test/funcionalidades/cuidador/cuidador_do_terae_local_test.dart`.

### CT24 — "Sair" revoga a sessão no servidor
- **Passos:** Conta → "Sair" (Rosa e Laura).
- **Esperado:** volta à capa, e as duas sessões do portal (senha e código) ficam com `revogada_em` no servidor.
- **Obtido:** como esperado nas duas personas.
- **Evidência:** `ct24a-capa-depois-de-sair-local.png`, `ct23e-servidor-sessao-revogada-rosa.txt`,
  `ct24b-servidor-sessao-revogada-laura.txt`.
- **Teste automatizado:** `sessao_do_portal_test.dart`.

### CT25 — Confirmar presença grava no Terae web
- **Passos:** Mariana → Início → "Confirmar presença" na sessão "Marcada" → clínica `:5201` → Agenda.
- **Esperado:** o app mostra "Presença confirmada". A clínica vê "Confirmada por Portal da família"
  (`agendamento.confirmado_em`, canal `portal`).
- **Obtido (27/11, teste assistido):** como esperado.
- **Evidência:** `assistido-27-11/C4-confirmar-presenca-gravou-no-portal.png`, `D3-agenda-mariana-proxima-semana.png`,
  `J1-mariana-inicio-presenca-confirmada-na-web.png`.
- **Teste automatizado:** `test/dados/terae_local/repositorios_terae_local_test.dart`.

### CT26 — Web ↔ app
- **Passos:** na clínica `:5201`, Caixa de entrada → "Marcar como revisada" num registro da Alice → no app, Diário.
- **Esperado:** o app mostra "Revisado pela terapeuta" e "Não dá mais para corrigir nem retirar". No outro sentido, o
  que a família envia aparece na Caixa de entrada.
- **Obtido (27/11, teste assistido):** como esperado. Nesta rodada, a Caixa de entrada mostrou de novo os registros
  da Alice enviados pelo app.
- **Evidência:** `assistido-27-11/J2-revisado-na-web-aparece-no-app.png` e a seção "Conferência na web da clínica"
  do `LEIA-ME.md` do assistido.

### CT27 — Trava: nunca a produção
- **Passos:** montar a fonte local com endereços que não são locais (domínio público, `*.localhost`, IP da rede).
- **Esperado:** o app recusa com um erro claro. Só aceita `127.0.0.1`, `::1`, `localhost` e `10.0.2.2`, e o
  cliente confere de novo ao nascer.
- **Obtido:** como esperado.
- **Teste automatizado:** `test/dados/terae_local/configuracao_terae_local_test.dart` ("recusa … com erro claro",
  "o cliente confere de novo ao nascer").

## Falhas encontradas e corrigidas

Nenhum caso reprovou na rodada final. Estas são as falhas achadas antes dela, cada uma com um teste de regressão:

| # | Onde | Falha | Correção |
|---|---|---|---|
| 1 | Teste assistido (Terae local) | Sem internet, a lista do diário mostrava só o erro e o registro guardado sumia | `7326de4`: os guardados e os vencidos são lidos antes da rede |
| 2 | Teste assistido | A agenda que a clínica não liberou parecia "Nenhuma sessão marcada" | `72fb156`: "A clínica ainda não liberou a agenda para esta conta." |
| 3 | Teste assistido | O aviso de recusa (409) nascia abaixo da dobra; a faixa do cuidador não citava o programa | `72fb156` |
| 4 | Teste assistido | "Mudar a resposta" repetia "Confirmar presença" e o portal respondia 409 | `8c312d2`: oferece só o que muda |
| 5 | Teste assistido | A aba Diário abria com a lista velha depois de enviar | `fcc9a31` |
| 6 | Teste das regras no emulador | O recorte `versoesAnteriores[0:0]` recusava toda primeira correção | corrigido nas `firestore.rules` (22 casos) |
| 7 | Ensaio | A saudação usava a hora em UTC ("Bom dia" às 22:30) | `961f6c8` |

## Estado dos servidores depois do roteiro

- **Firebase:** ficaram os registros de teste da Ana em 27/11 (novo, corrigido, retirado, crítico com 2 alertas, o
  guardado sem internet e a atividade "Rotina para dormir"), a presença do João e a conta
  `joao.pedro.assis@exemplo.test`, que consumiu o `K7M4QX`. O `P4X9RC` (cuidador da Ana, vale até 01/12) continua
  livre. Para zerar, rode a semente com `--reiniciar`, o que pede o ok do dono.
- **Terae local:** ficaram 2 registros da Laura e 1 da Rosa no programa. A Rosa não está mais confiável neste
  emulador.
