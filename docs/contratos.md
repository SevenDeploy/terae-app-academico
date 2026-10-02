# Contratos congelados da fundação (onda 1)

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
  nome, cpf})`, `revogar(vinculoId)`; `limiteCuidadores = 2` conta `SituacaoVinculo.contaNoLimite`.
- `RepositorioVisaoCuidador` (RNFM05; sem vínculo ativo → `acessoNegado`): com `{contaCuidadorId, pacienteId}`,
  `pacienteAcompanhado`, `consultas`, `receitaVigente`, `itensDaReceita(+receitaId)`, `alertas → [AvisoDeAlerta(
  emitidoEm, cienteEm)]`; e `profissional(id)`. Já devolvem as cópias reduzidas.
- `ControleDemonstracao` (D11): `semConexao`, `definirSemConexao({semConexao})` (religar reenvia a fila antes de
  responder; o alerta de um crítico que estava nela nasce aí), `reiniciarDados()`.

**Modelos e enums** — 12 classes imutáveis em `lib/dados/modelos/` com os campos da Figura 3, `fromMap`/`toMap`
(chave = nome do campo; enum pelo `name`; instante ISO UTC `Z`; data civil `AAAA-MM-DD`; erro = `FormatException`),
`==`, `copyWith` só nos campos de situação, `Paciente.paraCuidador()` e `Agendamento.paraCuidador()`. 11 enums em
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
