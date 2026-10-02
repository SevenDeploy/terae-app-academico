/// Dublês com dados e montagem do app para os testes das telas do paciente
/// (TM02–TM07). Estendem os dublês de `test/apoio/dubles.dart` sem editá-los:
/// nada aqui depende da implementação em memória real.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:terae_app/app.dart';
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
import 'package:terae_app/dados/repositorios/cuidadores_repositorio.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
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

/// Diário que anota cada envio e responde conforme o [modo].
class DiarioControlavel extends DiarioDuble {
  DiarioControlavel([this.modo = ModoDoDiario.comConexao]);

  ModoDoDiario modo;
  final List<RegistroDiario> enviados = [];
  final List<(RegistroDiario, Completer<ResultadoEnvio>)> _pendentes = [];

  /// Resultado "enviado" (com alerta se crítico) para o [registro].
  static ResultadoEnvio enviadoDe(RegistroDiario registro) {
    final enviado = registro.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
    return ResultadoEnvio(
      registro: enviado,
      alerta: registro.intensidade.ehCritica
          ? Alerta(
              id: 'al-${registro.id}',
              registroId: registro.id,
              regraDisparada: RegraAlerta.intensidadeCritica,
              emitidoEm: registro.registradoEm,
            )
          : null,
    );
  }

  /// Completa o envio lento mais antigo como enviado.
  void responder() {
    final (registro, completer) = _pendentes.removeAt(0);
    completer.complete(enviadoDe(registro));
  }

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    enviados.add(registro);
    switch (modo) {
      case ModoDoDiario.comConexao:
        return enviadoDe(registro);
      case ModoDoDiario.semConexao:
        return ResultadoEnvio(registro: registro);
      case ModoDoDiario.lento:
        final completer = Completer<ResultadoEnvio>();
        _pendentes.add((registro, completer));
        return completer.future;
      case ModoDoDiario.falha:
        throw StateError('falha inesperada');
    }
  }
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

/// Preenche o diário: adesão, intensidade e sintoma (três toques).
Future<void> preencherDiario(
  ContadorDeToques toques, {
  String adesao = 'Tomei tudo',
  String intensidade = 'Leve',
  String sintoma = 'Cansaço',
}) async {
  await toques.tocar(find.text(adesao));
  await toques.tocar(find.text(intensidade));
  await toques.tocar(find.text(sintoma));
}

final Finder botaoEnviar = find.byKey(const Key('enviar-diario'));

/// Algum texto da tela fala em "avisado/avisada"?
final Finder falaEmAvisado = find.textContaining('avisad');
