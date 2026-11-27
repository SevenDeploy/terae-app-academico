/// Dublês com dados e montagem do app para os testes das telas do paciente
/// (TM02–TM07). Estendem os dublês de `test/apoio/dubles.dart` sem editá-los:
/// nada aqui depende da implementação em memória real.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/alerta.dart';
import 'package:terae_app/dados/modelos/convite_acesso.dart';
import 'package:terae_app/dados/modelos/item_medicacao.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/profissional_saude.dart';
import 'package:terae_app/dados/modelos/receita_uso_continuo.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/modelos/vinculo_cuidador.dart';
import 'package:terae_app/dados/regras/diario.dart';
import 'package:terae_app/dados/repositorios/cuidadores_repositorio.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/metas_repositorio.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/dados/sincronizacao/situacao_sincronizacao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../apoio/dubles.dart';

// ─── Dados de teste (relativos a `agoraDeTeste`: sexta, 2/10/2026 10:00) ───

const ProfissionalSaude helena = ProfissionalSaude(
  id: 'pr-helena',
  nome: 'Dra. Helena Prado',
  registroConselho: 'CRM-MT 12345',
  especialidade: 'Psiquiatria',
);

/// Quarta, 7/10/2026 14:00 na clínica — "em 5 dias".
final Agendamento consultaFutura = Agendamento(
  id: 'ag-futura',
  pacienteId: 'p-ana',
  profissionalId: 'pr-helena',
  dataHora: instanteNaClinica(2026, 10, 7, 14),
  motivoRetorno: 'Retorno de acompanhamento',
  situacao: SituacaoAgendamento.agendado,
);

final List<Agendamento> consultasDeTeste = [
  Agendamento(
    id: 'ag-realizada',
    pacienteId: 'p-ana',
    profissionalId: 'pr-helena',
    dataHora: instanteNaClinica(2026, 9, 16, 14),
    situacao: SituacaoAgendamento.realizado,
  ),
  Agendamento(
    id: 'ag-cancelada',
    pacienteId: 'p-ana',
    profissionalId: 'pr-helena',
    dataHora: instanteNaClinica(2026, 9, 23, 14),
    situacao: SituacaoAgendamento.cancelado,
  ),
  consultaFutura,
];

final ReceitaUsoContinuo receitaDeTeste = ReceitaUsoContinuo(
  id: 'rc-ana',
  pacienteId: 'p-ana',
  profissionalId: 'pr-helena',
  orientacao: 'Tome 1 comprimido de manhã, depois do café.',
  vigenciaInicio: DataCivil(2026, 9, 1),
  vigenciaFim: DataCivil(2026, 10, 31),
  dataRenovacao: DataCivil(2026, 10, 8),
);

final List<ItemMedicacao> itensDeTeste = [
  ItemMedicacao(
    id: 'it-sertralina',
    receitaId: 'rc-ana',
    medicamento: 'Sertralina',
    posologia: '50 mg, 1 comprimido',
    horarios: const ['08:00'],
  ),
];

final List<MarcoJornada> marcosDeTeste = [
  MarcoJornada(
    id: 'mc-avaliacao',
    pacienteId: 'p-ana',
    tipo: TipoMarco.reavaliacao,
    data: DataCivil(2026, 9, 2),
    titulo: 'Primeira avaliação',
    textoSimples: 'Vocês combinaram os objetivos do tratamento.',
  ),
  MarcoJornada(
    id: 'mc-orientacao',
    pacienteId: 'p-ana',
    tipo: TipoMarco.orientacao,
    data: DataCivil(2026, 9, 16),
    titulo: 'Rotina de sono',
    textoSimples: 'Deitar no mesmo horário ajuda a dormir melhor.',
  ),
  MarcoJornada(
    id: 'mc-proximo',
    pacienteId: 'p-ana',
    tipo: TipoMarco.proximoPasso,
    data: DataCivil(2026, 10, 21),
    titulo: 'Nova avaliação',
    textoSimples: 'Vamos ver juntos como você evoluiu.',
  ),
];

/// Leitura do paciente com os dados acima; [falhar] faz toda leitura lançar.
class PacienteComDados extends PacienteDuble {
  PacienteComDados({
    this.consulta,
    List<Agendamento>? consultas,
    this.receita,
    List<ItemMedicacao>? itens,
    List<MarcoJornada>? marcosDaJornada,
  }) : consultas = consultas ?? consultasDeTeste,
       itens = itens ?? itensDeTeste,
       marcosDaJornada = marcosDaJornada ?? marcosDeTeste;

  /// Com tudo preenchido: consulta futura e receita vigente.
  factory PacienteComDados.completo() =>
      PacienteComDados(consulta: consultaFutura, receita: receitaDeTeste);

  Agendamento? consulta;
  List<Agendamento> consultas;
  ReceitaUsoContinuo? receita;
  List<ItemMedicacao> itens;
  List<MarcoJornada> marcosDaJornada;
  bool falhar = false;

  Future<T> _ler<T>(T valor) async {
    if (falhar) throw const RecusaDeRegra(MotivoRecusa.semConexao);
    return valor;
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) => _ler(helena);

  @override
  Future<Agendamento?> proximaConsulta(String pacienteId) => _ler(consulta);

  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) => _ler(consultas);

  @override
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId) =>
      _ler(receita);

  @override
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId) => _ler(itens);

  @override
  Future<List<MarcoJornada>> marcos(String pacienteId) => _ler(marcosDaJornada);
}

/// Como o diário dublê responde a `enviar`.
enum ModoDoDiario {
  /// Envia na hora; crítica ganha alerta (equipe avisada).
  comConexao,

  /// Fica na fila (`naFila`), sem alerta.
  semConexao,

  /// Só responde quando o teste chamar [DiarioControlavel.responder].
  lento,

  /// Lança erro inesperado.
  falha,
}

/// Diário que anota cada envio e responde conforme o [modo], com um
/// "servidor" de mentira para a lista (P3): [servidor] guarda o que chegou,
/// [fila] o que ficou no aparelho.
class DiarioControlavel extends DiarioDuble {
  DiarioControlavel([this.modo = ModoDoDiario.comConexao, this.iniciais]);

  ModoDoDiario modo;

  /// Registros já no servidor quando o teste começa.
  final List<RegistroDiario>? iniciais;
  final List<RegistroDiario> enviados = [];
  final List<(RegistroDiario, Completer<ResultadoEnvio>)> _pendentes = [];
  late final Map<String, RegistroDiario> servidor = {
    for (final r in iniciais ?? const <RegistroDiario>[]) r.id: r,
  };
  final Map<String, RegistroDiario> fila = {};
  final Map<String, Alerta> alertas = {};

  /// A terapeuta revisou no servidor sem o aparelho saber (o 409 do portal):
  /// a próxima correção ou retirada recusa `registroNaoMudaMais`.
  bool revisouNoMeio = false;
  int reenvios = 0;

  /// A lista do servidor não abre (sem internet): `pagina` recusa, mas os
  /// guardados no aparelho continuam legíveis.
  bool listaForaDoAr = false;

  /// Resultado "enviado" (com alerta se "Muito") para o [registro].
  static ResultadoEnvio enviadoDe(RegistroDiario registro) {
    final critico = registro.intensidadeSintoma?.ehCritico ?? false;
    final enviado = registro.copyWith(
      situacaoEnvio: SituacaoEnvio.enviado,
      enviadoEm: registro.enviadoEm ?? registro.registradoEm,
      alertouAEquipe: critico ? true : null,
    );
    return ResultadoEnvio(
      registro: enviado,
      alerta: critico
          ? Alerta(
              id: 'al-${registro.id}',
              registroId: registro.id,
              regraDisparada: RegraAlerta.intensidadeCritica,
              emitidoEm: registro.registradoEm,
            )
          : null,
    );
  }

  ResultadoEnvio _guardar(ResultadoEnvio r) {
    servidor[r.registro.id] = r.registro;
    fila.remove(r.registro.id);
    final alerta = r.alerta;
    if (alerta != null) alertas[r.registro.id] = alerta;
    return r;
  }

  /// Completa o envio lento mais antigo como enviado.
  void responder() {
    final (registro, completer) = _pendentes.removeAt(0);
    completer.complete(_guardar(enviadoDe(registro)));
  }

  /// Faz o envio lento mais antigo falhar de um jeito inesperado.
  void falharPendente() =>
      _pendentes.removeAt(0).$2.completeError(StateError('falha tardia'));

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    enviados.add(registro);
    switch (modo) {
      case ModoDoDiario.comConexao:
        return _guardar(enviadoDe(registro));
      case ModoDoDiario.semConexao:
        fila[registro.id] = registro;
        return ResultadoEnvio(registro: registro);
      case ModoDoDiario.lento:
        final completer = Completer<ResultadoEnvio>();
        _pendentes.add((registro, completer));
        return completer.future;
      case ModoDoDiario.falha:
        throw StateError('falha inesperada');
    }
  }

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async {
    reenvios++;
    if (modo != ModoDoDiario.comConexao) return const [];
    return [
      for (final r in [...fila.values]) _guardar(enviadoDe(r)),
    ];
  }

  @override
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) async {
    if (listaForaDoAr) throw const RecusaDeRegra(MotivoRecusa.semConexao);
    final todos = [
      for (final r in servidor.values)
        if (r.pacienteId == pacienteId &&
            (antes == null || momentoNaLista(r).isBefore(antes)))
          r,
    ]..sort(maisNovoPrimeiro);
    return PaginaDoDiario(
      registros: todos.take(registrosPorPagina).toList(),
      haMais: todos.length > registrosPorPagina,
    );
  }

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async => [
    for (final r in fila.values)
      if (r.pacienteId == pacienteId) r,
  ];

  @override
  Future<RegistroDiario> registro(String registroId) async =>
      servidor[registroId] ??
      fila[registroId] ??
      (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async =>
      alertas[registroId];

  RegistroDiario _alteravel(String registroId) {
    if (modo == ModoDoDiario.semConexao) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final atual =
        servidor[registroId] ??
        (throw const RecusaDeRegra(MotivoRecusa.registroInexistente));
    if (revisouNoMeio || !podeAlterar(atual)) {
      throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
    }
    return atual;
  }

  @override
  Future<ResultadoEnvio> corrigir(
    String registroId,
    EntradaDoDiario entrada,
  ) async {
    final novo = _alteravel(registroId).corrigido(entrada, em: agoraDeTeste);
    return _guardar(enviadoDe(novo));
  }

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) async {
    final retirado = _alteravel(registroId)
        .retiradoCom(motivo, em: agoraDeTeste);
    servidor[registroId] = retirado;
    return retirado;
  }
}

/// Um registro já enviado, para montar a lista dos testes de tela.
RegistroDiario registroEnviado(
  String id, {
  DateTime? em,
  Adesao adesao = Adesao.parcial,
  String? sintomas = 'Recusou o jantar duas vezes.',
  Intensidade? intensidade = Intensidade.moderado,
  String? observacoes,
  DateTime? revisadoEm,
  bool alertou = false,
  String pacienteId = 'p-ana',
}) {
  final quando = em ?? agoraDeTeste.subtract(const Duration(hours: 1));
  return RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: quando,
    adesao: adesao,
    sintomas: sintomas,
    intensidadeSintoma: intensidade,
    observacoes: observacoes,
    situacaoEnvio: SituacaoEnvio.enviado,
    enviadoEm: quando,
    revisadoEm: revisadoEm,
    alertouAEquipe: alertou,
  );
}

/// Convite de cuidador de teste.
ConviteAcesso conviteDe(String id, String codigo, String cpf) => ConviteAcesso(
  id: id,
  pacienteId: 'p-ana',
  codigo: codigo,
  tipo: TipoConvite.cuidador,
  cpfConvidado: cpf,
  expiraEm: instanteNaClinica(2026, 10, 9, 10),
);

/// Regina, ativa desde 10/09/2026.
CuidadorAutorizado reginaAtiva() => CuidadorAutorizado(
  vinculo: VinculoCuidador(
    id: 'vc-regina',
    pacienteId: 'p-ana',
    contaCuidadorId: 'c-regina',
    conviteId: 'cv-regina',
    nome: 'Regina Martins',
    situacao: SituacaoVinculo.ativo,
    autorizadoEm: instanteNaClinica(2026, 9, 10, 9),
  ),
  convite: conviteDe('cv-regina', 'REG123', '78945612301'),
);

/// Paulo, convite em aberto.
CuidadorAutorizado pauloPendente() => CuidadorAutorizado(
  vinculo: VinculoCuidador(
    id: 'vc-paulo',
    pacienteId: 'p-ana',
    conviteId: 'cv-paulo',
    nome: 'Paulo Martins',
    situacao: SituacaoVinculo.pendente,
  ),
  convite: conviteDe('cv-paulo', 'PAU456', '45612378902'),
);

/// Cuidadores em memória do teste: anota convites e revogações; [recusar]
/// faz o próximo convite ser recusado com o motivo.
class CuidadoresEmMemoria extends CuidadoresDuble {
  CuidadoresEmMemoria(List<CuidadorAutorizado> iniciais)
    : lista = [...iniciais];

  final List<CuidadorAutorizado> lista;
  final List<String> revogados = [];
  final List<({String nome, String cpf})> convidados = [];
  MotivoRecusa? recusar;

  @override
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId) async => [
    ...lista,
  ];

  @override
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  }) async {
    convidados.add((nome: nome, cpf: cpf));
    final motivo = recusar;
    if (motivo != null) throw RecusaDeRegra(motivo);
    final n = convidados.length;
    final novo = CuidadorAutorizado(
      vinculo: VinculoCuidador(
        id: 'vc-novo-$n',
        pacienteId: pacienteId,
        conviteId: 'cv-novo-$n',
        nome: nome,
        situacao: SituacaoVinculo.pendente,
      ),
      convite: conviteDe('cv-novo-$n', 'NOV00$n', cpf),
    );
    lista.insert(0, novo);
    return novo;
  }

  @override
  Future<CuidadorAutorizado> revogar(String vinculoId) async {
    revogados.add(vinculoId);
    final i = lista.indexWhere((c) => c.vinculo.id == vinculoId);
    final antigo = lista[i];
    final revogado = CuidadorAutorizado(
      vinculo: antigo.vinculo.copyWith(
        situacao: SituacaoVinculo.revogado,
        revogadoEm: agoraDeTeste,
      ),
      convite: antigo.convite,
    );
    lista[i] = revogado;
    return revogado;
  }
}

// ─── Montagem ───

/// Os dublês de uma montagem, para o teste conferir chamadas.
class AppDoPaciente {
  AppDoPaciente({
    required this.sessao,
    required this.paciente,
    required this.diario,
    required this.cuidadores,
    required this.lancador,
  });

  final Sessao sessao;
  final PacienteComDados paciente;
  final DiarioControlavel diario;
  final CuidadoresEmMemoria cuidadores;
  final LancadorDuble lancador;
}

/// Abre o app com a sessão de Ana (ou [sessao]) em [em], com os dublês acima.
Future<AppDoPaciente> abrirAppDoPaciente(
  WidgetTester tester, {
  String em = Rotas.pacienteInicio,
  Sessao? sessao,
  PacienteComDados? paciente,
  DiarioControlavel? diario,
  CuidadoresEmMemoria? cuidadores,
  RepositorioMetas? metas,
  ValueListenable<SituacaoSincronizacao>? conexao,
}) async {
  final app = AppDoPaciente(
    sessao: sessao ?? (Sessao()..entrar(vinculosAna())),
    paciente: paciente ?? PacienteComDados.completo(),
    diario: diario ?? DiarioControlavel(),
    cuidadores:
        cuidadores ?? CuidadoresEmMemoria([reginaAtiva(), pauloPendente()]),
    lancador: LancadorDuble(),
  );
  final base = repositoriosDuble();
  await tester.pumpWidget(
    TeraeApp(
      repositorios: Repositorios(
        autenticacao: base.autenticacao,
        paciente: app.paciente,
        diario: app.diario,
        cuidadores: app.cuidadores,
        visaoCuidador: base.visaoCuidador,
        demonstracao: base.demonstracao,
        metas: metas ?? base.metas,
        conexao: conexao ?? base.conexao,
      ),
      sessao: app.sessao,
      relogio: RelogioFixo(agoraDeTeste),
      lancador: app.lancador,
      localInicial: em,
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

/// O roteador do app montado.
GoRouter roteadorDe(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

/// Caminho atual.
String localDe(WidgetTester tester) =>
    roteadorDe(tester).routerDelegate.currentConfiguration.uri.path;

/// Toca e conta: cada [tocar] é um toque da pessoa (rolar não conta).
class ContadorDeToques {
  ContadorDeToques(this.tester);

  final WidgetTester tester;
  int total = 0;

  Future<void> tocar(Finder alvo, {bool assentar = true}) async {
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    await tester.tap(alvo);
    total++;
    if (assentar) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}

/// Preenche o diário (P3): a adesão (a única obrigatória) e, se dados, "O
/// quanto isso atrapalhou o dia?" — um toque cada — e o texto do que
/// aconteceu (digitar não conta como toque).
Future<void> preencherDiario(
  ContadorDeToques toques, {
  String adesao = 'Segui tudo',
  String? intensidade = 'Pouco — quase não atrapalhou',
  String? sintomas,
}) async {
  await toques.tocar(find.text(adesao));
  if (intensidade != null) await toques.tocar(find.text(intensidade));
  if (sintomas != null) {
    await toques.tester.enterText(
      find.byKey(const Key('campo-sintomas')),
      sintomas,
    );
    await toques.tester.pumpAndSettle();
  }
}

final Finder botaoEnviar = find.byKey(const Key('enviar-diario'));

/// A conexão do app sem internet (o aviso e os botões que pedem internet).
ValueNotifier<SituacaoSincronizacao> semInternet() =>
    ValueNotifier(const SituacaoSincronizacao(online: false));

/// Algum texto da tela fala em "avisado/avisada"?
final Finder falaEmAvisado = find.textContaining('avisad');
