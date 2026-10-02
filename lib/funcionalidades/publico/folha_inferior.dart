import 'package:flutter/material.dart';

import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';

/// Folha inferior das telas de entrada (TM00, TM01, TM09, TM10): título como
/// cabeçalho, botão "Fechar" com rótulo e conteúdo que rola quando a fonte do
/// aparelho está grande (RNFM01). Devolve o que a folha passar ao `pop`.
Future<T?> mostrarFolha<T>({
  required BuildContext context,
  required String titulo,
  required WidgetBuilder construtor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CoresTerae.superficieElevada,
    builder: (folha) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        MedidasTerae.margemLateral,
        MedidasTerae.espacoPequeno,
        MedidasTerae.margemLateral,
        MedidasTerae.espacoGrande,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    style: Theme.of(folha).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(folha).pop(),
              ),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          construtor(folha),
        ],
      ),
    ),
  );
}
