import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../dados/enums/ocupacao.dart';
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

/// "Nossas metas" (F3; D25): por área da vida, cada meta com a situação e, se
/// em andamento, o prazo. Tocar abre a TM20. Nada de escore.
class NossasMetas extends StatelessWidget {
  const NossasMetas({super.key, required this.grupos, this.aoAbrirMeta});

  final Map<Ocupacao, List<MetaTerapeutica>> grupos;

  /// Abre a TM20; sem ele, empilha a meta sem esperar a volta.
  final Future<void> Function(String metaId)? aoAbrirMeta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final secundario = textos.bodySmall?.copyWith(
      color: CoresTerae.textoSecundario,
    );
    return Column(
      key: const Key('nossas-metas'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloDeSecao('Nossas metas', icone: LucideIcons.target),
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Text(
          'Combinadas com a terapia. Toque numa meta para ver o que ajuda em '
          'casa.',
          style: secundario,
        ),
        for (final MapEntry(key: ocupacao, value: metas) in grupos.entries) ...[
          const SizedBox(height: MedidasTerae.espaco),
          Semantics(
            header: true,
            child: Text(
              ocupacao.rotulo,
              style: textos.titleSmall?.copyWith(color: CoresTerae.neutro700),
            ),
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          for (final m in metas) ...[
            Cartao(
              key: Key('meta-${m.id}'),
              aoTocar: () => aoAbrirMeta == null
                  ? context.push(Rotas.meta(m.id))
                  : aoAbrirMeta!(m.id),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.descricao, style: textos.titleSmall),
                        const SizedBox(height: MedidasTerae.espacoPequeno),
                        Wrap(
                          spacing: MedidasTerae.espacoPequeno,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            EtiquetaDaMeta(situacao: m.situacao),
                            if (textoDoPrazo(m) case final prazo?)
                              Text(prazo, style: secundario),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(
                    child: Icon(LucideIcons.chevronRight, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
          ],
        ],
      ],
    );
  }
}
