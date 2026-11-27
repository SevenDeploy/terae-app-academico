/// O programa em casa com SQLite + Firestore (evolução de TO, F1; D16, D26):
/// atividades com cópia local, registro do dia com a fila, correção,
/// desfazer, histórico do servidor, a migração v1 → v2 do banco e o "Sair".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/local/banco_local.dart';
import 'package:terae_app/dados/local/confirmacao_de_presenca_dao.dart';
import 'package:terae_app/dados/modelos/confirmacao_de_presenca.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/programa_em_casa_repositorio.dart';

import 'apoio_persistencia.dart';

const String _p = 'a0000000-0000-4000-8000-000000000005';
const String _a = 'ca000000-0000-4000-8000-000000000005';

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

void main() {
  late Montagem m;
  late RepositorioProgramaEmCasa programa;

  Future<void> semearAtividade() => m.firestore
      .collection('pacientes')
      .doc(_p)
      .collection('atividadesCasa')
      .doc(_a)
      .set({
        'id': _a,
        'pacienteId': _p,
        'profissionalId': 'd0000000-0000-4000-8000-000000000003',
        'titulo': 'Abotoar a camisa com a mão mais fraca',
        'texto': 'Sentado, abotoe 5 botões.',
        'vezesPorSemana': 5,
        'ocupacao': 'autocuidado',
        'publicadaEm': '2026-09-25T13:00:00.000Z',
        'encerradaEm': null,
      });

  Future<Map<String, Object?>?> noServidor(String id) async =>
      (await m.firestore
              .collection('pacientes')
              .doc(_p)
              .collection('registrosCasa')
              .doc(id)
              .get())
          .data();

  setUp(() async {
    m = await montar();
    programa = m.persistencia.repositorios.programaEmCasa;
    m.persistencia.sincronizador.acompanhar([_p]);
    await semearAtividade();
  });

  test(
    'atividades: com conexão lê do servidor; sem conexão, da cópia',
    () async {
      expect((await programa.atividades(_p)).single.id, _a);
      await m.conexao.desligar();
      expect((await programa.atividade(_p, _a)).vezesPorSemana, 5);
      await expectLater(
        programa.atividade(_p, 'outra'),
        _recusa(MotivoRecusa.atividadeInexistente),
      );
    },
  );

  test('registrar com conexão: SQLite e Firestore como enviado, fila '
      'vazia', () async {
    final r = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.emParte,
      reflexao: 'Consegui 2 botões.',
      quem: QuemRegistrou.paciente,
    );
    expect(r.situacaoEnvio, SituacaoEnvio.enviado);
    final remoto = (await noServidor(r.id))!;
    expect(remoto['situacaoEnvio'], 'enviado');
    expect(remoto['adesao'], 'emParte');
    expect(remoto['dia'], '2026-10-02');
    expect(remoto['quem'], 'paciente');
    expect((await programa.registros(_p)).single, r);
    expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
  });

  test('sem conexão: fica na fila do SQLite, conta no aviso e sai quando a '
      'conexão volta', () async {
    await programa.atividades(_p); // a cópia local da atividade
    await m.conexao.desligar();
    final r = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.feito,
      quem: QuemRegistrou.paciente,
    );
    expect(r.situacaoEnvio, SituacaoEnvio.naFila);
    expect(await noServidor(r.id), isNull);
    expect(m.persistencia.sincronizador.situacao.value.pendentes, 1);

    await m.conexao.ligar();
    await m.persistencia.sincronizador.sincronizar();
    expect((await noServidor(r.id))!['situacaoEnvio'], 'enviado');
    expect(
      (await programa.registros(_p)).single.situacaoEnvio,
      SituacaoEnvio.enviado,
    );
    expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
  });

  test('registrar de novo no dia corrige o mesmo; desfazer é lógico e vai '
      'ao servidor (D26)', () async {
    final primeiro = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.naoFeito,
      quem: QuemRegistrou.paciente,
    );
    final segundo = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.feito,
      reflexao: 'Deu à noite.',
      quem: QuemRegistrou.paciente,
    );
    expect(segundo.id, primeiro.id);
    expect((await noServidor(primeiro.id))!['adesao'], 'feito');

    final desfeito = await programa.desfazer(_p, primeiro.id);
    expect(desfeito.excluido, isTrue);
    expect((await noServidor(primeiro.id))!['excluidoEm'], isNotNull);
    expect(await programa.registros(_p), isEmpty);
    await expectLater(
      programa.desfazer(_p, 'nao-existe'),
      _recusa(MotivoRecusa.registroInexistente),
    );
  });

  test('o histórico do servidor chega ao SQLite na sincronização; o de '
      'outro dia não se desfaz', () async {
    await m.firestore
        .collection('pacientes')
        .doc(_p)
        .collection('registrosCasa')
        .doc('cb000000-0000-4000-8000-000000000001')
        .set({
          'id': 'cb000000-0000-4000-8000-000000000001',
          'pacienteId': _p,
          'atividadeId': _a,
          'dia': '2026-10-01',
          'adesao': 'feito',
          'reflexao': 'Os 5 botões!',
          'quem': 'paciente',
          'registradoEm': '2026-10-01T23:00:00.000Z',
          'situacaoEnvio': 'enviado',
          'atualizadoEm': null,
          'excluidoEm': null,
        });
    await m.persistencia.sincronizador.sincronizar();
    final registros = await programa.registros(_p);
    expect(registros.single.reflexao, 'Os 5 botões!');
    await expectLater(
      programa.desfazer(_p, registros.single.id),
      _recusa(MotivoRecusa.edicaoEncerrada),
    );
  });

  test('duplicado do mesmo dia vindo de outro aparelho: a correção vai no '
      'registro que a TM17 mostra, o mais recente (D31)', () async {
    final daqui = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.naoFeito,
      quem: QuemRegistrou.paciente,
    );
    const outro = 'cb000000-0000-4000-8000-000000000777';
    await m.firestore
        .collection('pacientes')
        .doc(_p)
        .collection('registrosCasa')
        .doc(outro)
        .set({
          'id': outro,
          'pacienteId': _p,
          'atividadeId': _a,
          'dia': '2026-10-02',
          'adesao': 'feito',
          'reflexao': null,
          'quem': 'paciente',
          'registradoEm': '2026-10-02T12:00:00.000Z',
          'situacaoEnvio': 'enviado',
          'atualizadoEm': null,
          'excluidoEm': null,
        });
    await m.persistencia.sincronizador.sincronizar();
    expect(await programa.registros(_p), hasLength(2));

    final corrigido = await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.emParte,
      quem: QuemRegistrou.paciente,
    );
    expect(corrigido.id, daqui.id);
    expect((await noServidor(daqui.id))!['adesao'], 'emParte');
    expect((await noServidor(outro))!['adesao'], 'feito');
  });

  group('presença (F2, D27)', () {
    const ag = 'ad000000-0000-4000-8000-000000000012';

    Future<void> semearSessao({required String dataHora}) => m.firestore
        .collection('pacientes')
        .doc(_p)
        .collection('agendamentos')
        .doc(ag)
        .set({
          'id': ag,
          'pacienteId': _p,
          'profissionalId': 'd0000000-0000-4000-8000-000000000003',
          'dataHora': dataHora,
          'motivoRetorno': 'Sessão de terapia ocupacional',
          'situacao': 'agendado',
        });

    Future<Map<String, Object?>?> confirmacaoNoServidor() async =>
        (await m.firestore
                .collection('pacientes')
                .doc(_p)
                .collection('confirmacoes')
                .doc(ag)
                .get())
            .data();

    test('responder com conexão grava o documento do agendamento', () async {
      await semearSessao(dataHora: '2026-10-09T12:00:00.000Z');
      final presenca = m.persistencia.repositorios.presenca;
      final c = await presenca.responder(
        pacienteId: _p,
        agendamentoId: ag,
        resposta: RespostaPresenca.naoVamos,
      );
      expect(c.situacaoEnvio, SituacaoEnvio.enviado);
      final doc = (await confirmacaoNoServidor())!;
      expect(doc['id'], ag);
      expect(doc['resposta'], 'naoVamos');
      expect(
        (await presenca.respostas(_p))[ag]!.resposta,
        RespostaPresenca.naoVamos,
      );
    });

    test('trocar a resposta durante o envio: a nova continua na fila e sai '
        'na próxima vez (revisão da F2)', () async {
      final dao = ConfirmacaoDePresencaDao(m.persistencia.banco);
      final primeira = ConfirmacaoDePresenca(
        agendamentoId: ag,
        pacienteId: _p,
        resposta: RespostaPresenca.vamos,
        respondidaEm: agoraDaPersistencia,
        situacaoEnvio: SituacaoEnvio.naFila,
      );
      await dao.salvar(primeira);
      // A primeira vai ao servidor; enquanto isso, a pessoa troca.
      final segunda = ConfirmacaoDePresenca(
        agendamentoId: ag,
        pacienteId: _p,
        resposta: RespostaPresenca.naoVamos,
        respondidaEm: agoraDaPersistencia.add(const Duration(minutes: 1)),
        situacaoEnvio: SituacaoEnvio.naFila,
      );
      await dao.salvar(segunda);
      await dao.marcarEnviada(
        primeira.copyWith(situacaoEnvio: SituacaoEnvio.enviado),
      );
      final linha = (await dao.doPaciente(_p))[ag]!;
      expect(linha.resposta, RespostaPresenca.naoVamos);
      expect(linha.situacaoEnvio, SituacaoEnvio.naFila);
      await dao.marcarEnviada(
        segunda.copyWith(situacaoEnvio: SituacaoEnvio.enviado),
      );
      expect(
        (await dao.doPaciente(_p))[ag]!.situacaoEnvio,
        SituacaoEnvio.enviado,
      );
    });

    test('sem conexão fica na fila e sai na sincronização', () async {
      await semearSessao(dataHora: '2026-10-09T12:00:00.000Z');
      final presenca = m.persistencia.repositorios.presenca;
      await m.persistencia.repositorios.paciente.agendamentos(_p);
      await m.conexao.desligar();
      final c = await presenca.responder(
        pacienteId: _p,
        agendamentoId: ag,
        resposta: RespostaPresenca.vamos,
      );
      expect(c.situacaoEnvio, SituacaoEnvio.naFila);
      expect(m.persistencia.sincronizador.situacao.value.pendentes, 1);
      await m.conexao.ligar();
      await m.persistencia.sincronizador.sincronizar();
      expect((await confirmacaoNoServidor())!['resposta'], 'vamos');
      expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
    });

    test('sessão que já começou é recusada', () async {
      await semearSessao(dataHora: '2026-10-02T13:00:00.000Z');
      await expectLater(
        m.persistencia.repositorios.presenca.responder(
          pacienteId: _p,
          agendamentoId: ag,
          resposta: RespostaPresenca.vamos,
        ),
        _recusa(MotivoRecusa.sessaoEncerrada),
      );
    });
  });

  test('"Sair" apaga também os registros das atividades (D20)', () async {
    await programa.registrar(
      pacienteId: _p,
      atividadeId: _a,
      adesao: AdesaoEmCasa.feito,
      quem: QuemRegistrou.paciente,
    );
    await m.persistencia.banco.apagarTudo();
    expect(await m.persistencia.banco.db.query('registros_casa'), isEmpty);
  });

  test('migração v1 → v2: o banco da Atividade 4 ganha a tabela nova sem '
      'perder o diário', () async {
    sqfliteFfiInit();
    final pasta = Directory.systemTemp.createTempSync('terae_app_migracao_');
    final caminho = '${pasta.path}${Platform.pathSeparator}terae.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => BancoLocal.migracoes.first(db),
      ),
    );
    await v1.insert('registros_diario', {
      'id': 'f0000000-0000-4000-8000-000000000001',
      'paciente_id': 'a0000000-0000-4000-8000-000000000001',
      'registrado_em': '2026-10-01T12:00:00.000Z',
      'adesao': 'total',
      'intensidade': 'leve',
      'sintoma': 'Cansaço',
      'observacao': null,
      'situacao_envio': 'naFila',
      'atualizado_em': null,
      'excluido_em': null,
      'texto_busca': 'cansaco',
    });
    await v1.close();

    final banco = await BancoLocal.abrir(
      fabrica: databaseFactoryFfi,
      caminho: caminho,
    );
    // F2 e P3: a v3 (respostas de presença) e a v4 (o diário do portal)
    // rodam junto, na mesma abertura.
    expect(await banco.db.getVersion(), BancoLocal.versao);
    expect(BancoLocal.versao, 4);
    final tabelas = await banco.db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    expect(
      tabelas.map((t) => t['name']),
      containsAll(['registros_casa', 'confirmacoes_presenca']),
    );
    final diario = await banco.db.query('registros_diario');
    expect(diario.single['situacao_envio'], 'naFila');
    await banco.fechar();
  });
}
