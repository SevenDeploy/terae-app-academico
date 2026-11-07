/// Regras das metas da terapia ocupacional (evolução de TO, F3; D25, D35,
/// D36).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/ocupacao.dart';
import 'package:terae_app/dados/enums/situacao_meta.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/meta_terapeutica.dart';
import 'package:terae_app/dados/regras/metas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

MetaTerapeutica _meta(
  String id,
  Ocupacao ocupacao,
  SituacaoMeta situacao,
  DataCivil prazo,
) => MetaTerapeutica(
  id: id,
  pacienteId: 'p',
  profissionalId: 'pr',
  ocupacao: ocupacao,
  descricao: 'Meta $id',
  combinadaCom: 'Família',
  prazo: prazo,
  situacao: situacao,
);

MarcoJornada _marco(String id, TipoMarco tipo, DataCivil data) => MarcoJornada(
  id: id,
  pacienteId: 'p',
  tipo: tipo,
  data: data,
  titulo: 'Marco $id',
  textoSimples: 'Texto simples.',
);

final DataCivil _hoje = DataCivil(2026, 10, 2);

void main() {
  test('ordem da Jornada: por ocupação; as em andamento primeiro, pelo '
      'prazo; depois as alcançadas e as que saíram de cena', () {
    final metas = [
      _meta('a', Ocupacao.escola, SituacaoMeta.ativa, DataCivil(2026, 12, 1)),
      _meta(
        'b',
        Ocupacao.autocuidado,
        SituacaoMeta.substituida,
        DataCivil(2026, 10, 10),
      ),
      _meta(
        'c',
        Ocupacao.autocuidado,
        SituacaoMeta.ativa,
        DataCivil(2026, 11, 20),
      ),
      _meta(
        'd',
        Ocupacao.autocuidado,
        SituacaoMeta.alcancada,
        DataCivil(2026, 9, 1),
      ),
      _meta(
        'e',
        Ocupacao.autocuidado,
        SituacaoMeta.ativa,
        DataCivil(2026, 11, 1),
      ),
      _meta(
        'f',
        Ocupacao.autocuidado,
        SituacaoMeta.interrompida,
        DataCivil(2026, 10, 1),
      ),
    ];
    expect(ordenarMetas(metas).map((m) => m.id), [
      'e',
      'c',
      'd',
      'f',
      'b',
      'a',
    ]);
    final grupos = metasPorOcupacao(metas);
    expect(grupos.keys, [Ocupacao.autocuidado, Ocupacao.escola]);
    expect(grupos[Ocupacao.autocuidado]!.map((m) => m.id), [
      'e',
      'c',
      'd',
      'f',
      'b',
    ]);
    expect(metasPorOcupacao(const []), isEmpty);
  });

  test('alta (D36): o marco "Alta" mais recente até hoje; a marcada para '
      'depois ainda não conta', () {
    expect(
      dataDaAlta([_marco('1', TipoMarco.proximoPasso, _hoje)], _hoje),
      isNull,
    );
    expect(
      dataDaAlta([_marco('1', TipoMarco.alta, _hoje.somarDias(3))], _hoje),
      isNull,
    );
    expect(dataDaAlta([_marco('1', TipoMarco.alta, _hoje)], _hoje), _hoje);
    expect(
      dataDaAlta([
        _marco('1', TipoMarco.alta, DataCivil(2026, 3, 1)),
        _marco('2', TipoMarco.alta, DataCivil(2026, 9, 30)),
        _marco('3', TipoMarco.reavaliacao, DataCivil(2026, 10, 1)),
      ], _hoje),
      DataCivil(2026, 9, 30),
    );
  });

  test('a família lê a situação em palavras, nunca em número (D25)', () {
    expect(SituacaoMeta.values.map((s) => s.rotulo), [
      'Em andamento',
      'Alcançada',
      'Interrompida',
      'Substituída por outra',
    ]);
    for (final s in SituacaoMeta.values) {
      expect(s.rotulo, isNot(matches(RegExp(r'\d'))));
    }
  });
}
