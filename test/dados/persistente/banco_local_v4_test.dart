/// A migração v3 → v4 do SQLite (P3: o diário igual ao do portal): a tabela
/// do diário é refeita, e nada do que a família registrou se perde.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/local/banco_local.dart';
import 'package:terae_app/dados/local/registro_diario_dao.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';

const String _ana = 'a0000000-0000-4000-8000-000000000001';

Map<String, Object?> _linhaV3({
  required String id,
  required String intensidade,
  required String sintoma,
  String situacao = 'enviado',
  String? observacao,
  String? atualizadoEm,
  String? excluidoEm,
}) => {
  'id': id,
  'paciente_id': _ana,
  'registrado_em': '2026-10-01T12:00:00.000Z',
  'adesao': 'parcial',
  'intensidade': intensidade,
  'sintoma': sintoma,
  'observacao': observacao,
  'situacao_envio': situacao,
  'atualizado_em': atualizadoEm,
  'excluido_em': excluidoEm,
  'texto_busca': sintoma.toLowerCase(),
};

void main() {
  test('v3 → v4: cada registro antigo vira o registro do portal, com o '
      'sintoma no texto contado, sem perder nenhum', () async {
    sqfliteFfiInit();
    final pasta = Directory.systemTemp.createTempSync('terae_app_v4_');
    final caminho = '${pasta.path}${Platform.pathSeparator}terae.db';
    final v3 = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          for (final migrar in BancoLocal.migracoes.take(3)) {
            await migrar(db);
          }
        },
      ),
    );
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r1',
        intensidade: 'critica',
        sintoma: 'Tristeza',
        observacao: 'Dia difícil',
      ),
    );
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r2',
        intensidade: 'moderada',
        sintoma: 'Sono ruim',
        atualizadoEm: '2026-10-01T13:00:00.000Z',
      ),
    );
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r3',
        intensidade: 'leve',
        sintoma: 'Cansaço',
        excluidoEm: '2026-10-01T14:00:00.000Z',
      ),
    );
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r4',
        intensidade: 'grave',
        sintoma: 'Dor',
        situacao: 'naFila',
      ),
    );
    // Revisão da P3: o app antigo punha a correção e a exclusão na fila.
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r5',
        intensidade: 'grave',
        sintoma: 'Dor',
        situacao: 'naFila',
        atualizadoEm: '2026-10-01T13:30:00.000Z',
      ),
    );
    await v3.insert(
      'registros_diario',
      _linhaV3(
        id: 'r6',
        intensidade: 'leve',
        sintoma: 'Sono ruim',
        situacao: 'naFila',
        excluidoEm: '2026-10-01T13:40:00.000Z',
      ),
    );
    await v3.insert('alertas', {
      'id': 'al1',
      'registro_id': 'r1',
      'regra': 'intensidadeCritica',
      'emitido_em': '2026-10-01T12:00:00.000Z',
      'ciente_em': null,
    });
    await v3.close();

    final banco = await BancoLocal.abrir(
      fabrica: databaseFactoryFfi,
      caminho: caminho,
    );
    expect(await banco.db.getVersion(), 4);
    final dao = RegistroDiarioDao(banco);

    final r1 = (await dao.porId('r1'))!;
    expect(r1.adesao, Adesao.parcial);
    expect(r1.sintomas, 'Tristeza', reason: 'o sintoma vira o texto contado');
    expect(r1.intensidadeSintoma, Intensidade.critico);
    expect(r1.observacoes, 'Dia difícil');
    expect(r1.versao, 1);
    expect(r1.versoesAnteriores, isEmpty);
    expect(r1.enviadoEm, DateTime.utc(2026, 10, 1, 12));
    expect(r1.alertouAEquipe, isTrue, reason: 'tinha alerta');
    expect(r1.revisado, isFalse);
    expect(r1.retirado, isFalse);

    final r2 = (await dao.porId('r2'))!;
    expect(r2.intensidadeSintoma, Intensidade.moderado);
    expect(r2.atualizadoEm, DateTime.utc(2026, 10, 1, 13));
    expect(r2.alertouAEquipe, isFalse);

    final r3 = (await dao.porId('r3'))!;
    expect(r3.retiradoEm, DateTime.utc(2026, 10, 1, 14));
    expect(r3.motivoDaRetirada!.categoria, MotivoDaRetirada.outro);
    expect(r3.motivoDaRetirada, RegistroDiario.retiradaDoAppAntigo);
    expect(
      BancoLocal.detalheDaRetiradaAntiga,
      RegistroDiario.retiradaDoAppAntigo.detalhe,
    );

    final r4 = (await dao.porId('r4'))!;
    expect(r4.situacaoEnvio, SituacaoEnvio.naFila);
    expect(r4.enviadoEm, isNull, reason: 'ainda não chegou');
    // A correção e a exclusão que esperavam na fila continuam nela, como
    // versão 1 no formato novo (as regras aceitam a troca de formato).
    final r5 = (await dao.porId('r5'))!;
    expect(r5.versao, 1);
    expect(r5.atualizadoEm, DateTime.utc(2026, 10, 1, 13, 30));
    final r6 = (await dao.porId('r6'))!;
    expect(r6.retirado, isTrue);
    expect(await dao.pendentes(), unorderedEquals([r4, r5, r6]));

    // A lista nova lê os enviados (o retirado também) e o alerta continua.
    final pagina = await dao.pagina(_ana);
    expect({for (final r in pagina.registros) r.id}, {'r1', 'r2', 'r3'});
    expect((await dao.alertaDoRegistro('r1'))!.id, 'al1');

    // O registro novo grava na tabela refeita, ida e volta.
    final corrigido = r2.corrigido(
      EntradaDoDiario(adesao: Adesao.total, sintomas: 'Melhorou.'),
      em: DateTime.utc(2026, 10, 2),
    );
    await dao.salvar(corrigido);
    expect(await dao.porId('r2'), corrigido);
    await banco.fechar();
  });

  test('banco novo: abre direto na v4 com a tabela do diário nova', () async {
    sqfliteFfiInit();
    final banco = await BancoLocal.abrir(
      fabrica: databaseFactoryFfi,
      caminho: inMemoryDatabasePath,
    );
    expect(BancoLocal.versao, 4);
    final colunas = await banco.db.rawQuery(
      'PRAGMA table_info(registros_diario)',
    );
    expect(
      colunas.map((c) => c['name']),
      containsAll([
        'sintomas',
        'intensidade_sintoma',
        'observacoes',
        'versao',
        'enviado_em',
        'alertou_a_equipe',
        'revisado_em',
        'retirado_em',
        'motivo_retirada',
        'detalhe_retirada',
        'versoes_anteriores',
      ]),
    );
    expect(colunas.map((c) => c['name']), isNot(contains('sintoma')));
    await banco.fechar();
  });
}
