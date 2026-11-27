import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/relogio.dart';
import '../enums/situacao_envio.dart';
import '../local/preferencias_locais.dart';
import '../local/registro_diario_dao.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/alerta.dart';
import '../remoto/falhas_remotas.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/diario_repositorio.dart';
import '../repositorios/falhas.dart';
import '../repositorios/visao_cuidador_repositorio.dart';
import 'fila_de_entidade.dart';
import 'monitor_conexao.dart';
import 'situacao_sincronizacao.dart';

/// Id do alerta de um registro: um UUID derivado do id do registro (§23:
/// no máximo um alerta por registro). Assim, se um envio que "falhou" por
/// prazo chegar ao servidor depois, o reenvio grava o mesmo documento em vez
/// de criar um segundo alerta.
String idDoAlertaDe(String registroId) {
  final h = sha256.convert('alerta:$registroId'.codeUnits).bytes;
  String hex(int de, int ate) =>
      [for (final b in h.sublist(de, ate)) b.toRadixString(16).padLeft(2, '0')]
          .join();
  final versao = (h[6] & 0x0f | 0x50).toRadixString(16).padLeft(2, '0');
  final variante = (h[8] & 0x3f | 0x80).toRadixString(16).padLeft(2, '0');
  return '${hex(0, 4)}-${hex(4, 6)}-$versao${hex(7, 8)}-'
      '$variante${hex(9, 10)}-${hex(10, 16)}';
}

/// O fluxo online/offline do diário (Atividade 4, D16, D18) e das outras
/// entidades gravadas no aparelho ([FilaDeEntidade], evolução de TO).
///
/// - Envia a fila do SQLite (os registros novos guardados sem internet), do
///   mais antigo ao mais novo, um lote do Firestore por registro: o registro
///   `enviado` e, se a regra do §7.1 disparar, o alerta e o aviso do
///   cuidador — tudo confirmado junto ou nada.
/// - Depois envia as [FilaDeEntidade] das outras entidades gravadas no
///   aparelho (evolução de TO), na ordem da lista.
/// - Depois busca no servidor os registros e alertas do paciente e junta com
///   os locais (`RegistroDiarioDao.mesclarDoServidor`: a mudança local ainda
///   na fila vence), e o mesmo para cada fila.
/// - Roda ao abrir o app, quando a conexão volta, no "puxar para atualizar"
///   da TM13 e depois de cada gravação local; publica a [situacao] para o
///   aviso de conexão das telas.
class Sincronizador {
  Sincronizador({
    required this._dao,
    required this._fonte,
    required this._monitor,
    required this._relogio,
    this._preferencias,
    List<FilaDeEntidade> filas = const [],
  }) : _filas = List.unmodifiable(filas);

  final RegistroDiarioDao _dao;
  final FonteFirestore _fonte;
  final MonitorConexao _monitor;
  final Relogio _relogio;
  final PreferenciasLocais? _preferencias;

  /// As outras entidades gravadas no aparelho, além do diário.
  final List<FilaDeEntidade> _filas;

  final ValueNotifier<SituacaoSincronizacao> _situacao = ValueNotifier(
    const SituacaoSincronizacao(),
  );

  /// Para o aviso de conexão (D16).
  ValueListenable<SituacaoSincronizacao> get situacao => _situacao;

  Set<String> _pacientes = const {};
  Future<void>? _emAndamento;
  bool _servidorRespondeu = true;

  /// Pacientes (perfil paciente/família) cujos registros são buscados.
  void acompanhar(Iterable<String> pacienteIds) {
    _pacientes = Set.unmodifiable(pacienteIds);
  }

  /// Passa a ouvir a conexão: quando ela volta, sincroniza sozinho.
  Future<void> iniciar() async {
    _monitor.addListener(_aoMudarConexao);
    await atualizarSituacao();
    if (_monitor.online) unawaited(sincronizar().catchError((Object _) {}));
  }

  void _aoMudarConexao() {
    _servidorRespondeu = true;
    unawaited(atualizarSituacao());
    if (_monitor.online) unawaited(sincronizar().catchError((Object _) {}));
  }

  bool get _online => _monitor.online && _servidorRespondeu;

  /// Recalcula a [situacao] (rede e tamanho de todas as filas).
  Future<void> atualizarSituacao({bool? sincronizando}) async {
    var pendentes = await _dao.contarPendentes();
    for (final fila in _filas) {
      pendentes += await fila.contarPendentes();
    }
    _situacao.value = _situacao.value.copyWith(
      online: _online,
      pendentes: pendentes,
      sincronizando: sincronizando,
      ultimaSincronizacao: _preferencias?.ultimaSincronizacao,
    );
  }

  /// Envia um registro agora: o novo da fila, a correção ou a retirada
  /// (P3). Lança `RecusaDeRegra(semConexao)` sem rede ou se o servidor não
  /// confirmar no prazo — nada muda no aparelho. Devolve o resultado
  /// confirmado, com o alerta se houver; o registro volta com `enviadoEm`
  /// (o primeiro recebimento) e `alertouAEquipe`.
  Future<ResultadoEnvio> enviar(RegistroDiario registro) async {
    if (!_monitor.online) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final existente = await _dao.alertaDoRegistro(registro.id);
    final anterior = await _dao.anteriorA(registro);
    final regra =
        registro.retirado || registro.alertouAEquipe || existente != null
        ? null
        : regraDoAlerta(
            nova: registro.intensidadeSintoma,
            anterior: anterior?.intensidadeSintoma,
          );
    final enviado = registro.copyWith(
      situacaoEnvio: SituacaoEnvio.enviado,
      enviadoEm: registro.enviadoEm ?? _relogio.agora(),
      alertouAEquipe: regra != null ? true : null,
    );
    final pid = registro.pacienteId;
    final lote = _fonte.db.batch()
      ..set(
        _fonte.doPaciente(pid, 'registros').doc(registro.id),
        enviado.toMap(),
      );
    Alerta? alerta;
    if (regra != null) {
      alerta = Alerta(
        id: idDoAlertaDe(registro.id),
        registroId: registro.id,
        regraDisparada: regra,
        emitidoEm: _relogio.agora(),
      );
      lote
        ..set(_fonte.doPaciente(pid, 'alertas').doc(alerta.id), alerta.toMap())
        ..set(_fonte.doPaciente(pid, 'avisosCuidador').doc(alerta.id), {
          ...AvisoDeAlerta.doAlerta(alerta).toMap(),
          'id': alerta.id,
        });
    }
    try {
      await _fonte.gravar(lote);
    } on RecusaDeRegra catch (r) {
      if (r.motivo == MotivoRecusa.semConexao) _servidorRespondeu = false;
      await atualizarSituacao();
      rethrow;
    }
    _servidorRespondeu = true;
    await _dao.salvar(enviado);
    if (alerta != null) await _dao.salvarAlerta(alerta);
    await atualizarSituacao();
    return ResultadoEnvio(registro: enviado, alerta: alerta ?? existente);
  }

  /// Envia a fila do diário e depois a de cada [FilaDeEntidade]; para de
  /// enviar no primeiro "sem conexão" (o resto continua na fila). Devolve os
  /// registros do diário que saíram dela.
  ///
  /// Regra da Atividade 4, a mesma para todas as filas: parar de enviar não
  /// para a sincronização. A busca do servidor ainda roda; se a leitura
  /// responder, o app volta a "online" (a rede voltou e só o envio demorou),
  /// e o que ficou na fila sai na próxima vez.
  Future<List<ResultadoEnvio>> enviarFila() async {
    final saidas = <ResultadoEnvio>[];
    if (!_monitor.online) return saidas;
    for (final r in await _dao.pendentes()) {
      try {
        saidas.add(await enviar(r));
      } on RecusaDeRegra catch (recusa) {
        if (recusa.motivo == MotivoRecusa.semConexao) return saidas;
        rethrow;
      }
    }
    for (final fila in _filas) {
      try {
        await fila.enviarPendentes();
      } on RecusaDeRegra catch (recusa) {
        if (ehSemConexao(recusa)) {
          _servidorRespondeu = false;
          break;
        }
        // F1 (achado da revisão da F0): o servidor recusou um item desta
        // fila. Ele continua na fila (o aviso mostra os pendentes) e não
        // derruba o diário, as outras filas nem a busca.
        debugPrint('Fila ${fila.runtimeType} recusada: ${recusa.motivo}');
      }
    }
    if (_filas.isNotEmpty) await atualizarSituacao();
    return saidas;
  }

  /// Busca no servidor os registros e alertas dos pacientes acompanhados.
  Future<void> buscarDoServidor() async {
    for (final pid in _pacientes) {
      final registros = await _fonte.listar(
        _fonte.doPaciente(pid, 'registros'),
      );
      await _dao.mesclarDoServidor([
        for (final m in registros) RegistroDiario.fromMap(m),
      ]);
      final alertas = await _fonte.listar(_fonte.doPaciente(pid, 'alertas'));
      for (final m in alertas) {
        await _dao.salvarAlerta(Alerta.fromMap(m));
      }
      for (final fila in _filas) {
        try {
          await fila.buscar(pid);
        } on RecusaDeRegra catch (recusa) {
          if (ehSemConexao(recusa)) rethrow;
          // F2 (revisão): uma coleção que o servidor recusa (regra ainda não
          // publicada, por exemplo) fica sem a cópia nova, e o resto segue.
          debugPrint(
            'Busca de ${fila.runtimeType} recusada para $pid: '
            '${recusa.motivo}',
          );
        }
      }
    }
  }

  /// Envia a fila e busca o servidor. Sem rede, só atualiza a [situacao].
  /// Chamadas ao mesmo tempo esperam a que já está em andamento.
  Future<void> sincronizar() =>
      _emAndamento ??= _sincronizar().whenComplete(() => _emAndamento = null);

  Future<void> _sincronizar() async {
    if (!_monitor.online) {
      await atualizarSituacao(sincronizando: false);
      return;
    }
    await atualizarSituacao(sincronizando: true);
    try {
      await enviarFila();
      await buscarDoServidor();
      _servidorRespondeu = true;
      await _preferencias?.guardarSincronizacao(_relogio.agora());
    } on RecusaDeRegra catch (r) {
      if (!ehSemConexao(r)) rethrow;
      _servidorRespondeu = false;
    } finally {
      await atualizarSituacao(sincronizando: false);
    }
  }

  void encerrar() => _monitor.removeListener(_aoMudarConexao);
}
