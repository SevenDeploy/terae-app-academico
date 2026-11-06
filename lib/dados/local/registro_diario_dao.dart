import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../conversao_mapa.dart';
import '../enums/intensidade.dart';
import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import 'banco_local.dart';

/// Acesso às tabelas `registros_diario` e `alertas` (D16). Converte objeto ↔
/// linha pelo `toMap`/`fromMap` do modelo, trocando só o nome das colunas
/// (`pacienteId` ↔ `paciente_id`), para a mesma validação valer no banco.
class RegistroDiarioDao {
  RegistroDiarioDao(this._banco);

  final BancoLocal _banco;

  static const Map<String, String> _colunas = {
    'id': 'id',
    'pacienteId': 'paciente_id',
    'registradoEm': 'registrado_em',
    'adesao': 'adesao',
    'intensidade': 'intensidade',
    'sintomaPredominante': 'sintoma',
    'observacao': 'observacao',
    'situacaoEnvio': 'situacao_envio',
    'atualizadoEm': 'atualizado_em',
    'excluidoEm': 'excluido_em',
  };

  /// Objeto → linha.
  static Map<String, Object?> paraLinha(RegistroDiario r) => {
    for (final MapEntry(:key, :value) in r.toMap().entries)
      _colunas[key]!: value,
    'texto_busca': textoDeBusca(r),
  };

  /// Linha → objeto (lança `FormatException` se a linha estiver errada).
  static RegistroDiario daLinha(Map<String, Object?> linha) =>
      RegistroDiario.fromMap({
        for (final MapEntry(:key, :value) in _colunas.entries)
          key: linha[value],
      });

  /// Grava ou substitui (o id é o UUID do aparelho).
  Future<void> salvar(RegistroDiario r) => _banco.db.insert(
    'registros_diario',
    paraLinha(r),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<RegistroDiario?> porId(String id) async {
    final linhas = await _banco.db.query(
      'registros_diario',
      where: 'id = ?',
      whereArgs: [id],
    );
    return linhas.isEmpty ? null : daLinha(linhas.single);
  }

  /// TM13 — os que valem (sem excluídos), do mais recente ao mais antigo,
  /// filtrados no próprio SQL: [texto] com `LIKE` no texto de busca e
  /// [intensidades] com `IN`.
  Future<List<RegistroDiario>> doPaciente(
    String pacienteId, {
    String texto = '',
    Set<Intensidade> intensidades = const {},
  }) async {
    final onde = ['paciente_id = ?', 'excluido_em IS NULL'];
    final argumentos = <Object?>[pacienteId];
    final procura = normalizarBusca(texto);
    if (procura.isNotEmpty) {
      onde.add('texto_busca LIKE ?');
      argumentos.add('%$procura%');
    }
    if (intensidades.isNotEmpty) {
      onde.add(
        'intensidade IN (${List.filled(intensidades.length, '?').join(', ')})',
      );
      argumentos.addAll(intensidades.map((i) => i.name));
    }
    final linhas = await _banco.db.query(
      'registros_diario',
      where: onde.join(' AND '),
      whereArgs: argumentos,
      orderBy: 'registrado_em DESC',
    );
    return [for (final l in linhas) daLinha(l)];
  }

  /// A fila: registros novos, corrigidos ou excluídos que o servidor ainda
  /// não confirmou, do mais antigo ao mais novo (§19).
  Future<List<RegistroDiario>> pendentes() async {
    final linhas = await _banco.db.query(
      'registros_diario',
      where: 'situacao_envio = ?',
      whereArgs: [SituacaoEnvio.naFila.name],
      orderBy: 'registrado_em ASC',
    );
    return [for (final l in linhas) daLinha(l)];
  }

  Future<int> contarPendentes() async {
    final linhas = await _banco.db.rawQuery(
      'SELECT COUNT(*) AS n FROM registros_diario WHERE situacao_envio = ?',
      [SituacaoEnvio.naFila.name],
    );
    return linhas.single['n']! as int;
  }

  /// §7.1 — o registro do mesmo paciente imediatamente anterior a [r] (pelo
  /// `registradoEm`), sem os excluídos.
  Future<RegistroDiario?> anteriorA(RegistroDiario r) async {
    final linhas = await _banco.db.query(
      'registros_diario',
      where:
          'paciente_id = ? AND id <> ? AND registrado_em < ? '
          'AND excluido_em IS NULL',
      whereArgs: [r.pacienteId, r.id, escreverInstante(r.registradoEm)],
      orderBy: 'registrado_em DESC',
      limit: 1,
    );
    return linhas.isEmpty ? null : daLinha(linhas.single);
  }

  /// Junta o que veio do servidor: a versão local que ainda está na fila
  /// vence (é a mudança mais nova do paciente); o resto vira a do servidor.
  Future<void> mesclarDoServidor(List<RegistroDiario> remotos) async {
    await _banco.db.transaction((t) async {
      for (final remoto in remotos) {
        final local = await t.query(
          'registros_diario',
          columns: ['situacao_envio'],
          where: 'id = ?',
          whereArgs: [remoto.id],
        );
        final naFila =
            local.isNotEmpty &&
            local.single['situacao_envio'] == SituacaoEnvio.naFila.name;
        if (naFila) continue;
        await t.insert(
          'registros_diario',
          paraLinha(remoto.copyWith(situacaoEnvio: SituacaoEnvio.enviado)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ---------------------------------------------------------------- alertas

  Future<void> salvarAlerta(Alerta a) => _banco.db.insert('alertas', {
    'id': a.id,
    'registro_id': a.registroId,
    'regra': a.regraDisparada.name,
    'emitido_em': escreverInstante(a.emitidoEm),
    'ciente_em': escreverInstanteOpcional(a.cienteEm),
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<Alerta?> alertaDoRegistro(String registroId) async {
    final linhas = await _banco.db.query(
      'alertas',
      where: 'registro_id = ?',
      whereArgs: [registroId],
    );
    if (linhas.isEmpty) return null;
    final l = linhas.single;
    return Alerta.fromMap({
      'id': l['id'],
      'registroId': l['registro_id'],
      'regraDisparada': l['regra'],
      'emitidoEm': l['emitido_em'],
      'cienteEm': l['ciente_em'],
    });
  }
}
