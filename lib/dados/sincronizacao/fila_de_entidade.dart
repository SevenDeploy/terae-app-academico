/// Uma entidade que o aparelho grava e envia depois (evolução de TO): a
/// fila de envio dela, no SQLite, e a busca do que o servidor já tem.
///
/// O diário continua com o caminho próprio no `Sincronizador` (o envio leva
/// o alerta no mesmo lote, D18); cada entidade nova gravada pelo usuário —
/// o registro da atividade de casa, a resposta de presença — implementa esta
/// interface e entra na lista do sincronizador. Assim o aviso de conexão
/// conta todas as filas e a conexão de volta esvazia todas.
abstract interface class FilaDeEntidade {
  /// Quantos itens desta entidade esperam envio.
  Future<int> contarPendentes();

  /// Envia a fila, do mais antigo ao mais novo, e marca cada item como
  /// enviado só depois de o servidor confirmar. Sem rede ou sem resposta no
  /// prazo, lança `RecusaDeRegra(semConexao)` e o que faltou continua na
  /// fila (o sincronizador para e tenta de novo depois).
  Future<void> enviarPendentes();

  /// Busca no servidor os itens do paciente [pacienteId] e junta com os
  /// locais — o que ainda está na fila vence.
  Future<void> buscar(String pacienteId);
}
