/// Banco SQLite do aparelho (Atividade 4, D16): a fonte local da verdade.
///
/// - `registros_diario`: o item principal, com a fila de envio (as linhas com
///   `situacao_envio = 'naFila'`) e o texto de busca da TM13;
/// - `alertas`: os alertas confirmados dos registros do paciente;
/// - `cache_documentos`: as cópias de leitura da §23 (paciente,
///   profissional, consultas, receita, marcos, vínculos), cada uma guardada
///   como o JSON do `toMap` do modelo.
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
  ];

  /// Migrações em ordem: a de índice `i` leva o banco da versão `i` à `i + 1`.
  /// Nunca se muda uma migração publicada; corrige-se com outra.
  static const List<Future<void> Function(Database db)> migracoes = [_versao1];

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
