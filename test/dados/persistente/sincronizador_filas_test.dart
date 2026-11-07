/// As filas das outras entidades gravadas no aparelho (evolução de TO): o
/// sincronizador conta, envia e busca cada [FilaDeEntidade] junto com o
/// diário, sem mudar o caminho do diário (D16, D18).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/local/banco_local.dart';
import 'package:terae_app/dados/local/registro_de_atividade_dao.dart';
import 'package:terae_app/dados/local/registro_diario_dao.dart';
import 'package:terae_app/dados/modelos/registro_de_atividade.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/remoto/fonte_firestore.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/sincronizacao/fila_de_entidade.dart';
import 'package:terae_app/dados/sincronizacao/fila_registros_casa.dart';
import 'package:terae_app/dados/sincronizacao/sincronizador.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'apoio_persistencia.dart';

const String _paciente = 'a0000000-0000-4000-8000-000000000005';

/// Fila de mentira: [pendentes] itens; [semConexao] faz o envio recusar.
class _FilaDeTeste implements FilaDeEntidade {
  _FilaDeTeste(this.nome, this.diario, {this.pendentes = 0});

  final String nome;

  /// O diário, para saber se ele já saiu quando esta fila envia.
  final RegistroDiarioDao diario;

  int pendentes;
  bool semConexao = false;
  final List<String> eventos = [];

  @override
  Future<int> contarPendentes() async => pendentes;

  @override
  Future<void> enviarPendentes() async {
    eventos.add('enviar com o diário em ${await diario.contarPendentes()}');
    if (semConexao) throw const RecusaDeRegra(MotivoRecusa.semConexao);
    pendentes = 0;
  }

  @override
  Future<void> buscar(String pacienteId) async {
    eventos.add('buscar $pacienteId');
  }
}

void main() {
  late BancoLocal banco;
  late RegistroDiarioDao dao;
  late ConexaoDeTeste conexao;
  late _FilaDeTeste casa;
  late _FilaDeTeste presenca;
  late Sincronizador sincronizador;

  setUp(() async {
    sqfliteFfiInit();
    banco = await BancoLocal.abrir(
      fabrica: databaseFactoryFfi,
      caminho: inMemoryDatabasePath,
    );
    dao = RegistroDiarioDao(banco);
    conexao = ConexaoDeTeste();
    await conexao.monitor.iniciar();
    casa = _FilaDeTeste('casa', dao, pendentes: 2);
    presenca = _FilaDeTeste('presenca', dao, pendentes: 1);
    sincronizador = Sincronizador(
      dao: dao,
      fonte: FonteFirestore(FakeFirebaseFirestore()),
      monitor: conexao.monitor,
      relogio: RelogioFixo(agoraDaPersistencia),
      filas: [casa, presenca],
    )..acompanhar([_paciente]);
  });

  tearDown(() => banco.fechar());

  Future<void> umRegistroNaFila() => dao.salvar(
    RegistroDiario(
      id: 'f0000000-0000-4000-8000-000000000099',
      pacienteId: _paciente,
      registradoEm: agoraDaPersistencia,
      adesao: Adesao.total,
      intensidade: Intensidade.leve,
      sintomaPredominante: 'Cansaço',
      situacaoEnvio: SituacaoEnvio.naFila,
    ),
  );

  test('o aviso de conexão soma o diário e todas as filas', () async {
    await umRegistroNaFila();
    await sincronizador.atualizarSituacao();
    expect(sincronizador.situacao.value.pendentes, 1 + 2 + 1);
  });

  test('sincronizar envia o diário primeiro, depois cada fila em ordem, e '
      'busca cada fila por paciente', () async {
    await umRegistroNaFila();
    await sincronizador.sincronizar();
    expect(casa.eventos, ['enviar com o diário em 0', 'buscar $_paciente']);
    expect(presenca.eventos, ['enviar com o diário em 0', 'buscar $_paciente']);
    expect(sincronizador.situacao.value.pendentes, 0);
    expect(sincronizador.situacao.value.online, isTrue);
  });

  test('"sem conexão" numa fila para as seguintes e mantém os pendentes; a '
      'busca ainda roda e, se a leitura responde, volta a online (regra da '
      'A4)', () async {
    casa.semConexao = true;
    await sincronizador.sincronizar();
    expect(casa.eventos, ['enviar com o diário em 0', 'buscar $_paciente']);
    expect(presenca.eventos, ['buscar $_paciente']);
    expect(sincronizador.situacao.value.pendentes, 2 + 1);
    expect(sincronizador.situacao.value.online, isTrue);

    casa.semConexao = false;
    await sincronizador.sincronizar();
    expect(sincronizador.situacao.value.pendentes, 0);
    expect(sincronizador.situacao.value.online, isTrue);
  });

  test('sem rede, nenhuma fila é chamada', () async {
    await conexao.desligar();
    await sincronizador.sincronizar();
    expect(casa.eventos, isEmpty);
    expect(presenca.eventos, isEmpty);
    expect(sincronizador.situacao.value.pendentes, 3);
  });

  test('diário da A4 sem mudança: o envio passa do prazo, a leitura '
      'responde, a busca roda e o app volta a online com o registro na '
      'fila (achado da revisão da F0)', () async {
    final fonte = _FonteDeEnvioLento(FakeFirebaseFirestore());
    final s = Sincronizador(
      dao: dao,
      fonte: fonte,
      monitor: conexao.monitor,
      relogio: RelogioFixo(agoraDaPersistencia),
    )..acompanhar([_paciente]);
    await umRegistroNaFila();
    await s.sincronizar();
    expect(fonte.leituras, greaterThan(0), reason: 'buscou o servidor');
    expect(s.situacao.value.online, isTrue);
    expect(s.situacao.value.pendentes, 1);
  });

  test('na fila dos registros de casa, um item recusado fica pendente e os '
      'seguintes saem (D33)', () async {
    final daoCasa = RegistroDeAtividadeDao(banco);
    RegistroDeAtividade registro(String id, int hora) => RegistroDeAtividade(
      id: id,
      pacienteId: _paciente,
      atividadeId: 'ca000000-0000-4000-8000-000000000005',
      dia: DataCivil(2026, 10, 2),
      adesao: AdesaoEmCasa.feito,
      quem: QuemRegistrou.paciente,
      registradoEm: instanteNaClinica(2026, 10, 2, hora),
      situacaoEnvio: SituacaoEnvio.naFila,
    );
    await daoCasa.salvar(registro('primeiro', 8));
    await daoCasa.salvar(registro('segundo', 9));
    final fila = _FilaQueRecusa(
      dao: daoCasa,
      fonte: FonteFirestore(FakeFirebaseFirestore()),
      monitor: conexao.monitor,
      recusado: 'primeiro',
    );
    await expectLater(fila.enviarPendentes(), throwsA(isA<RecusaDeRegra>()));
    expect((await daoCasa.pendentes()).map((r) => r.id), ['primeiro']);
    expect(
      (await daoCasa.porId('segundo'))!.situacaoEnvio,
      SituacaoEnvio.enviado,
    );
  });

  test('o servidor recusar um item de uma fila não derruba o diário, as '
      'outras filas nem a busca; o item continua pendente (F1)', () async {
    final quebrada = _FilaQuebrada();
    final s = Sincronizador(
      dao: dao,
      fonte: FonteFirestore(FakeFirebaseFirestore()),
      monitor: conexao.monitor,
      relogio: RelogioFixo(agoraDaPersistencia),
      filas: [quebrada, presenca],
    )..acompanhar([_paciente]);
    await umRegistroNaFila();
    await s.sincronizar();
    expect(await dao.contarPendentes(), 0, reason: 'o diário saiu');
    expect(presenca.eventos, ['enviar com o diário em 0', 'buscar $_paciente']);
    expect(s.situacao.value.pendentes, 1, reason: 'o recusado continua');
    expect(s.situacao.value.online, isTrue);
  });
}

/// O envio passa do prazo (`semConexao`); a leitura responde.
class _FonteDeEnvioLento extends FonteFirestore {
  _FonteDeEnvioLento(super.db);

  int leituras = 0;

  @override
  Future<void> gravar(WriteBatch lote) async =>
      throw const RecusaDeRegra(MotivoRecusa.semConexao);

  @override
  Future<List<Mapa>> listar(Query<Mapa> consulta) {
    leituras++;
    return super.listar(consulta);
  }
}

/// Fila de verdade em que o servidor recusa um registro específico.
class _FilaQueRecusa extends FilaRegistrosCasa {
  _FilaQueRecusa({
    required super.dao,
    required super.fonte,
    required super.monitor,
    required this.recusado,
  });

  final String recusado;

  @override
  Future<RegistroDeAtividade> enviar(RegistroDeAtividade registro) {
    if (registro.id == recusado) {
      return Future.error(const RecusaDeRegra(MotivoRecusa.acessoNegado));
    }
    return super.enviar(registro);
  }
}

class _FilaQuebrada implements FilaDeEntidade {
  @override
  Future<int> contarPendentes() async => 1;

  @override
  Future<void> enviarPendentes() =>
      Future.error(const RecusaDeRegra(MotivoRecusa.acessoNegado));

  @override
  Future<void> buscar(String pacienteId) async {}
}
