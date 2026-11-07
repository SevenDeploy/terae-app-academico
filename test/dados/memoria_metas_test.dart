/// As metas da terapia ocupacional sobre a memória (evolução de TO, F3; D25,
/// D35): a demonstração, a recusa e a integridade das ligações.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/ocupacao.dart';
import 'package:terae_app/dados/enums/situacao_meta.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';

import 'memoria_apoio.dart';

String _meta(int n) =>
    'ce000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

void main() {
  test('a demonstração: Miguel com 3, Ana com 2, Antônio com 3 e Laura sem '
      'metas, na ordem da Jornada', () async {
    final metas = memoriaDeTeste().repositorios.metas;
    final miguel = await metas.metas(idMiguel);
    expect(miguel.map((m) => m.ocupacao), [
      Ocupacao.autocuidado,
      Ocupacao.brincar,
      Ocupacao.escola,
    ]);
    expect(miguel.last.situacao, SituacaoMeta.alcancada);
    expect(await metas.metas(idAna), hasLength(2));
    final antonio = await metas.metas(idAntonio);
    expect(antonio.map((m) => m.id), [_meta(7), _meta(6), _meta(8)]);
    expect(await metas.metas(idLaura), isEmpty);
  });

  test('meta de outro paciente ou inexistente é recusada', () async {
    final metas = memoriaDeTeste().repositorios.metas;
    expect(
      (await metas.meta(idAntonio, _meta(7))).descricao,
      'Vestir a camisa de botão sozinho',
    );
    await expectLater(
      metas.meta(idAntonio, _meta(1)),
      _recusa(MotivoRecusa.metaInexistente),
    );
    await expectLater(
      metas.meta(idAntonio, 'nao-existe'),
      _recusa(MotivoRecusa.metaInexistente),
    );
  });

  test('as 6 atividades de casa e os marcos ligados apontam para metas do '
      'mesmo paciente', () {
    final e = memoriaDeTeste().estado;
    final atividades = e.atividadesCasa.values.where((a) => a.metaId != null);
    expect(atividades, hasLength(6));
    for (final a in atividades) {
      expect(e.metas[a.metaId]!.pacienteId, a.pacienteId);
    }
    final marcos = e.marcos.values.where((m) => m.metaId != null);
    expect(marcos, hasLength(4));
    for (final m in marcos) {
      expect(e.metas[m.metaId]!.pacienteId, m.pacienteId);
    }
  });

  group('integridade (F3)', () {
    test('atividade ligada à meta de outro paciente não carrega', () {
      final dados = dadosDaDemonstracao();
      itemDe(
        dados,
        'atividadesCasa',
        'ca000000-0000-4000-8000-000000000005',
      )['metaId'] = _meta(
        1,
      );
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('marco ligado à meta de outro paciente não carrega', () {
      final dados = dadosDaDemonstracao();
      itemDe(
        dados,
        'marcos',
        'f0000000-0000-4000-8000-000000000012',
      )['metaId'] = _meta(
        1,
      );
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('"Meta alcançada" de meta que não foi alcançada não carrega', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'metas', _meta(8))['situacao'] = 'ativa';
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('meta sem descrição não carrega', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'metas', _meta(1))['descricao'] = '  ';
      expect(() => memoriaDeTeste(dados: dados), throwsArgumentError);
    });
  });
}
