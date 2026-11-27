/// Regras do diário da família (P3; quadros 18e e 18f; D17 revista) como
/// funções puras, para a memória, a persistência local e as telas decidirem
/// igual.
library;

import '../modelos/registro_diario.dart';

/// Quantos registros a lista do diário traz por vez ("Ver registros mais
/// antigos"; `REGISTROS_DO_DIARIO_POR_PAGINA` do portal).
const int registrosPorPagina = 30;

/// Quanto tempo o registro precisa ter esperado no aparelho para a lista
/// dizer "Escrito em X, enviado em Y" (PMC-558 do portal: mais de 5 minutos).
const Duration esperaQueAparece = Duration(minutes: 5);

/// D17 revista — o [registro] ainda pode ser corrigido ou retirado: já chegou
/// ao servidor, a terapeuta não revisou, não foi retirado e não avisou a
/// equipe (o `podeAlterar` do portal). Não depende mais do dia.
bool podeAlterar(RegistroDiario registro) =>
    registro.enviado &&
    !registro.revisado &&
    !registro.retirado &&
    !registro.alertouAEquipe;

/// O instante em que a lista mostra o registro: quando o servidor recebeu
/// (ou, na fila, quando foi escrito).
DateTime momentoNaLista(RegistroDiario registro) =>
    registro.enviadoEm ?? registro.registradoEm;

/// A lista ordena do mais novo ao mais antigo; empate pelo id, para a
/// página seguinte começar sempre no mesmo lugar.
int maisNovoPrimeiro(RegistroDiario a, RegistroDiario b) {
  final porMomento = momentoNaLista(b).compareTo(momentoNaLista(a));
  return porMomento != 0 ? porMomento : b.id.compareTo(a.id);
}

/// "Escrito em X, enviado em Y": só quando o envio esperou na fila.
bool esperouNaFila(RegistroDiario registro) {
  final enviado = registro.enviadoEm;
  return enviado != null &&
      enviado.difference(registro.registradoEm) > esperaQueAparece;
}

/// Quantos dias um registro guardado sem internet ainda sai: o
/// `VALIDADE_DO_ENVIO_GUARDADO_DIAS` de `packages/domain` do terae (a chave
/// de idempotência da API vale um dia a mais). Passado isso, a fonte Terae
/// local não o envia mais (TL8).
const int validadeDoEnvioGuardadoDias = 7;
