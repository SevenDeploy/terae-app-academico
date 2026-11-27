/// Banco SQLite do aparelho (Atividade 4, D16): a fonte local da verdade.
///
/// - `registros_diario`: o item principal, com a fila de envio (as linhas com
///   `situacao_envio = 'naFila'`) e o texto de busca da TM13;
/// - `alertas`: os alertas confirmados dos registros do paciente;
/// - `cache_documentos`: as cópias de leitura da §23 (paciente,
///   profissional, consultas, receita, marcos, vínculos, atividades de casa),
///   cada uma guardada como o JSON do `toMap` do modelo;
/// - `registros_casa` (versão 2, evolução de TO): os registros das atividades
///   de casa, com a fila de envio deles;
/// - `confirmacoes_presenca` (versão 3, evolução de TO): as respostas de
///   presença, uma por agendamento, com a fila de envio;
/// - versão 4 (P3, diário igual ao do portal): `registros_diario` é refeita
///   com as quatro perguntas do portal, a versão, a revisão, a retirada com
///   motivo e as versões anteriores, copiando cada linha antiga.
///
/// Sem cifra nesta versão (D15: limitação declarada; os dados são fictícios).
///
/// Esquema por migrações numeradas ([migracoes]): o banco novo roda todas, e
/// o banco de uma versão anterior roda só as que faltam (`onUpgrade`), sem
/// perder o que já está no aparelho. Tabela nova = migração nova no fim da
/// lista (a [BancoLocal.versao] sobe sozinha) e o nome dela em
/// [BancoLocal.tabelas], senão o "Sair" não a apaga (D20).
library;

import 'package:path/path.dart' as caminhos;
import 'package:sqflite/sqflite.dart';

/// O banco aberto e as operações que valem para ele inteiro.
class BancoLocal {
  BancoLocal._(this.db);

  /// Abre (ou cria) o banco. No app, [fabrica] é a do sqflite e o arquivo
  /// fica na pasta de bancos do aparelho; no teste, `databaseFactoryFfi` com
  /// [caminho] = `inMemoryDatabasePath`.
  static Future<BancoLocal> abrir({
    DatabaseFactory? fabrica,
    String? caminho,
  }) async {
    final f = fabrica ?? databaseFactory;
    final destino =
        caminho ?? caminhos.join(await f.getDatabasesPath(), nomeDoArquivo);
    final db = await f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: versao,
        onCreate: (db, versao) => _migrar(db, de: 0, ate: versao),
        onUpgrade: (db, de, ate) => _migrar(db, de: de, ate: ate),
      ),
    );
    return BancoLocal._(db);
  }

  static const String nomeDoArquivo = 'terae.db';

  /// Versão do esquema = quantidade de [migracoes].
  static int get versao => migracoes.length;

  final Database db;

  /// Tabelas, na ordem em que são criadas.
  static const List<String> tabelas = [
    'registros_diario',
    'alertas',
    'cache_documentos',
    'registros_casa',
    'confirmacoes_presenca',
  ];

  /// Migrações em ordem: a de índice `i` leva o banco da versão `i` à `i + 1`.
  /// Nunca se muda uma migração publicada; corrige-se com outra.
  static const List<Future<void> Function(Database db)> migracoes = [
    _versao1,
    _versao2,
    _versao3,
    _versao4,
  ];

  static Future<void> _migrar(
    Database db, {
    required int de,
    required int ate,
  }) async {
    for (var v = de; v < ate; v++) {
      await migracoes[v](db);
    }
  }

  /// Versão 1 (Atividade 4): diário, alertas e cópias de leitura.
  static Future<void> _versao1(Database db) async {
    final lote = db.batch()
      ..execute('''
        CREATE TABLE registros_diario (
          id TEXT PRIMARY KEY,
          paciente_id TEXT NOT NULL,
          registrado_em TEXT NOT NULL,
          adesao TEXT NOT NULL,
          intensidade TEXT NOT NULL,
          sintoma TEXT NOT NULL,
          observacao TEXT,
          situacao_envio TEXT NOT NULL,
          atualizado_em TEXT,
          excluido_em TEXT,
          texto_busca TEXT NOT NULL
        )''')
      ..execute(
        'CREATE INDEX idx_registros_paciente '
        'ON registros_diario (paciente_id, registrado_em)',
      )
      ..execute(
        'CREATE INDEX idx_registros_fila ON registros_diario (situacao_envio)',
      )
      ..execute('''
        CREATE TABLE alertas (
          id TEXT PRIMARY KEY,
          registro_id TEXT NOT NULL UNIQUE,
          regra TEXT NOT NULL,
          emitido_em TEXT NOT NULL,
          ciente_em TEXT
        )''')
      ..execute('''
        CREATE TABLE cache_documentos (
          colecao TEXT NOT NULL,
          id TEXT NOT NULL,
          dono TEXT NOT NULL,
          json TEXT NOT NULL,
          sincronizado_em TEXT NOT NULL,
          PRIMARY KEY (colecao, id)
        )''');
    await lote.commit(noResult: true);
  }

  /// Versão 2 (evolução de TO, F1): os registros das atividades de casa, com
  /// a fila de envio (`situacao_envio = 'naFila'`).
  static Future<void> _versao2(Database db) async {
    final lote = db.batch()
      ..execute('''
        CREATE TABLE registros_casa (
          id TEXT PRIMARY KEY,
          paciente_id TEXT NOT NULL,
          atividade_id TEXT NOT NULL,
          dia TEXT NOT NULL,
          adesao TEXT NOT NULL,
          reflexao TEXT,
          quem TEXT NOT NULL,
          registrado_em TEXT NOT NULL,
          situacao_envio TEXT NOT NULL,
          atualizado_em TEXT,
          excluido_em TEXT
        )''')
      ..execute(
        'CREATE INDEX idx_casa_paciente ON registros_casa (paciente_id, dia)',
      )
      ..execute(
        'CREATE INDEX idx_casa_atividade ON registros_casa (atividade_id, dia)',
      )
      ..execute(
        'CREATE INDEX idx_casa_fila ON registros_casa (situacao_envio)',
      );
    await lote.commit(noResult: true);
  }

  /// Versão 3 (evolução de TO, F2): as respostas de presença, uma por
  /// agendamento, com a fila de envio.
  static Future<void> _versao3(Database db) async {
    final lote = db.batch()
      ..execute('''
        CREATE TABLE confirmacoes_presenca (
          agendamento_id TEXT PRIMARY KEY,
          paciente_id TEXT NOT NULL,
          resposta TEXT NOT NULL,
          respondida_em TEXT NOT NULL,
          situacao_envio TEXT NOT NULL
        )''')
      ..execute(
        'CREATE INDEX idx_presenca_paciente ON confirmacoes_presenca '
        '(paciente_id)',
      )
      ..execute(
        'CREATE INDEX idx_presenca_fila ON confirmacoes_presenca '
        '(situacao_envio)',
      );
    await lote.commit(noResult: true);
  }

  /// Versão 4 (P3, diário igual ao do portal): o registro passa a ter só a
  /// adesão obrigatória (o sintoma escolhido, a intensidade e a observação
  /// viram as três perguntas opcionais), a versão e as anteriores, quando o
  /// servidor recebeu, se avisou a equipe, a revisão e a retirada com motivo.
  ///
  /// O SQLite não tira o `NOT NULL` de uma coluna, então a tabela é refeita:
  /// a nova recebe a cópia de cada linha da antiga, e só então a antiga sai.
  /// Nada do que a família registrou se perde:
  /// - o sintoma escolhido vira o texto de `sintomas`;
  /// - `moderada`/`critica` viram `moderado`/`critico` (os nomes da API);
  /// - o registro enviado ganha `enviado_em` = `registrado_em`;
  /// - o que tem alerta ganha `alertou_a_equipe`;
  /// - o excluído (D17 antiga) vira retirado, com o motivo "Outro".
  static Future<void> _versao4(Database db) async {
    final lote = db.batch()
      ..execute('''
        CREATE TABLE registros_diario_v4 (
          id TEXT PRIMARY KEY,
          paciente_id TEXT NOT NULL,
          registrado_em TEXT NOT NULL,
          adesao TEXT NOT NULL,
          sintomas TEXT,
          intensidade_sintoma TEXT,
          observacoes TEXT,
          situacao_envio TEXT NOT NULL,
          versao INTEGER NOT NULL,
          enviado_em TEXT,
          atualizado_em TEXT,
          alertou_a_equipe INTEGER NOT NULL,
          revisado_em TEXT,
          retirado_em TEXT,
          motivo_retirada TEXT,
          detalhe_retirada TEXT,
          versoes_anteriores TEXT NOT NULL
        )''')
      ..execute('''
        INSERT INTO registros_diario_v4 SELECT
          r.id, r.paciente_id, r.registrado_em, r.adesao, r.sintoma,
          CASE r.intensidade
            WHEN 'moderada' THEN 'moderado'
            WHEN 'critica' THEN 'critico'
            ELSE r.intensidade END,
          r.observacao, r.situacao_envio, 1,
          CASE WHEN r.situacao_envio = 'enviado' THEN r.registrado_em END,
          r.atualizado_em,
          EXISTS (SELECT 1 FROM alertas a WHERE a.registro_id = r.id),
          NULL,
          r.excluido_em,
          CASE WHEN r.excluido_em IS NOT NULL THEN 'outro' END,
          CASE WHEN r.excluido_em IS NOT NULL
            THEN '$detalheDaRetiradaAntiga' END,
          '[]'
        FROM registros_diario r''')
      ..execute('DROP TABLE registros_diario')
      ..execute('ALTER TABLE registros_diario_v4 RENAME TO registros_diario')
      ..execute(
        'CREATE INDEX idx_registros_paciente '
        'ON registros_diario (paciente_id, registrado_em)',
      )
      ..execute(
        'CREATE INDEX idx_registros_fila ON registros_diario (situacao_envio)',
      );
    await lote.commit(noResult: true);
  }

  /// O detalhe do motivo do registro excluído antes da versão 4 (o mesmo de
  /// `RegistroDiario.retiradaDoAppAntigo`).
  static const String detalheDaRetiradaAntiga =
      'Excluído no app antes da mudança do diário.';

  /// D20 — "Sair" apaga tudo o que a conta deixou no aparelho.
  Future<void> apagarTudo() async {
    final lote = db.batch();
    for (final t in tabelas) {
      lote.delete(t);
    }
    await lote.commit(noResult: true);
  }

  Future<void> fechar() => db.close();
}
