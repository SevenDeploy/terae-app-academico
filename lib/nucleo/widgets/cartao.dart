import 'package:flutter/material.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

/// O cartão das telas do portal (`apps/portal/src/componentes/Cartao.tsx`):
/// branco, borda `slate-200`, cantos de 16 e só a sombra leve `shadow-card`.
///
/// [sobre] é o sobretítulo em caixa alta ("PRÓXIMA SESSÃO") e [titulo] a
/// frase principal em Lexend 18, com [icone] em azul. Com [aoTocar], o
/// cartão inteiro vira um botão (um único nó de acessibilidade com o texto de
/// dentro, ou [rotuloSemantico] se dado).
class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.child,
    this.aoTocar,
    this.sobre,
    this.titulo,
    this.icone,
    this.corBorda = CoresTerae.borda,
    this.corFundo = CoresTerae.superficieElevada,
    this.padding = const EdgeInsets.all(MedidasTerae.espacoCartao),
    this.rotuloSemantico,
  });

  final Widget child;
  final VoidCallback? aoTocar;
  final String? sobre;
  final String? titulo;
  final IconData? icone;
  final Color corBorda;
  final Color corFundo;
  final EdgeInsetsGeometry padding;
  final String? rotuloSemantico;

  /// `--shadow-card: 0 1px 2px rgb(13 21 32 / 0.04)`.
  static const List<BoxShadow> sombra = [
    BoxShadow(color: Color(0x0A0D1520), blurRadius: 2, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    const raio = BorderRadius.all(Radius.circular(MedidasTerae.raioCartao));
    final sobre = this.sobre;
    final titulo = this.titulo;
    final Widget corpo = sobre == null && titulo == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sobre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    header: titulo == null,
                    child: Text(
                      sobre.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: CoresTerae.neutro600,
                      ),
                    ),
                  ),
                ),
              if (titulo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Semantics(
                    header: true,
                    child: Row(
                      children: [
                        if (icone != null) ...[
                          ExcludeSemantics(
                            child: Icon(
                              icone,
                              size: 20,
                              color: CoresTerae.primaria700,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            titulo,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              child,
            ],
          );
    final conteudo = Padding(padding: padding, child: corpo);
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

/// Tom do [Selo], como `TomDoSelo` do portal.
enum TomDoSelo { sucesso, atencao, info, neutro, erro }

/// O selo de estado do portal: pílula com ícone e texto, nunca só a cor
/// ("Aguardando a terapeuta", "Presença confirmada", "Revisado").
class Selo extends StatelessWidget {
  const Selo({
    super.key,
    required this.texto,
    required this.tom,
    required this.icone,
  });

  final String texto;
  final TomDoSelo tom;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final (cor, fundo, borda) = switch (tom) {
      TomDoSelo.sucesso => (
        CoresTerae.sucesso,
        CoresTerae.sucessoFundo,
        CoresTerae.sucessoBorda,
      ),
      TomDoSelo.atencao => (
        CoresTerae.atencao,
        CoresTerae.atencaoFundo,
        CoresTerae.atencaoBorda,
      ),
      TomDoSelo.info => (
        CoresTerae.info,
        CoresTerae.infoFundo,
        CoresTerae.infoBorda,
      ),
      TomDoSelo.erro => (
        CoresTerae.erro,
        CoresTerae.erroFundo,
        CoresTerae.erroBorda,
      ),
      TomDoSelo.neutro => (
        CoresTerae.neutro700,
        CoresTerae.neutro100,
        CoresTerae.borda,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: borda),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icone, size: 16, color: cor)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O estado vazio do portal (`EmptyState` do `@terae/ui`): ícone num círculo,
/// título e uma frase de apoio, com ação opcional.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.descricao,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String? descricao;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final descricao = this.descricao;
    final acao = this.acao;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: CoresTerae.neutro100,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(icone, size: 24, color: CoresTerae.neutro600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (descricao != null) ...[
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: CoresTerae.neutro600),
            ),
          ],
          if (acao != null) ...[const SizedBox(height: 16), acao],
        ],
      ),
    );
  }
}
