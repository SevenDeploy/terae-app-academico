# Estado do terae_app — 06/11/2026 (Atividade 4 e evolução de TO)

Projeto acadêmico (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção: o produto é um SaaS web, e o
canal do paciente no produto é um PWA na Play Store.

## Atividade 5 — finalização do MVP e testes (26/11/2026, branch `atividade-5`)

Decisão do dono: o MVP final é a main da F3 (`389b7b8`). A F4 fica como evolução, e nenhuma funcionalidade nova
entra. O líder cuida da mescla na main, do repositório público e do APK final.

**Roteiro.** São 20 casos, CT01–CT20, em [`docs/casos-de-teste-a5.md`](casos-de-teste-a5.md), com o requisito, a
persona, os passos, o resultado esperado e o obtido, a evidência e o teste automatizado de cada um.
- O roteiro rodou no emulador `Terae_Pixel`, com o APK de depuração e o Firebase real, um toque por vez.
- Com o ok do dono, a semente rodou com `--reiniciar` antes e depois do roteiro. As regras não foram publicadas.
- As evidências estão em `docs/evidencias-a5/`, com nenhuma captura da tela de login nem do passo da senha.
- Ana: login, recusas, diário, CRUD, fila sem conexão, crítica e "Sair".
- João: primeiro acesso com `K7M4QX`, código inexistente e código usado.
- Antônio: Em casa, sessões, lembretes, metas e o convite de cuidador.
- Carla, cuidadora fictícia criada pelo convite do Antônio: TM10 e TM08.
- Patrícia: o bloqueio por muitas tentativas, na 7ª tentativa.

**Resultado:** 18 casos aprovados de primeira e 2 reprovados, corrigidos com teste de regressão e aprovados no
reteste no aparelho:
1. **CT16, lembretes** (`2f389fa`):
   - O defeito: o reagendamento, que roda ao fim de cada sincronização e na volta ao app, chamava `cancelAll()`. No
     Android, isso também tira da barra as notificações já mostradas. O lembrete de teste sumia segundos depois, e um
     lembrete de véspera já entregue sumiria igual.
   - A correção: o reagendamento passou a usar `cancelAllPendingNotifications()`, e o "Sair" continua tirando tudo
     (D20).
2. **CT06, TM10** (`29a9920`):
   - O defeito: ao cuidador de quem só faz TO, a TM10 prometia "A medicação…" e falava só de "consulta", e a D29 diz
     que esse cuidador não vê medicação.
   - O convite público só traz o nome do paciente, e expor as linhas de cuidado nele seria pior. Por isso, os textos
     passaram a servir às duas linhas: "sessão ou consulta" e remédios "se houver".

Outros commits:
- teste de tela da TM01 para "muitas tentativas" (`139b2a9`), que só tinha o teste do mapeamento;
- **`integration_test/jornada_principal_test.dart`** (`532df58`): entrar → diário → Meus registros → corrigir →
  excluir → sair, com o app inteiro sobre a memória (D19), sem o Firebase. Passou no `Terae_Pixel` (`flutter test
  integration_test/jornada_principal_test.dart -d emulator-5554`). Ele fica fora do `flutter test` do portão,
  porque precisa de aparelho.

**Portão:** `dart format --set-exit-if-changed lib test integration_test` sem mudança e `flutter analyze` sem issue.
O `flutter test` passou com 733 testes (eram 730 na F3; entraram 2 testes de regressão e o da TM01). Além disso, o
teste de integração passou no emulador.

**Firebase depois do roteiro (26/11, 16h20):**
- a semente final deixou livres o `K7M4QX` (João, até 08/12) e o `P4X9RC` (cuidador da Ana, até 01/12); depois de
  01/12, rode a semente de novo;
- sobrou no Authentication a conta de teste `carla.ribeiro@exemplo.test`, que fica sem vínculo. A semente só apaga os
  e-mails que conhece, e apagar a conta é decisão do dono.

Pendências da A5:
1. Sessões e presença, lembretes e metas não têm número de RFM: o v4.0 é anterior a elas. A tabela usa D27, D28 e
   D35 e sugere RFM14–RFM16 para o documento v5.0.
2. A senha de demonstração apareceu uma vez na saída de uma ferramenta da sessão do roteiro: um toque caiu fora do
   campo de senha e ela foi digitada no campo de e-mail, que é visível. Ela não foi para arquivo nem para o
   repositório. O dono decide se troca a senha (`.env` e semente).

## Evolução de TO (evolução livre, desde 06/11/2026)

Pedido do dono (06/11/2026): desenvolver mais funções "como se fosse o app do Terae que o espaço de TO usaria com os
pacientes", sem integrar com o Terae web. Respostas dele: **evolução livre / portfólio** (sem enunciado nem prazo) e
**somar TO para todas as idades** (o que as A1–A4 documentaram fica). O plano aprovado está em
`C:\Users\willi\.claude\plans\c-users-willi-projetos-terae-terae-app-jiggly-floyd.md`. Fases:
- F0 — fundação;
- F1 — Em casa;
- F2 — sessões, presença e lembretes;
- F3 — metas;
- F4 — rotina visual;
- F5 e F6 — opcionais.

### Decisões (do líder, por delegação do dono)

| # | Decisão |
|---|---|
| D21 | Linhas de cuidado por paciente (`acompanhamentoClinico`, `terapiaOcupacional`). Receita e remédios só no clínico; a aba "Em casa" só na TO. **O diário vale para todos** (ajuste do plano em F0): o alerta da crítica também protege a família de TO, como o acompanhamento F04 do Terae web |
| D22 | A barra de abas mostra só as abas da linha do paciente, e a guarda recusa a rota de TO a quem não a tem. **Cuidadores saiu da barra para o menu do Início** (a saída prevista na D22): com 5 abas, o rótulo "Cuidadores" quebrava em duas linhas a 360 dp mesmo com a fonte em 100%. Ficam Início, Diário, Em casa (TO) e Jornada |
| D23 | Personas: Laura (4) e Miguel (7) só com TO, pela mãe; Ana (16) com psiquiatria e TO; **Antônio Carlos Ribeiro (71)**, titular, só TO depois de um AVC, com o terapeuta ocupacional **Tiago Moreira**; João sem mudança |
| D24 | Voz do app: o titular lê sobre si ("Vamos cuidar de você hoje?"); o responsável legal e o cuidador leem sobre o paciente ("Vamos cuidar de Miguel hoje?"). A voz vem da qualidade do termo vigente |
| D25–D30 | Do plano, a aplicar nas fases seguintes: metas sem escore; registro da atividade de casa um por dia; presença que não cancela; lembretes só locais; o cuidador vê sessões e rotina, não atividades; fora do app ficam ABA, foto, chat e o lado da clínica |
| D31 | (F1) O registro da atividade de casa tem id UUID v4 gerado no aparelho, e "um por atividade por dia" (D26) é garantido pela busca do registro do dia, que é corrigido no lugar. Não usamos id derivado porque as regras do Firestore não calculam hash, e um id que elas conseguissem conferir (`atividadeId_dia`) não seria UUID, o que o §23 pede. As regras não garantem a unicidade entre aparelhos (limitação declarada). Se dois aparelhos registrarem o mesmo dia, vale o mais recente, e é ele que a TM17 mostra, que a faixa e a semana contam e que a correção altera |
| D32 | (F1) Quem só faz TO tem o mesmo diário, com o mesmo alerta da crítica, mas com as palavras da TO: "E a rotina combinada, deu para seguir?" (Segui/Seguimos, Em parte, Não deu hoje), "O quanto o dia foi difícil?" e "O que mais pesou hoje?" (crise ou desregulação, sono, alimentação…), na voz do perfil. Quem tem acompanhamento clínico, com ou sem TO, continua com o diário das A3/A4 |
| D33 | (F1) Se o servidor recusar um item de uma fila por algo que não seja "sem conexão", o item fica na fila (o aviso conta), e o diário, as outras filas e a busca seguem. A recusa vai para o log de depuração. Isso resolve a pendência 4 da F0. A regra da rotina local do plano (F4) passa a ser a D34 |
| D35 | (F3) As metas da TO são só leitura, num contrato próprio (`RepositorioMetas`). A família lê descrição, área da vida, prazo (só da meta em andamento: na alcançada, a etiqueta basta), situação em palavras ("Em andamento", "Alcançada", "Interrompida", "Substituída por outra") e com quem foi combinada. O modelo não tem escore, nível GAS nem peso, e o que vier a mais no documento é ignorado, também na cópia local e na semente (D25). O cuidador não lê metas: a regra do Firestore é só do titular, e nenhuma tela do cuidador as mostra (D29) |
| D36 | (F3) A alta da terapia ocupacional é um marco "Alta" com data até hoje. A clínica encerra as atividades no mesmo dia (`encerradaEm`), e por isso o registro já é recusado pela vigência, os lembretes de casa param e o cartão do Início some. A TM16 mostra "Programa encerrado", com a faixa dos 14 dias, só para leitura, quando há alta **e nenhuma atividade vale hoje**: quem decide é a vigência, como no registro, no Início e nos lembretes. Se a clínica publicar atividades depois da alta (a volta à TO), o programa reabre sozinho. Nenhuma persona da demonstração tem alta, para o programa continuar à mostra; a alta aparece nos testes que a preparam e numa captura |
| D37 | (F3) A atividade de casa e o marco apontam para a meta por um `metaId` opcional. A carga da memória exige que a meta seja do mesmo paciente e que o marco "Meta alcançada" aponte para uma meta alcançada. Os dados das fases anteriores, sem o campo, continuam valendo |

### F0 — Fundação (06/11/2026, branch `to-f0-fundacao`)

O que entrou:
- `LinhaDeCuidado` e `Paciente.linhasDeCuidado`; sem linha gravada, vale só o clínico.
- `VinculosDaConta.qualidades` e `Perfil.voz`.
- TM16 "Em casa" em estado vazio, aba adaptável e guarda por linha.
- A TM07 abre pelo menu do Início.
- O Início e a Jornada escondem os remédios de quem não tem acompanhamento clínico.
- `FilaDeEntidade` no `Sincronizador`. Toda fila segue a regra da A4: "sem conexão" no envio para de enviar, mas a
  busca do servidor ainda roda, e se a leitura responder o app volta a "online".
- `BancoLocal` passou a migrações numeradas, ainda só com a versão 1.
- Tiago e Antônio entraram no `demonstracao.json`, e os 5 pacientes ganharam linhas de cuidado.

O que a verificação achou:
- **A captura mostrou "Cuidadores" quebrado em duas linhas.** O teste de estouro não pega quebra de linha. Entrou um
  teste com a Lexend real, a 100% e a 200%; conferi que ele falha com 5 abas.
- **A revisão em contexto limpo bloqueou uma regressão minha.** Eu tinha tomado como defeito a fila voltar a "online"
  depois de um "sem conexão" no envio, e a "correção" fazia a sincronização parar sem buscar o servidor. Isso mudava o
  diário da A4: com a rede de volta e só o envio demorando, o app ficava em "Sem conexão" e não trazia o histórico. A
  correção foi desfeita. Entrou um teste do caminho do diário (o envio passa do prazo, a leitura responde): ele busca o
  servidor e volta a "online", e com a correção ele falhava.
- A revisão também pediu o teste das duas vozes da TM16 (`test/funcionalidades/paciente/em_casa_test.dart`).

**Adiado para a F1, desvio do plano da F0:**
- O enum `Ocupacao` fica para a F1, que é a primeira a usá-lo.
- O SQLite v2 (`onUpgrade` 1→2) e o teste "abre um banco v1 com registros e migra" também ficam para a F1. Sem uma
  tabela nova, não há o que migrar. A F0 deixou só o mecanismo, e o `onUpgrade` ainda não roda em nenhum teste.

Pendências:
1. **Firebase acadêmico** — a semente (`node ferramentas/semear-firebase.mjs --reiniciar`) ainda não rodou com Antônio,
   Tiago e as linhas de cuidado. Ela mexe no Firebase do dono e pede o ok dele. Até lá, no Firebase:
   - os pacientes aparecem como só clínicos, sem a aba "Em casa";
   - Antônio não existe.

   As `firestore.rules` não mudaram na F0.
2. **Textos ainda da saúde mental para quem só tem TO.** A F1 (diário com textos da TO) e a F2 (sessões) cuidam disso:
   - no diário, "Tomei tudo" e os sintomas;
   - no Início, "Sua próxima consulta";
   - na TM07, "horários de remédio".
3. **Roteiro no emulador da F0 não feito.** Falta a semente, e não há tela nova com dados.
4. Da revisão, a decidir na F1:
   - Hoje um erro de uma fila que não seja "sem conexão" (por exemplo `acessoNegado`) aborta o `sincronizar()` antes
     da busca, e o "puxar para atualizar" da TM13 passa a lançar por causa de outra entidade. Ainda não afeta nada,
     porque nenhuma fila está registrada.
   - Tabela nova entra também em `BancoLocal.tabelas`, para o "Sair" apagá-la (D20).
5. Da revisão, para a F2 (D29): para paciente que só tem TO, o cuidador ainda vê o atalho "Medicação" na TM08. Nenhuma
   persona passa por isso hoje.

Situação dessas pendências depois da F1:
- 1 e 3 continuam abertas (veja as pendências da F1).
- 2 foi feita no diário (D32); "Sua próxima consulta" e a TM07 ficam para a F2.
- 4 foi decidida (D33), e `registros_casa` está em `BancoLocal.tabelas`.
- 5 continua para a F2.

A 5 foi feita na F2 (D29): a TM08 só mostra "Medicação" para paciente com acompanhamento clínico.

### F1 — "Em casa" (06/11/2026, branch `to-f1-em-casa`)

O que entrou:
- **Domínio:**
  - enums `Ocupacao`, `AdesaoEmCasa` e `QuemRegistrou`;
  - modelos `AtividadeDeCasa` (só leitura) e `RegistroDeAtividade`;
  - regras puras em `lib/dados/regras/programa_em_casa.dart`: vigentes, registro do dia, "esta semana", faixa de 14 dias e resumo de hoje;
  - recusa `atividadeInexistente`.
- **Repositório `RepositorioProgramaEmCasa`:**
  - na memória, com fila e simulação do servidor;
  - na persistência, com atividades por `LeituraComCopia`, registros pelo DAO, `FilaRegistrosCasa` como a primeira `FilaDeEntidade` e o SQLite v2 (`registros_casa`, com teste de migração v1 → v2 que não perde o diário);
  - no Firebase, com `atividadesCasa` só para leitura do titular e `registrosCasa` validado pelas regras;
  - semente nova em `semear-firebase.mjs`.
- **Telas:**
  - TM16 Em casa: resumo de hoje, cartões com "Esta semana: 2 de 3" e a resposta de hoje, e a faixa de 14 dias com legenda e rótulo por dia;
  - TM17 Atividade: o que fazer, "Conseguiu fazer hoje?", reflexão opcional, corrigir e desfazer só hoje, "O dia não permitiu. Tudo bem, é comum." e o histórico do que foi contado;
  - cartão "Atividades de casa" no Início;
  - diário com as palavras da TO (D32) também na TM04, na TM14, na TM15 e no atalho do Início.
- **Demonstração:**
  - 6 atividades: Miguel com 2, Ana com 2 e Antônio com 2;
  - 39 registros em 14 dias, entre eles o copo do Antônio hoje;
  - a avaliação de TO da Ana com o Tiago, há 14 dias;
  - a Laura fica sem atividades de propósito, porque a primeira avaliação dela ainda vai acontecer.
- **Portão:** 627 testes, 18 capturas e a TM17 nas telas reais (alvo de toque, contraste, fonte a 200%).

O que a verificação achou:
- **A fonte a 200% estourava três linhas fixas** ("Hoje: [etiqueta]", "Resposta de hoje" e a legenda da faixa). Elas
  passaram a quebrar linha.
- **Sem conexão, a mensagem repetia o texto do cartão "Guardado no aparelho".** Agora diz só "Registrado, sem conexão
  agora.".
- **A revisão em contexto limpo bloqueou dois pontos. Os dois foram corrigidos e testados:**
  - **TM16 e Início desatualizados.** Depois de registrar com conexão, a TM16 e o cartão do Início continuavam com o
    número antigo. A recarga pela sincronização só dispara quando os pendentes mudam. Além disso, a TM17 estava
    embrulhada no `_VoltaPara`, que troca o voltar por um `go`, e assim o `push` nunca terminava. Agora a TM17
    desempilha (e por link direto a seta vai à TM16), a TM16 relê ao voltar e o Início refaz o resumo quando a aba
    volta a ficar ativa (`RecarregaAoVoltar`).
  - **Faltava o "puxar para atualizar" da TM16.** Ele entrou (`RepositorioProgramaEmCasa.atualizar` → sincronizador).
- **Achados menores da revisão, também corrigidos:**
  - com um registro do mesmo dia vindo de outro aparelho, a correção ia para um registro diferente do mostrado;
  - a fila parava no primeiro item recusado, e agora segue com os próximos (D33);
  - a dica do diário de TO ainda dizia "o sintoma";
  - o `conferir-firebase.mjs` não mostrava os registros de casa.

**Firebase e emulador (06/11/2026, com o ok do dono):**
- As `firestore.rules` novas foram publicadas e compilaram no servidor.
- A semente rodou com `--reiniciar`: 4 contas, 5 pacientes, 19 registros do diário, 6 atividades e 39 registros de
  casa.
- No emulador `Terae_Pixel`, com o APK de depuração e o Firebase real, foi conferido:
  - Antônio entra com e-mail e senha;
  - o Início mostra o diário com as palavras da TO e "Hoje: 1 de 2 registradas";
  - a TM16 lê as atividades e a faixa do servidor;
  - na TM17, "Em parte" → "Registrado. Obrigado por contar!", que só aparece depois da confirmação do servidor; isso
    prova que a regra de criação de `registrosCasa` aceita;
  - de volta à TM16, aparece "Hoje: 2 de 2", o que confirma no aparelho a correção da revisão;
  - "Desfazer" → o servidor mostra o registro DESFEITO, o que prova a regra de atualização.
- Todas as passagens foram conferidas com `node ferramentas/conferir-firebase.mjs a0000000-0000-4000-8000-000000000005`.
  As capturas estão em `docs/evidencias-f1/`.
- Ficou no servidor o registro desfeito de hoje do "Abotoar". Para voltar ao início, rode a semente com `--reiniciar`.

Pendências da F1:
1. **Partes do roteiro que não foram feitas no aparelho:**
   - a fila no modo avião, que tem cobertura nos testes de persistência, e cujo mecanismo é o mesmo que o roteiro da A4
     provou para o diário;
   - a correção, que usa a mesma regra de atualização do desfazer;
   - a voz da Patrícia pelo Miguel, que tem cobertura nos testes de tela.
2. As regras de `registrosCasa` continuam sem teste automático, porque o projeto não usa o emulador de regras. Elas
   foram provadas só pelo roteiro acima.
3. **Para a F2:** "Sua próxima consulta" no Início, "horários de remédio" na TM07 e o atalho "Medicação" do cuidador
   para quem só faz TO.
4. **Da revisão:**
   - Se o servidor recusar o registro por algo que não seja "sem conexão", a TM17 mostra o erro, mas o registro fica na
     fila e aparece como "Guardado no aparelho". Nenhuma recusa realista dispara isso hoje.
   - O `metaId` da atividade entra na F3.

O item 3 foi feito na F2.

### F2 — Sessões, presença e lembretes (06/11/2026, branch `to-f2-sessoes`)

O que entrou:
- **Presença (D27):**
  - `ConfirmacaoDePresenca` e `RespostaPresenca`. Os textos são "Sim, vamos" ou "Não vamos conseguir", e o titular lê
    "Sim, vou" ou "Não vou conseguir".
  - Uma resposta por agendamento, que pode mudar até o horário da sessão (`regras/presenca.dart`) e nunca cancela a
    sessão.
  - Fica na memória e no SQLite v3 (`confirmacoes_presenca`), com a `FilaConfirmacoes`.
  - No Firestore, em `pacientes/{pid}/confirmacoes/{agendamentoId}`. As regras conferem a sessão marcada e que
    `respondidaEm` é anterior a ela (como texto ISO UTC), e o cuidador lê.
- **TM18 Sessões** (`/paciente/sessoes`, aberta pelo cartão da próxima sessão no Início e por uma sessão ou consulta
  da Jornada):
  - as próximas, com "Vocês vão?" ou "Você vai?";
  - "Falar com a clínica", com ligar e WhatsApp para o número fictício `(65) 0000-0000`, que começa com 0 e não chama
    ninguém;
  - as anteriores, como "Realizada" ou "Cancelada".
- **Textos de TO** (pendência 3 da F1):
  - "Sua próxima sessão" ou "Próxima sessão de Miguel" no Início, com a resposta de presença no cartão;
  - "Sessão de terapia ocupacional com …" na Jornada, com o rótulo "Sessão";
  - a TM07 diz "a agenda de sessões e a rotina" e não fala de remédio para quem só faz TO (nem no rodapé nem ao
    revogar);
  - TM08 e TM12 chamam a TO de sessão ("Sessão cancelada").
- **Cuidador (D29):**
  - vê "Presença confirmada" ou "Avisaram que não vão" (`respostasDePresenca`);
  - "Medicação" (o atalho, o bloco do próximo remédio e a rota `cuidadorMedicacao`, pela guarda
    `doAcompanhamentoClinico`) só aparece para paciente com acompanhamento clínico.
- **Lembretes locais (D28):**
  - `flutter_local_notifications` 22 e `timezone`, no fuso `America/Cuiaba`, sem alarme exato.
  - Véspera de cada sessão ou consulta (18:00 a 21:00), e atividades de casa todo dia (8:00, 12:00, 18:00 ou 20:00),
    para quem faz TO. São agendadas uma a uma para os próximos 7 dias.
  - As abas do paciente (`ReagendaLembretes`) refazem tudo ao abrir, ao voltar do segundo plano, ao voltar ao Início
    e ao fim de cada sincronização.
  - O texto é genérico: "Amanhã às 14:00 tem compromisso na clínica.", "Hora das atividades de casa.".
  - **TM19 Lembretes** (menu do Início) explica antes por que o Android vai perguntar (só para quem ainda não deu a
    permissão), pede a permissão do Android 13+ ao salvar, mostra os próximos e manda um lembrete de teste.
  - As preferências ficam em SharedPreferences. "Sair" cancela tudo e apaga.
  - Android: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, receivers do plugin e desugaring.
- **Demonstração:** a Ana já confirmou a consulta com a Dra. Helena. Miguel e Antônio ainda não responderam, para a
  pergunta aparecer.

- **Portão:** 689 testes, 21 capturas (TM18 e TM19 novas) e a TM18 e a TM19 nas telas reais.

O que a verificação achou:
- **A revisão em contexto limpo bloqueou sete pontos.** Cinco foram reproduzidos com testes que falhavam antes; os sete
  foram corrigidos e testados:
  - **A TM18 continuava com "Guardado no aparelho" depois que a fila saía.** Agora ela relê pela sincronização
    (`RecarregaAoSincronizar`), e o "puxar para atualizar" envia a fila e busca o servidor
    (`RepositorioPresenca.atualizar`).
  - **A TM18 não abria pela Jornada**, como o plano pede. Agora a sessão ou consulta da Jornada abre a TM18.
  - **Os lembretes só eram refeitos na primeira carga do Início.** Com o app vivo em segundo plano por mais de 7 dias,
    os de casa acabavam sem aviso. O reagendamento saiu do Início e foi para as abas (`ReagendaLembretes`).
  - **"Sair" durante um reagendamento deixava lembretes agendados.** O `reagendar` lia a agenda (até 2 s por paciente)
    e agendava depois do `cancelAll` do "Sair". Agora os `reagendar` rodam em fila, e o "Sair" faz o que estiver em
    curso desistir.
  - **A hora padrão das atividades (18:00) não estava entre as opções da TM19.** As opções passaram a 8, 12, 18 e 20,
    ficam junto da hora padrão, e hora guardada fora delas volta à padrão.
  - **Faltava o texto que explica o pedido de permissão.** Ele aparece antes de salvar, só para quem ainda não deu.
  - **Entregas sem teste:** Jornada com "Sessão", TM07 de quem só faz TO, TM08 sem "Medicação" para quem só faz TO,
    reagendamento pelas abas e `LembretesLocais` com o plugin de mentira (fuso, sem alarme exato, "Sair" e ordem).
- **O teste novo da TM07 achou mais um texto** que a revisão não viu: o rodapé ("Cuidadores veem só sua agenda, seus
  horários de remédio…") e a confirmação de revogação falavam de remédio para quem só faz TO.
- **Do "registra e segue" da revisão, corrigido:**
  - a TM08 caía inteira quando a leitura das respostas falhava; agora a agenda e os avisos aparecem sem elas;
  - a busca recusada de uma fila derrubava a busca dos pacientes seguintes; agora vai ao log e o resto segue;
  - a fila marcava como enviada a resposta lida antes do envio, e uma troca feita no meio podia se perder;
  - o `conferir-firebase.mjs` não mostrava `confirmacoes`;
  - na demonstração (web), o "Sair" não apagava as escolhas de lembrete;
  - "Consulta" na Jornada e na TM12 para a TO;
  - `calcularLembretes` engolia qualquer erro (agora só a recusa), e a TM19 não tinha `try` (podia ficar em
    "Salvando…").
- **No emulador, depois das correções:** a Jornada abre a TM18 e o voltar traz de volta; a TM19 manteve a véspera às
  19:00, não mostra o texto da permissão (já dada) e o alarme foi refeito ao abrir o app.

Desvios conscientes:
- O `flutter_local_notifications` ficou em `^22.0.0`. A 23 exige o compileSdk 37, que não está instalado, e instalar
  pede aceitar a licença do Android SDK. A 21 conflita com o `connectivity_plus`.
- O lembrete das atividades não usa repetição diária do plugin: são 7 agendamentos, refeitos pelas abas. Assim um
  programa encerrado ou uma preferência mudada valem sem estado no plugin. Quem não abrir o app por mais de 7 dias
  fica sem o lembrete das atividades até abrir de novo.
- Na Jornada, o rótulo "Sessão" fica acima de "Sessão de terapia ocupacional com …", como "Consulta" ficava acima de
  "Consulta com …".
- A confirmação leva `id` (= `agendamentoId`) no mapa, porque a `LeituraComCopia` usa `id` como chave.

**Firebase e emulador (06/11/2026, com o ok do dono):**
- As `firestore.rules` com `confirmacoes` foram publicadas e compilaram no servidor.
- A semente rodou com `--reiniciar`: 4 contas, 5 pacientes e 19 registros do diário, com a consulta da Ana já
  confirmada.
- No emulador `Terae_Pixel` (Android 16), com o APK de depuração e o Firebase real, foi conferido:
  - **Lembretes (Antônio):**
    - a TM19 pediu a permissão do Android ao salvar a véspera às 19:00;
    - o sistema registrou o alarme de 12/11 às 23:00 UTC (19:00 na clínica, véspera da sessão de 13/11 às 08:00);
    - o lembrete de teste chegou no canal `lembretes`, com visibilidade privada;
    - depois das correções da revisão, o alarme foi refeito ao abrir o app, e a TM19 não mostrou mais o texto da
      permissão, já dada.
  - **"Sair":** os alarmes pendentes do app caíram de 1 para 0.
  - **Presença (Antônio, depois de entrar de novo):** "Sim, vou" → "A clínica recebeu sua resposta.". O servidor
    mostrou `vamos`, enviado, o que prova a regra de criação.
  - **Sem conexão:**
    - "Mudar a resposta" → "Não vou conseguir" → "Guardado no aparelho", com 1 registro aguardando envio;
    - com a rede de volta e sem nenhum toque, a TM18 passou sozinha a "A clínica foi avisada…", o que confirma no
      aparelho o achado 1 da revisão;
    - o servidor mostrou `naoVamos`, enviado, com a hora em que a resposta foi dada, o que prova a regra de
      atualização;
    - o Início passou a "Avisou que não vai".
  - **Jornada:** a sessão abre a TM18, e o voltar traz de volta.
  - **Cuidadora (Regina):** a TM08 e a TM12 mostram "Presença confirmada" na consulta da Ana, sem conteúdo clínico,
    o que prova a regra de leitura do cuidador.
- Todas as passagens foram conferidas com `node ferramentas/conferir-firebase.mjs`. As capturas estão em
  `docs/evidencias-f2/`.
- Ficou no servidor a resposta "não vou" do Antônio. Para voltar ao início, rode a semente com `--reiniciar`.

Pendências da F2:
1. As regras de `confirmacoes` continuam sem teste automático, porque o projeto não usa o emulador de regras. Elas
   foram provadas só pelo roteiro acima.
2. **Limitações declaradas:**
   - com várias contas no mesmo aparelho, os lembretes são da última que abriu as abas do paciente. Com a Patrícia,
     eles cobrem Miguel e Laura juntos;
   - o cuidador lê o documento inteiro de `confirmacoes`, com o `respondidaEm`, porque a regra não escolhe campos na
     leitura. O app mostra a ele só a resposta, e nenhum dos campos é dado clínico;
   - o `respondidaEm` vem do aparelho, porque a resposta pode chegar depois pela fila. Quem antedatar consegue trocar
     a resposta depois da sessão (como na D31);
   - se a sessão for cancelada no servidor enquanto a resposta espera na fila, a regra recusa e ela fica "aguardando
     envio" (D33). Hoje nada no app cancela sessão, porque não existe o lado da clínica.

### F3 — Metas e progresso (06/11/2026, branch `to-f3-metas`)

O que entrou:
- **Metas (D35):**
  - `MetaTerapeutica` e `SituacaoMeta`, com a regra pura em `regras/metas.dart`: a ordem da Jornada (por área da
    vida; dentro dela, as em andamento pelo prazo, depois as alcançadas e as que saíram de cena) e o dia da alta.
  - `RepositorioMetas`, com a memória e o persistente (`LeituraComCopia` sobre `pacientes/{pid}/metas`).
  - O titular lê as metas no Firestore; o cuidador, não. Só a semente grava.
- **Jornada (TM06):** "Nossas metas", por área da vida, com a situação e, na meta em andamento, o prazo. Tocar numa
  meta abre a TM20. Só aparece para quem faz TO.
- **TM20 Meta** (`/paciente/meta?id=`, empilhada):
  - a meta, com quem foi combinada, quem acompanha, a situação, a área da vida e o prazo;
  - "O que ajuda em casa", com as atividades ligadas, que abrem a TM17;
  - os marcos da meta e uma nota: "Para mudar uma meta, fale com a clínica.";
  - meta de outro paciente ou inexistente: "Não encontramos esta meta"; por link direto, a seta vai à Jornada.
- **Ligações (D37):** a TM16 diz "Ajuda na meta: …" em cada atividade, e a TM17 tem o cartão "Esta atividade ajuda
  na meta", que abre a TM20. Na Jornada, os marcos "Meta alcançada" e "Alta" ganham ícone próprio, e o marco de uma
  meta abre a TM20.
- **Alta (D36):** a TM16 mostra "Programa encerrado" com o dia da alta, um botão para a Jornada e a faixa dos 14 dias.
- **Demonstração:**
  - Miguel: "Vestir a camiseta sozinho…", "Brincar de massinha…" e "Segurar o lápis com a pinça dos dedos"
    (alcançada, com o marco);
  - Ana: "Ir à escola 4 de 5 dias da semana" e "Deitar até as 23h…", com o Tiago;
  - Antônio: "Vestir a camisa de botão sozinho", "Tomar o café da manhã sem ajuda" e "Escovar os dentes com a mão
    mais fraca" (alcançada, com o marco);
  - as 6 atividades de casa e os "próximos passos" do Miguel e do Antônio apontam para as metas; Laura fica sem metas.
- **Firestore e ferramentas:** `metas` na lista do titular em `firestore.rules`, na semente e no
  `conferir-firebase.mjs`.
- **Portão (antes da revisão):** 723 testes e 23 capturas (TM20 e a TM16 depois da alta, novas).

Desvios conscientes:
- O contrato das metas é próprio (`RepositorioMetas`) e não um método a mais do programa em casa: a Jornada, a TM16,
  a TM17 e a TM20 leem as metas, e o padrão sem metas serve aos dublês.
- Nenhuma persona tem alta (D36). O teste do inventário de marcos da demonstração passou a não exigir o tipo "Alta".
- O prazo aparece só na meta em andamento (D35).

O que a verificação achou:
- **A revisão em contexto limpo bloqueou três pontos, os três reproduzidos e agora cobertos por testes:**
  - **A TM16 ficava com o dia velho** quando o registro era feito pelo caminho Jornada → TM20 → TM17: com conexão,
    os pendentes não mudam e nada relia a aba. Agora a TM16 relê também ao voltar à aba (`RecarregaAoVoltar`).
  - **A TM17 de baixo não relia** na pilha TM17 → TM20 → TM17, e o "Registrar" nela trocava, sem aviso, o registro
    feito na de cima (a reflexão sumia). Agora o cartão da meta espera a TM20 desempilhar e a TM17 relê.
  - **"Programa encerrado" seguia só o marco, mas o registro segue a vigência:** depois de uma alta antiga e da volta
    à TO, a TM16 escondia as atividades enquanto o Início e a TM17 as aceitavam. Agora o encerrado exige alta e
    nenhuma atividade valendo hoje (D36).
- **Do "registra e segue" da revisão, corrigido:**
  - a cópia local das metas guardava o documento inteiro do servidor; agora guarda só os campos do modelo, e a
    semente grava só esses campos (D25);
  - a alta preparada no teste deixava registro depois da alta; agora ela é hoje às 10h, depois do registro das 8h10;
  - "Nossas metas" que não pôde ser lida sumia sem volta; a Jornada ganhou "puxar para atualizar" e relê quando a
    sincronização termina, e a TM20 diz quando as atividades não puderam ser lidas, em vez de "nenhuma";
  - o teste de "quem não faz TO" não testava o filtro; agora a Ana sem TO tem metas na memória e não as vê;
  - o "nenhuma persona tem alta" ganhou o `expect`, e os estados da TM20 (falha com "Tentar de novo", sem
    atividade ligada) ganharam teste.
- **Portão depois das correções:** 730 testes e 23 capturas.

**Firebase e emulador (07/11/2026, com o ok do dono):**
- As `firestore.rules` com `metas` foram publicadas e compilaram no servidor.
- A semente rodou com `--reiniciar`: 4 contas, 5 pacientes, 19 registros do diário e 3 metas para o Antônio e 3 para o
  Miguel (o `conferir-firebase.mjs` mostra as metas sem escore).
- No emulador `Terae_Pixel` (Android 16), com o APK de depuração e o Firebase real, o Antônio entrou de novo e foi
  conferido:
  - **Jornada:** "Nossas metas", em Autocuidado, com "Em andamento" e os prazos, e a alcançada por último. Isso prova
    a regra de leitura do titular.
  - **TM20:** "Vestir a camisa de botão sozinho", "Combinada com Antônio e a família", "Acompanhada por Tiago
    Moreira", a atividade "Abotoar…" e o marco "Vestir a camisa sozinho", ligados pelo `metaId` vindo do servidor.
  - **TM17 pela meta:** o cartão "Esta atividade ajuda na meta"; "Sim" → "Registrado. Obrigado por contar!", com o
    registro no servidor como enviado.
  - **Achado 1 da revisão, no aparelho:** depois de voltar à Jornada e tocar na aba Em casa, a TM16 passou sozinha a
    "Hoje: 2 de 2 atividades registradas", com "Ajuda na meta: …" em cada atividade.
  - **Marco "Meta alcançada":** com o troféu na história; ele abre a TM20 da meta alcançada, sem prazo e com "Nenhuma
    atividade de casa ligada a esta meta agora".
- As capturas estão em `docs/evidencias-f3/`.
- Ficou no servidor o registro de hoje do "Abotoar". Para voltar ao início, rode a semente com `--reiniciar`.

Pendências da F3:
1. As regras de `metas` continuam sem teste automático, porque o projeto não usa o emulador de regras. O roteiro
   provou a leitura do titular; a recusa ao cuidador (D29) fica provada só pela regra, que deixa `metas` fora da
   lista do cuidador.

## Atividade 4 — Persistência local e integração com o Firebase (06/11/2026)

Plano: `C:\Users\willi\.claude\plans\crie-um-plano-para-piped-hare.md`. Prazo de entrega: até ~13/11/2026.

### Decisões

Do dono (06/11/2026):

| # | Decisão |
|---|---|
| D12 | Serviço remoto: Firebase (Authentication + Cloud Firestore), plano Spark, projeto acadêmico próprio `terae-app-academico` |
| D13 | Item principal do CRUD: RegistroDiario |
| D14 | Usuários com e-mail e senha (Firebase Authentication); o aparelho nunca grava a senha (RNFM04) |
| D15 | Prazo de 1 semana: sem SQLCipher e sem tela "Minha conta" (cifragem do SQLite fica como limitação declarada) |
| — | Projeto movido para `C:\Users\willi\Projetos\Terae\terae_app` (fora do OneDrive) e a pasta do curso renomeada para `Dispositivos Moveis` |

Do líder, por delegação do dono (06/11/2026):

| # | Decisão |
|---|---|
| D16 | SQLite é a fonte local da verdade: o diário é lido do SQLite e a fila de envio são as linhas `naFila`; as cópias de leitura tentam o servidor por 2 s e caem na cópia local; persistência offline do Firestore desligada |
| D17 | Corrigir e excluir o registro só no mesmo dia civil da clínica; exclusão lógica (`excluidoEm`); alerta já emitido nunca some. Substitui "depois de enviado, o registro não é editado" (A3 §23) |
| D18 | Sem Cloud Functions no Spark, o alerta é avaliado no aparelho e vai no mesmo lote do registro (id derivado do registro: no máximo um); as `firestore.rules` só aceitam alerta de registro grave/crítico |
| D19 | Web e testes continuam na memória (sqflite não roda na web); a memória ganhou e-mail/senha e o CRUD |
| D20 | "Sair" encerra o Firebase e apaga o SQLite e as preferências da conta |

### Pronto (local, sem commit)

- `lib/dados/local/` (SQLite: `banco_local`, `registro_diario_dao`, `cache_dao`; SharedPreferences:
  `preferencias_locais`), `lib/dados/remoto/` (Firestore, hash do convite, falhas → recusas),
  `lib/dados/sincronizacao/` (monitor de conexão, sincronizador, situação para o aviso), `lib/dados/persistente/`
  (os seis contratos sobre Firebase + SQLite e a composição).
- Telas: TM01 com e-mail e senha; TM09/TM10 com o passo 4 "Crie seu acesso"; TM13 Meus registros (lista, busca,
  filtro, puxar para atualizar); TM14 Registro (visualização, excluir); TM15 Corrigir registro; aviso de conexão na
  TM02, TM03, TM08, TM13 e TM14.
- `firestore.rules`, `firebase.json`, `ferramentas/semear-firebase.mjs` (+ `package.json`), `.env.exemplo`;
  permissões `INTERNET` e `ACCESS_NETWORK_STATE` no manifesto principal.
- Portão verde: `dart format` sem mudança, `flutter analyze` sem issue, **541 testes** (16 telas nos testes de
  acessibilidade e capturas, incluindo TM13–TM15).

### Firebase de verdade (06/11/2026)

- Projeto `terae-app-academico` (conta `sevendeploy7@gmail.com`, plano Spark), com e-mail/senha ativado pelo dono,
  app Android `br.edu.unemat.terae_app` registrado pelo `flutterfire configure` e `firestore.rules` publicadas.
- **Região do Firestore: `nam5` (EUA)**, e não `southamerica-east1` como planejado: a primeira publicação das regras
  criou o banco com a região padrão, que não muda depois. Mantida porque os dados são fictícios; registrado no docx.
- Chave da conta de serviço em `C:\Users\willi\Projetos\Terae\.credenciais\` (fora do OneDrive e do git); `.env`
  (fora do git) com o caminho dela e a senha de demonstração, gerada e nunca escrita em chat nem em código.
- Semente rodada; `node ferramentas/conferir-firebase.mjs [pacienteId]` mostra os registros, alertas e contas.

### Roteiro no emulador (06/11/2026), com o Firebase real

Passou: entrar (Ana); registrar online; modo avião → "Registro guardado", aviso "Sem conexão — 1 registro
aguardando envio" e selo na TM13; conexão de volta → a fila saiu sozinha; corrigir para crítico → TM05 "Seu
profissional foi avisado" e alerta + aviso do cuidador no Firestore; excluir (lógico, `excluidoEm`); "Sair";
cadastro do João pelo código `K7M4QX` nos quatro passos (conta, código usado, paciente ligado e consentimento no
Firestore, pelas regras); Regina vê o aviso novo na TM12 sem ver o diário. Capturas em `docs/evidencias-a4/`.

Achou e corrigiu (com teste de regressão):
1. o histórico do servidor só chegava ao SQLite na sincronização seguinte à entrada — agora a entrada sincroniza;
2. TM13/TM14 não se atualizavam depois que a fila saía — agora recarregam ao fim da sincronização;
3. bloqueio por muitas tentativas aparecia como "sem internet" — agora `muitasTentativas`.

Observação do roteiro: o primeiro login logo depois de instalar pode passar dos 10 s do Authentication e mostrar
"Sem internet agora"; a segunda tentativa entra.

### Pendências da Atividade 4

1. Feito em 06/11: commits `8c10d1b` (código) e `3976154` (documentação), mesclados na `main` local em `a949f38`,
   sem envio (não há remoto). Se o dono quiser, ainda falta o docx "Resumo".
2. Passar à equipe a senha de demonstração (está no `.env` do dono) — ou cada um usa o primeiro acesso.
3. Ajustar a data da versão 4.0 no `gerar_docx.py` (`DATA_DA_VERSAO`) se a entrega não for em 13/11.

## Pronto na Atividade 3 (main `d1b91e0` + documentação)

- As 13 telas da Atividade 3 (TM00–TM12, mais a seleção de perfil da TM01), o roteador com a guarda de perfil, as 12
  entidades e os 11 enums, e os repositórios em memória com a demonstração das personas.
- Portão verde: `dart format` sem mudança, `flutter analyze` sem issue e **477 testes** em 36 arquivos (`test/dados`,
  `test/funcionalidades`, `test/nucleo`, `test/acessibilidade`, `test/capturas`, `test/arquitetura_test.dart`).
- Acessibilidade: as 13 telas passam nos guias de alvo de toque (Android e iOS), rótulo, contraste e fonte a 200%
  em 360×800.
- 14 capturas determinísticas em `docs/capturas/` (720×1600, geradas no Windows).
- APK de depuração e build web gerados. O caminho crítico da §12 (Entrar → Ana → diário crítico em 5 toques → TM05
  com 188/192 e "profissional avisado" → voltar leva ao Início) foi conferido no emulador Android 16.
- Como acessar: seção "Como acessar localmente" do `README.md`.

## Decisões da Atividade 3 (líder, por delegação do dono, 02/10/2026)

Do plano:

| # | Decisão |
|---|---|
| D1 | Repositório próprio em `Terae/terae_app`, fora do monorepo do produto; caminho ASCII (o Gradle falha com "Móveis"); em 06/11 confirmado: dentro do OneDrive também não compila |
| D1b | Identificador `br.edu.unemat.terae_app`; selo "Projeto acadêmico — UNEMAT 2026"; sem publicação em loja |
| D2 | Flutter 3.47, Android 8+ (minSdk 26) e **iOS 15+**: o Flutter 3.47 não suporta iOS < 15, então o RNFM06 precisa de ajuste |
| D3 | Dependências do §24 mais o `url_launcher`, para ligar para 188/192 com um toque; Lexend embarcada; UUID v4 próprio |
| D4 | Ícones Material, no lugar dos lucide do protótipo |
| D5 | Login Google/Apple simulado ("Escolha uma conta"); Apple só no iOS — **superada pela D14 na Atividade 4** |
| D6 | Nada persiste no aparelho nesta etapa (RNFM04 cumprido por ausência) — **superada pela D16 na Atividade 4** |
| D7 | Fuso da clínica fixo em −04:00, com `Relogio` injetável |
| D8 | Enums com a grafia do docx (`moderada`, `critica`) |
| D9 | Datas da demonstração relativas a hoje |
| D10 | Seletor com estado semântico, texto ≥ 14 sp, e a TM04 não volta sozinha com leitor de tela |
| D11 | Painel de demonstração (sem conexão, reiniciar dados) só em modo depuração |

Da revisão:

- Criança (menos de 12 anos completos, no fuso da clínica) só é ativada pelo responsável legal (ECA art. 2º; LGPD
  art. 14 §1º). Adolescente e adulto podem ser titulares.
- Religar a conexão reenvia a fila, e o alerta do registro crítico que estava na fila nasce nesse momento.
- O id do rascunho do diário fica o mesmo até o envio ser confirmado, e "Tentar de novo" reenvia o mesmo registro.
  A TM04 diz "Enviando…" até a resposta, e a TM05 mostra a falha mantendo 188/192.
- A cópia do cuidador é montada por lista branca de campos: a receita vai sem orientação e sem profissional.
- Convite expirado não conta no limite de 2 cuidadores, e o CPF dele pode ser convidado de novo.
- Opções de sintoma (Tristeza, Ansiedade, Cansaço, Dor, Sono ruim, Falta de ar, Outro, Nenhum em especial) vêm dos
  exemplos do protótipo; nenhum texto é obrigatório (RNFM02).

## Pendências da Atividade 3

1. **Re-revisão das 6 correções** (`670f734..b4e7a53`) em contexto limpo. Foi interrompida pelo limite semanal antes
   de reportar. Uma das correções resolveu achado bloqueante (criança como titular). Os testes que reproduziam cada
   achado passam.
2. **Documentação da Onda 4**, que também foi interrompida:
   - `docs/rastreabilidade.md`: RFM/RNFM → tela → arquivo → teste;
   - `docs/ajustes-atividade3.md`: rascunho para a v4.0 do docx (RNFM06 → iOS 15; TM05 só para crítica; limite com
     pendentes não expirados; corte de 12 anos; D10; `AvisoDeAlerta` na visão do cuidador; recorte acadêmico × PWA);
   - `.github/workflows/flutter.yml`, só local, com `@Tags(['capturas'])` no teste de capturas, porque as imagens
     divergem fora do Windows.
3. **GitHub**: o dono escolheu "só local por enquanto". Criar `SevenDeploy/terae-app` e convidar a equipe só com novo
   ok dele.
4. **Diferenças visuais em relação ao protótipo**, aceitas por ora:
   - a TM02 não tem o cartão "Seu próximo remédio";
   - "Tomei uma parte" quebra em 3 linhas a 360 dp;
   - a demonstração não tem consulta cancelada futura, então esse aviso da TM12 não aparece.
5. Prazo e formato de entrega da Atividade 3 dependem do enunciado, que não está no disco.
