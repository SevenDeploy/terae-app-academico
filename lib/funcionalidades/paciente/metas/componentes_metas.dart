import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../dados/enums/situacao_meta.dart';
import '../../../dados/modelos/meta_terapeutica.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';

/// A situação da meta (F3; D25): "Em andamento", "Alcançada"…, nunca escore
/// nem nível.
class EtiquetaDaMeta extends StatelessWidget {
  const EtiquetaDaMeta({super.key, required this.situacao});

  final SituacaoMeta situacao;

  @override
  Widget build(BuildContext context) => Etiqueta(
    texto: situacao.rotulo,
    icone: switch (situacao) {
      SituacaoMeta.ativa => Icons.trending_up,
      SituacaoMeta.alcancada => Icons.emoji_events_outlined,
      SituacaoMeta.interrompida => Icons.pause_circle_outline,
      SituacaoMeta.substituida => Icons.swap_horiz,
    },
    cores: switch (situacao) {
      SituacaoMeta.ativa => const ParDeCores(
        CoresTerae.primaria700,
        CoresTerae.primaria50,
      ),
      SituacaoMeta.alcancada => const ParDeCores(
        CoresTerae.clinico700,
        CoresTerae.clinico50,
      ),
      SituacaoMeta.interrompida || SituacaoMeta.substituida => const ParDeCores(
        CoresTerae.neutro700,
        CoresTerae.neutro100,
      ),
    },
  );
}

/// "Prazo: 30/11/2026", só para a meta em andamento.
String? textoDoPrazo(MetaTerapeutica meta) =>
    meta.situacao == SituacaoMeta.ativa
    ? 'Prazo: ${formatarDataCivil(meta.prazo)}'
    : null;

/// "Esta atividade ajuda na meta: …" (TM17; F3): o cartão abre a TM20.
class CartaoDaMetaLigada extends StatelessWidget {
  const CartaoDaMetaLigada({super.key, required this.meta, this.aoVoltar});

  final MetaTerapeutica meta;

  /// Chamado quando a TM20 desempilha. Pela TM20 dá para abrir a mesma
  /// atividade numa TM17 por cima e registrar; a de baixo precisa reler.
  final Future<void> Function()? aoVoltar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: const Key('meta-da-atividade'),
      aoTocar: () async {
        await context.push<void>(Rotas.meta(meta.id));
        await aoVoltar?.call();
      },
      corBorda: CoresTerae.primaria100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao(
            'Esta atividade ajuda na meta',
            icone: Icons.track_changes,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Row(
            children: [
              Expanded(child: Text(meta.descricao, style: textos.titleMedium)),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Align(
            alignment: Alignment.centerLeft,
            child: EtiquetaDaMeta(situacao: meta.situacao),
          ),
        ],
      ),
    );
  }
}
