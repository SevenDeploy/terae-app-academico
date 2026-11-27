import 'dart:convert';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../conversao_mapa.dart';
import '../enums/situacao_envio.dart';
import '../modelos/alerta.dart';
import '../modelos/registro_diario.dart';
import '../regras/diario.dart';
import 'banco_local.dart';

/// Acesso às tabelas `registros_diario` e `alertas` (D16; versão 4 do banco,
/// P3). Converte objeto ↔ linha campo a campo, pelo mapa do modelo, para a
/// mesma validação do `fromMap` valer no banco.
class RegistroDiarioDao {
  RegistroDiarioDao(this._banco);

  final BancoLocal _banco;

  /// Ordem da lista: o instante da lista (recebido ou escrito), do mais novo
  /// ao mais antigo, e o id no empate (`maisNovoPrimeiro`).
  static const String _momento = 'COALESCE(enviado_em, registrado_em)';

  /// Objeto → linha.
  static Map<String, Object?> paraLinha(RegistroDiario r) {
    final m = r.toMap();
    final motivo = r.motivoDaRetirada;
    return {
      'id': m['id'],
      'paciente_id': m['pacienteId'],
      'registrado_em': m['registradoEm'],
      'adesao': m['adesao'],
      'sintomas': m['sintomas'],
      'intensidade_sintoma': m['intensidadeSintoma'],
      'observacoes': m['observacoes'],
      'situacao_envio': m['situacaoEnvio'],
      'versao': r.versao,
      'enviado_em': m['enviadoEm'],
      'atualizado_em': m['atualizadoEm'],
      'alertou_a_equipe': r.alertouAEquipe ? 1 : 0,
      'revisado_em': m['revisadoEm'],
      'retirado_em': m['retiradoEm'],
      'motivo_retirada': motivo?.categoria.valor,
      'detalhe_retirada': motivo?.detalhe,
      'versoes_anteriores': jsonEncode([
        for (final v in r.versoesAnteriores) v.toMap(),
      ]),
    };
  }

  /// Linha → objeto (lança `FormatException` se a linha estiver errada).
  static RegistroDiario daLinha(Map<String, Object?> linha) {
    final versoes = linha['versoes_anteriores'];
    final motivo = linha['motivo_retirada'];
    return RegistroDiario.fromMap({
      'id': linha['id'],
      'pacienteId': linha['paciente_id'],
      'registradoEm': linha['registrado_em'],
      'adesao': linha['adesao'],
      'sintomas': linha['sintomas'],
      'intensidadeSintoma': linha['intensidade_sintoma'],
      'observacoes': linha['observacoes'],
      'situacaoEnvio': linha['situacao_envio'],
      'versao': linha['versao'],
      'enviadoEm': linha['enviado_em'],
      'atualizadoEm': linha['atualizado_em'],
      'alertouAEquipe': linha['alertou_a_equipe'] == 1,
      'revisadoEm': linha['revisado_em'],
      'retiradoEm': linha['retirado_em'],
      'motivoDaRetirada': motivo == null
          ? null
          : {'categoria': motivo, 'detalhe': linha['detalhe_retirada']},
      'versoesAnteriores': versoes is String ? jsonDecode(versoes) : versoes,
    });
  }

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

  /// TM03 — uma página da lista: os que chegaram ao servidor (os retirados
  /// também), do mais novo ao mais antigo, [registrosPorPagina] por vez, só
  /// os anteriores a [antes] quando dado. Lê um a mais para saber se há
  /// mais antigos.
  Future<({List<RegistroDiario> registros, bool haMais})> pagina(
    String pacienteId, {
    DateTime? antes,
  }) async {
    final onde = ['paciente_id = ?', 'situacao_envio = ?'];
    final argumentos = <Object?>[pacienteId, SituacaoEnvio.enviado.name];
    if (antes != null) {
      onde.add('$_momento < ?');
      argumentos.add(escreverInstante(antes));
    }
    final linhas = await _banco.db.query(
      'registros_diario',
      where: onde.join(' AND '),
      whereArgs: argumentos,
      orderBy: '$_momento DESC, id DESC',
      limit: registrosPorPagina + 1,
    );
    return (
      registros: [for (final l in linhas.take(registrosPorPagina)) daLinha(l)],
      haMais: linhas.length > registrosPorPagina,
    );
  }

  /// A fila: registros que o servidor ainda não confirmou, do mais antigo ao
  /// mais novo (§19); com [pacienteId], só os dele ("Guardados neste
  /// aparelho").
  Future<List<RegistroDiario>> pendentes({String? pacienteId}) async {
    final linhas = await _banco.db.query(
      'registros_diario',
      where: pacienteId == null
          ? 'situacao_envio = ?'
          : 'situacao_envio = ? AND paciente_id = ?',
      whereArgs: [SituacaoEnvio.naFila.name, ?pacienteId],
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
  /// `registradoEm`), sem os retirados.
  Future<RegistroDiario?> anteriorA(RegistroDiario r) async {
    final linhas = await _banco.db.query(
      'registros_diario',
      where:
          'paciente_id = ? AND id <> ? AND registrado_em < ? '
          'AND retirado_em IS NULL',
      whereArgs: [r.pacienteId, r.id, escreverInstante(r.registradoEm)],
      orderBy: 'registrado_em DESC',
      limit: 1,
    );
    return linhas.isEmpty ? null : daLinha(linhas.single);
  }

  /// Junta o que veio do servidor: o registro novo que ainda está na fila
  /// vence (é a mudança mais nova do aparelho); o resto vira a do servidor
  /// (a revisão da terapeuta chega assim).
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
