import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../enums/situacao_envio.dart';
import '../modelos/confirmacao_de_presenca.dart';
import 'banco_local.dart';

/// Acesso à tabela `confirmacoes_presenca` (evolução de TO, F2; D16, D27):
/// uma resposta por agendamento, com a fila de envio.
class ConfirmacaoDePresencaDao {
  ConfirmacaoDePresencaDao(this._banco);

  final BancoLocal _banco;

  static const String _tabela = 'confirmacoes_presenca';

  static Map<String, Object?> paraLinha(ConfirmacaoDePresenca c) => {
    'agendamento_id': c.agendamentoId,
    'paciente_id': c.pacienteId,
    'resposta': c.resposta.name,
    'respondida_em': c.toMap()['respondidaEm'],
    'situacao_envio': c.situacaoEnvio.name,
  };

  static ConfirmacaoDePresenca daLinha(Map<String, Object?> l) =>
      ConfirmacaoDePresenca.fromMap({
        'agendamentoId': l['agendamento_id'],
        'pacienteId': l['paciente_id'],
        'resposta': l['resposta'],
        'respondidaEm': l['respondida_em'],
        'situacaoEnvio': l['situacao_envio'],
      });

  /// Grava ou troca a resposta do agendamento.
  Future<void> salvar(ConfirmacaoDePresenca c) => _banco.db.insert(
    _tabela,
    paraLinha(c),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  /// Depois do envio, passa a `enviado` só se a linha ainda é a mesma
  /// resposta: se a pessoa trocou a resposta durante o envio, a nova continua
  /// na fila e sai na próxima vez.
  Future<void> marcarEnviada(ConfirmacaoDePresenca enviada) {
    final linha = paraLinha(enviada);
    return _banco.db.update(
      _tabela,
      {'situacao_envio': SituacaoEnvio.enviado.name},
      where: 'agendamento_id = ? AND resposta = ? AND respondida_em = ?',
      whereArgs: [
        linha['agendamento_id'],
        linha['resposta'],
        linha['respondida_em'],
      ],
    );
  }

  /// As respostas do paciente, por id do agendamento.
  Future<Map<String, ConfirmacaoDePresenca>> doPaciente(
    String pacienteId,
  ) async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'paciente_id = ?',
      whereArgs: [pacienteId],
    );
    return {for (final l in linhas) l['agendamento_id']! as String: daLinha(l)};
  }

  /// A fila, da resposta mais antiga à mais nova.
  Future<List<ConfirmacaoDePresenca>> pendentes() async {
    final linhas = await _banco.db.query(
      _tabela,
      where: 'situacao_envio = ?',
      whereArgs: [SituacaoEnvio.naFila.name],
      orderBy: 'respondida_em ASC',
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

  /// Junta o que veio do servidor: a resposta local ainda na fila vence.
  Future<void> mesclarDoServidor(List<ConfirmacaoDePresenca> remotas) async {
    await _banco.db.transaction((t) async {
      for (final remota in remotas) {
        final local = await t.query(
          _tabela,
          columns: ['situacao_envio'],
          where: 'agendamento_id = ?',
          whereArgs: [remota.agendamentoId],
        );
        final naFila =
            local.isNotEmpty &&
            local.single['situacao_envio'] == SituacaoEnvio.naFila.name;
        if (naFila) continue;
        await t.insert(
          _tabela,
          paraLinha(remota.copyWith(situacaoEnvio: SituacaoEnvio.enviado)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
