# Paridade do app com o portal da família

**Para que serve.** O dono pediu, em 26/11/2026, o `terae_app` o mais parecido possível com o portal da família do
Terae web (`terae/apps/portal`, React), porque o app real será feito depois em **React Native** a partir do portal. Este
mapa diz, tela a tela, onde está cada coisa nos dois lados e o que ainda diverge. Quem portar para React Native começa
pela coluna "Portal". O Flutter é o ensaio, e o código de verdade a reaproveitar é o do portal.

Branch: `portal-paridade` (P0–P4). Plano: `~/.claude/plans/queria-o-aplicativo-mais-melodic-lightning.md`.

## Base visual

| Item | Portal (fonte da verdade) | App |
|---|---|---|
| Cores | `packages/ui/src/tokens.css` | `lib/nucleo/tema/cores.dart` (mesmos valores e nomes em português) |
| Fontes | Inter no corpo, Lexend nos títulos (`apps/portal/public/fonts`) | as mesmas, convertidas para TTF em `assets/fonts/` |
| Ícones | `lucide-react` | `lucide_icons_flutter` |
| Cartão, selo, vazio | `componentes/Cartao.tsx` (`Cartao`, `Selo`, `BarraDeProgresso`), `EmptyState` | `nucleo/widgets/cartao.dart` (`Cartao`, `Selo`, `EstadoVazio`), `BarraDeProgresso` em `inicio_tela.dart` |
| Botão | `Button` `lg` + `h-12`, raio 8 | `BotaoGrande` (48, raio 8; primário, secundário, perigo) |
| Faixa sem internet | `FaixaSemConexao.tsx` | `AvisoDeConexao` (faixa escura, texto do portal) |

## Moldura e navegação

| Item | Portal | App |
|---|---|---|
| Barra de baixo | `MolduraDoPortal.tsx` (`NAVEGACAO`): Início, Diário, Em casa, Agenda, Conta | `funcionalidades/moldura/moldura_do_portal.dart` (`AbaDoPortal`, `ramosDoPaciente`) |
| Cuidador | mesma moldura, sem Diário, faixa "Modo cuidador" | `ramosDoCuidador` (Início, Agenda, Conta) + `FaixaModoCuidador` |
| Topo | seletor de paciente + "Ajuda imediata" | `TopoDoPortal`, folha "De quem você quer ver?" (`mostrarEscolhaDePaciente`) |
| Ajuda sem conta | `/portal/ajuda` | `/ajuda` (`Rotas.livres`), TM05 sem registro |

## Telas

| App | Rota do app | Portal | Arquivo do portal | Quadro |
|---|---|---|---|---|
| TM00 Boas-vindas | `/` | painel da `MolduraDeEntrada` | `componentes/MolduraDeEntrada.tsx` | 18a |
| TM01 Entrar (+ código no modo local) | `/entrar` | `/portal/entrar` | `telas/Entrar.tsx` | 18a, 18b |
| TM01b De quem você quer ver? | `/entrar/perfil` | escolha do paciente | `componentes/RotaComSessao.tsx` | 18l |
| TM09/TM10 Primeiro acesso | `/cadastro/*` | `/portal/primeiro-acesso/:token` | `telas/PrimeiroAcesso.tsx` | 18c |
| TM02 Início | `/paciente/inicio` | `/portal` | `telas/Inicio.tsx` | 18d |
| TM03 Diário (lista) | `/paciente/diario` | `/portal/diario` | `telas/diario/Diario.tsx` | 18e |
| TM13 Novo registro | `/paciente/registros/novo` | `/portal/diario/novo` | `telas/diario/FormularioDoRegistro.tsx` | 18e |
| TM04 Registro enviado / guardado | `/paciente/diario/enviado` | `/portal/diario/:id`, `/guardado` | `RegistroEnviado.tsx`, `RegistroGuardado.tsx` | 18f, 19d |
| TM05 Ajuda imediata | `/paciente/diario/ajuda`, `/ajuda` | `/portal/ajuda` | `telas/Ajuda.tsx` | 18g |
| TM14 Registro (versões, retirar) | `/paciente/registros/registro` | `/portal/diario/:id` | `RetirarRegistro.tsx` | 18f |
| TM15 Corrigir registro | `/paciente/registros/corrigir` | `/portal/diario/:id/corrigir` | `FormularioDoRegistro.tsx` | 18f |
| TM16 Em casa (+ Nossas metas) | `/paciente/casa` | `/portal/programa` | `telas/Programa.tsx` | 18h |
| TM17 Atividade | `/paciente/casa/atividade` | (dentro do Programa) | `telas/Programa.tsx` | 18h |
| TM18 Agenda | `/paciente/sessoes` | `/portal/agenda` | `telas/Agenda.tsx` | 18i |
| TM21 Conta | `/paciente/conta`, `/cuidador/conta` | `/portal/conta` | `telas/MinhaConta.tsx` | 18k |
| TM07 Cuidadores | `/paciente/cuidadores` | `/portal/conta/cuidadores/*` | `telas/cuidadores/*` | A1–A7 |
| TM08 Início do cuidador | `/cuidador/inicio` | `/portal` (perfil cuidador) | `telas/Inicio.tsx` | 18j |
| TM12 Agenda do cuidador | `/cuidador/agenda` | `/portal/agenda` | `telas/Agenda.tsx` | 18j |

## Só no app (ideias para o portal, tarefas 578–585 do `terae/`)

Jornada (TM06) e metas (TM20) com os marcos "Meta alcançada" e "Alta", a faixa dos 14 dias por atividade, lembretes
de véspera e de horário (TM19), "Falar com a clínica" na Agenda, a primeira pergunta do diário pela linha de cuidado e
a medicação do acompanhamento clínico (TM11). Detalhes em [`ideias-para-o-portal.md`](ideias-para-o-portal.md).

## Só no portal (melhorias futuras do app)

Segundo fator por código e aparelhos confiáveis (o app só tem no modo Terae local), "Esqueci a senha", avisos push,
recibos, instalar como PWA, rascunho do diário guardado enquanto se escreve, aviso dos 18 anos e o layout de computador.

## Divergências conhecidas

Conferidas em 27/11/2026 com o app no emulador contra o Terae local e o quadro 18d do portal (Design/telas), mais a
tela de entrada do portal rodando em `portal.localhost:5175`. Evidências em
[`evidencias-terae-local/paridade/`](evidencias-terae-local/paridade/LEIA-ME.md).

- **Entrar (modo local):** o portal tem "Etapa 1 de 2", o link "Esqueci a senha", o botão "Continuar →" e a frase
  "Depois da senha, enviamos um código para o seu e-mail." O app mostra "Entrar" sem o indicador na primeira etapa (a
  "Etapa 2 de 2" só aparece com o código) e não tem "Esqueci a senha".
- **Topo:** o portal mostra só o primeiro nome do paciente e o botão "Ajuda imediata"; o app mostra o nome completo e
  "Ajuda". A marca do portal é o símbolo do Terae em minúsculas ("terae"); o app usa um ícone lucide.
- **Início, próxima sessão:** o portal tem o bloco de data (QUI 12 NOV), "14:00 · 50 minutos", "Com Ana · terapia
  ocupacional", a sala e os botões "Confirmar presença" e "Avisar que não vamos" no próprio cartão; o app mostra o nome,
  a especialidade, a data por extenso e as etiquetas, e responde pela aba Agenda. O portal também põe a clínica ao lado
  da data ("Terça, 10 de novembro · Clínica Raízes").
- **Cuidador (Início):** continua o desenho antigo da TM08 ("Olá, Rosa!", "Ver mais", "Conteúdo clínico bloqueado"); o
  portal usa o mesmo Início da família ("Bom dia, Rosa."), com o programa primeiro e o diário bloqueado.
- **Cuidador (programa):** a API local entrega o programa em casa à cuidadora e o portal o mostra, mas a moldura do
  cuidador no app não tem a aba Em casa (só Início, Agenda e Conta).
- **Agenda, "Falar com a clínica":** o telefone ainda é o número fictício fixo do app; o portal usa
  `telefoneDaClinica` do `GET /portal/eu`.

- **Agenda:** o visual é o do portal, mas ainda não agrupa as sessões em "Esta semana" e "Próxima semana".
- **Primeiro acesso:** o termo vem antes da senha (no portal é o contrário), para não mexer na regra do consentimento.
- **Rótulos da barra:** ficam em 14 (D10), não nos 12 do portal. A escala do texto da barra para em 1,15×, para "Em casa" caber
  em 72 dp.
- **Entrada:** a marca usa um ícone lucide no lugar do símbolo do Terae.
- **Fonte Terae local:** sem cópia local. O que a API do portal não tem some pela `CapacidadesDaFonte` (TL5 em `estado.md`).
