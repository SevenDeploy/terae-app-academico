# Ideias do terae_app para o portal da família do Terae

26/11/2026. O app Flutter acadêmico (`terae_app`, disciplina de Dispositivos Móveis) foi feito como se fosse o app que a
família de uma clínica de TO usaria (evolução livre de TO, F0–F3, decisões D21–D37 em `docs/estado.md`). Algumas
soluções dele podem melhorar o portal real (`terae/apps/portal`, React, versões 2.0–2.3). Este documento junta essas
ideias e diz, para cada uma, o porquê, onde ela entra no portal, o que falta na API e um quadro sugerido.

Nada aqui é código do portal. As ideias viraram as tarefas **578 a 585** de `terae/docs/plano/tarefas.md` (com um
resumo no bloco "DPO, família e operador do Terae" de `terae/docs/plano/fila-por-perfil.md`). O app continua sem
ligação com a API ou com os dados do produto (CLAUDE.md do app): o caminho é só de ideias.

## O que já existe no portal (para não repetir)

Conferido no código da `main` local do `terae` (`487770a2`) em 26/11/2026:

| No app | No portal hoje |
|---|---|
| Voz em primeira ou terceira pessoa (D24) | Já existe: `tratamentoDoPaciente(nome, perfil)` em `apps/portal/src/estado/tratamento.ts`, usado no Início, na Agenda, no Programa, no diário, nos recibos e no seletor ("Como foi o seu dia?" para o titular, "Como foi o dia de Helena?" para os responsáveis). Falta só a conferência do resto (ideia 6) |
| Lembrete de véspera da sessão (D28, 18:00–21:00) | Já existe como Web Push da 2.1 (`lembrete_de_sessao`, janela 18:00–21:00 da clínica, `packages/domain/src/identidade/pushDaFamilia.ts`), ligado por padrão |
| Lembrete das atividades de casa (D28) | Existe em parte: o push `programa_do_dia` sai entre 17:00 e 19:00, só se ainda faltar registrar, e nasce desligado. A família **não escolhe o horário** (no app: 8:00, 12:00, 18:00 ou 20:00) |
| "Falar com a clínica" (TM18) | Só na ajuda imediata (`Ajuda.tsx`, "Ligar para a clínica" com o `telefoneDaClinica` do `GET /api/portal/eu`). A Agenda não tem |
| Faixa dos 14 dias por atividade (TM16/TM17) | Só do lado da clínica: `EsquemaAdesaoDaOrientacao.dias` em `GET /api/v1/pacientes/{id}/programa-domiciliar/retorno`. O portal só mostra o registro de hoje (`registroDeHoje`) |
| Metas e marcos (TM06, TM20, D35–D37) | Nada no portal. A meta existe no plano terapêutico (`packages/contratos/src/prontuario/plano.ts`, `EsquemaMeta`) e a orientação já aponta para ela do lado da clínica (`EsquemaMetaDaOrientacao`), mas `EsquemaOrientacaoNoPortal` não a expõe |
| Diário com as palavras da TO (D32) | O portal usa as palavras do F04 para todos ("Fizemos tudo / parte / não deu"; "O quanto atrapalhou") |

## Duas travas antes das ideias 1 e 7 (decisão do dono)

A ADR-0023 (portal da família) diz duas coisas que as ideias de metas e de alta esbarram:

- **"Nenhuma evolução clínica aparece no portal, nem anamnese, avaliação, escore, relatório, anexo"** (decisão 7).
  A meta do plano não está na lista, mas é parte do prontuário. Mostrar a meta **sem escore, nível GAS, peso, critério
  nem relevância** (como o app faz, D25/D35) é uma exceção nova, como foi a do financeiro na 2.3.1 (ADR-0025).
- **"A alta tira o paciente do portal"** (decisão 6, regra de `pacienteEmAlta`). Então um marco "Alta" e um "Programa
  encerrado" no portal, como na TM16 do app (D36), não aparecem para ninguém hoje: a família perde o acesso no mesmo
  dia. Mostrar a alta pede outra mudança da ADR (por exemplo, um período só de leitura depois da alta).

Por isso a tarefa 578 nasce **bloqueada, com o dono**: o resto pode andar sem ela.

---

## 1. Metas e marcos ("Meta alcançada", "Alta", "Programa encerrado") — tarefa 578

**Por quê.** No app, a família vê para que serve cada atividade de casa ("Ajuda na meta: vestir a camiseta
sozinho") e comemora quando a meta é alcançada. A adesão sobe quando a tarefa tem sentido; para a TO, é a intervenção
centrada na família (`combinadaCom: 'familia'`) chegando a quem faz a atividade. Hoje a família recebe a orientação
solta, sem saber o objetivo.

**Onde entra no portal.**
- Uma tela nova **"Metas"** (`/metas`, e o detalhe em `/metas/:codigo`), aberta por um cartão no Programa e, no
  telefone, pelo menu "Conta" ou por uma quinta entrada da barra só se couber (no app, "Cuidadores" saiu da barra por
  falta de espaço, D22).
- No **Programa** (`Programa.tsx`), cada orientação ganha a linha "Ajuda na meta: …", que abre o detalhe.
- O detalhe mostra a meta, a área da vida (`ocupacao`), com quem foi combinada, a situação em palavras ("Em
  andamento", "Alcançada", "Interrompida", "Substituída por outra"), o prazo só na meta em andamento, as orientações
  ligadas e a nota "Para mudar uma meta, fale com a clínica.".
- O marco "Meta alcançada" é o `alta.emIso` da meta com `situacao: 'atingida'`; "Alta" e "Programa encerrado"
  dependem da segunda trava acima.

**O que falta na API.**
- Recurso novo na `MATRIZ_DO_PORTAL` (por exemplo `portal_metas`), **sem o cuidador** (no app, o cuidador não lê
  metas, D29/D35), com a função do banco do mesmo jeito das outras (`app.pacientes_da_conta`).
- `GET /api/portal/metas`: as metas dos planos em andamento do paciente escolhido, só com `codigo`, `descricao`
  (≤ 300), `ocupacao`, `combinadaCom`, `situacao`, `prazoIso` (só na ativa), `alcancadaEm` (só na atingida) e o
  primeiro nome de quem acompanha. **Nunca** `niveis`, `criterio`, `relevancia`, `apoios`, `peso`, `alcance` nem o
  `motivo` da alta da meta (texto clínico).
- Campo novo `meta?: { codigoMeta, descricao }` em `EsquemaOrientacaoNoPortal` (PMC), tirado da
  `EsquemaMetaDaOrientacao` que a orientação já tem do lado da clínica.
- A trilha da leitura (`gravarNaTrilha`), como nas outras rotas do portal.

**Quadro sugerido (telefone).**
```
┌──────────────────────────────────────┐
│ ← Metas de Miguel                    │
│                                      │
│ AUTOCUIDADO                          │
│ ┌──────────────────────────────────┐ │
│ │ Vestir a camiseta sozinho        │ │
│ │ Em andamento · até 15/12         │ │
│ │ Combinada com a família · Ana    │ │
│ └──────────────────────────────────┘ │
│ BRINCAR                              │
│ ┌──────────────────────────────────┐ │
│ │ ★ Segurar o lápis com a pinça    │ │
│ │ Alcançada em 03/11               │ │
│ └──────────────────────────────────┘ │
│ Para mudar uma meta, fale com a      │
│ clínica.                             │
└──────────────────────────────────────┘
```

## 2. Faixa dos 14 dias e histórico por orientação — tarefa 579

**Por quê.** No app (TM16 e TM17), cada atividade mostra 14 quadradinhos, do mais antigo ao de hoje: feito, em parte,
não deu ou sem registro. A família vê a constância sem número nem nota, e a conversa com a TO fica mais fácil ("na
semana passada não deu quase nada"). No portal, a família só vê o registro de hoje e perde o que fez ontem.

**Onde entra no portal.** No **Programa**: a faixa embaixo de cada orientação, e um toque abre o histórico da
orientação (`/programa/:idOrientacao`) com os dias e as próprias reflexões desta conta.

**O que falta na API.**
- Campo novo `ultimos14Dias: { dia, situacao }[]` em `EsquemaOrientacaoNoPortal` (PMC), com a mesma regra do
  `EsquemaAdesaoDaOrientacao.dias` da clínica (`EsquemaSituacaoDoDia`, dia civil da clínica, ADR-0013) — de
  preferência a mesma função do domínio, para as duas telas contarem igual.
- `GET /api/portal/programa/{idOrientacao}/historico`: os dias e **só as reflexões desta conta** (a regra do
  `registroDeHoje`: a reflexão de outra conta nunca sai). O cuidador, que registra a adesão, também lê a faixa.
- Sem as `reflexoes` da família inteira nem o `previstas` (é um número para a terapeuta, não uma nota para a família).

**Quadro sugerido.**
```
┌──────────────────────────────────────┐
│ Brincar de massinha                  │
│ 3 vezes por semana · de Ana          │
│ ▢▢■■▣▢■▢■■▣■▢●   últimos 14 dias     │
│ ■ feito  ▣ em parte  ▢ sem registro  │
│ [ Registrar hoje ]   Ver histórico › │
└──────────────────────────────────────┘
```

## 3. Lembrete das atividades no horário da família — tarefa 580

**Por quê.** No app, a família escolhe quando lembrar das atividades de casa (8:00, 12:00, 18:00 ou 20:00): a
criança que faz a atividade de manhã antes da escola não ganha nada com um aviso às 18:00. O lembrete de véspera da
sessão já existe no portal e fica como está.

**Onde entra no portal.** Em "Avisos" (`componentes/Avisos.tsx`), embaixo do "Programa do dia": a escolha
do horário, na tela "Minha conta" (`MinhaConta.tsx`), com o texto do push igual ao de hoje (sem dado clínico,
`TEXTO_DO_PUSH` da família).

**O que falta na API.**
- Coluna nova na preferência do push (migração, expand-only) e campo `horarioDoProgramaDoDia` (um de quatro valores
  fixos, para o emissor de 10 em 10 minutos continuar barato) no contrato das preferências do aparelho.
- `JANELA_DO_PROGRAMA_DO_DIA` passa a ser por preferência, mantendo a regra "só se ainda faltar registrar" e a
  marca do dia (`aviso_push_emitido`) para sair uma vez.

**Quadro sugerido.**
```
Programa do dia                     [ligado]
Lembrar às  ( ) 8:00  ( ) 12:00  (•) 18:00  ( ) 20:00
Só avisa se ainda faltar registrar.
```

## 4. "Falar com a clínica" na agenda — tarefa 581

**Por quê.** No app (TM18), quem não pode ir à sessão tem "Ligar" e "WhatsApp" ao lado da lista. No portal, o
"Avisar que não vamos" deixa a sessão marcada "até a recepção ligar"; a família que quer remarcar ou tirar uma dúvida
precisa achar o telefone em outro lugar. O número já chega à tela.

**Onde entra no portal.** Na **Agenda** (`Agenda.tsx`), um cartão no fim da lista (e no estado "agenda não
liberada"), com "Ligar para a clínica" (`tel:`, a mesma `numeroParaLigar` da `Ajuda.tsx`). Sem telefone cadastrado, o
cartão não aparece (a regra da ajuda).

**O que falta na API.** Nada para ligar: `telefoneDaClinica` já vem em `GET /api/portal/eu`. Um botão de WhatsApp
pediria um campo novo (`whatsappDaClinica`, que a coordenação edita) e uma decisão: o WhatsApp é de terceiros e a
conversa sai do Terae. Sugestão: só o "Ligar" agora; o WhatsApp como decisão do dono.

**Quadro sugerido.**
```
┌──────────────────────────────────────┐
│ Precisa remarcar ou tirar uma        │
│ dúvida?                              │
│ [ ☎ Ligar para a clínica ]           │
└──────────────────────────────────────┘
```

## 5. A primeira pergunta do diário pela linha de cuidado — tarefa 582

**Por quê.** O app pergunta à família de TO "E a rotina combinada, deu para seguir?" e "O quanto o dia foi
difícil?" (D32), e à de acompanhamento clínico as perguntas das A3/A4. O portal usa as palavras do F04 para todos
("Atividades: fizemos tudo"; "O quanto atrapalhou" um sintoma). Para a família de uma criança com TO ou ABA,
"sintoma" e "orientações" soam como consulta médica; a palavra certa aumenta a resposta honesta.

**Onde entra no portal.** No formulário do diário (`telas/diario/FormularioDoRegistro.tsx` e `textos.ts`): os
**mesmos valores** (`adesao`: total/parcial/nenhuma; `intensidadeSintoma`: leve…crítico, com o crítico levando à
ajuda imediata), só com outras palavras por linha de cuidado. A lista e o recibo seguem as mesmas palavras.

**O que falta na API.**
- Saber a linha de cuidado do paciente no portal: campo novo em `EsquemaPacienteDaConta` (PMC), por exemplo
  `linhasDeCuidado: ('terapia_ocupacional' | 'aba' | 'psicologia' | …)[]`, tirado das especialidades dos vínculos
  terapêuticos ativos. Sem ela, fica a palavra de hoje.
- O "O que mais pesou hoje?" do app (escolha entre crise, sono, alimentação…) é campo novo do F04 e mexe no link
  público também: fica fora desta tarefa, anotado como ideia futura.

**Quadro sugerido.**
```
Como foi o dia de Miguel?
E a rotina combinada, deu para seguir?
 ( ) Seguimos   ( ) Em parte   ( ) Não deu hoje
O quanto o dia foi difícil?
 ( ) Pouco  ( ) Mais ou menos  ( ) Bastante  ( ) Muito — precisamos de ajuda
```

## 6. Voz em primeira ou terceira pessoa: conferir o que sobrou — tarefa 583

**Por quê.** No app, a voz vem do perfil (D24): o titular lê "você", o responsável e o cuidador leem o nome. O
portal já faz isso pelo `tratamentoDoPaciente`; o risco é uma frase nova escapar (um aviso do Início, um texto de
push, a Conta, os cuidadores, os vazios).

**Onde entra no portal.** Uma varredura das telas e dos textos fixos (`apps/portal/src`), e um teste que monte cada
tela com os três perfis e procure as frases do outro perfil ("de Helena" na conta do titular; "seu dia" na do
responsável).

**O que falta na API.** Nada.

## 7. O cartão do último marco no Início — tarefa 584 (depende da 578)

**Por quê.** A família abre o portal para registrar e sai. Um cartão pequeno com a última conquista ("Miguel
alcançou: segurar o lápis com a pinça — 03/11") dá ânimo e leva às metas. No app, os marcos estão na Jornada; no
portal, o Início é o lugar que todos abrem.

**Onde entra no portal.** No **Início** (`Inicio.tsx`), depois do programa de hoje, só para quem lê metas (não o
cuidador), só se houver marco nos últimos 30 dias. Toque abre o detalhe da meta.

**O que falta na API.** Campo novo `ultimoMarco?: { tipo: 'meta_alcancada', em, descricaoDaMeta, codigoMeta }` em
`EsquemaInicioDoPortal` (PMC), com o refine "o cuidador não recebe", como o `diario`.

**Quadro sugerido.**
```
┌──────────────────────────────────────┐
│ ★ Conquista                          │
│ Miguel alcançou: segurar o lápis     │
│ com a pinça · 03/11                  │
│                          Ver metas › │
└──────────────────────────────────────┘
```

## 8. A semente da homologação com programa e agenda no portal da Alice — tarefa 585

**Por quê.** Na homologação, a conta da Mariana (responsável legal da Alice), a da avó (cuidadora) e a da paciente
adulta entram no portal (`apps/api/src/homologacao/semear-contas-da-familia.ts`), mas o Programa e a Agenda aparecem
vazios: a semente (`semear-homologacao.ts`) cria sessões e registros em casa, mas **não publica um programa em casa**
nem **liga a marca `agenda_no_portal`** do vínculo. Toda demonstração e todo teste manual das ideias 1–7 precisam
disso.

**Onde entra.** `apps/api/src/homologacao/semear-homologacao.ts` (ou a `semear-contas-da-familia.ts`), pelos casos de
uso auditados, como o resto da semente:
- publicar uma versão do programa da Alice com 2 ou 3 orientações ligadas às metas do plano fictício
  (`EsquemaPublicarProgramaDomiciliar`);
- liberar a agenda do vínculo da Mariana (`EsquemaLiberarAgendaNoPortal`), e deixar a do cuidador como a regra mandar;
- idempotente (rodar de novo não duplica), com a contagem nova no relatório da CLI.

**O que falta na API.** Nenhuma rota: só a semente, que já recusa produção.

---

## Ordem sugerida

1. 585 (a semente): é o palco para ver as outras.
2. 581 e 583: pequenas, sem contrato novo.
3. 579 e 580: contrato novo, sem trava de ADR.
4. 582: contrato novo em `EsquemaPacienteDaConta`.
5. 578 e depois 584: só depois da decisão do dono sobre a ADR-0023.
