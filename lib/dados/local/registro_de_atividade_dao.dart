import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../nucleo/tempo/data_civil.dart';
import '../enums/situacao_envio.dart';
import '../modelos/registro_de_atividade.dart';
import 'banco_local.dart';

/// Acesso à tabela `registros_casa` (evolução de TO, F1; D16, D26). Como o
/// DAO do diário, converte objeto ↔ linha pelo `toMap`/`fromMap` do modelo,
/// trocando só o nome das colunas, para a mesma validação valer no banco.
class RegistroDeAtividadeDao {
  RegistroDeAtividadeDao(this._banco);

  final BancoLocal _banco;

  static const String _tabela = 'registros_casa';

  static const Map<String, String> _colunas = {
    'id': 'id',
    'pacienteId': 'paciente_id',
    'atividadeId': 'atividade_id',
    'dia': 'dia',
    'adesao': 'adesao',
    'reflexao': 'reflexao',
    'quem': 'quem',
    'registradoEm': 'registrado_em',
    'situacaoEnvio': 'situacao_envio',
    'atualizadoEm': 'atualizado_em',
    'excluidoEm': 'excluido_em',
  };

  /// Objeto → linha.
  static Map<String, Object?> paraLinha(RegistroDeAtividade r) => {
    for (final MapEntry(:key, :value) in r.toMap().entries)
      _colunas[key]!: value,
  };

  /// Linha → objeto (lança `FormatException` se a linha estiver errada).
  static RegistroDeAtividade daLinha(Map<String, Object?> linha) =>
      RegistroDeAtividade.fromMap({
        for (final MapEntry(:key, :value) in _colunas.entries)
          key: linha[value],
      });

  /// Grava ou substitui (o id é o UUID do aparelho).
  Future<void> salvar(RegistroDeAtividade r) => _banco.db.insert(
    _tabela,
    paraLinha(r),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<RegistroDeAtividade?> porId(String id) async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'id = ?',
      whereArgs: [id],
    );
    return linhas.isEmpty ? null : daLinha(linhas.single);
  }

  /// D26 — o registro da atividade no [dia] que um novo registro corrige: o
  /// mesmo que `registroParaReaproveitar` escolhe (o mais recente que vale;
  /// sem nenhum que valha, o desfeito mais recente).
  Future<RegistroDeAtividade?> doDia(String atividadeId, DataCivil dia) async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'atividade_id = ? AND dia = ?',
      whereArgs: [atividadeId, dia.paraIso()],
      orderBy: '(excluido_em IS NULL) DESC, registrado_em DESC',
      limit: 1,
    );
    return linhas.isEmpty ? null : daLinha(linhas.single);
  }

  /// Os que valem (sem desfeitos) do paciente a partir de [desde], do mais
  /// recente ao mais antigo.
  Future<List<RegistroDeAtividade>> doPaciente(
    String pacienteId, {
    required DataCivil desde,
  }) async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'paciente_id = ? AND excluido_em IS NULL AND dia >= ?',
      whereArgs: [pacienteId, desde.paraIso()],
      orderBy: 'dia DESC, registrado_em DESC',
    );
    return [for (final l in linhas) daLinha(l)];
  }

  /// A fila: registros novos, corrigidos ou desfeitos que o servidor ainda
  /// não confirmou, do mais antigo ao mais novo.
  Future<List<RegistroDeAtividade>> pendentes() async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'situacao_envio = ?',
      whereArgs: [SituacaoEnvio.naFila.name],
      orderBy: 'registrado_em ASC',
    );
    return [for (final l in linhas) daLinha(l)];
  }

  Future<int> contarPendentes() async {
    final linhas = await _banco.db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_tabela WHERE situacao_envio = ?',
      [SituacaoEnvio.naFila.name],
    );
    return linhas.single['n']! as int;
  }

  /// Junta o que veio do servidor: a versão local que ainda está na fila
  /// vence; o resto vira a do servidor.
  Future<void> mesclarDoServidor(List<RegistroDeAtividade> remotos) async {
    await _banco.db.transaction((t) async {
      for (final remoto in remotos) {
        final local = await t.query(
          _tabela,
          columns: ['situacao_envio'],
          where: 'id = ?',
          whereArgs: [remoto.id],
        );
        final naFila =
            local.isNotEmpty &&
            local.single['situacao_envio'] == SituacaoEnvio.naFila.name;
        if (naFila) continue;
        await t.insert(
          _tabela,
          paraLinha(remoto.copyWith(situacaoEnvio: SituacaoEnvio.enviado)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
