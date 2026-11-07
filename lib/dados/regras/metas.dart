/// Regras das metas da terapia ocupacional (evolução de TO, F3; D25, D35,
/// D36), sem estado.
library;

import '../../nucleo/tempo/data_civil.dart';
import '../enums/ocupacao.dart';
import '../enums/tipo_marco.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/meta_terapeutica.dart';

/// As metas na ordem da Jornada (TM06): por ocupação, na ordem de
/// [Ocupacao]; dentro de cada uma, as em andamento primeiro (o prazo mais
/// perto antes), depois as alcançadas e as que saíram de cena.
List<MetaTerapeutica> ordenarMetas(Iterable<MetaTerapeutica> metas) =>
    [...metas]..sort((a, b) {
      final porOcupacao = a.ocupacao.index.compareTo(b.ocupacao.index);
      if (porOcupacao != 0) return porOcupacao;
      final porSituacao = a.situacao.index.compareTo(b.situacao.index);
      if (porSituacao != 0) return porSituacao;
      final porPrazo = a.prazo.compareTo(b.prazo);
      if (porPrazo != 0) return porPrazo;
      return a.id.compareTo(b.id);
    });

/// "Nossas metas" (TM06): as metas agrupadas por ocupação, na ordem de
/// [ordenarMetas]; só as ocupações que têm meta.
Map<Ocupacao, List<MetaTerapeutica>> metasPorOcupacao(
  Iterable<MetaTerapeutica> metas,
) {
  final grupos = <Ocupacao, List<MetaTerapeutica>>{};
  for (final m in ordenarMetas(metas)) {
    (grupos[m.ocupacao] ??= []).add(m);
  }
  return grupos;
}

/// D36 — o dia da alta da terapia ocupacional: o marco "Alta" mais recente
/// até [hoje]. `null` sem alta, ou com a alta só marcada para depois.
DataCivil? dataDaAlta(Iterable<MarcoJornada> marcos, DataCivil hoje) {
  DataCivil? alta;
  for (final m in marcos) {
    if (m.tipo != TipoMarco.alta || m.data.ehDepoisDe(hoje)) continue;
    if (alta == null || m.data.ehDepoisDe(alta)) alta = m.data;
  }
  return alta;
}
