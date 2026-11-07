/// As metas com Firestore e a cópia local (evolução de TO, F3; D16, D25,
/// D35).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_meta.dart';
import 'package:terae_app/dados/local/cache_dao.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/metas_repositorio.dart';

import 'apoio_persistencia.dart';

const String _p = 'a0000000-0000-4000-8000-000000000005';
const String _meta = 'ce000000-0000-4000-8000-000000000007';

void main() {
  late Montagem m;
  late RepositorioMetas metas;

  setUp(() async {
    m = await montar();
    metas = m.persistencia.repositorios.metas;
    await m.firestore
        .collection('pacientes')
        .doc(_p)
        .collection('metas')
        .doc(_meta)
        .set({
          'id': _meta,
          'pacienteId': _p,
          'profissionalId': 'd0000000-0000-4000-8000-000000000003',
          'ocupacao': 'autocuidado',
          'descricao': 'Vestir a camisa de botão sozinho',
          'combinadaCom': 'Antônio e a família',
          'prazo': '2026-11-16',
          'situacao': 'ativa',
          // O que a família nunca vê (D25): o app ignora, mesmo que venha.
          'escore': 2,
          'nivelGas': -1,
        });
  });

  test('com conexão lê do servidor; sem conexão, da cópia; o escore que '
      'viesse fica de fora (D25)', () async {
    final lidas = await metas.metas(_p);
    expect(lidas.single.situacao, SituacaoMeta.ativa);
    expect(lidas.single.toMap().keys, isNot(contains('escore')));
    expect(lidas.single.toMap().keys, isNot(contains('nivelGas')));
    // A cópia local também (revisão da F3): o SQLite guarda só os campos do
    // modelo.
    final copia = await CacheDao(
      m.persistencia.banco,
      agora: m.relogio.agora,
    ).listar('metas', _p);
    expect(copia.single.keys, isNot(contains('escore')));
    expect(copia.single.keys, isNot(contains('nivelGas')));
    await m.conexao.desligar();
    expect(
      (await metas.meta(_p, _meta)).descricao,
      'Vestir a camisa de botão sozinho',
    );
    await expectLater(
      metas.meta(_p, 'outra'),
      throwsA(
        isA<RecusaDeRegra>().having(
          (r) => r.motivo,
          'motivo',
          MotivoRecusa.metaInexistente,
        ),
      ),
    );
  });
}
