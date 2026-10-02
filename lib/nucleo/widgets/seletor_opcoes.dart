import 'package:flutter/material.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

/// Uma opção do [SeletorOpcoes].
@immutable
class OpcaoSeletor<T> {
  const OpcaoSeletor({
    required this.valor,
    required this.rotulo,
    this.icone,
    this.cores,
    this.habilitada = true,
  });

  final T valor;
  final String rotulo;
  final IconData? icone;

  /// Cores quando selecionada; sem elas, azul (primaria700/primaria50).
  final ParDeCores? cores;

  /// `false`: a opção aparece esmaecida, não responde ao toque e o leitor de
  /// tela a anuncia como desativada (TM09: criança não é titular). A tela
  /// explica o porquê ao lado.
  final bool habilitada;
}

/// Grupo de botões grandes de escolha única — adesão (3) e intensidade (4) da
/// TM03 (RFM03, RNFM01, RNFM02: escolher em vez de digitar).
///
/// Acessibilidade (D10, falha do protótipo): o [rotulo] é o nome do grupo;
/// cada opção é um nó só, `button`, `inMutuallyExclusiveGroup` e `selected`
/// conforme o [valor]; a selecionada também tem marca de verificação (não
/// depende só da cor) e o foco de teclado desenha contorno de 3 px. Cada opção
/// tem pelo menos 64 de altura.
class SeletorOpcoes<T> extends StatelessWidget {
  const SeletorOpcoes({
    super.key,
    required this.rotulo,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
    this.colunas = 3,
    this.mostrarRotulo = true,
  });

  /// A pergunta (ex.: "E os seus remédios de hoje?").
  final String rotulo;
  final List<OpcaoSeletor<T>> opcoes;

  /// Opção marcada; `null` = nenhuma ainda.
  final T? valor;
  final ValueChanged<T> aoMudar;
  final int colunas;

  /// `false` quando a tela já mostra a pergunta como título.
  final bool mostrarRotulo;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    for (var i = 0; i < opcoes.length; i += colunas) {
      final fim = (i + colunas).clamp(0, opcoes.length);
      final daLinha = opcoes.sublist(i, fim);
      if (linhas.isNotEmpty) {
        linhas.add(const SizedBox(height: MedidasTerae.espacoPequeno));
      }
      linhas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < colunas; j++) ...[
                if (j > 0) const SizedBox(width: MedidasTerae.espacoPequeno),
                Expanded(
                  child: j < daLinha.length
                      ? _BotaoOpcao<T>(
                          opcao: daLinha[j],
                          selecionada: daLinha[j].valor == valor,
                          aoTocar: daLinha[j].habilitada
                              ? () => aoMudar(daLinha[j].valor)
                              : null,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: rotulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mostrarRotulo) ...[
            ExcludeSemantics(
              child: Text(
                rotulo,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: CoresTerae.neutro700),
              ),
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
          ],
          ...linhas,
        ],
      ),
    );
  }
}

class _BotaoOpcao<T> extends StatefulWidget {
  const _BotaoOpcao({
    super.key,
    required this.opcao,
    required this.selecionada,
    required this.aoTocar,
  });

  final OpcaoSeletor<T> opcao;
  final bool selecionada;

  /// `null` = opção desativada.
  final VoidCallback? aoTocar;

  @override
  State<_BotaoOpcao<T>> createState() => _BotaoOpcaoState<T>();
}

class _BotaoOpcaoState<T> extends State<_BotaoOpcao<T>> {
  bool _focada = false;

  @override
  Widget build(BuildContext context) {
    final cores =
        widget.opcao.cores ??
        const ParDeCores(CoresTerae.primaria700, CoresTerae.primaria50);
    final sel = widget.selecionada;
    final habilitada = widget.aoTocar != null;
    final corTexto = sel
        ? cores.texto
        : habilitada
        ? CoresTerae.neutro700
        : CoresTerae.neutro600;
    final BorderSide borda;
    if (_focada) {
      borda = const BorderSide(
        color: CoresTerae.foco,
        width: MedidasTerae.larguraFoco,
      );
    } else {
      borda = BorderSide(color: sel ? cores.texto : CoresTerae.borda, width: 2);
    }
    const raio = BorderRadius.all(Radius.circular(MedidasTerae.raioBotao));
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: sel,
        enabled: habilitada,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: sel
              ? cores.fundo
              : habilitada
              ? CoresTerae.branco
              : CoresTerae.neutro100,
          shape: RoundedRectangleBorder(borderRadius: raio, side: borda),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.aoTocar,
            onFocusChange: (focada) => setState(() => _focada = focada),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: MedidasTerae.alturaMinimaSeletor,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.opcao.icone != null) ...[
                            Icon(widget.opcao.icone, size: 26, color: corTexto),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            widget.opcao.rotulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: corTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (sel)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: cores.texto,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
