# Contratos congelados da fundação (onda 1) e da Atividade 4

Mudar qualquer item abaixo exige combinar com o líder. Detalhe e doc de cada símbolo estão no próprio arquivo.

**Rotas** — `lib/nucleo/rotas/rotas.dart`, nunca string à mão (teste de arquitetura). `Rotas.boasVindas` `/` TM00 ·
`entrar` TM01 · `entrarPerfil` TM01 seleção · `cadastroPaciente` TM09 · `cadastroCuidador` TM10 · `pacienteInicio`
TM02 · `pacienteDiario` TM03 · `pacienteDiarioEnviado` TM04 · `pacienteDiarioAjuda` TM05 · `pacienteJornada` TM06 ·
`pacienteCuidadores` TM07 · `cuidadorInicio` TM08 · `cuidadorMedicacao` TM11 · `cuidadorAgenda` TM12; conjuntos
`publicas`, `doPaciente`, `doCuidador`, `todas`, `porTela`.

**Roteador** — `lib/roteador.dart` (`criarRoteador`, `guardaDePerfil`, `inicioDoPapel`), já completo; telas não decidem
acesso. Sem sessão só públicas (resto → TM00); vários perfis sem ativo → `/entrar/perfil`; com perfil, pública →
início do papel e cada papel só nas próprias rotas. Abas: `StatefulShellRoute.indexedStack` em
`funcionalidades/paciente/abas_paciente.dart` (chaves `aba-inicio|diario|jornada|cuidadores`; voltar fora do Início →
Início). TM04/TM05 no navegador raiz, tela cheia; voltar → Início. TM11/TM12: a TM08 abre com
`context.push(Rotas.cuidadorMedicacao)`; voltar → TM08. Cada tela é um `*_tela.dart` no caminho do §21 com
`Scaffold(key: Key('TMxx'))` — **mantenha a chave**. TM04/TM05 recebem `ResultadoEnvio? envio`: o diário navega com
`context.go(Rotas.pacienteDiarioAjuda, extra: resultado)` (crítica) ou `pacienteDiarioEnviado`, e limpa o formulário
antes (a aba guarda o estado). `EntrarTela(selecaoDePerfil: true)` em `/entrar/perfil`.

**Sessão** — `lib/nucleo/sessao/sessao.dart`. `Papel {pacienteFamilia, cuidador}`; `Perfil(papel, paciente)` (no
cuidador, `paciente` é a cópia sem CPF/nascimento). `Sessao` (ChangeNotifier, só memória): `conta`, `autenticada`,
`perfis`, `perfilAtivo`, `temVariosPerfis`; `entrar(VinculosDaConta)` (um perfil já fica ativo), `escolherPerfil`,
`trocarPerfil` (só com vários), `sair`. **Depois de chamar, não navegue**: o roteador escuta a sessão e leva ao lugar.

**Dependências nas telas** — tudo por provider, acima do roteador: `context.read<RepositorioX>()`,
`context.read<Relogio>()`, `context.read<LancadorExterno>()`, `context.watch<Sessao>()`. Estado de tela num
`*_controlador.dart` (ChangeNotifier) criado com `ChangeNotifierProvider` dentro da própria tela. `TeraeApp(repositorios,
sessao, relogio, lancador, localInicial)` em `lib/app.dart`; `main.dart` só cria — o agente `dados` troca o corpo de
`_criarRepositorios` pela memória.

**Repositórios** — `lib/dados/repositorios/`, `abstract interface class`, tudo `Future`, recusa = `RecusaDeRegra(
MotivoRecusa.x)` com `.mensagem` simples (`falhas.dart`); nenhuma implementação pode ser `Listenable`.
- `RepositorioAutenticacao`: `identidadesNoAparelho(Provedor)`, `entrar(IdentidadeProvedor) → VinculosDaConta`,
  `conferirCodigoPaciente({codigo, cpf, dataNascimento: DataCivil}) → ConviteConferido`, `ativarPaciente({codigo, cpf,
  dataNascimento, qualidade, canalAutorizado, versaoTermo, identidade})` (paciente com menos de 12 anos hoje, no dia
  da clínica, só `responsavelLegal`; senão `MotivoRecusa.criancaComoTitular` — ECA art. 2º, LGPD art. 14 § 1º; regra
  pura em `dados/regras/consentimento.dart`, usada também pela TM09), `conferirConviteCuidador({codigo, cpf})`,
  `aceitarConviteCuidador({codigo, cpf, identidade})`. `VinculosDaConta(conta, pacientes, acompanhados)`.
- `RepositorioPaciente`: `paciente`, `profissional`, `proximaConsulta`, `agendamentos`, `receitaVigente`,
  `itensDaReceita(receitaId)`, `marcos`.
- `RepositorioDiario`: `enviar(RegistroDiario) → ResultadoEnvio(registro, alerta?)` (idempotente pelo id; `.enviado`,
  `.equipeAvisada` — só esta autoriza "profissional avisado"), `reenviarFila`, `registros`, `alertaDoRegistro`.
- `RepositorioCuidadores`: `cuidadores(pacienteId) → [CuidadorAutorizado(vinculo, convite)]`, `convidar({pacienteId,
  nome, cpf})`, `revogar(vinculoId)`; `limiteCuidadores = 2` conta
  `CuidadorAutorizado.contaNoLimite(agora)` — ativo, ou pendente com convite não usado e não vencido (regra em
  `dados/regras/cuidadores.dart`); pendente vencido não ocupa vaga e a TM07 o mostra como "Convite expirado".
- `RepositorioVisaoCuidador` (RNFM05; sem vínculo ativo → `acessoNegado`): com `{contaCuidadorId, pacienteId}`,
  `pacienteAcompanhado`, `consultas`, `receitaVigente`, `itensDaReceita(+receitaId)`, `alertas → [AvisoDeAlerta(
  emitidoEm, cienteEm)]`; e `profissional(id)`. Já devolvem as cópias reduzidas.
- `ControleDemonstracao` (D11): `semConexao`, `definirSemConexao({semConexao})` (religar reenvia a fila antes de
  responder; o alerta de um crítico que estava nela nasce aí), `reiniciarDados()`.

**Modelos e enums** — 12 classes imutáveis em `lib/dados/modelos/` com os campos da Figura 3, `fromMap`/`toMap`
(chave = nome do campo; enum pelo `name`; instante ISO UTC `Z`; data civil `AAAA-MM-DD`; erro = `FormatException`),
`==`, `copyWith` só nos campos de situação, `Paciente.paraCuidador()`, `Agendamento.paraCuidador()` e
`ReceitaUsoContinuo.paraCuidador()` (sem `orientacao` nem `profissionalId`, anuláveis por isso — RNFM05). 11 enums em
`lib/dados/enums/` com a grafia do docx e `.rotulo` em linguagem simples (`Intensidade.ehCritica`).

**Núcleo** — `tempo/relogio.dart`: `Relogio.agora()` (UTC; `RelogioSistema`, `RelogioFixo` p/ teste),
`instanteNaClinica`, `formatarHora|Data|DataHora|DiaPorExtenso`, `formatarDataCivil…`, `descricaoRelativa`, fuso −04:00;
`tempo/data_civil.dart`: `DataCivil` (`hoje(relogio)`, `doInstante`, `somarDias`, `diasAte`). `validacao/cpf.dart`
(`cpfValido`, `mascararCpf`, `formatarCpf`, `somenteDigitos`) e `FormatadorCpf`; `uuid.dart` (`gerarUuidV4`).
Tema: `temaTerae()`, `CoresTerae` (`daIntensidade`, `daAdesao` → `ParDeCores`), `MedidasTerae`. Widgets:
`BotaoGrande(rotulo, aoTocar, icone, variante)`, `Cartao(child, aoTocar)`, `SeletorOpcoes<T>(rotulo, opcoes:
[OpcaoSeletor(valor, rotulo, icone, cores, habilitada)], valor, aoMudar, colunas)` (`habilitada: false` = opção
indisponível, sem toque e anunciada desativada), `FaixaEmergencia(destaque)` (chaves `ligar-188`, `ligar-192`),
`SeloAcademico`.

**Testes** — `test/apoio/dubles.dart` (dublês que lançam `UnimplementedError`: estenda e sobrescreva; personas
`vinculosAna/Regina/Patricia/Mistos`, `LancadorDuble`) e `test/apoio/app_de_teste.dart` (`appDeTeste(sessao, em)`).
Portão: `dart format --set-exit-if-changed lib test`, `flutter analyze` sem issue, `flutter test`.

## Atividade 4 (06/11/2026)

**Rotas novas** — `pacienteRegistros` TM13 `/paciente/registros`, `pacienteRegistro` TM14 e
`pacienteCorrigirRegistro` TM15 (id na consulta: use `Rotas.registro(id)` e `Rotas.corrigirRegistro(id)`), todas em
`doPaciente`, empilhadas sobre as abas pelo navegador raiz.

**`RepositorioAutenticacao`** — `entrar({email, senha})`, `sessaoGuardada()` (a sessão do Firebase ao reabrir o app;
sem conexão, a cópia local), `sair()` (D20: encerra e apaga o local); `ativarPaciente(..., acesso: NovoAcesso)` e
`aceitarConviteCuidador(..., acesso: NovoAcesso)` com `NovoAcesso(nome, email, senha)`. Saem `Provedor`,
`IdentidadeProvedor` e `identidadesNoAparelho`. Recusas novas: `credenciaisInvalidas`, `emailJaCadastrado`,
`emailInvalido`, `senhaFraca`.

**`RepositorioDiario`** — também `buscar(pacienteId, {texto, intensidades})`, `registro(id)`, `atualizar(corrigido)`
e `excluir(id)` (D17: mesmo dia, exclusão lógica); `registros` deixa de fora os excluídos. Recusas novas:
`edicaoEncerrada`, `registroInexistente`. Regras puras em `dados/regras/diario.dart` (`podeAlterar`, busca sem
acento) e `dados/regras/alerta.dart` (`regraDoAlerta`).

**`RegistroDiario`** — campos `atualizadoEm?` e `excluidoEm?`; `corrigido(...)` e `excluidoAs(em)`.

**`Repositorios.conexao`** — `ValueListenable<SituacaoSincronizacao>` (online, pendentes, sincronizando, última
sincronização), entregue às telas como `ConexaoDoApp` e mostrado pelo `AvisoDeConexao` (`nucleo/widgets`).

**`Sessao`** — `Sessao({aoMudarPerfil, aoSair})`; `entrar(vinculos, {perfilGuardado})` reabre o perfil pela
`Perfil.chave` (`papel:pacienteId`) guardada em SharedPreferences.

**Camadas** — telas só falam com contratos: `funcionalidades/` não importa `dados/local|remoto|persistente|
sincronizacao` nem sqflite/Firebase (exceção: `situacao_sincronizacao.dart`); só `main.dart` monta a persistência
(`dados/persistente/composicao.dart`). Conferido por `test/arquitetura_test.dart`.

## Evolução de TO — F0, fundação (06/11/2026)

Plano: `C:\Users\willi\.claude\plans\c-users-willi-projetos-terae-terae-app-jiggly-floyd.md`. Decisões D21–D24 em
`docs/estado.md`.

**`Paciente.linhasDeCuidado`** — `Set<LinhaDeCuidado>` (`acompanhamentoClinico`, `terapiaOcupacional`), nunca vazio,
no mapa como lista de `name` na ordem do enum (`lerEnums` em `conversao_mapa.dart`). Sem o campo (dados e cópias
anteriores), vale `Paciente.linhasPadrao` = só o clínico. Vai também na cópia do cuidador (`paraCuidador`). Atalhos
`temAcompanhamentoClinico` e `temTerapiaOcupacional`.

**`VinculosDaConta.qualidades`** — `Map<pacienteId, QualidadeConsentimento>` do termo vigente da conta (memória:
`consentimentos`; Firebase: `consentimentos where contaId == uid`, sem os revogados; a cópia local guarda o mapa).
Paciente sem entrada fala como titular.

**`Perfil.voz`** — `Voz.primeiraPessoa` (titular) ou `Voz.terceiraPessoa` (responsável legal e todo cuidador),
calculada em `Sessao.perfisDe`; `Perfil.falaDeOutraPessoa`. Não entra na igualdade do perfil.

**Rotas** — `pacienteCasa` TM16 `/paciente/casa`, em `doPaciente` e em `daTerapiaOcupacional`: a guarda leva ao
Início quem não tem terapia ocupacional. A TM07 `pacienteCuidadores` deixou a barra: é rota empilhada, aberta pelo
menu do Início (`Key('menu-cuidadores')`, `context.push`), com `BackButton`, e voltar leva ao Início.

**Abas** — `AbaDoPaciente` (`inicio`, `diario`, `casa`, `jornada`): o índice do enum é o índice do ramo do
`StatefulShellRoute`. `abasVisiveis(temTerapiaOcupacional:)` tira "Em casa" de quem não tem TO. A barra tem no máximo
4 abas, e o rótulo fica numa linha só a 360 dp com a Lexend em 100%, conferido em
`test/acessibilidade/telas_fonte_real_test.dart`.

**`FilaDeEntidade`** (`dados/sincronizacao/fila_de_entidade.dart`) — `contarPendentes()`, `enviarPendentes()` (lança
`RecusaDeRegra(semConexao)` para parar) e `buscar(pacienteId)`. O `Sincronizador(filas: [...])` envia o diário primeiro
e depois cada fila em ordem. `situacao.pendentes` soma todas. No primeiro "sem conexão" o envio para (o resto fica na
fila), mas a busca do servidor ainda roda, como no diário da A4: se a leitura responder, o app volta a "online".

**`BancoLocal`** — esquema por migrações numeradas (`BancoLocal.migracoes`; `versao` = quantas são): o banco novo roda
todas, e o antigo só as que faltam (`onUpgrade`). Tabela nova = migração nova no fim da lista e o nome dela em
`BancoLocal.tabelas` (o "Sair" apaga, D20). Na F0 só existe a versão 1; a primeira migração real (v2) vem com a F1.
