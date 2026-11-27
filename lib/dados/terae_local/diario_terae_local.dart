/// O diário da família no Terae local (P3 + P4): `/api/portal/diario`.
///
/// Contrato de referência, no monorepo do Terae web:
/// `packages/contratos/src/portal/index.ts` (`EsquemaEnvioDoDiario`,
/// `EsquemaRegistroDoDiarioNoPortal`, `EsquemaPaginaDoDiarioNoPortal`,
/// `EsquemaVersaoDoDiarioNoPortal`, `EsquemaReciboDoDiarioNoPortal`,
/// `EsquemaEnvioDaRetirada`) e o controlador
/// `apps/api/src/modulos/portal/apresentacao/diario-do-portal.controller.ts`.
///
/// Diferença de propósito em relação ao resto da fonte local (TL4, sem
/// fila): o diário guarda no aparelho o registro que não saiu por falta de
/// rede, como a fila do portal web (IndexedDB, PMC-516), e reenvia com a
/// mesma `Idempotency-Key` (o `id` do registro, gerado no aparelho) e o
/// `guardadoEm` (PMC-558). Corrigir e retirar pedem a internet na hora.
///
/// O servidor dá o próprio id ao registro: depois do envio, o registro que
/// o app conhece é o do servidor (o da lista), e o id do aparelho fica só
/// como chave de idempotência.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../conversao_mapa.dart';
import '../enums/adesao.dart';
import '../enums/intensidade.dart';
import '../enums/motivo_da_retirada.dart';
import '../enums/regra_alerta.dart';
import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import 'cliente_do_portal.dart';
import 'contexto_do_portal.dart';

/// Onde a fila do diário fica guardada no aparelho (um texto JSON).
abstract interface class GuardaDaFilaDoDiario {
  Future<String?> ler();
  Future<void> gravar(String? texto);
}

/// A fila do diário nas `SharedPreferences` (só o modo local).
class GuardaDaFilaEmPreferencias implements GuardaDaFilaDoDiario {
  GuardaDaFilaEmPreferencias(this._prefs);

  static const String chave = 'terae_local.fila_do_diario';

  final SharedPreferences _prefs;

  @override
  Future<String?> ler() async => _prefs.getString(chave);

  @override
  Future<void> gravar(String? texto) async {
    if (texto == null) {
      await _prefs.remove(chave);
    } else {
      await _prefs.setString(chave, texto);
    }
  }
}

/// A fila só em memória (testes).
class GuardaDaFilaEmMemoria implements GuardaDaFilaDoDiario {
  String? texto;

  @override
  Future<String?> ler() async => texto;

  @override
  Future<void> gravar(String? texto) async => this.texto = texto;
}

/// Quantas páginas, no máximo, [DiarioTeraeLocal.registro] percorre para
/// achar um registro que ainda não passou pela lista deste aparelho.
const int _paginasParaAchar = 10;

/// O diário da família sobre a API do portal do Terae local.
class DiarioTeraeLocal implements RepositorioDiario {
  DiarioTeraeLocal(this._contexto, {required this.fila});

  final ContextoDoPortal _contexto;

  /// Onde fica o registro que não saiu por falta de rede.
  final GuardaDaFilaDoDiario fila;

  /// Os registros vistos (lista, envio, correção, retirada), pelo id do
  /// servidor: a TM14/TM15 abrem por id e a API não tem `GET /diario/:id`.
  final Map<String, RegistroDiario> _vistos = {};

  /// O registro que saiu da fila, pelo id do aparelho (reenviar não duplica).
  final Map<String, ResultadoEnvio> _saidos = {};

  // -------------------------------------------------------------------------
  // fila
  // -------------------------------------------------------------------------

  Future<List<RegistroDiario>> _lerFila() async {
    final texto = await fila.ler();
    if (texto == null || texto.isEmpty) return const [];
    final bruto = jsonDecode(texto);
    if (bruto is! List) return const [];
    return [
      for (final item in bruto)
        if (item is Map<String, Object?>) RegistroDiario.fromMap(item),
    ];
  }

  Future<void> _gravarFila(List<RegistroDiario> registros) => fila.gravar(
    registros.isEmpty
        ? null
        : jsonEncode([for (final r in registros) r.toMap()]),
  );

  /// D20 — "Sair" esquece a fila e o que foi visto neste aparelho.
  Future<void> esquecer() async {
    _vistos.clear();
    _saidos.clear();
    await _gravarFila(const []);
  }

  // -------------------------------------------------------------------------
  // contrato
  // -------------------------------------------------------------------------

  @override
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    if (_saidos[registro.id] case final pronto?) return pronto;
    final fila = await _lerFila();
    final naFila = fila.any((r) => r.id == registro.id);
    try {
      final resultado = await _enviarAoServidor(registro, daFila: naFila);
      if (naFila) {
        await _gravarFila([
          for (final r in fila)
            if (r.id != registro.id) r,
        ]);
      }
      return resultado;
    } on RecusaDeRegra catch (recusa) {
      if (recusa.motivo != MotivoRecusa.semConexao) rethrow;
      final guardado = registro.copyWith(situacaoEnvio: SituacaoEnvio.naFila);
      if (!naFila) await _gravarFila([...fila, guardado]);
      return ResultadoEnvio(registro: guardado);
    }
  }

  @override
  Future<List<ResultadoEnvio>> reenviarFila() async {
    final fila = await _lerFila();
    final saidos = <ResultadoEnvio>[];
    final restam = <RegistroDiario>[];
    var semRede = false;
    for (final r in fila) {
      if (semRede) {
        restam.add(r);
        continue;
      }
      try {
        saidos.add(await _enviarAoServidor(r, daFila: true));
      } on RecusaDeRegra catch (recusa) {
        if (recusa.motivo == MotivoRecusa.semConexao) semRede = true;
        // Outra recusa (paciente fora do diário, sessão acabada) também
        // fica guardada: nada se perde em silêncio.
        restam.add(r);
      }
    }
    if (restam.length != fila.length) await _gravarFila(restam);
    return List.unmodifiable(saidos);
  }

  @override
  Future<PaginaDoDiario> pagina(String pacienteId, {DateTime? antes}) =>
      _pagina(pacienteId, antes: antes, tentarFila: antes == null);

  Future<PaginaDoDiario> _pagina(
    String pacienteId, {
    DateTime? antes,
    required bool tentarFila,
  }) async {
    if (tentarFila) {
      // Como o `EsvaziadorDaFila` do portal: ao abrir a lista, tenta a fila.
      try {
        await reenviarFila();
      } on Exception {
        // A lista abre mesmo assim; os guardados continuam guardados.
      }
    }
    final c = _contexto;
    final corpo = await c.comPaciente(
      pacienteId,
      () async => (await c.cliente.get(
        'diario',
        consulta: {if (antes != null) 'antes': escreverInstante(antes)},
      )).objeto,
    );
    final (itens, haMais) = _ler(
      () => (
        lerMapas<Mapa>(corpo, 'registros', (m) => m),
        lerCampo<bool>(corpo, 'haMais'),
      ),
    );
    final registros = <RegistroDiario>[];
    for (final item in itens) {
      registros.add(await _doPortal(pacienteId, item));
    }
    return PaginaDoDiario(
      registros: List.unmodifiable(registros),
      haMais: haMais,
    );
  }

  @override
  Future<List<RegistroDiario>> pendentes(String pacienteId) async => [
    for (final r in await _lerFila())
      if (r.pacienteId == pacienteId) r,
  ]..sort((a, b) => a.registradoEm.compareTo(b.registradoEm));

  @override
  Future<RegistroDiario> registro(String registroId) async {
    if (_vistos[registroId] case final visto?) return visto;
    for (final r in await _lerFila()) {
      if (r.id == registroId) return r;
    }
    final pacienteId = _contexto.eu?.idPacienteAtual;
    if (pacienteId == null) {
      throw const RecusaDeRegra(MotivoRecusa.registroInexistente);
    }
    DateTime? antes;
    for (var i = 0; i < _paginasParaAchar; i++) {
      final pagina = await _pagina(pacienteId, antes: antes, tentarFila: false);
      for (final r in pagina.registros) {
        if (r.id == registroId) return r;
      }
      if (!pagina.haMais || pagina.registros.isEmpty) break;
      final ultimo = pagina.registros.last;
      antes = ultimo.enviadoEm ?? ultimo.registradoEm;
    }
    throw const RecusaDeRegra(MotivoRecusa.registroInexistente);
  }

  @override
  Future<Alerta?> alertaDoRegistro(String registroId) async {
    final r = _vistos[registroId];
    if (r == null || !r.alertouAEquipe) return null;
    return _alertaDe(r);
  }

  @override
  Future<ResultadoEnvio> corrigir(
    String registroId,
    EntradaDoDiario entrada,
  ) async {
    final atual = await registro(registroId);
    if (!atual.enviado) {
      // Guardado neste aparelho: ainda não existe no servidor.
      throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
    }
    final c = _contexto;
    final recibo = await c.comPaciente(
      atual.pacienteId,
      () async => (await c.cliente.put(
        'diario/${atual.id}',
        corpo: _corpo(atual.pacienteId, entrada),
      )).objeto,
      seNaoExiste: MotivoRecusa.registroInexistente,
      seConflito: MotivoRecusa.registroNaoMudaMais,
    );
    // A API grava cada versão numa linha nova (`id_linhagem`): o recibo traz
    // o id da versão vigente, que é o que a lista passa a mostrar.
    final idNovo = _ler(() => lerCampo<String>(recibo, 'id'));
    final (versao, recebidoEm, ajuda) = _lerRecibo(recibo);
    final corrigido = atual.corrigido(entrada, em: recebidoEm);
    if (corrigido.versao != versao) {
      throw RespostaInesperadaDoPortal(
        detalhe: 'Versão $versao, esperada ${corrigido.versao}.',
      );
    }
    final novo = RegistroDiario(
      id: idNovo,
      pacienteId: corrigido.pacienteId,
      registradoEm: corrigido.registradoEm,
      adesao: corrigido.adesao,
      sintomas: corrigido.sintomas,
      intensidadeSintoma: corrigido.intensidadeSintoma,
      observacoes: corrigido.observacoes,
      situacaoEnvio: corrigido.situacaoEnvio,
      versao: corrigido.versao,
      enviadoEm: corrigido.enviadoEm,
      atualizadoEm: corrigido.atualizadoEm,
      alertouAEquipe: corrigido.alertouAEquipe || ajuda,
      revisadoEm: corrigido.revisadoEm,
      versoesAnteriores: corrigido.versoesAnteriores,
    );
    _vistos[novo.id] = novo;
    // Quem ainda tem o id antigo (a TM14 aberta antes) chega na vigente.
    _vistos[registroId] = novo;
    return ResultadoEnvio(
      registro: novo,
      alerta: ajuda ? _alertaDe(novo) : null,
    );
  }

  @override
  Future<RegistroDiario> retirar(
    String registroId,
    RetiradaDoRegistro motivo,
  ) async {
    final atual = await registro(registroId);
    if (!atual.enviado) {
      throw const RecusaDeRegra(MotivoRecusa.registroNaoMudaMais);
    }
    final c = _contexto;
    final corpo = await c.comPaciente(
      atual.pacienteId,
      () async => (await c.cliente.post(
        'diario/${atual.id}/retirada',
        corpo: {
          'idPaciente': atual.pacienteId,
          'motivo': {
            'categoria': motivo.categoria.valor,
            if (motivo.detalhe case final d? when d.isNotEmpty) 'detalhe': d,
          },
        },
      )).objeto,
      seNaoExiste: MotivoRecusa.registroInexistente,
      seConflito: MotivoRecusa.registroNaoMudaMais,
    );
    return _doPortal(atual.pacienteId, corpo, anteriores: atual);
  }

  // -------------------------------------------------------------------------
  // detalhes
  // -------------------------------------------------------------------------

  Future<ResultadoEnvio> _enviarAoServidor(
    RegistroDiario registro, {
    required bool daFila,
  }) async {
    final c = _contexto;
    final recibo = await c.comPaciente(
      registro.pacienteId,
      () async => (await c.cliente.post(
        'diario',
        corpo: {
          ..._corpo(registro.pacienteId, registro.entrada),
          // PMC-558: só o envio que esperou na fila leva a hora em que foi
          // guardado.
          if (daFila) 'guardadoEm': escreverInstante(registro.registradoEm),
        },
        chaveDeIdempotencia: registro.id,
      )).objeto,
      seNaoExiste: MotivoRecusa.acessoNegado,
      seConflito: MotivoRecusa.registroNaoMudaMais,
    );
    final id = _ler(() => lerCampo<String>(recibo, 'id'));
    final (versao, recebidoEm, ajuda) = _lerRecibo(recibo);
    final enviado = RegistroDiario(
      id: id,
      pacienteId: registro.pacienteId,
      registradoEm: registro.registradoEm,
      adesao: registro.adesao,
      sintomas: registro.sintomas,
      intensidadeSintoma: registro.intensidadeSintoma,
      observacoes: registro.observacoes,
      situacaoEnvio: SituacaoEnvio.enviado,
      versao: versao,
      enviadoEm: recebidoEm,
      alertouAEquipe: ajuda,
    );
    _vistos[id] = enviado;
    final resultado = ResultadoEnvio(
      registro: enviado,
      alerta: ajuda ? _alertaDe(enviado) : null,
    );
    _saidos[registro.id] = resultado;
    return resultado;
  }

  Map<String, Object?> _corpo(String pacienteId, EntradaDoDiario e) => {
    'idPaciente': pacienteId,
    'adesao': e.adesao.name,
    'sintomas': ?e.sintomas,
    if (e.intensidadeSintoma case final i?) 'intensidadeSintoma': i.name,
    'observacoes': ?e.observacoes,
  };

  (int, DateTime, bool) _lerRecibo(Mapa recibo) => _ler(
    () => (
      lerCampo<int>(recibo, 'versao'),
      lerInstante(recibo, 'recebidoEm'),
      lerCampo<bool>(recibo, 'ajudaImediata'),
    ),
  );

  /// Um `RegistroDoDiarioNoPortal` lido campo a campo. Com versão > 1, as
  /// anteriores vêm de `GET /diario/:id/versoes` (ou do [anteriores] já
  /// conhecido, se a versão é a mesma).
  Future<RegistroDiario> _doPortal(
    String pacienteId,
    Mapa m, {
    RegistroDiario? anteriores,
  }) async {
    final base = _ler(() {
      final id = lerCampo<String>(m, 'id');
      final enviadoEm = lerInstante(m, 'enviadoEm');
      final motivo = m['motivoDaRetirada'];
      return (
        id: id,
        idPaciente: lerCampo<String>(m, 'idPaciente'),
        versao: lerCampo<int>(m, 'versao'),
        enviadoEm: enviadoEm,
        escritoEm: lerInstanteOpcional(m, 'escritoEm'),
        adesao: lerEnum(m, 'adesao', Adesao.values),
        intensidade: lerEnumOpcional(
          m,
          'intensidadeSintoma',
          Intensidade.values,
        ),
        sintomas: lerOpcional<String>(m, 'sintomas'),
        observacoes: lerOpcional<String>(m, 'observacoes'),
        revisadoEm: lerInstanteOpcional(m, 'revisadoEm'),
        retiradoEm: lerInstanteOpcional(m, 'retiradoEm'),
        motivo: switch (motivo) {
          null => null,
          final Map<String, Object?> mm => _motivo(mm),
          _ => throw FormatException('motivoDaRetirada inválido', motivo),
        },
        alertou: lerCampo<bool>(m, 'alertouAEquipe'),
      );
    });
    if (base.idPaciente != pacienteId) {
      throw RespostaInesperadaDoPortal(
        detalhe: 'Registro ${base.id} de outro paciente.',
      );
    }
    final conhecido = anteriores ?? _vistos[base.id];
    final (versoes, vigenteEm) = base.versao == 1
        ? (const <VersaoDoRegistro>[], null)
        : (conhecido != null &&
              conhecido.id == base.id &&
              conhecido.versao == base.versao)
        ? (conhecido.versoesAnteriores, conhecido.atualizadoEm)
        : await _anteriores(base.id, pacienteId, base.versao);
    final registro = _ler(
      () => RegistroDiario(
        id: base.id,
        pacienteId: base.idPaciente,
        registradoEm: base.escritoEm ?? base.enviadoEm,
        adesao: base.adesao,
        sintomas: base.sintomas,
        intensidadeSintoma: base.intensidade,
        observacoes: base.observacoes,
        situacaoEnvio: SituacaoEnvio.enviado,
        versao: base.versao,
        enviadoEm: base.enviadoEm,
        atualizadoEm: vigenteEm,
        alertouAEquipe: base.alertou,
        revisadoEm: base.revisadoEm,
        retiradoEm: base.retiradoEm,
        motivoDaRetirada: base.motivo,
        versoesAnteriores: versoes,
      ),
    );
    _vistos[registro.id] = registro;
    return registro;
  }

  /// As versões anteriores à [versao] e quando a vigente foi enviada (o
  /// `atualizadoEm` do registro).
  Future<(List<VersaoDoRegistro>, DateTime?)> _anteriores(
    String id,
    String pacienteId,
    int versao,
  ) async {
    final c = _contexto;
    final corpo = await c.comPaciente(
      pacienteId,
      () async => (await c.cliente.get('diario/$id/versoes')).corpo,
      seNaoExiste: MotivoRecusa.registroInexistente,
    );
    if (corpo is! List) {
      throw const RespostaInesperadaDoPortal(
        detalhe: 'As versões não são uma lista.',
      );
    }
    final lidas = _ler(
      () => [
        for (final item in corpo)
          if (item is Map<String, Object?>)
            (
              versao: lerCampo<int>(item, 'versao'),
              vigente: lerCampo<bool>(item, 'vigente'),
              enviadaEm: lerInstante(item, 'enviadaEm'),
              escritaEm: lerInstanteOpcional(item, 'escritaEm'),
              adesao: lerEnum(item, 'adesao', Adesao.values),
              intensidade: lerEnumOpcional(
                item,
                'intensidadeSintoma',
                Intensidade.values,
              ),
              sintomas: lerOpcional<String>(item, 'sintomas'),
              observacoes: lerOpcional<String>(item, 'observacoes'),
            )
          else
            throw FormatException('Versão inválida', item),
      ]..sort((a, b) => a.versao.compareTo(b.versao)),
    );
    final vigenteEm = lidas.where((v) => v.vigente).firstOrNull?.enviadaEm;
    final anteriores = [
      for (final v in lidas)
        if (!v.vigente && v.versao < versao)
          VersaoDoRegistro(
            versao: v.versao,
            enviadaEm: v.enviadaEm,
            adesao: v.adesao,
            sintomas: v.sintomas,
            intensidadeSintoma: v.intensidade,
            observacoes: v.observacoes,
          ),
    ];
    if (anteriores.length != versao - 1) {
      throw RespostaInesperadaDoPortal(
        detalhe:
            'Registro $id: ${anteriores.length} versões anteriores, '
            'esperadas ${versao - 1}.',
      );
    }
    return (anteriores, vigenteEm);
  }

  RetiradaDoRegistro _motivo(Mapa m) {
    final valor = lerCampo<String>(m, 'categoria');
    final categoria =
        MotivoDaRetirada.doValor(valor) ??
        (throw FormatException('Categoria de retirada inválida', valor));
    return RetiradaDoRegistro(
      categoria: categoria,
      detalhe: lerOpcional<String>(m, 'detalhe'),
    );
  }

  /// O portal só diz que o registro avisou a equipe (`ajudaImediata`,
  /// `alertouAEquipe`), não qual regra nem qual alerta: o alerta do app nasce
  /// daí, com a regra que a intensidade explica.
  Alerta _alertaDe(RegistroDiario r) => Alerta(
    id: 'portal:alerta:${r.id}',
    registroId: r.id,
    regraDisparada: r.intensidadeSintoma == Intensidade.critico
        ? RegraAlerta.intensidadeCritica
        : RegraAlerta.graveConsecutivo,
    emitidoEm: r.atualizadoEm ?? r.enviadoEm ?? r.registradoEm,
  );
}

T _ler<T>(T Function() leitura) {
  try {
    return leitura();
  } on FormatException catch (e) {
    throw RespostaInesperadaDoPortal(detalhe: e.message);
  }
}
