import 'package:flutter/material.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

/// Cartão branco com borda, raio 16 e a sombra `shadow-card` do Terae.
///
/// Com [aoTocar], o cartão inteiro vira um botão (um único nó de
/// acessibilidade com o texto de dentro, ou [rotuloSemantico] se dado).
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.child,
    this.aoTocar,
    this.corBorda = CoresTerae.borda,
    this.corFundo = CoresTerae.superficieElevada,
    this.padding = const EdgeInsets.all(MedidasTerae.espaco),
    this.rotuloSemantico,
  });

  final Widget child;
  final VoidCallback? aoTocar;
  final Color corBorda;
  final Color corFundo;
  final EdgeInsetsGeometry padding;
  final String? rotuloSemantico;

  static const List<BoxShadow> sombra = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  @override
  Widget build(BuildContext context) {
    const raio = BorderRadius.all(Radius.circular(MedidasTerae.raioCartao));
    final conteudo = Padding(padding: padding, child: child);
    Widget superficie = Material(
      color: corFundo,
      shape: RoundedRectangleBorder(
        borderRadius: raio,
        side: BorderSide(color: corBorda),
      ),
      clipBehavior: Clip.antiAlias,
      child: aoTocar == null
          ? conteudo
          : InkWell(onTap: aoTocar, child: conteudo),
    );
    if (aoTocar != null) {
      superficie = MergeSemantics(
        child: Semantics(
          button: true,
          label: rotuloSemantico,
          child: superficie,
        ),
      );
    }
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: raio, boxShadow: sombra),
      child: superficie,
    );
  }
}
