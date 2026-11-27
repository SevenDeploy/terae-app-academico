import 'package:flutter/material.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

/// Uma opção do [GrupoDeCartoes]: título e, se houver, a frase que explica.
@immutable
class OpcaoDeCartao<T> {
  const OpcaoDeCartao({
    required this.valor,
    required this.titulo,
    this.descricao,
  });

  final T valor;
  final String titulo;
  final String? descricao;
}

/// Os cartões de escolha única do portal (`CartaoDeOpcao` do `@terae/ui`,
/// quadros 18e e 18f): um cartão por linha, com o círculo de rádio, o título
/// e a descrição. Usado na adesão, no "O quanto isso atrapalhou o dia?" e no
/// motivo de retirar (P3).
///
/// Acessibilidade: a [pergunta] é o nome do grupo (e o título visível, a
/// menos que [mostrarPergunta] seja falso); cada cartão é um nó só,
/// `inMutuallyExclusiveGroup` e `checked` conforme o [valor], com alvo de
/// toque de pelo menos 56 e contorno de foco de 3 px. A seleção também se vê
/// pelo círculo preenchido, não só pela cor.
class GrupoDeCartoes<T> extends StatelessWidget {
  const GrupoDeCartoes({
    super.key,
    required this.pergunta,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
    this.opcional = false,
    this.mostrarPergunta = true,
    this.erro,
    this.estiloDaPergunta,
  });

  final String pergunta;
  final List<OpcaoDeCartao<T>> opcoes;

  /// A opção marcada; `null` = nenhuma ainda.
  final T? valor;
  final ValueChanged<T> aoMudar;

  /// Mostra "(opcional)" depois da pergunta.
  final bool opcional;
  final bool mostrarPergunta;

  /// A mensagem do que falta, sob os cartões.
  final String? erro;
  final TextStyle? estiloDaPergunta;

  @override
  Widget build(BuildContext context) {
    final erro = this.erro;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: opcional ? '$pergunta (opcional)' : pergunta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mostrarPergunta) ...[
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  text: pergunta,
                  children: [
                    if (opcional)
                      const TextSpan(
                        text: ' (opcional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: CoresTerae.neutro600,
                        ),
                      ),
                  ],
                ),
                style:
                    estiloDaPergunta ??
                    const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: CoresTerae.neutro900,
                    ),
              ),
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
          ],
          for (final (i, opcao) in opcoes.indexed) ...[
            if (i > 0) const SizedBox(height: MedidasTerae.espacoPequeno),
            CartaoDeOpcao(
              key: ValueKey('opcao-${opcao.valor}'),
              titulo: opcao.titulo,
              descricao: opcao.descricao,
              selecionado: opcao.valor == valor,
              aoTocar: () => aoMudar(opcao.valor),
            ),
          ],
          if (erro != null) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Semantics(
              liveRegion: true,
              child: Text(
                erro,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CoresTerae.erro,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Um cartão de escolha: borda azul e fundo claro quando selecionado.
class CartaoDeOpcao extends StatefulWidget {
  const CartaoDeOpcao({
    super.key,
    required this.titulo,
    required this.selecionado,
    required this.aoTocar,
    this.descricao,
  });

  final String titulo;
  final String? descricao;
  final bool selecionado;
  final VoidCallback aoTocar;

  @override
  State<CartaoDeOpcao> createState() => _CartaoDeOpcaoState();
}

class _CartaoDeOpcaoState extends State<CartaoDeOpcao> {
  bool _focado = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selecionado;
    final descricao = widget.descricao;
    final borda = _focado
        ? const BorderSide(
            color: CoresTerae.foco,
            width: MedidasTerae.larguraFoco,
          )
        : BorderSide(
            color: sel ? CoresTerae.primaria600 : CoresTerae.borda,
            width: sel ? 2 : 1,
          );
    return MergeSemantics(
      child: Semantics(
        checked: sel,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: sel ? CoresTerae.primaria50 : CoresTerae.branco,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(MedidasTerae.raioCartao - 4),
            ),
            side: borda,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.aoTocar,
            onFocusChange: (focado) => setState(() => _focado = focado),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(child: _Radio(marcado: sel)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.titulo,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CoresTerae.neutro900,
                            ),
                          ),
                          if (descricao != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              descricao,
                              style: const TextStyle(
                                fontSize: 14,
                                color: CoresTerae.neutro600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.marcado});

  final bool marcado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CoresTerae.branco,
        border: Border.all(
          color: marcado ? CoresTerae.primaria600 : CoresTerae.bordaCampo,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: marcado
          ? const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CoresTerae.primaria600,
              ),
              child: SizedBox(width: 10, height: 10),
            )
          : null,
    );
  }
}
