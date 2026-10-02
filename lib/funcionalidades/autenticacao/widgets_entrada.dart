import 'package:flutter/material.dart';

import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';

/// Recusa de regra em linguagem simples (RNFM01), anunciada pelo leitor de
/// tela assim que aparece (região viva). Não depende só da cor: tem ícone.
class AvisoDeRecusa extends StatelessWidget {
  const AvisoDeRecusa(this.mensagem, {super.key});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const Key('aviso-recusa'),
        decoration: BoxDecoration(
          color: CoresTerae.negativo50,
          borderRadius: const BorderRadius.all(
            Radius.circular(MedidasTerae.raioBotao),
          ),
          border: Border.all(color: CoresTerae.negativo700),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: CoresTerae.negativo700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagem,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CoresTerae.negativo700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caixa neutra com ícone e texto (avisos que não são erro).
class CaixaInformativa extends StatelessWidget {
  const CaixaInformativa({
    super.key,
    required this.icone,
    required this.texto,
    this.corIcone = CoresTerae.primaria700,
  });

  final IconData icone;
  final String texto;
  final Color corIcone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoresTerae.neutro50,
        borderRadius: const BorderRadius.all(
          Radius.circular(MedidasTerae.raioBotao),
        ),
        border: Border.all(color: CoresTerae.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icone, color: corIcone)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: CoresTerae.neutro700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
