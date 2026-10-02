import 'package:flutter/material.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

enum VarianteBotao {
  /// Ação principal da tela (azul).
  primario,

  /// Ação secundária (contorno).
  secundario,

  /// Emergência ou ação que remove acesso (vermelho).
  perigo,
}

/// Botão de largura total, 56 de altura, texto 18 (RNFM01: botões grandes).
///
/// `aoTocar: null` desabilita. O rótulo quebra linha em vez de cortar quando
/// a fonte do aparelho está grande.
class BotaoGrande extends StatelessWidget {
  const BotaoGrande({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.icone,
    this.variante = VarianteBotao.primario,
    this.larguraTotal = true,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final VarianteBotao variante;
  final bool larguraTotal;

  static const TextStyle _texto = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  @override
  Widget build(BuildContext context) {
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icone != null) ...[
          Icon(icone, size: 24),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(rotulo, textAlign: TextAlign.center)),
      ],
    );
    const tamanho = Size(
      MedidasTerae.alturaBotaoGrande,
      MedidasTerae.alturaBotaoGrande,
    );
    final Widget botao = switch (variante) {
      VarianteBotao.primario => FilledButton(
        onPressed: aoTocar,
        style: FilledButton.styleFrom(minimumSize: tamanho, textStyle: _texto),
        child: conteudo,
      ),
      VarianteBotao.secundario => OutlinedButton(
        onPressed: aoTocar,
        style: OutlinedButton.styleFrom(
          minimumSize: tamanho,
          textStyle: _texto,
        ),
        child: conteudo,
      ),
      VarianteBotao.perigo => FilledButton(
        onPressed: aoTocar,
        style: FilledButton.styleFrom(
          minimumSize: tamanho,
          textStyle: _texto,
          backgroundColor: CoresTerae.sevCritica,
          foregroundColor: CoresTerae.branco,
        ),
        child: conteudo,
      ),
    };
    return larguraTotal
        ? SizedBox(width: double.infinity, child: botao)
        : botao;
  }
}
