/// Regras do programa em casa (evolução de TO, F1; D26) como funções puras,
/// para a memória, a persistência local e as telas TM16/TM17 decidirem igual.
library;

import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../enums/adesao_em_casa.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/registro_de_atividade.dart';

/// Quantos dias a faixa e o histórico mostram (como a janela de adesão de
/// 14 dias do Terae web).
const int diasDaFaixa = 14;

/// As atividades que valem no [dia], na ordem em que foram publicadas.
List<AtividadeDeCasa> atividadesVigentes(
  Iterable<AtividadeDeCasa> atividades,
  DataCivil dia,
) =>
    atividades.where((a) => a.vigenteEm(dia)).toList()
      ..sort((a, b) => a.publicadaEm.compareTo(b.publicadaEm));

/// O mais recente (pelo `registradoEm`) de [registros], ou `null`.
RegistroDeAtividade? _maisRecente(Iterable<RegistroDeAtividade> registros) {
  RegistroDeAtividade? escolhido;
  for (final r in registros) {
    if (escolhido == null || r.registradoEm.isAfter(escolhido.registradoEm)) {
      escolhido = r;
    }
  }
  return escolhido;
}

/// D26 — o registro da atividade [atividadeId] no [dia], se houver um que
/// valha (desfeito não conta). Se dois aparelhos registraram o mesmo dia
/// (D31), vale o mais recente — o mesmo que a faixa e o "Esta semana" contam
/// e que uma correção altera.
RegistroDeAtividade? registroDoDia(
  Iterable<RegistroDeAtividade> registros,
  String atividadeId,
  DataCivil dia,
) => _maisRecente(
  registros.where(
    (r) => r.atividadeId == atividadeId && r.dia == dia && !r.excluido,
  ),
);

/// D26 — o registro que um novo registro da atividade no [dia] corrige, para
/// ficar no máximo um por atividade e por dia: o [registroDoDia]; sem nenhum
/// que valha, o desfeito mais recente (volta a valer).
RegistroDeAtividade? registroParaReaproveitar(
  Iterable<RegistroDeAtividade> registros,
  String atividadeId,
  DataCivil dia,
) =>
    registroDoDia(registros, atividadeId, dia) ??
    _maisRecente(
      registros.where((r) => r.atividadeId == atividadeId && r.dia == dia),
    );

/// Um registro por atividade e por dia: o [registroDoDia] de cada par.
Iterable<RegistroDeAtividade> _umPorAtividadeEDia(
  Iterable<RegistroDeAtividade> registros,
) {
  final escolhidos = <String, RegistroDeAtividade>{};
  for (final r in registros) {
    if (r.excluido) continue;
    final chave = '${r.atividadeId}/${r.dia}';
    final atual = escolhidos[chave];
    if (atual == null || r.registradoEm.isAfter(atual.registradoEm)) {
      escolhidos[chave] = r;
    }
  }
  return escolhidos.values;
}

/// D26 — o registro ainda pode ser corrigido ou desfeito em [hoje]: é do
/// mesmo dia civil da clínica e ainda vale. Depois disso é só leitura.
bool podeAlterarRegistro(RegistroDeAtividade registro, DataCivil hoje) =>
    !registro.excluido && registro.dia == hoje;

/// "Esta semana: 2 de 3" — quantos dias, nos últimos 7 (hoje incluído), a
/// atividade foi feita, mesmo que em parte.
int vezesNaSemana(
  Iterable<RegistroDeAtividade> registros,
  String atividadeId,
  DataCivil hoje,
) {
  final inicio = hoje.somarDias(-6);
  return {
    for (final r in _umPorAtividadeEDia(registros))
      if (r.atividadeId == atividadeId &&
          r.adesao.conta &&
          !r.dia.ehAntesDe(inicio) &&
          !r.dia.ehDepoisDe(hoje))
        r.dia,
  }.length;
}

/// Um dia da faixa: a resposta daquele dia, ou `null` sem registro.
@immutable
class DiaDaFaixa {
  const DiaDaFaixa(this.dia, this.adesao);

  final DataCivil dia;
  final AdesaoEmCasa? adesao;

  @override
  bool operator ==(Object other) =>
      other is DiaDaFaixa && other.dia == dia && other.adesao == adesao;

  @override
  int get hashCode => Object.hash(dia, adesao);

  @override
  String toString() => 'DiaDaFaixa($dia, ${adesao?.name})';
}

/// A faixa dos últimos [dias] dias, do mais antigo a [hoje]. Com
/// [atividadeId], a resposta daquela atividade; sem ele, a melhor resposta
/// do dia entre todas (feito > em parte > não deu), para a TM16.
List<DiaDaFaixa> faixaDeDias(
  Iterable<RegistroDeAtividade> registros,
  DataCivil hoje, {
  String? atividadeId,
  int dias = diasDaFaixa,
}) {
  final melhor = <DataCivil, AdesaoEmCasa>{};
  for (final r in _umPorAtividadeEDia(registros)) {
    if (atividadeId != null && r.atividadeId != atividadeId) continue;
    final atual = melhor[r.dia];
    if (atual == null || r.adesao.index < atual.index) melhor[r.dia] = r.adesao;
  }
  return [
    for (var i = dias - 1; i >= 0; i--)
      DiaDaFaixa(hoje.somarDias(-i), melhor[hoje.somarDias(-i)]),
  ];
}

/// "Hoje: 1 de 2 atividades registradas" — quantas das [atividades] já têm
/// registro hoje (qualquer resposta: "não deu" também é registro).
({int registradas, int total}) resumoDeHoje(
  Iterable<AtividadeDeCasa> atividades,
  Iterable<RegistroDeAtividade> registros,
  DataCivil hoje,
) {
  final vigentes = atividadesVigentes(atividades, hoje);
  return (
    registradas: vigentes
        .where((a) => registroDoDia(registros, a.id, hoje) != null)
        .length,
    total: vigentes.length,
  );
}
