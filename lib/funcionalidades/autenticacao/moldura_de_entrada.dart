import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/widgets/selo_academico.dart';

/// A moldura das telas sem sessão, como a do portal da família
/// (`apps/portal/src/componentes/MolduraDeEntrada.tsx`, quadros 18a e 18c):
/// no telefone, a faixa marinho com a marca e a ajuda imediata; embaixo, o
/// fundo branco com a etapa, o título (`h1` 26), a descrição e o formulário,
/// numa coluna de no máximo 420. O selo acadêmico fecha a tela (D1b).
///
/// [chaveDaTela] vai no Scaffold (contrato dos testes). Com [aoVoltar], a
/// seta da faixa chama ele; sem, a seta só aparece quando há o que
/// desempilhar.
class MolduraDeEntrada extends StatelessWidget {
  const MolduraDeEntrada({
    super.key,
    required this.chaveDaTela,
    required this.titulo,
    required this.children,
    this.descricao,
    this.etapa,
    this.selo,
    this.aoVoltar,
  });

  final Key chaveDaTela;
  final String titulo;
  final String? descricao;
  final EtapaDaEntrada? etapa;

  /// O círculo com o ícone entre a etapa e o título (o "Pronto" do 18c).
  final Widget? selo;
  final VoidCallback? aoVoltar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final descricao = this.descricao;
    final etapa = this.etapa;
    final selo = this.selo;
    final aoVoltar = this.aoVoltar;
    final podeVoltar = aoVoltar != null || Navigator.of(context).canPop();
    return Scaffold(
      key: chaveDaTela,
      backgroundColor: CoresTerae.branco,
      appBar: AppBar(
        backgroundColor: CoresTerae.marinho900,
        foregroundColor: CoresTerae.branco,
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        titleSpacing: podeVoltar ? 0 : 16,
        leading: podeVoltar
            ? BackButton(
                color: CoresTerae.branco,
                onPressed: aoVoltar ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const MarcaDoPortal(),
        actions: const [LinkDaAjuda(), SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (etapa != null) ...[
                    IndicadorDeEtapa(etapa: etapa),
                    const SizedBox(height: 10),
                  ],
                  if (selo != null) ...[selo, const SizedBox(height: 10)],
                  Semantics(
                    header: true,
                    child: Text(titulo, style: textos.headlineSmall),
                  ),
                  if (descricao != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      descricao,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: CoresTerae.neutro600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                  const SizedBox(height: 32),
                  const Center(child: SeloAcademico()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A etapa de um fluxo em etapas ("Etapa 1 de 3 · Confirmação").
@immutable
class EtapaDaEntrada {
  const EtapaDaEntrada({required this.atual, required this.total, this.rotulo});

  final int atual;
  final int total;
  final String? rotulo;
}

/// O `IndicadorDeEtapa` do `@terae/ui`: um traço por etapa (feita em
/// turquesa, atual em azul) e "Etapa X de N · rótulo", lido como uma frase.
class IndicadorDeEtapa extends StatelessWidget {
  const IndicadorDeEtapa({super.key, required this.etapa});

  final EtapaDaEntrada etapa;

  @override
  Widget build(BuildContext context) {
    final rotulo = etapa.rotulo;
    final texto =
        'Etapa ${etapa.atual} de ${etapa.total}'
        '${rotulo == null ? '' : ' · $rotulo'}';
    return Semantics(
      container: true,
      label: texto,
      excludeSemantics: true,
      child: Row(
        children: [
          for (var n = 1; n <= etapa.total; n++) ...[
            if (n > 1) const SizedBox(width: 4),
            Container(
              width: 24,
              height: 4,
              decoration: BoxDecoration(
                color: n < etapa.atual
                    ? CoresTerae.clinico500
                    : n == etapa.atual
                    ? CoresTerae.primaria600
                    : CoresTerae.neutro200,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CoresTerae.neutro500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A marca na faixa marinho: o símbolo, "Terae" e "Portal da família".
class MarcaDoPortal extends StatelessWidget {
  const MarcaDoPortal({super.key, this.grande = false});

  final bool grande;

  @override
  Widget build(BuildContext context) {
    final lado = grande ? 44.0 : 32.0;
    return Semantics(
      label: 'Terae, portal da família',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: lado,
            height: lado,
            decoration: BoxDecoration(
              color: CoresTerae.branco.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(lado / 4),
            ),
            child: Icon(
              LucideIcons.heartPulse,
              size: lado * 0.6,
              color: CoresTerae.clinico300,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terae',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: grande ? 26 : 19,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: CoresTerae.branco,
                  ),
                ),
                Text(
                  'Portal da família',
                  style: TextStyle(
                    fontSize: grande ? 15 : 14,
                    height: 1.2,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                    color: CoresTerae.marinho200,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ajuda imediata" na faixa marinho (`LinkDaAjuda` do portal): abre a TM05
/// sem registro, sem conta e sem internet.
class LinkDaAjuda extends StatelessWidget {
  const LinkDaAjuda({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('entrada-ajuda'),
      onPressed: () => context.push(Rotas.ajuda),
      style: TextButton.styleFrom(foregroundColor: CoresTerae.branco),
      icon: const Icon(LucideIcons.lifeBuoy, size: 20),
      label: const Text('Ajuda'),
    );
  }
}
