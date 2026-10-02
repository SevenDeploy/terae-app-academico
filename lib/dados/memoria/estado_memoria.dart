/// Estado único da implementação em memória (§22): o "servidor simulado" e,
/// em [EstadoMemoria.fila], o que ainda está só no aparelho (D11).
library;

import 'dart:convert';

import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/validacao/cpf.dart';
import '../conversao_mapa.dart';
import '../enums/situacao_conta.dart';
import '../enums/situacao_envio.dart';
import '../enums/situacao_vinculo.dart';
import '../enums/tipo_convite.dart';
import '../modelos/agendamento.dart';
import '../modelos/alerta.dart';
import '../modelos/consentimento.dart';
import '../modelos/conta_usuario.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../modelos/registro_diario.dart';
import '../modelos/vinculo_cuidador.dart';
import '../repositorios/autenticacao_repositorio.dart';
import '../repositorios/falhas.dart';
import 'regras.dart';

/// Lê o texto de `demonstracao.json`. Lança [FormatException] se não for um
/// objeto JSON.
Mapa lerDemonstracao(String texto) {
  final valor = jsonDecode(texto);
  if (valor is! Map<String, Object?>) {
    throw const FormatException('demonstracao.json precisa ser um objeto');
  }
  return valor;
}

final RegExp _formatoHora = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

/// D9 — troca, em qualquer profundidade de [valor], cada data relativa pela
/// data absoluta no formato do mapa, contada a partir de [hoje] (dia civil da
/// clínica):
/// - `{"emDias": n}` → data civil `AAAA-MM-DD` de hoje + n;
/// - `{"emDias": n, "hora": "HH:mm"}` → instante ISO UTC dessa hora de parede
///   da clínica (−04:00).
///
/// Devolve uma cópia; [valor] não muda. Outra chave junto de `emDias` lança
/// [FormatException].
Object? resolverDatasRelativas(Object? valor, DataCivil hoje) {
  if (valor is Map<String, Object?>) {
    if (valor.containsKey('emDias')) return _dataRelativa(valor, hoje);
    return <String, Object?>{
      for (final e in valor.entries)
        e.key: resolverDatasRelativas(e.value, hoje),
    };
  }
  if (valor is List<Object?>) {
    return [for (final item in valor) resolverDatasRelativas(item, hoje)];
  }
  return valor;
}

String _dataRelativa(Mapa relativa, DataCivil hoje) {
  final extras = relativa.keys.where((k) => k != 'emDias' && k != 'hora');
  if (extras.isNotEmpty) {
    throw FormatException('Data relativa com chave desconhecida', relativa);
  }
  final dias = lerCampo<int>(relativa, 'emDias');
  final dia = hoje.somarDias(dias);
  final hora = lerOpcional<String>(relativa, 'hora');
  if (hora == null) return dia.paraIso();
  final m = _formatoHora.firstMatch(hora);
  if (m == null) throw FormatException('Hora fora do formato HH:mm', hora);
  return escreverInstante(
    instanteNaClinica(
      dia.ano,
      dia.mes,
      dia.dia,
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
    ),
  );
}

const Set<String> _chavesConhecidas = {
  'versao',
  'descricao',
  'identidades',
  'profissionais',
  'contas',
  'pacientes',
  'consentimentos',
  'convites',
  'vinculos',
  'agendamentos',
  'receitas',
  'itensMedicacao',
  'marcos',
  'registros',
  'alertas',
};

List<Mapa> _entradas(Mapa dados, String chave) {
  final valor = dados[chave];
  if (valor == null) return const [];
  if (valor is! List<Object?>) {
    throw FormatException('"$chave" precisa ser uma lista', valor);
  }
  final entradas = <Mapa>[];
  for (final item in valor) {
    if (item is! Map<String, Object?>) {
      throw FormatException('Item de "$chave" precisa ser um objeto', item);
    }
    entradas.add(item);
  }
  return entradas;
}

IdentidadeProvedor _identidadeDoMapa(Mapa mapa) => IdentidadeProvedor(
  provedor: lerEnum(mapa, 'provedor', Provedor.values),
  idProvedor: lerCampo<String>(mapa, 'idProvedor'),
  email: lerCampo<String>(mapa, 'email'),
  nomeExibicao: lerCampo<String>(mapa, 'nomeExibicao'),
);

Mapa _identidadeParaMapa(IdentidadeProvedor i) => {
  'provedor': i.provedor.name,
  'idProvedor': i.idProvedor,
  'email': i.email,
  'nomeExibicao': i.nomeExibicao,
};

FormatException _inconsistente(String descricao, [Object? fonte]) =>
    FormatException('Demonstração inconsistente: $descricao', fonte);

/// Todas as coleções, por `id` e na ordem de criação (o `Map` do Dart guarda
/// a ordem de inserção; trocar o valor de uma chave mantém o lugar). Nenhuma
/// operação remove item: muda a situação ou preenche a data (§23).
///
/// As coleções ficam expostas para os repositórios em memória e para os testes
/// de regra (`test/dados/`); tela nenhuma chega aqui (§24).
class EstadoMemoria {
  /// Carrega [dados] no formato de `demonstracao.json`, resolvendo as datas
  /// relativas a [hoje], e confere a integridade referencial. Lança
  /// [FormatException] no primeiro problema.
  EstadoMemoria.daDemonstracao(Mapa dados, {required DataCivil hoje}) {
    final desconhecidas = dados.keys.where(
      (k) => !_chavesConhecidas.contains(k),
    );
    if (desconhecidas.isNotEmpty) {
      throw FormatException('Coleção desconhecida', desconhecidas.join(', '));
    }
    final d = resolverDatasRelativas(dados, hoje) as Mapa;
    identidades.addAll(_entradas(d, 'identidades').map(_identidadeDoMapa));
    _carregar(
      d,
      'profissionais',
      profissionais,
      ProfissionalSaude.fromMap,
      (x) => x.id,
    );
    _carregar(d, 'contas', contas, ContaUsuario.fromMap, (x) => x.id);
    _carregar(d, 'pacientes', pacientes, Paciente.fromMap, (x) => x.id);
    _carregar(
      d,
      'consentimentos',
      consentimentos,
      Consentimento.fromMap,
      (x) => x.id,
    );
    _carregar(d, 'convites', convites, ConviteAcesso.fromMap, (x) => x.id);
    _carregar(d, 'vinculos', vinculos, VinculoCuidador.fromMap, (x) => x.id);
    _carregar(
      d,
      'agendamentos',
      agendamentos,
      Agendamento.fromMap,
      (x) => x.id,
    );
    _carregar(d, 'receitas', receitas, ReceitaUsoContinuo.fromMap, (x) => x.id);
    _carregar(
      d,
      'itensMedicacao',
      itensMedicacao,
      ItemMedicacao.fromMap,
      (x) => x.id,
    );
    _carregar(d, 'marcos', marcos, MarcoJornada.fromMap, (x) => x.id);
    final todos = <String, RegistroDiario>{};
    _carregar(d, 'registros', todos, RegistroDiario.fromMap, (x) => x.id);
    for (final r in todos.values) {
      (r.situacaoEnvio == SituacaoEnvio.enviado ? registros : fila)[r.id] = r;
    }
    _carregar(d, 'alertas', alertas, Alerta.fromMap, (x) => x.id);
    _conferirIntegridade();
    for (final a in alertas.values) {
      destinatarios[a.id] = _destinatarioDoRegistro(a.registroId);
    }
  }

  /// D5 — contas do provedor "no aparelho" (folha "Escolha uma conta").
  final List<IdentidadeProvedor> identidades = [];
  final Map<String, ProfissionalSaude> profissionais = {};
  final Map<String, ContaUsuario> contas = {};
  final Map<String, Paciente> pacientes = {};
  final Map<String, Consentimento> consentimentos = {};
  final Map<String, ConviteAcesso> convites = {};
  final Map<String, VinculoCuidador> vinculos = {};
  final Map<String, Agendamento> agendamentos = {};
  final Map<String, ReceitaUsoContinuo> receitas = {};
  final Map<String, ItemMedicacao> itensMedicacao = {};
  final Map<String, MarcoJornada> marcos = {};

  /// Registros que o servidor recebeu (`enviado`). Nunca editados (§23).
  final Map<String, RegistroDiario> registros = {};

  /// Fila de envio do aparelho (`naFila`), na ordem em que entrou.
  final Map<String, RegistroDiario> fila = {};
  final Map<String, Alerta> alertas = {};

  /// Caixa de cada alerta: id do alerta → id do profissional de referência
  /// do paciente no momento em que o servidor o criou (§23: "endereçado ao
  /// profissional de referência"; o modelo Alerta não carrega esse campo).
  final Map<String, String> destinatarios = {};

  static void _carregar<T>(
    Mapa dados,
    String chave,
    Map<String, T> destino,
    T Function(Mapa) doMapa,
    String Function(T) id,
  ) {
    for (final mapa in _entradas(dados, chave)) {
      final item = doMapa(mapa);
      if (destino.containsKey(id(item))) {
        throw _inconsistente('id repetido em "$chave"', id(item));
      }
      destino[id(item)] = item;
    }
  }

  void _exigir(bool condicao, String descricao, Object? fonte) {
    if (!condicao) throw _inconsistente(descricao, fonte);
  }

  void _conferirIntegridade() {
    final cpfs = <String>{};
    for (final p in pacientes.values) {
      _exigir(
        profissionais.containsKey(p.profissionalRefId),
        'profissional de referência',
        p.id,
      );
      _exigir(
        p.contaId == null || contas.containsKey(p.contaId),
        'conta do paciente',
        p.id,
      );
      final cpf = p.cpf;
      _exigir(
        cpf != null && cpfValido(cpf) && cpf == somenteDigitos(cpf),
        'CPF do paciente',
        p.id,
      );
      _exigir(cpfs.add(cpf!), 'CPF repetido entre pacientes', p.id);
      _exigir(p.dataNascimento != null, 'nascimento do paciente', p.id);
    }
    for (final c in consentimentos.values) {
      _exigir(
        pacientes.containsKey(c.pacienteId),
        'paciente do consentimento',
        c.id,
      );
      _exigir(contas.containsKey(c.contaId), 'conta do consentimento', c.id);
    }
    final codigos = <String>{};
    for (final c in convites.values) {
      final paciente = pacientes[c.pacienteId];
      _exigir(paciente != null, 'paciente do convite', c.id);
      _exigir(codigoBemFormado(c.codigo), 'código de convite', c.codigo);
      _exigir(codigos.add(c.codigo), 'código de convite repetido', c.codigo);
      _exigir(
        cpfValido(c.cpfConvidado) &&
            c.cpfConvidado == somenteDigitos(c.cpfConvidado),
        'CPF do convite',
        c.id,
      );
      if (c.tipo == TipoConvite.paciente) {
        _exigir(
          c.cpfConvidado == paciente!.cpf,
          'CPF do código da clínica',
          c.id,
        );
        _exigir(
          c.usadoEm == null || paciente.contaId != null,
          'código usado sem conta',
          c.id,
        );
      }
    }
    for (final v in vinculos.values) {
      final convite = convites[v.conviteId];
      _exigir(pacientes.containsKey(v.pacienteId), 'paciente do vínculo', v.id);
      _exigir(
        convite != null &&
            convite.tipo == TipoConvite.cuidador &&
            convite.pacienteId == v.pacienteId,
        'convite do vínculo',
        v.id,
      );
      _exigir(
        v.contaCuidadorId == null || contas.containsKey(v.contaCuidadorId),
        'conta do cuidador',
        v.id,
      );
      final aceito = convite!.usadoEm != null;
      switch (v.situacao) {
        case SituacaoVinculo.pendente:
          _exigir(
            !aceito && v.contaCuidadorId == null,
            'vínculo pendente já aceito',
            v.id,
          );
        case SituacaoVinculo.ativo:
          _exigir(
            aceito && v.contaCuidadorId != null && v.autorizadoEm != null,
            'vínculo ativo sem aceite',
            v.id,
          );
        case SituacaoVinculo.revogado:
          _exigir(v.revogadoEm != null, 'vínculo revogado sem data', v.id);
      }
    }
    _exigir(
      convites.values
          .where((c) => c.tipo == TipoConvite.cuidador)
          .every(
            (c) =>
                vinculos.values.where((v) => v.conviteId == c.id).length == 1,
          ),
      'convite de cuidador sem exatamente um vínculo',
      null,
    );
    for (final a in agendamentos.values) {
      _exigir(
        pacientes.containsKey(a.pacienteId),
        'paciente da consulta',
        a.id,
      );
      _exigir(
        profissionais.containsKey(a.profissionalId),
        'profissional da consulta',
        a.id,
      );
    }
    for (final r in receitas.values) {
      _exigir(pacientes.containsKey(r.pacienteId), 'paciente da receita', r.id);
      _exigir(
        profissionais.containsKey(r.profissionalId),
        'profissional da receita',
        r.id,
      );
    }
    for (final i in itensMedicacao.values) {
      _exigir(receitas.containsKey(i.receitaId), 'receita do item', i.id);
    }
    for (final m in marcos.values) {
      _exigir(pacientes.containsKey(m.pacienteId), 'paciente do marco', m.id);
    }
    for (final r in [...registros.values, ...fila.values]) {
      _exigir(
        pacientes.containsKey(r.pacienteId),
        'paciente do registro',
        r.id,
      );
    }
    final comAlerta = <String>{};
    for (final a in alertas.values) {
      _exigir(
        registros.containsKey(a.registroId),
        'alerta de registro não enviado',
        a.id,
      );
      _exigir(
        comAlerta.add(a.registroId),
        'dois alertas no mesmo registro',
        a.id,
      );
    }
  }

  String _destinatarioDoRegistro(String registroId) =>
      pacientes[registros[registroId]!.pacienteId]!.profissionalRefId;

  // ---------------------------------------------------------------------------
  // Consultas usadas pelos repositórios
  // ---------------------------------------------------------------------------

  /// O paciente, ou recusa com `acessoNegado` (contratos de leitura).
  Paciente exigirPaciente(String pacienteId) =>
      pacientes[pacienteId] ??
      (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));

  ContaUsuario? contaDoProvedor(String idProvedor) {
    for (final c in contas.values) {
      if (c.idProvedor == idProvedor) return c;
    }
    return null;
  }

  ConviteAcesso? conviteDoCodigo(String codigo) {
    final normalizado = normalizarCodigo(codigo);
    for (final c in convites.values) {
      if (c.codigo == normalizado) return c;
    }
    return null;
  }

  /// Vínculo que nasceu do convite de cuidador [conviteId] (sempre um só).
  VinculoCuidador vinculoDoConvite(String conviteId) =>
      vinculos.values.firstWhere((v) => v.conviteId == conviteId);

  Set<String> get codigos => {for (final c in convites.values) c.codigo};

  /// §7.4 — vínculos do paciente que contam no limite de dois (pendentes e
  /// ativos), sem contar [exceto].
  int vinculosNoLimite(String pacienteId, {String? exceto}) => vinculos.values
      .where(
        (v) =>
            v.pacienteId == pacienteId &&
            v.id != exceto &&
            v.situacao.contaNoLimite,
      )
      .length;

  /// Há vínculo pendente ou ativo do paciente convidado com este CPF?
  bool cpfComVinculoEmAberto(String pacienteId, String cpf) =>
      vinculos.values.any(
        (v) =>
            v.pacienteId == pacienteId &&
            v.situacao.contaNoLimite &&
            convites[v.conviteId]!.cpfConvidado == cpf,
      );

  /// §19 — o perfil decorre dos vínculos: pacientes ativos com `contaId` da
  /// [conta] (cópia completa) e pacientes ativos com vínculo de cuidador
  /// ativo da [conta] (cópia do cuidador, RNFM05).
  VinculosDaConta vinculosDaConta(ContaUsuario conta) => VinculosDaConta(
    conta: conta,
    pacientes: List.unmodifiable([
      for (final p in pacientes.values)
        if (p.contaId == conta.id && p.ativo) p,
    ]),
    acompanhados: List.unmodifiable([
      for (final v in vinculos.values)
        if (v.contaCuidadorId == conta.id &&
            v.situacao == SituacaoVinculo.ativo &&
            pacientes[v.pacienteId]!.ativo)
          pacientes[v.pacienteId]!.paraCuidador(),
    ]),
  );

  /// A conta tem vínculo de cuidador ativo com o paciente, e os dois estão
  /// ativos? (RNFM05)
  bool cuidadorAutorizado(String contaCuidadorId, String pacienteId) {
    final conta = contas[contaCuidadorId];
    final paciente = pacientes[pacienteId];
    if (conta == null || conta.situacao != SituacaoConta.ativa) return false;
    if (paciente == null || !paciente.ativo) return false;
    return vinculos.values.any(
      (v) =>
          v.pacienteId == pacienteId &&
          v.contaCuidadorId == contaCuidadorId &&
          v.situacao == SituacaoVinculo.ativo,
    );
  }

  /// RFM02 — receita do paciente vigente em [hoje]; havendo mais de uma, a de
  /// início mais recente.
  ReceitaUsoContinuo? receitaVigente(String pacienteId, DataCivil hoje) {
    ReceitaUsoContinuo? vigente;
    for (final r in receitas.values) {
      if (r.pacienteId != pacienteId || !r.vigenteEm(hoje)) continue;
      if (vigente == null ||
          r.vigenciaInicio.ehDepoisDe(vigente.vigenciaInicio)) {
        vigente = r;
      }
    }
    return vigente;
  }

  /// Itens da receita, na ordem em que a receita os lista.
  List<ItemMedicacao> itensDaReceita(String receitaId) => List.unmodifiable(
    itensMedicacao.values.where((i) => i.receitaId == receitaId),
  );

  /// §7.1 — registro do mesmo paciente que o servidor recebeu imediatamente
  /// antes de [registro] (pelo `registradoEm`).
  RegistroDiario? registroAnterior(RegistroDiario registro) {
    RegistroDiario? anterior;
    for (final r in registros.values) {
      if (r.pacienteId != registro.pacienteId || r.id == registro.id) continue;
      if (!r.registradoEm.isBefore(registro.registradoEm)) continue;
      if (anterior == null || r.registradoEm.isAfter(anterior.registradoEm)) {
        anterior = r;
      }
    }
    return anterior;
  }

  Alerta? alertaDoRegistro(String registroId) {
    for (final a in alertas.values) {
      if (a.registroId == registroId) return a;
    }
    return null;
  }

  /// Alertas na caixa do profissional, na ordem em que o servidor os criou.
  List<Alerta> alertasDoProfissional(String profissionalId) => [
    for (final a in alertas.values)
      if (destinatarios[a.id] == profissionalId) a,
  ];

  /// Grava o alerta criado pelo servidor e o endereça ao profissional de
  /// referência do paciente do registro.
  void guardarAlerta(Alerta alerta) {
    alertas[alerta.id] = alerta;
    destinatarios[alerta.id] = _destinatarioDoRegistro(alerta.registroId);
  }

  /// Retrato de tudo, no formato dos mapas — para comparar estados em teste
  /// (ex.: `reiniciarDados` volta ao inicial).
  Mapa paraMapa() => {
    'identidades': [for (final i in identidades) _identidadeParaMapa(i)],
    'profissionais': [for (final x in profissionais.values) x.toMap()],
    'contas': [for (final x in contas.values) x.toMap()],
    'pacientes': [for (final x in pacientes.values) x.toMap()],
    'consentimentos': [for (final x in consentimentos.values) x.toMap()],
    'convites': [for (final x in convites.values) x.toMap()],
    'vinculos': [for (final x in vinculos.values) x.toMap()],
    'agendamentos': [for (final x in agendamentos.values) x.toMap()],
    'receitas': [for (final x in receitas.values) x.toMap()],
    'itensMedicacao': [for (final x in itensMedicacao.values) x.toMap()],
    'marcos': [for (final x in marcos.values) x.toMap()],
    'registros': [for (final x in registros.values) x.toMap()],
    'fila': [for (final x in fila.values) x.toMap()],
    'alertas': [for (final x in alertas.values) x.toMap()],
    'destinatarios': {...destinatarios},
  };
}
