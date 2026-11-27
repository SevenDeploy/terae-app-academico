import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import 'entrar_controlador.dart';
import 'moldura_de_entrada.dart';
import 'widgets_entrada.dart';

/// Etapa 2 da entrada na fonte Terae local, com os textos do
/// "Digite o código do e-mail" do portal da família (`Entrar.tsx`, quadro
/// 18b): as 6 caixas do código, o e-mail mascarado, "Enviar um código novo"
/// depois de 60 s e "Confiar neste aparelho por 30 dias", desmarcado.
class EtapaDoCodigo extends StatefulWidget {
  const EtapaDoCodigo({super.key, required this.etapa});

  final CodigoDeAcessoPedido etapa;

  @override
  State<EtapaDoCodigo> createState() => _EtapaDoCodigoState();
}

class _EtapaDoCodigoState extends State<EtapaDoCodigo> {
  final _codigo = TextEditingController();
  bool _confiar = false;
  Timer? _contagem;

  @override
  void initState() {
    super.initState();
    _codigo.addListener(_aoDigitar);
    _contar();
  }

  @override
  void didUpdateWidget(EtapaDoCodigo antes) {
    super.didUpdateWidget(antes);
    if (!identical(antes.etapa, widget.etapa)) {
      _codigo.clear();
      _contar();
    }
  }

  @override
  void dispose() {
    _contagem?.cancel();
    _codigo
      ..removeListener(_aoDigitar)
      ..dispose();
    super.dispose();
  }

  void _aoDigitar() => setState(() {});

  /// Atualiza "Reenviar o código em m:ss" a cada segundo, e para quando o
  /// botão libera.
  void _contar() {
    _contagem?.cancel();
    _contagem = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final c = context.read<EntrarControlador>();
      if (c.paraReenviar == Duration.zero) timer.cancel();
      setState(() {});
    });
  }

  Future<void> _entrar() => context.read<EntrarControlador>().confirmarCodigo(
    _codigo.text,
    confiarNesteAparelho: _confiar,
  );

  Future<void> _reenviar() async {
    _codigo.clear();
    await context.read<EntrarControlador>().reenviarCodigo();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EntrarControlador>();
    final etapa = widget.etapa;
    final paraReenviar = c.paraReenviar;
    final reenvio = BotaoGrande(
      key: const Key('reenviar-codigo'),
      rotulo: paraReenviar > Duration.zero
          ? 'Reenviar o código em ${formatarRestante(paraReenviar)}'
          : 'Enviar um código novo',
      icone: paraReenviar > Duration.zero
          ? LucideIcons.timer
          : LucideIcons.mail,
      variante: VarianteBotao.secundario,
      aoTocar: paraReenviar > Duration.zero || c.ocupado
          ? null
          : () => unawaited(_reenviar()),
    );
    final voltar = TextButton(
      key: const Key('voltar-para-a-senha'),
      onPressed: c.voltarParaASenha,
      child: const Text('Voltar para a entrada'),
    );

    if (!etapa.codigoEnviado) {
      return MolduraDeEntrada(
        chaveDaTela: const Key('TM01-codigo'),
        titulo: 'Não conseguimos enviar o código agora',
        etapa: const EtapaDaEntrada(atual: 2, total: 2),
        aoVoltar: c.voltarParaASenha,
        children: [
          const AvisoDeRecusa(
            'Tente de novo mais tarde. Num aparelho que você já marcou como '
            'confiável, a entrada não pede código.',
          ),
          const SizedBox(height: MedidasTerae.espacoCartao),
          reenvio,
          const SizedBox(height: MedidasTerae.espacoPequeno),
          voltar,
        ],
      );
    }

    final mensagem = c.mensagem;
    final erro = c.erroDoCodigo;
    final completo = _codigo.text.length == 6;
    return MolduraDeEntrada(
      chaveDaTela: const Key('TM01-codigo'),
      titulo: 'Digite o código do e-mail',
      descricao:
          'Enviamos um código de 6 dígitos para ${etapa.emailMascarado}.',
      etapa: const EtapaDaEntrada(atual: 2, total: 2),
      aoVoltar: c.voltarParaASenha,
      children: [
        if (c.reenviado && !c.codigoVencido && erro == null) ...[
          const CaixaInformativa(
            key: Key('codigo-reenviado'),
            icone: LucideIcons.mailCheck,
            texto: 'Enviamos um código novo. O anterior deixou de valer.',
          ),
          const SizedBox(height: MedidasTerae.espacoCartao),
        ],
        if (c.codigoVencido)
          const AvisoDeRecusa(
            'Este código venceu. Cada código vale 10 minutos.',
            key: Key('codigo-vencido'),
          )
        else ...[
          if (mensagem != null) ...[
            AvisoDeRecusa(mensagem),
            const SizedBox(height: MedidasTerae.espacoCartao),
          ],
          CampoDeCodigo(
            controlador: _codigo,
            erro: erro,
            aoConcluir: completo && !c.ocupado
                ? () => unawaited(_entrar())
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vale 10 minutos e serve uma vez só. Colar o código preenche as '
            'seis caixas.',
            style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
          ),
          const SizedBox(height: MedidasTerae.espacoCartao),
          CheckboxListTile(
            key: const Key('confiar-neste-aparelho'),
            value: _confiar,
            onChanged: (marcado) => setState(() => _confiar = marcado ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Confiar neste aparelho por 30 dias',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: const Text(
              'Aqui, a entrada não vai pedir o código por 30 dias. Não marque '
              'em aparelho de outra pessoa ou de uso coletivo.',
            ),
          ),
          const SizedBox(height: MedidasTerae.espacoCartao),
          if (c.ocupado) ...[
            const LinearProgressIndicator(semanticsLabel: 'Entrando'),
            const SizedBox(height: MedidasTerae.espaco),
          ],
          BotaoGrande(
            key: const Key('entrar-com-codigo'),
            rotulo: c.ocupado ? 'Entrando…' : 'Entrar',
            icone: LucideIcons.logIn,
            aoTocar: completo && !c.ocupado ? () => unawaited(_entrar()) : null,
          ),
        ],
        const SizedBox(height: 12),
        reenvio,
        const SizedBox(height: MedidasTerae.espacoPequeno),
        const CaixaInformativa(
          icone: LucideIcons.info,
          corIcone: CoresTerae.neutro600,
          texto:
              'Não chegou? Confira a caixa de spam ou peça outro código quando '
              'o botão liberar.',
        ),
        const SizedBox(height: MedidasTerae.espacoPequeno),
        voltar,
      ],
    );
  }
}

/// `m:ss` do que falta (portal: `formatarRestante`).
String formatarRestante(Duration restante) {
  final segundos = (restante.inMilliseconds / 1000).ceil();
  return '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';
}

/// As seis caixas do código (`CampoDeCodigo` do portal): um só campo de
/// texto, invisível, por cima das caixas — digitar, apagar e colar valem
/// para as seis de uma vez, e o leitor de tela lê "Código".
class CampoDeCodigo extends StatelessWidget {
  const CampoDeCodigo({
    super.key,
    required this.controlador,
    this.erro,
    this.aoConcluir,
  });

  final TextEditingController controlador;
  final String? erro;
  final VoidCallback? aoConcluir;

  @override
  Widget build(BuildContext context) {
    final erro = this.erro;
    final texto = controlador.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Código',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CoresTerae.texto,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Caixa(
                          digito: i < texto.length ? texto[i] : '',
                          atual: i == texto.length,
                          comErro: erro != null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: TextField(
                  key: const Key('campo-codigo'),
                  controller: controlador,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: true,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    labelStyle: TextStyle(color: Colors.transparent),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => aoConcluir?.call(),
                ),
              ),
            ],
          ),
        ),
        if (erro != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              erro,
              key: const Key('erro-codigo'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CoresTerae.erro,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({
    required this.digito,
    required this.atual,
    required this.comErro,
  });

  final String digito;
  final bool atual;
  final bool comErro;

  @override
  Widget build(BuildContext context) {
    final borda = comErro
        ? CoresTerae.erro
        : atual
        ? CoresTerae.primaria700
        : CoresTerae.borda;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoresTerae.branco,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: borda, width: atual || comErro ? 2 : 1),
      ),
      child: Center(
        child: Text(
          digito,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: CoresTerae.texto,
          ),
        ),
      ),
    );
  }
}
