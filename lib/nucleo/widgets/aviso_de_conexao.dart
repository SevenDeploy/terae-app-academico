import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../dados/sincronizacao/situacao_sincronizacao.dart';
import '../tema/cores.dart';
import '../tema/tema.dart';

/// Aviso de conexão (Atividade 4, D16), com o tom da `FaixaSemConexao` do
/// portal: some com conexão e fila vazia; sem
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
        // Sem internet: a faixa escura do portal (`FaixaSemConexao`).
        final cores = semConexao
            ? const ParDeCores(CoresTerae.branco, CoresTerae.neutro900)
            : const ParDeCores(CoresTerae.info, CoresTerae.infoFundo);
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
                border: semConexao
                    ? null
                    : Border.all(color: CoresTerae.infoBorda),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        semConexao
                            ? LucideIcons.wifiOff
                            : LucideIcons.refreshCw,
                        size: 20,
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
        ? 'Sem internet. Pode continuar usando o app. Para enviar, espere a '
              'internet voltar.'
        : 'Sem internet — $fila. Ele sai sozinho quando a internet voltar.';
  }
  return fila == null ? null : 'Enviando: $fila.';
}
