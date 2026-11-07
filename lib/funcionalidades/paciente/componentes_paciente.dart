import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';

/// Peças de layout repetidas nas telas do paciente (TM02–TM07), sobre o tema
/// e os widgets do `nucleo` (RNFM01: linguagem simples, texto ≥ 14).

/// Corpo rolável padrão de uma aba: margens do Terae e conteúdo em coluna.
///
/// `SingleChildScrollView` + `Column` (e não `ListView`) de propósito: as
/// telas são curtas e tudo fica montado, o que deixa o teste de estouro com
/// fonte grande enxergar a tela inteira.
///
/// Com [aoAtualizar], ganha o "puxar para atualizar" (F1, TM16): a rolagem
/// passa a aceitar o gesto mesmo quando o conteúdo cabe na tela.
class CorpoDaTela extends StatelessWidget {
  const CorpoDaTela({super.key, required this.children, this.aoAtualizar});

  final List<Widget> children;
  final Future<void> Function()? aoAtualizar;

  @override
  Widget build(BuildContext context) {
    final aoAtualizar = this.aoAtualizar;
    final rolagem = SingleChildScrollView(
      physics: aoAtualizar == null
          ? null
          : const AlwaysScrollableScrollPhysics(),
      padding: MedidasTerae.paddingTela,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return SafeArea(
      child: aoAtualizar == null
          ? rolagem
          : RefreshIndicator(onRefresh: aoAtualizar, child: rolagem),
    );
  }
}

/// Chama [aoVoltar] quando a rota [rota] volta a ser a atual (F1): a aba
/// Início continua montada no `StatefulShellRoute` e precisa refazer o
/// resumo das atividades de casa depois que a pessoa registra na TM17.
class RecarregaAoVoltar extends StatefulWidget {
  const RecarregaAoVoltar({
    super.key,
    required this.rota,
    required this.aoVoltar,
    required this.child,
  });

  final String rota;
  final VoidCallback aoVoltar;
  final Widget child;

  @override
  State<RecarregaAoVoltar> createState() => _RecarregaAoVoltarState();
}

class _RecarregaAoVoltarState extends State<RecarregaAoVoltar> {
  GoRouterDelegate? _delegado;
  bool _naRota = true;

  String? get _local => _delegado?.currentConfiguration.uri.path;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegado = GoRouter.maybeOf(context)?.routerDelegate;
    if (identical(delegado, _delegado)) return;
    _delegado?.removeListener(_aoMudarRota);
    _delegado = delegado;
    _naRota = _local == widget.rota;
    delegado?.addListener(_aoMudarRota);
  }

  void _aoMudarRota() {
    final agora = _local == widget.rota;
    if (agora && !_naRota) widget.aoVoltar();
    _naRota = agora;
  }

  @override
  void dispose() {
    _delegado?.removeListener(_aoMudarRota);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Título da tela (cabeçalho para leitor de tela) e a frase de apoio.
class CabecalhoDaTela extends StatelessWidget {
  const CabecalhoDaTela({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acao,
  });

  final String titulo;
  final String? subtitulo;

  /// Botão no canto (ex.: menu da TM02).
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final titulo = Semantics(
      header: true,
      child: Text(this.titulo, style: textos.headlineMedium),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (acao == null)
          titulo
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titulo),
              const SizedBox(width: MedidasTerae.espacoPequeno),
              acao!,
            ],
          ),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitulo!,
            style: textos.bodyMedium?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

/// Rótulo de seção em caixa alta ("O QUE VEM POR AÍ"), marcado como
/// cabeçalho.
class RotuloDeSecao extends StatelessWidget {
  const RotuloDeSecao(
    this.texto, {
    super.key,
    this.cor = CoresTerae.primaria700,
    this.icone,
  });

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final rotulo = Text(
      texto.toUpperCase(),
      style: TextStyle(
        fontSize: MedidasTerae.textoMinimo,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: cor,
      ),
    );
    return Semantics(
      header: true,
      label: texto,
      excludeSemantics: true,
      child: icone == null
          ? rotulo
          : Row(
              children: [
                Icon(icone, size: 18, color: cor),
                const SizedBox(width: 6),
                Flexible(child: rotulo),
              ],
            ),
    );
  }
}

/// Etiqueta arredondada com texto (nunca só cor).
class Etiqueta extends StatelessWidget {
  const Etiqueta({
    super.key,
    required this.texto,
    this.cores = const ParDeCores(
      CoresTerae.primaria700,
      CoresTerae.primaria50,
    ),
    this.icone,
  });

  final String texto;
  final ParDeCores cores;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cores.fundo,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: cores.texto.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              ExcludeSemantics(
                child: Icon(icone, size: 16, color: cores.texto),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: MedidasTerae.textoMinimo,
                  fontWeight: FontWeight.w600,
                  color: cores.texto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enquanto carrega: indicador com rótulo para o leitor de tela.
class Carregando extends StatelessWidget {
  const Carregando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: MedidasTerae.espacoGrande),
      child: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
      ),
    );
  }
}

/// Falha ao carregar, em linguagem simples, com "Tentar de novo".
class AvisoDeFalha extends StatelessWidget {
  const AvisoDeFalha({
    super.key,
    required this.mensagem,
    required this.aoTentarDeNovo,
  });

  final String mensagem;
  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Cartaozinho(
      cores: const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
      icone: Icons.wifi_off,
      children: [
        Text(
          mensagem,
          style: const TextStyle(fontSize: 16, color: CoresTerae.aviso900),
        ),
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: aoTentarDeNovo,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ),
      ],
    );
  }
}

/// Caixa de aviso colorida (renovação, limite, recusa), com ícone e texto.
class Cartaozinho extends StatelessWidget {
  const Cartaozinho({
    super.key,
    required this.cores,
    required this.icone,
    required this.children,
  });

  final ParDeCores cores;
  final IconData icone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cores.fundo,
        borderRadius: const BorderRadius.all(
          Radius.circular(MedidasTerae.raioCartao),
        ),
        border: Border.all(color: cores.texto.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MedidasTerae.espaco),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icone, color: cores.texto, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
