/// Regras do CRUD do diário (D17, Atividade 4) como funções puras, para a
/// memória, a persistência local e as telas TM13/TM14 decidirem igual.
library;

import '../../nucleo/tempo/data_civil.dart';
import '../enums/intensidade.dart';
import '../modelos/registro_diario.dart';

/// D17 — o [registro] ainda pode ser corrigido ou excluído em [agora]: não
/// foi excluído e foi feito no mesmo dia civil da clínica (−04:00). Depois
/// disso ele é só de leitura: a equipe já pode tê-lo lido.
bool podeAlterar(RegistroDiario registro, DateTime agora) =>
    !registro.excluido &&
    DataCivil.doInstante(registro.registradoEm) == DataCivil.doInstante(agora);

/// Texto de busca da TM13: minúsculo e sem acento, para "ansiedade" achar
/// "Ansiedade" e "cansaco" achar "Cansaço".
String normalizarBusca(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final minusculo = texto.toLowerCase().trim();
  final saida = StringBuffer();
  for (final letra in minusculo.split('')) {
    final i = de.indexOf(letra);
    saida.write(i < 0 ? letra : para[i]);
  }
  return saida.toString();
}

/// O texto em que a busca da TM13 procura: sintoma e observação.
String textoDeBusca(RegistroDiario registro) => normalizarBusca(
  '${registro.sintomaPredominante} ${registro.observacao ?? ''}',
);

/// O [registro] passa no filtro da TM13: [texto] (vazio = qualquer) no
/// sintoma ou na observação, e intensidade em [intensidades] (vazio =
/// qualquer). Excluído nunca passa.
bool passaNoFiltro(
  RegistroDiario registro, {
  String texto = '',
  Set<Intensidade> intensidades = const {},
}) {
  if (registro.excluido) return false;
  if (intensidades.isNotEmpty && !intensidades.contains(registro.intensidade)) {
    return false;
  }
  final procura = normalizarBusca(texto);
  return procura.isEmpty || textoDeBusca(registro).contains(procura);
}
