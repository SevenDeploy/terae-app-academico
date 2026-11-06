import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../conversao_mapa.dart';
import 'banco_local.dart';

/// As cópias de leitura da §23 na tabela `cache_documentos` (D16): cada
/// documento é o `toMap` do modelo convertido em JSON (`jsonEncode`), com a
/// coleção, o id e o [dono] (o paciente ou a conta a que pertence). É daqui
/// que as telas leem quando não há conexão.
class CacheDao {
  CacheDao(this._banco, {DateTime Function()? agora})
    : _agora = agora ?? DateTime.now;

  final BancoLocal _banco;
  final DateTime Function() _agora;

  /// Troca de uma vez todos os documentos de [colecao] do [dono] pelos
  /// [documentos] (id → mapa), numa transação: a cópia nunca fica pela
  /// metade.
  Future<void> substituir(
    String colecao,
    String dono,
    Map<String, Mapa> documentos,
  ) async {
    final quando = escreverInstante(_agora());
    await _banco.db.transaction((t) async {
      await t.delete(
        'cache_documentos',
        where: 'colecao = ? AND dono = ?',
        whereArgs: [colecao, dono],
      );
      for (final MapEntry(key: id, value: mapa) in documentos.entries) {
        await t.insert('cache_documentos', {
          'colecao': colecao,
          'id': id,
          'dono': dono,
          'json': jsonEncode(mapa),
          'sincronizado_em': quando,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Grava (ou troca) um documento só.
  Future<void> salvar(String colecao, String id, String dono, Mapa mapa) =>
      _banco.db.insert('cache_documentos', {
        'colecao': colecao,
        'id': id,
        'dono': dono,
        'json': jsonEncode(mapa),
        'sincronizado_em': escreverInstante(_agora()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Os documentos de [colecao] do [dono], na ordem em que foram gravados;
  /// vazio se nunca houve cópia.
  Future<List<Mapa>> listar(String colecao, String dono) async {
    final linhas = await _banco.db.query(
      'cache_documentos',
      where: 'colecao = ? AND dono = ?',
      whereArgs: [colecao, dono],
      orderBy: 'rowid',
    );
    return [for (final l in linhas) _ler(l)];
  }

  /// Um documento pelo id, se houver cópia.
  Future<Mapa?> ler(String colecao, String id) async {
    final linhas = await _banco.db.query(
      'cache_documentos',
      where: 'colecao = ? AND id = ?',
      whereArgs: [colecao, id],
    );
    return linhas.isEmpty ? null : _ler(linhas.single);
  }

  /// Há cópia de [colecao] do [dono] (mesmo que vazia não conta)?
  Future<bool> temCopia(String colecao, String dono) async =>
      (await listar(colecao, dono)).isNotEmpty;

  static Mapa _ler(Map<String, Object?> linha) {
    final valor = jsonDecode(linha['json']! as String);
    if (valor is! Map<String, Object?>) {
      throw FormatException('Cópia local inválida', linha['id']);
    }
    return valor;
  }
}
