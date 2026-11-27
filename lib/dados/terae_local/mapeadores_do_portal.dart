/// Os corpos de `/api/portal/{inicio,agenda,programa}` lidos campo a campo
/// (sem cast) e os mapeadores para os modelos do app.
///
/// Contratos de referência, no monorepo do Terae web:
/// `packages/contratos/src/portal/index.ts` (`EsquemaSessaoNoPortal`,
/// `EsquemaAgendaNoPortal`, `EsquemaOrientacaoNoPortal`,
/// `EsquemaProgramaNoPortal`, `EsquemaInicioDoPortal`). Campo ausente ou de
/// tipo errado vira [RespostaInesperadaDoPortal].
library;

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/adesao_em_casa.dart';
import '../enums/linha_de_cuidado.dart';
import '../enums/ocupacao.dart';
import '../enums/qualidade_consentimento.dart';
import '../enums/quem_registrou.dart';
import '../enums/resposta_presenca.dart';
import '../enums/situacao_agendamento.dart';
import '../enums/situacao_conta.dart';
import '../enums/situacao_envio.dart';
import '../modelos/agendamento.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/confirmacao_de_presenca.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/paciente.dart';
import '../modelos/registro_de_atividade.dart';
import '../repositorios/autenticacao_repositorio.dart';
import 'cliente_do_portal.dart';
import 'sessao_do_portal.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// A resposta da família a uma sessão (`CONFIRMACOES_NO_PORTAL`).
enum ConfirmacaoNoPortal {
  pendente('pendente'),
  confirmada('confirmada'),
  ausenciaAvisada('ausencia_avisada'),
  desmarcadaPelaClinica('desmarcada_pela_clinica');

  const ConfirmacaoNoPortal(this.valor);

  final String valor;
}

/// Uma sessão futura (`EsquemaSessaoNoPortal`).
class SessaoNoPortal {
  const SessaoNoPortal({
    required this.idSessao,
    required this.inicio,
    required this.fim,
    required this.primeiroNomeDoTerapeuta,
    required this.confirmacao,
    required this.podeResponder,
    required this.podeAvisarAusencia,
    this.especialidade,
    this.local,
  });

  final String idSessao;
  final DateTime inicio;
  final DateTime fim;
  final String primeiroNomeDoTerapeuta;
  final String? especialidade;
  final String? local;
  final ConfirmacaoNoPortal confirmacao;
  final bool podeResponder;
  final bool podeAvisarAusencia;
}

/// A agenda (`EsquemaAgendaNoPortal`): desligada, `liberada: false` e vazia.
class AgendaNoPortal {
  const AgendaNoPortal({required this.liberada, required this.sessoes});

  final bool liberada;
  final List<SessaoNoPortal> sessoes;
}

/// Quem fez o registro de hoje de uma orientação.
enum RegistradoPor {
  estaConta('esta_conta'),
  outraConta('outra_conta'),
  link('link');

  const RegistradoPor(this.valor);

  final String valor;
}

/// O registro de hoje de uma orientação (`EsquemaRegistroDeHojeNoPortal`).
class RegistroDeHojeNoPortal {
  const RegistroDeHojeNoPortal({
    required this.adesao,
    required this.registradoPor,
    this.primeiroNome,
    this.registradoEm,
    this.reflexao,
  });

  final AdesaoEmCasa adesao;
  final RegistradoPor registradoPor;
  final String? primeiroNome;

  /// Só no registro desta conta.
  final DateTime? registradoEm;

  /// Só no registro desta conta.
  final String? reflexao;
}

/// Uma orientação vigente do programa (`EsquemaOrientacaoNoPortal`).
class OrientacaoNoPortal {
  const OrientacaoNoPortal({
    required this.idOrientacao,
    required this.titulo,
    required this.texto,
    required this.vezesPorSemana,
    required this.primeiroNomeDoTerapeuta,
    required this.publicadaEm,
    this.especialidade,
    this.registroDeHoje,
  });

  final String idOrientacao;
  final String titulo;
  final String texto;
  final int vezesPorSemana;
  final String primeiroNomeDoTerapeuta;
  final String? especialidade;
  final DateTime publicadaEm;
  final RegistroDeHojeNoPortal? registroDeHoje;
}

/// O programa em casa no dia da clínica (`EsquemaProgramaNoPortal`).
class ProgramaNoPortal {
  const ProgramaNoPortal({required this.dia, required this.orientacoes});

  final DataCivil dia;
  final List<OrientacaoNoPortal> orientacoes;
}

/// O que o app usa de `GET /portal/inicio`: o dia e a próxima sessão (só com
/// a agenda liberada).
class InicioNoPortal {
  const InicioNoPortal({required this.dia, this.proximaSessao});

  final DataCivil dia;
  final SessaoNoPortal? proximaSessao;
}

// ---------------------------------------------------------------------------
// Leitura dos corpos
// ---------------------------------------------------------------------------

T _ler<T>(T Function() leitura) {
  try {
    return leitura();
  } on FormatException catch (e) {
    throw RespostaInesperadaDoPortal(detalhe: e.message);
  }
}

E _enum<E>(List<E> valores, String Function(E) valor, String texto) =>
    valores.where((v) => valor(v) == texto).firstOrNull ??
    (throw FormatException('Valor desconhecido', texto));

List<Mapa> _objetos(Mapa m, String chave) => [
  for (final item in lerCampo<List<Object?>>(m, chave))
    if (item is Mapa)
      item
    else
      throw FormatException('Item de "$chave" que não é objeto', item),
];

SessaoNoPortal _sessao(Mapa m) => SessaoNoPortal(
  idSessao: lerCampo<String>(m, 'idSessao'),
  inicio: lerInstante(m, 'inicio'),
  fim: lerInstante(m, 'fim'),
  primeiroNomeDoTerapeuta: lerCampo<String>(m, 'primeiroNomeDoTerapeuta'),
  especialidade: lerOpcional<String>(m, 'especialidade'),
  local: lerOpcional<String>(m, 'local'),
  confirmacao: _enum(
    ConfirmacaoNoPortal.values,
    (c) => c.valor,
    lerCampo<String>(m, 'confirmacao'),
  ),
  podeResponder: lerCampo<bool>(m, 'podeResponder'),
  podeAvisarAusencia: lerCampo<bool>(m, 'podeAvisarAusencia'),
);

/// `GET /portal/agenda`.
AgendaNoPortal lerAgenda(Mapa m) => _ler(
  () => AgendaNoPortal(
    liberada: lerCampo<bool>(m, 'liberada'),
    sessoes: [for (final s in _objetos(m, 'sessoes')) _sessao(s)],
  ),
);

/// `GET /portal/inicio` (só o que o app usa).
InicioNoPortal lerInicio(Mapa m) => _ler(() {
  final proxima = lerOpcional<Mapa>(m, 'proximaSessao');
  return InicioNoPortal(
    dia: lerDataCivil(m, 'dia'),
    proximaSessao: proxima == null ? null : _sessao(proxima),
  );
});

/// A adesão no contrato (`feito|em_parte|nao_feito`) e de volta.
AdesaoEmCasa adesaoDoPortal(String texto) => switch (texto) {
  'feito' => AdesaoEmCasa.feito,
  'em_parte' => AdesaoEmCasa.emParte,
  'nao_feito' => AdesaoEmCasa.naoFeito,
  _ => throw FormatException('Adesão desconhecida', texto),
};

String adesaoParaOPortal(AdesaoEmCasa adesao) => switch (adesao) {
  AdesaoEmCasa.feito => 'feito',
  AdesaoEmCasa.emParte => 'em_parte',
  AdesaoEmCasa.naoFeito => 'nao_feito',
};

RegistroDeHojeNoPortal _registroDeHoje(Mapa m) => RegistroDeHojeNoPortal(
  adesao: adesaoDoPortal(lerCampo<String>(m, 'adesao')),
  registradoPor: _enum(
    RegistradoPor.values,
    (r) => r.valor,
    lerCampo<String>(m, 'registradoPor'),
  ),
  primeiroNome: lerOpcional<String>(m, 'primeiroNome'),
  registradoEm: lerInstanteOpcional(m, 'registradoEm'),
  reflexao: lerOpcional<String>(m, 'reflexao'),
);

OrientacaoNoPortal _orientacao(Mapa m) {
  final registro = lerOpcional<Mapa>(m, 'registroDeHoje');
  return OrientacaoNoPortal(
    idOrientacao: lerCampo<String>(m, 'idOrientacao'),
    titulo: lerCampo<String>(m, 'titulo'),
    texto: lerCampo<String>(m, 'texto'),
    vezesPorSemana: lerCampo<int>(m, 'vezesPorSemana'),
    primeiroNomeDoTerapeuta: lerCampo<String>(m, 'primeiroNomeDoTerapeuta'),
    especialidade: lerOpcional<String>(m, 'especialidade'),
    publicadaEm: lerInstante(m, 'publicadaEm'),
    registroDeHoje: registro == null ? null : _registroDeHoje(registro),
  );
}

/// `GET /portal/programa`.
ProgramaNoPortal lerPrograma(Mapa m) => _ler(
  () => ProgramaNoPortal(
    dia: lerDataCivil(m, 'dia'),
    orientacoes: [for (final o in _objetos(m, 'orientacoes')) _orientacao(o)],
  ),
);

// ---------------------------------------------------------------------------
// Mapeadores para o app
// ---------------------------------------------------------------------------

/// O provedor da conta no modo local (`ContaUsuario.idProvedor`).
const String provedorTeraeLocal = 'terae-local';

/// O Terae local é a clínica de terapia ocupacional infantil (v1 do produto):
/// todo paciente do portal tem a linha de TO, e só ela (D21: sem receita).
const Set<LinhaDeCuidado> linhasDoTeraeLocal = {
  LinhaDeCuidado.terapiaOcupacional,
};

/// O paciente do seletor como o app o conhece. O portal não expõe CPF,
/// nascimento nem o profissional de referência (`profissionalRefId` vazio).
Paciente pacienteDoPortal(PacienteDaConta p) => Paciente(
  id: p.idPaciente,
  profissionalRefId: '',
  nome: p.nome,
  ativo: true,
  linhasDeCuidado: linhasDoTeraeLocal,
  nomeDaClinica: p.nomeDaClinica,
  telefoneDaClinica: p.telefoneDaClinica,
);

/// O `/eu` vira a conta e os vínculos de onde a `Sessao` deriva os perfis:
/// responsável legal e titular → perfil paciente/família (com a voz da D24);
/// cuidador → perfil cuidador, com a cópia sem dados pessoais.
VinculosDaConta vinculosDoPortal(EuDoPortal eu) {
  final familia = [
    for (final p in eu.pacientes)
      if (p.perfil != PerfilDoPortal.cuidador) p,
  ];
  return VinculosDaConta(
    conta: ContaUsuario(
      id: eu.idUsuario,
      nomeExibicao: eu.nome,
      email: eu.email,
      idProvedor: provedorTeraeLocal,
      situacao: SituacaoConta.ativa,
    ),
    pacientes: [for (final p in familia) pacienteDoPortal(p)],
    acompanhados: [
      for (final p in eu.pacientes)
        if (p.perfil == PerfilDoPortal.cuidador)
          pacienteDoPortal(p).paraCuidador(),
    ],
    qualidades: {
      for (final p in familia)
        p.idPaciente: p.perfil == PerfilDoPortal.responsavelLegal
            ? QualidadeConsentimento.responsavelLegal
            : QualidadeConsentimento.titular,
    },
  );
}

/// Uma sessão do portal como agendamento. Desmarcada pela clínica →
/// `cancelado`; o resto, `agendado` (a agenda só traz sessões futuras).
Agendamento agendamentoDoPortal(
  SessaoNoPortal s, {
  required String pacienteId,
  required String profissionalId,
}) => Agendamento(
  id: s.idSessao,
  pacienteId: pacienteId,
  profissionalId: profissionalId,
  dataHora: s.inicio,
  situacao: s.confirmacao == ConfirmacaoNoPortal.desmarcadaPelaClinica
      ? SituacaoAgendamento.cancelado
      : SituacaoAgendamento.agendado,
  duracaoMinutos: s.fim.difference(s.inicio).inMinutes,
);

/// A resposta de presença que a sessão já tem, ou `null` (pendente ou
/// desmarcada). O portal não diz quando respondeu: [respondidaEm] é o
/// instante do recibo, se o app o recebeu, ou o da leitura.
ConfirmacaoDePresenca? confirmacaoDoPortal(
  SessaoNoPortal s, {
  required String pacienteId,
  required DateTime respondidaEm,
}) {
  final resposta = switch (s.confirmacao) {
    ConfirmacaoNoPortal.confirmada => RespostaPresenca.vamos,
    ConfirmacaoNoPortal.ausenciaAvisada => RespostaPresenca.naoVamos,
    ConfirmacaoNoPortal.pendente ||
    ConfirmacaoNoPortal.desmarcadaPelaClinica => null,
  };
  if (resposta == null) return null;
  return ConfirmacaoDePresenca(
    agendamentoId: s.idSessao,
    pacienteId: pacienteId,
    resposta: resposta,
    respondidaEm: respondidaEm,
    situacaoEnvio: SituacaoEnvio.enviado,
  );
}

/// Uma orientação como atividade de casa. O portal não tem ocupação (a tela
/// esconde a etiqueta: `CapacidadesDaFonte.ocupacaoDaAtividade`) nem limite
/// de vezes por semana (o app vai até 7).
AtividadeDeCasa atividadeDoPortal(
  OrientacaoNoPortal o, {
  required String pacienteId,
  required String profissionalId,
}) => AtividadeDeCasa(
  id: o.idOrientacao,
  pacienteId: pacienteId,
  profissionalId: profissionalId,
  titulo: o.titulo,
  texto: o.texto,
  vezesPorSemana: o.vezesPorSemana.clamp(1, 7),
  ocupacao: Ocupacao.autocuidado,
  publicadaEm: o.publicadaEm,
);

/// Id do registro de hoje de uma orientação: um por orientação e dia.
String idDoRegistroDeHoje(String idOrientacao, DataCivil dia) =>
    '$idOrientacao:${dia.paraIso()}';

/// O registro de hoje de uma orientação, como registro de atividade.
RegistroDeAtividade registroDoPortal(
  OrientacaoNoPortal o,
  RegistroDeHojeNoPortal r, {
  required String pacienteId,
  required DataCivil dia,
  required QuemRegistrou quem,
}) => RegistroDeAtividade(
  id: idDoRegistroDeHoje(o.idOrientacao, dia),
  pacienteId: pacienteId,
  atividadeId: o.idOrientacao,
  dia: dia,
  adesao: r.adesao,
  reflexao: r.reflexao,
  quem: quem,
  // Sem a hora (registro de outra conta ou de link), o começo do dia.
  registradoEm: r.registradoEm ?? dia.inicioNaClinica,
  situacaoEnvio: SituacaoEnvio.enviado,
);
