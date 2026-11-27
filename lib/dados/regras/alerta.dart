/// Regra do alerta do §7.1 como função pura.
///
/// Na Atividade 3 só o "servidor simulado" a usava. Na Atividade 4 (D18), sem
/// Cloud Functions no plano gratuito do Firebase, o aparelho a avalia — mas só
/// depois que o servidor confirma a gravação do registro, e o alerta vai no
/// mesmo lote. A memória continua usando a mesma função.
library;

import '../enums/intensidade.dart';
import '../enums/regra_alerta.dart';

/// §7.1 — a regra disparada pelo registro [nova], dado o registro
/// imediatamente anterior do mesmo paciente ([anterior]). A pergunta "O
/// quanto isso atrapalhou o dia?" é opcional (P3), então as duas podem
/// faltar: (a) "Muito" (crítico), sempre; (b) "Bastante" (grave) quando o
/// anterior também foi "Bastante". `null` = sem alerta.
RegraAlerta? regraDoAlerta({
  required Intensidade? nova,
  required Intensidade? anterior,
}) {
  if (nova == Intensidade.critico) return RegraAlerta.intensidadeCritica;
  if (nova == Intensidade.grave && anterior == Intensidade.grave) {
    return RegraAlerta.graveConsecutivo;
  }
  return null;
}
