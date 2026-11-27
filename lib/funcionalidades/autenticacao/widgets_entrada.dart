import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
          color: CoresTerae.erroFundo,
          borderRadius: const BorderRadius.all(
            Radius.circular(MedidasTerae.raioBotao),
          ),
          border: Border.all(color: CoresTerae.erroBorda),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.circleAlert, color: CoresTerae.erro),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagem,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CoresTerae.erro,
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

/// Campo de senha com "mostrar/ocultar" (D14; TM01, TM09, TM10). O texto
/// digitado nunca sai do campo a não ser para o repositório (RNFM04).
class CampoDeSenha extends StatefulWidget {
  const CampoDeSenha({
    super.key,
    required this.controlador,
    required this.rotulo,
    this.erro,
    this.ajuda,
    this.novaSenha = false,
    this.acao = TextInputAction.next,
    this.aoConcluir,
  });

  final TextEditingController controlador;
  final String rotulo;
  final String? erro;
  final String? ajuda;

  /// Senha nova (cadastro) ou a de quem entra (TM01): muda o preenchimento
  /// automático sugerido ao gerenciador de senhas do aparelho.
  final bool novaSenha;
  final TextInputAction acao;
  final VoidCallback? aoConcluir;

  @override
  State<CampoDeSenha> createState() => _CampoDeSenhaState();
}

class _CampoDeSenhaState extends State<CampoDeSenha> {
  bool _visivel = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controlador,
      obscureText: !_visivel,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.acao,
      autofillHints: [
        widget.novaSenha ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onSubmitted: widget.aoConcluir == null
          ? null
          : (_) => widget.aoConcluir!(),
      decoration: InputDecoration(
        labelText: widget.rotulo,
        helperText: widget.ajuda,
        errorText: widget.erro,
        suffixIcon: IconButton(
          tooltip: _visivel ? 'Ocultar senha' : 'Mostrar senha',
          icon: Icon(_visivel ? LucideIcons.eyeOff : LucideIcons.eye),
          onPressed: () => setState(() => _visivel = !_visivel),
        ),
      ),
    );
  }
}

/// Campo de e-mail (D14; TM01, TM09, TM10).
class CampoDeEmail extends StatelessWidget {
  const CampoDeEmail({
    super.key,
    required this.controlador,
    this.erro,
    this.rotulo = 'E-mail',
  });

  final TextEditingController controlador;
  final String? erro;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: 'nome@exemplo.com',
        errorText: erro,
      ),
    );
  }
}
