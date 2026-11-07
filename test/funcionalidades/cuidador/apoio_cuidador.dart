/// Visão do cuidador de mentira para a TM08, TM11 e TM12. De propósito, os
/// dados vêm COM o que o cuidador não pode ver (motivo do retorno, orientação
/// da receita) e a sessão traz o paciente com CPF e nascimento: os testes
/// provam que a tela não mostra nada disso (RNFM05 na camada de tela), mesmo
/// que o repositório falhasse em reduzir a cópia.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/item_medicacao.dart';
import 'package:terae_app/dados/modelos/profissional_saude.dart';
import 'package:terae_app/dados/modelos/receita_uso_continuo.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/visao_cuidador_repositorio.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../apoio/dubles.dart';

Agendamento consultaDe(
  String id,
  DateTime dataHora, {
  String profissionalId = 'pr-helena',
  String? motivo,
  SituacaoAgendamento situacao = SituacaoAgendamento.agendado,
}) => Agendamento(
  id: id,
  pacienteId: 'p-ana',
  profissionalId: profissionalId,
  dataHora: dataHora,
  motivoRetorno: motivo,
  situacao: situacao,
);

/// Hoje cedo (já passou), +5 dias, cancelada em +12 e outra em +19.
final List<Agendamento> consultasDeTeste = [
  consultaDe(
    'ag-0',
    instanteNaClinica(2026, 10, 2, 8),
    motivo: 'Retorno de hoje cedo',
  ),
  consultaDe(
    'ag-1',
    instanteNaClinica(2026, 10, 7, 14),
    motivo: 'Ajuste da sertralina',
  ),
  consultaDe(
    'ag-2',
    instanteNaClinica(2026, 10, 14, 9),
    motivo: 'Revisão do plano',
    situacao: SituacaoAgendamento.cancelado,
  ),
  consultaDe(
    'ag-3',
    instanteNaClinica(2026, 10, 21, 10, 30),
    profissionalId: 'pr-larissa',
    motivo: 'Avaliação inicial',
  ),
];

ReceitaUsoContinuo receitaDe({
  DataCivil? vigenciaFim,
  DataCivil? dataRenovacao,
}) => ReceitaUsoContinuo(
  id: 'rc-1',
  pacienteId: 'p-ana',
  profissionalId: 'pr-helena',
  orientacao: 'Tomar depois do café, com água.',
  vigenciaInicio: DataCivil(2026, 9, 1),
  vigenciaFim: vigenciaFim ?? DataCivil(2026, 12, 1),
  dataRenovacao: dataRenovacao ?? DataCivil(2026, 10, 8),
);

final List<ItemMedicacao> itensDeTeste = [
  ItemMedicacao(
    id: 'it-1',
    receitaId: 'rc-1',
    medicamento: 'Sertralina',
    posologia: '50 mg, 1 comprimido',
    horarios: ['08:00'],
  ),
  ItemMedicacao(
    id: 'it-2',
    receitaId: 'rc-1',
    medicamento: 'Melatonina',
    posologia: '3 mg, 1 comprimido',
    horarios: ['21:00'],
  ),
  ItemMedicacao(
    id: 'it-3',
    receitaId: 'rc-1',
    medicamento: 'Vitamina D',
    posologia: '1 gota',
    horarios: ['08:00'],
  ),
  ItemMedicacao(
    id: 'it-4',
    receitaId: 'rc-1',
    medicamento: 'Dipirona',
    posologia: '500 mg, se tiver dor',
    horarios: [],
  ),
];

/// Um alerta já visto pelo profissional e um ainda não visto.
final List<AvisoDeAlerta> alertasDeTeste = [
  AvisoDeAlerta(
    emitidoEm: instanteNaClinica(2026, 10, 1, 22, 10),
    cienteEm: instanteNaClinica(2026, 10, 2, 8, 5),
  ),
  AvisoDeAlerta(emitidoEm: instanteNaClinica(2026, 9, 28, 19, 30)),
];

const Map<String, ProfissionalSaude> profissionaisDeTeste = {
  'pr-helena': ProfissionalSaude(
    id: 'pr-helena',
    nome: 'Dra. Helena Prado',
    registroConselho: 'CRM-MT 12345',
    especialidade: 'Psiquiatria',
  ),
  'pr-larissa': ProfissionalSaude(
    id: 'pr-larissa',
    nome: 'Dra. Larissa Campos',
    registroConselho: 'CREFITO-9 30125-TO',
    especialidade: 'Terapia ocupacional',
  ),
};

class VisaoCuidadorFake extends VisaoCuidadorDuble {
  VisaoCuidadorFake({
    List<Agendamento>? consultas,
    ReceitaUsoContinuo? receita,
    this.semReceita = false,
    List<ItemMedicacao>? itens,
    List<AvisoDeAlerta>? alertas,
    this.recusa,
  }) : _consultas = consultas ?? consultasDeTeste,
       _receita = receita ?? receitaDe(),
       _itens = itens ?? itensDeTeste,
       _alertas = alertas ?? alertasDeTeste;

  final List<Agendamento> _consultas;
  final ReceitaUsoContinuo _receita;
  final bool semReceita;
  final List<ItemMedicacao> _itens;
  final List<AvisoDeAlerta> _alertas;

  /// Recusa de toda chamada (ex.: `acessoNegado`), até ser apagada.
  MotivoRecusa? recusa;

  /// `conta|paciente` de cada chamada, para conferir quem a tela pediu.
  final List<String> chamadas = [];

  void _registrar(String conta, String paciente) {
    chamadas.add('$conta|$paciente');
    final motivo = recusa;
    if (motivo != null) throw RecusaDeRegra(motivo);
  }

  @override
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    _registrar(contaCuidadorId, pacienteId);
    return _consultas;
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async =>
      profissionaisDeTeste[profissionalId]!;

  @override
  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    _registrar(contaCuidadorId, pacienteId);
    return semReceita ? null : _receita;
  }

  @override
  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  }) async {
    _registrar(contaCuidadorId, pacienteId);
    return [
      for (final i in _itens)
        if (i.receitaId == receitaId) i,
    ];
  }

  @override
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    _registrar(contaCuidadorId, pacienteId);
    return _alertas;
  }
}

/// Regina acompanhando Ana, mas com a cópia COMPLETA do paciente (CPF e
/// nascimento), para provar que a tela não os mostra.
VinculosDaConta vinculosReginaComPacienteCompleto() => VinculosDaConta(
  conta: contaDe('c-regina', 'Regina Souza'),
  acompanhados: [pacienteDe('p-ana', 'Ana Lúcia Martins')],
);

/// Regina acompanhando um paciente que só faz terapia ocupacional (D21).
VinculosDaConta vinculosReginaDeQuemSoFazTerapia() => VinculosDaConta(
  conta: contaDe('c-regina', 'Regina Souza'),
  acompanhados: [
    pacienteDe(
      'p-ana',
      'Ana Lúcia Martins',
      linhas: soTerapiaOcupacional,
    ).paraCuidador(),
  ],
);

/// O que o cuidador nunca pode ler na tela (RNFM05).
const List<String> proibidosAoCuidador = [
  '52998224725',
  '529.982.247-25',
  '14/03/2010',
  'CPF',
  'nascimento',
  'Retorno de hoje cedo',
  'Ajuste da sertralina',
  'Revisão do plano',
  'Avaliação inicial',
  'motivo',
  'Tomar depois do café',
  'Crítica',
  'Grave',
  'intensidade',
];

/// Todo o texto renderizado (inclusive fora da tela visível).
List<String> textosRenderizados(WidgetTester tester) => [
  for (final r in tester.widgetList<RichText>(
    find.byType(RichText, skipOffstage: false),
  ))
    r.text.toPlainText(),
];

void conferirQueNaoMostraDadoProibido(WidgetTester tester) {
  final textos = textosRenderizados(tester);
  expect(textos, isNotEmpty);
  for (final proibido in proibidosAoCuidador) {
    final achados = [
      for (final t in textos)
        if (t.toLowerCase().contains(proibido.toLowerCase())) t,
    ];
    expect(achados, isEmpty, reason: 'a tela mostrou "$proibido"');
  }
}
