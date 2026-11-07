/// Monta a persistência da Atividade 4 (D12, D16): SQLite + SharedPreferences
/// no aparelho, Firebase Authentication + Firestore no servidor, e o
/// sincronizador entre os dois. O `main.dart` só chama [montarPersistencia].
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart' show DatabaseFactory;

import '../../nucleo/tempo/relogio.dart';
import '../local/banco_local.dart';
import '../local/cache_dao.dart';
import '../local/confirmacao_de_presenca_dao.dart';
import '../local/preferencias_locais.dart';
import '../local/registro_de_atividade_dao.dart';
import '../local/registro_diario_dao.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/demonstracao_repositorio.dart';
import '../repositorios/repositorios.dart';
import '../sincronizacao/fila_confirmacoes.dart';
import '../sincronizacao/fila_registros_casa.dart';
import '../sincronizacao/monitor_conexao.dart';
import '../sincronizacao/sincronizador.dart';
import 'autenticacao_firebase.dart';
import 'cuidadores_firebase.dart';
import 'diario_persistente.dart';
import 'leitura_com_copia.dart';
import 'lembretes_locais.dart';
import 'metas_persistente.dart';
import 'paciente_persistente.dart';
import 'presenca_persistente.dart';
import 'programa_em_casa_persistente.dart';
import 'visao_cuidador_persistente.dart';

/// Tudo o que o app usa com a persistência real.
class Persistencia {
  Persistencia._({
    required this.repositorios,
    required this.preferencias,
    required this.sincronizador,
    required this.monitor,
    required this.banco,
  });

  final Repositorios repositorios;
  final PreferenciasLocais preferencias;
  final Sincronizador sincronizador;
  final MonitorConexao monitor;
  final BancoLocal banco;
}

/// Abre o banco, lê as preferências, liga o monitor de conexão e monta os
/// contratos (os seis da Atividade 4 e o programa em casa da evolução de TO,
/// cuja fila entra no sincronizador). [fabricaDoBanco], [caminhoDoBanco], [preferencias] e
/// [monitor] existem para o teste.
Future<Persistencia> montarPersistencia({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
  required Relogio relogio,
  DatabaseFactory? fabricaDoBanco,
  String? caminhoDoBanco,
  PreferenciasLocais? preferencias,
  MonitorConexao? monitor,
}) async {
  final banco = await BancoLocal.abrir(
    fabrica: fabricaDoBanco,
    caminho: caminhoDoBanco,
  );
  final prefs = preferencias ?? await PreferenciasLocais.abrir();
  final conexao = monitor ?? MonitorConexao();
  await conexao.iniciar();
  final fonte = FonteFirestore(firestore);
  final dao = RegistroDiarioDao(banco);
  final cache = CacheDao(banco, agora: relogio.agora);
  final leitura = LeituraComCopia(cache: cache, monitor: conexao);
  final daoCasa = RegistroDeAtividadeDao(banco);
  final filaCasa = FilaRegistrosCasa(
    dao: daoCasa,
    fonte: fonte,
    monitor: conexao,
  );
  final daoPresenca = ConfirmacaoDePresencaDao(banco);
  final filaPresenca = FilaConfirmacoes(
    dao: daoPresenca,
    fonte: fonte,
    monitor: conexao,
  );
  final sincronizador = Sincronizador(
    dao: dao,
    fonte: fonte,
    monitor: conexao,
    relogio: relogio,
    preferencias: prefs,
    filas: [filaCasa, filaPresenca],
  );
  final paciente = PacientePersistente(
    fonte: fonte,
    leitura: leitura,
    cache: cache,
    relogio: relogio,
  );
  final programa = ProgramaEmCasaPersistente(
    fonte: fonte,
    leitura: leitura,
    dao: daoCasa,
    fila: filaCasa,
    sincronizador: sincronizador,
    relogio: relogio,
  );
  final repositorios = Repositorios(
    autenticacao: AutenticacaoFirebase(
      auth: auth,
      fonte: fonte,
      banco: banco,
      cache: cache,
      preferencias: prefs,
      monitor: conexao,
      sincronizador: sincronizador,
      relogio: relogio,
    ),
    paciente: paciente,
    diario: DiarioPersistente(
      dao: dao,
      sincronizador: sincronizador,
      relogio: relogio,
    ),
    cuidadores: CuidadoresFirebase(
      fonte: fonte,
      leitura: leitura,
      monitor: conexao,
      relogio: relogio,
    ),
    visaoCuidador: VisaoCuidadorPersistente(
      fonte: fonte,
      leitura: leitura,
      relogio: relogio,
    ),
    demonstracao: DemonstracaoPersistente(
      monitor: conexao,
      sincronizador: sincronizador,
      banco: banco,
    ),
    presenca: PresencaPersistente(
      dao: daoPresenca,
      fila: filaPresenca,
      paciente: paciente,
      sincronizador: sincronizador,
      relogio: relogio,
    ),
    programaEmCasa: programa,
    metas: MetasPersistente(leitura: leitura, fonte: fonte),
    lembretes: LembretesLocais(
      preferencias: prefs,
      paciente: paciente,
      programa: programa,
      relogio: relogio,
    ),
    conexao: sincronizador.situacao,
  );
  return Persistencia._(
    repositorios: repositorios,
    preferencias: prefs,
    sincronizador: sincronizador,
    monitor: conexao,
    banco: banco,
  );
}

/// D11 sobre a persistência real: "sem conexão" força o offline (sem modo
/// avião) e "reiniciar dados" apaga a cópia local e busca de novo o
/// servidor. Os dados do servidor só voltam ao início pela semente
/// (`node ferramentas/semear-firebase.mjs --reiniciar`).
class DemonstracaoPersistente implements ControleDemonstracao {
  DemonstracaoPersistente({
    required this._monitor,
    required Sincronizador sincronizador,
    required this._banco,
  }) : _sinc = sincronizador;

  final MonitorConexao _monitor;
  final Sincronizador _sinc;
  final BancoLocal _banco;

  @override
  bool get semConexao => _monitor.forcadoSemConexao;

  /// Com a conexão de volta, a fila sai sozinha (o sincronizador escuta o
  /// monitor); aqui também se espera ela sair, como na memória.
  @override
  Future<void> definirSemConexao({required bool semConexao}) async {
    _monitor.forcadoSemConexao = semConexao;
    if (!semConexao) await _sinc.sincronizar();
    await _sinc.atualizarSituacao();
  }

  @override
  Future<void> reiniciarDados() async {
    _monitor.forcadoSemConexao = false;
    await _banco.apagarTudo();
    await _sinc.sincronizar();
  }
}
