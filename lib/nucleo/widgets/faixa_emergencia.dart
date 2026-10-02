import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../tema/cores.dart';
import '../tema/tema.dart';

/// Abre `tel:`, `mailto:` e `https:` fora do app (url_launcher). O `TeraeApp`
/// disponibiliza por provider; teste troca por um dublê que só anota a [Uri].
class LancadorExterno {
  const LancadorExterno();

  Future<bool> abrir(Uri uri) => launchUrl(uri);
}

/// Contato de emergência da faixa.
@immutable
class ContatoEmergencia {
  const ContatoEmergencia({
    required this.sigla,
    required this.numero,
    required this.descricao,
  });

  final String sigla;
  final String numero;
  final String descricao;

  Uri get uri => Uri(scheme: 'tel', path: numero);
}

/// CVV 188 e SAMU 192 com um toque, sem login (RFM10, §7.1; TM00 e TM05).
///
/// `destaque: false` (TM00): faixa vermelha compacta, fixa no rodapé.
/// `destaque: true` (TM05): dois cartões grandes, um por contato.
/// O lançador vem de [lancador] ou, sem ele, do provider de
/// [LancadorExterno]; sem nenhum dos dois, usa o url_launcher direto.
class FaixaEmergencia extends StatelessWidget {
  const FaixaEmergencia({super.key, this.destaque = false, this.lancador});

  final bool destaque;
  final LancadorExterno? lancador;

  static const ContatoEmergencia cvv = ContatoEmergencia(
    sigla: 'CVV',
    numero: '188',
    descricao: 'Apoio emocional, 24 horas, ligação gratuita',
  );

  static const ContatoEmergencia samu = ContatoEmergencia(
    sigla: 'SAMU',
    numero: '192',
    descricao: 'Atendimento médico de urgência',
  );

  static const List<ContatoEmergencia> contatos = [cvv, samu];

  LancadorExterno _lancador(BuildContext context) {
    if (lancador != null) return lancador!;
    try {
      return Provider.of<LancadorExterno>(context, listen: false);
    } on ProviderNotFoundException {
      return const LancadorExterno();
    }
  }

  Future<void> _ligar(BuildContext context, ContatoEmergencia contato) =>
      _lancador(context).abrir(contato.uri);

  @override
  Widget build(BuildContext context) {
    return destaque ? _cartoes(context) : _faixa(context);
  }

  Widget _faixa(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Ajuda em crise',
      child: Material(
        color: CoresTerae.sevCritica,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MedidasTerae.margemLateral,
              vertical: MedidasTerae.espacoPequeno,
            ),
            child: Row(
              children: [
                for (final contato in contatos) ...[
                  if (contato != contatos.first)
                    const SizedBox(width: MedidasTerae.espacoPequeno),
                  Expanded(
                    child: _Ligar(
                      key: Key('ligar-${contato.numero}'),
                      contato: contato,
                      aoTocar: () => _ligar(context, contato),
                      corFoco: CoresTerae.branco,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.phone,
                            color: CoresTerae.branco,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${contato.sigla} ${contato.numero}',
                              style: const TextStyle(
                                color: CoresTerae.branco,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cartoes(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final contato in contatos) ...[
          if (contato != contatos.first)
            const SizedBox(height: MedidasTerae.espaco),
          Material(
            color: CoresTerae.branco,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(MedidasTerae.raioCartao),
              ),
              side: BorderSide(
                color: CoresTerae.sevCritica.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _Ligar(
              key: Key('ligar-${contato.numero}'),
              contato: contato,
              aoTocar: () => _ligar(context, contato),
              corFoco: CoresTerae.foco,
              child: Padding(
                padding: const EdgeInsets.all(MedidasTerae.espaco),
                child: Row(
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: CoresTerae.sevCriticaFundo,
                        borderRadius: BorderRadius.all(
                          Radius.circular(MedidasTerae.raioBotao),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.phone,
                          color: CoresTerae.sevCritica,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: MedidasTerae.espaco),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${contato.sigla} — ${contato.numero}',
                            style: textos.headlineSmall,
                          ),
                          Text(
                            contato.descricao,
                            style: textos.bodySmall?.copyWith(
                              color: CoresTerae.neutro500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Área de toque de um contato: um nó só, botão, "Ligar para o CVV, 188…",
/// com contorno de foco de 3 px na [corFoco].
class _Ligar extends StatefulWidget {
  const _Ligar({
    super.key,
    required this.contato,
    required this.aoTocar,
    required this.corFoco,
    required this.child,
  });

  final ContatoEmergencia contato;
  final VoidCallback aoTocar;
  final Color corFoco;
  final Widget child;

  @override
  State<_Ligar> createState() => _LigarState();
}

class _LigarState extends State<_Ligar> {
  bool _focado = false;

  @override
  Widget build(BuildContext context) {
    const raio = BorderRadius.all(Radius.circular(MedidasTerae.raioBotao));
    final contato = widget.contato;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: widget.aoTocar,
          onFocusChange: (focado) => setState(() => _focado = focado),
          borderRadius: raio,
          child: Semantics(
            label:
                'Ligar para o ${contato.sigla}, ${contato.numero}. '
                '${contato.descricao}',
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: raio,
                border: _focado
                    ? Border.all(
                        color: widget.corFoco,
                        width: MedidasTerae.larguraFoco,
                      )
                    : null,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: MedidasTerae.alturaMinimaBotao,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
