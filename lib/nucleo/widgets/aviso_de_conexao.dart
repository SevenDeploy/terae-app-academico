import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/sincronizacao/situacao_sincronizacao.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';

/// Aviso de conexão (Atividade 4, D16): some com conexão e fila vazia; sem
/// conexão diz que o app continua funcionando e quantos registros do diário
/// esperam envio; com conexão e fila, diz que está enviando.
///
/// Lê a [ConexaoDoApp] do provider; sem ela (teste antigo), não mostra
/// nada.
class AvisoDeConexao extends StatelessWidget {
  const AvisoDeConexao({super.key});

  @override
  Widget build(BuildContext context) {
    final ConexaoDoApp conexao;
    try {
      conexao = context.read<ConexaoDoApp>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<SituacaoSincronizacao>(
      valueListenable: conexao.situacao,
      builder: (context, situacao, _) {
        final texto = textoDoAviso(situacao);
        if (texto == null) return const SizedBox.shrink();
        final semConexao = !situacao.online;
        final cores = semConexao
            ? const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50)
            : const ParDeCores(CoresTerae.primaria700, CoresTerae.primaria50);
        return Padding(
          padding: const EdgeInsets.only(bottom: MedidasTerae.espaco),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: DecoratedBox(
              key: const Key('aviso-conexao'),
              decoration: BoxDecoration(
                color: cores.fundo,
                borderRadius: const BorderRadius.all(
                  Radius.circular(MedidasTerae.raioBotao),
                ),
                border: Border.all(color: cores.texto.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        semConexao ? Icons.cloud_off : Icons.cloud_sync,
                        color: cores.texto,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        texto,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cores.texto,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// O texto do aviso, ou `null` quando não há nada a dizer.
String? textoDoAviso(SituacaoSincronizacao s) {
  final fila = switch (s.pendentes) {
    0 => null,
    1 => '1 registro aguardando envio',
    final n => '$n registros aguardando envio',
  };
  if (!s.online) {
    return fila == null
        ? 'Sem conexão. Você pode continuar usando o app.'
        : 'Sem conexão — $fila. Ele sai sozinho quando a conexão voltar.';
  }
  return fila == null ? null : 'Enviando: $fila.';
}
