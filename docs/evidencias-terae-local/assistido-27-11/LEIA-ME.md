# Teste assistido no emulador — 27/11/2026

Emulador `Terae_Pixel` (1080×2400), app `--dart-define=TERAE_FONTE=local` (`http://10.0.2.2:3000`, banco
`terae_app_local`), branch `portal-paridade`. Personas fictícias da homologação: **Laura** (titular adulta), **Rosa**
(avó, cuidadora da Alice) e **Mariana** (responsável legal da Alice). Nenhuma captura mostra senha nem código de e-mail
(o código foi digitado sem captura, e a tela de senha nunca foi guardada). Os códigos saíram do Mailpit local; o banco
foi só lido.

Legenda: PASSOU · FALHOU (achado, corrigido ou registrado) · NÃO TESTÁVEL (e por quê). As capturas ficam nesta pasta.

| Item | Resultado | Captura / observação |
|---|---|---|
| A. Capa e Entrar com "Etapa 1 de 2" e a frase do código | PASSOU | capa e `02-entrar` em `../paridade/` |
| A. Senha errada: mensagem genérica | PASSOU | `A2-senha-errada` |
| A. Código errado: "Você ainda tem 4 tentativas" | PASSOU | `A5-codigo-errado` |
| A. Código certo entra; "Confiar neste aparelho" desmarcado | PASSOU | `A4-codigo-do-email` |
| A. Ajuda do topo: só SAMU/CVV, "não avisa a clínica", sem "Envio pendente" | PASSOU | `A7-ajuda-imediata` |
| B. 5 abas (família) e 4 (cuidador, sem Diário); topo com o primeiro nome e "Ajuda imediata" | PASSOU | `B1`, `B2`, `C1` |
| B. Faixa "Modo cuidador" | PASSOU; o texto não citava o programa → corrigido (`72fb156`) | `B2` |
| B. Seletor de paciente | NÃO TESTÁVEL: as três personas têm um paciente só (coberto por teste de widget) | — |
| C. Início: "Boa noite, Nome.", clínica ao lado da data, cartão da sessão (bloco "Ter 1 dez", "14:00 · 50 minutos"), programa com barra, diário | PASSOU | `B1`, `C1` |
| C. "Confirmar presença" grava no portal (`agendamento.confirmado_em`, canal `portal`) | PASSOU | `C4`, `D3` |
| C. "Mudar a resposta" repetia "Confirmar presença", e o portal respondia 409 com "Esta sessão já começou ou foi cancelada" | FALHOU → corrigido: oferece só o que muda | `C2`, `C3` |
| C. "Avisar que não vamos" (pergunta antes) | NÃO TESTÁVEL ao vivo: o aviso não volta atrás no portal (409), e as sessões da demonstração ficariam avisadas; coberto por teste de widget | — |
| D. Agenda por semana ("Próxima semana", blocos de data) | PASSOU | `D3` |
| D. Agenda da Laura vazia, sem telefone: só o convite a falar com a clínica | PASSOU | `D1` |
| D. "Falar com a clínica" com telefone real e só "Ligar" | NÃO TESTÁVEL: a clínica da homologação não tem `telefoneDaClinica` (coberto por teste) | — |
| D. Agenda que a clínica não liberou (Rosa) parecia "Nenhuma sessão marcada" | FALHOU → corrigido (`72fb156`): "A clínica ainda não liberou a agenda para esta conta." | `D2` |
| E. Em casa vazio (Laura) | PASSOU | `E1` |
| E. Rosa: lista do programa, registrar "Sim" com reflexão, corrigir o próprio (conferido em `registro_programa_domiciliar`) | PASSOU | `E2`, `E4`, `E5` |
| E. Registro de outra conta: 409 amigável "Outra pessoa da família já registrou…" | PASSOU; a mensagem nascia abaixo da dobra → corrigido (rola até ela) | `E3` |
| F. Novo registro: só a adesão obrigatória; "Muito" mostra a ajuda imediata e "A equipe da clínica foi avisada" | PASSOU | `F2`, `F3` |
| F. Voltar ao início e abrir o Diário já traz o registro; o que avisou a equipe não se corrige nem se retira | PASSOU | `F4` |
| F. Corrigir (versão 2), "Ver a versão 1", retirar com motivo (nada é apagado) | PASSOU | `F5`–`F9` |
| F. Sem internet: "Registro guardado neste aparelho." | PASSOU | `F10` |
| F. Sem internet, a lista do diário mostrava só o erro e o guardado sumia da tela | FALHOU → corrigido (`7326de4`); refeito com o app novo | `F11` (antes), `F13` (depois) |
| F. Ao voltar a internet, "Enviar agora" envia o guardado uma vez só (1 linha no banco) | PASSOU | `F12`, `F14` |
| F. Estado vazio do diário | NÃO TESTÁVEL ao vivo: as personas já têm registros das fumaças (coberto por teste de widget) | — |
| G. Rosa não vê Diário, metas, jornada, lembretes nem cuidadores | PASSOU | `G1` |
| H. Conta: seus dados, quem você acompanha, lembretes, Sair | PASSOU | `H1` |
| H. "Sair" revoga a sessão e volta à capa; nada da conta anterior aparece na seguinte | PASSOU (as sessões de senha e de código ficam com `revogada_em`) | — |
| I. Comparação com o portal web | NÃO FEITA ao vivo: a cota de códigos não deu para uma entrada no portal; vale a comparação já registrada em `../paridade/` e em `docs/paridade-com-portal.md` | — |
| Fumaça `ferramentas/fumaca_repositorios_terae_local_test.dart` | PASSOU com a **Laura** (a Mariana só tinha cota de um código, gasto no emulador): leitura e diário (enviar, listar, corrigir, retirar, sair). A primeira corrida da fumaça pegou o código do teste anterior e foi corrigida (`450b1d8`) | — |

## Defeitos achados e corrigidos

1. `7326de4` — **Diário sem internet**: os guardados e os vencidos são lidos antes da rede.
2. `72fb156` — **Agenda não liberada** (texto), **aviso de recusa fora da tela** (rola até ele), **faixa do cuidador**
   cita o programa em casa quando a fonte o tem.
3. Corrigido nesta rodada, junto com o commit final: **"Mudar a resposta"** não repete a resposta de agora.
4. `450b1d8` — a fumaça escolhe o código novo, não o do teste anterior.

## Fica registrado (não corrigido)

- Depois de "Avisar que não vamos", "Confirmar presença" volta 409 e o app diz "Esta sessão já começou ou foi cancelada":
  o texto é do `sessaoEncerrada`. No portal, o aviso não volta atrás; falta um texto próprio para o 409 depois do aviso.
- O cuidador (Rosa) vê "Corrigir" na resposta que outra conta registrou; o portal só mostra "Registrado hoje por…".
- A API limita 10 códigos de acesso por conta em 24 h e um a cada 60 s: rodadas seguidas de teste esgotam a cota.

## Conferência na web da clínica (27/11/2026, noite)

Feita depois dos testes no emulador, pela SPA da terapeuta (`http://[::1]:5201`, atalho de dev sem senha; o Vite escuta só
em IPv6), olhando a tela, não só o banco:

| Do app para a web | Resultado |
|---|---|
| Diário enviado, corrigido (versão 2, "Ver as versões anteriores") e retirado ("Retirado pela família: Enviei sem querer") | Caixa de entrada mostra cada um, "Alice", "pelo portal" |
| Registro escrito sem internet ("Guardado offline Mariana") | Aparece uma vez só, "A revisar" |
| "Confirmar presença" da sessão de 01/12 14:00 | Agenda mostra "Confirmada" e "Confirmada por Portal da família" |

### O caminho de volta, da web para o app (feito pela tela)

A terapeuta marcou "Guardado offline Mariana" como revisada na caixa de entrada da clínica (a resposta saiu de "A revisar").
Depois, no emulador, a Mariana entrou (senha e código do Mailpit; nenhuma captura mostra senha nem código) e viu:

| Web da clínica | App | Captura |
|---|---|---|
| Sessão de 01/12 14:00 "Confirmada por Portal da família" | Início: "Presença confirmada", "Combinado! A clínica recebeu a resposta."; programa de hoje 2 de 3 | `J1-mariana-inicio-presenca-confirmada-na-web.png` |
| "Marcar como revisada" no registro de 17:46 | Diário: selo "Revisado pela terapeuta", "Revisado pela terapeuta hoje, às 19:10. Não dá mais para corrigir nem retirar." | `J2-revisado-na-web-aparece-no-app.png` |

"Sair" revogou a sessão (`sessao_autenticada.revogada_em` preenchido) e o app voltou à capa.

O portal web da família foi aberto lado a lado, com o mesmo login e uma janela de 360×800: os dados são os mesmos e o
Diário é praticamente idêntico; as diferenças estão em `docs/paridade-com-portal.md` (seção "Conferência lado a lado").
Ele foi preenchido por um ajudante local de uma sessão só, que serviu a senha e o código sem passarem pelo chat; "Sair" no
portal revogou a sessão (`revogada_em` preenchido).

O que a revisão visual achou na aba Conta ("Quem você acompanha": o nome quebrava em quatro linhas a 360 dp porque o selo
"Vendo agora" ficava ao lado) foi corrigido em `298f4a3`, com teste.

## Reteste de 28/11/2026 (depois das diferenças do Início e do ajuste da Conta)

App reinstalado no emulador (`flutter run`, fonte local), a Mariana entrou de novo (código lido do Mailpit, sem captura da
tela de senha nem do código) e conferi pela tela: o Início novo (`R1-inicio-depois-da-paridade.png`: iniciais "AF" e nome
inteiro, "Avisar que não vamos" no lugar de "Mudar a resposta", "2 de 3 orientações registradas" com a lista e quem
registrou), a pergunta de avisar ausência (aberta e cancelada com Voltar, porque no Terae local o aviso não desfaz), a
Agenda por semana e a Conta com o nome inteiro e o selo "Vendo agora" embaixo (`R2-conta-quem-voce-acompanha-arrumado.png`).
"Sair" revogou as duas sessões da Mariana no banco. A segunda sessão da Agenda (03/12 08:00, "Presença confirmada") veio
do banco (`canal_confirmacao = portal`, confirmada em 27/11).

Não repeti o portal web neste reteste: a Mariana chegou a 10 códigos em 24 h (o teto). O lado do portal é o da conferência
anterior.
