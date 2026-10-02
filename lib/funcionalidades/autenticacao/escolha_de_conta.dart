import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import '../publico/folha_inferior.dart';
import 'controlador_de_entrada.dart';

/// "Continuar com Google" e, só no iOS, "Continuar com Apple" — opção
/// equivalente exigida pela diretriz 4.8 da App Store (RFM01; TM01, TM09,
/// TM10). `aoEscolher: null` desabilita os dois.
class BotoesDeProvedor extends StatelessWidget {
  const BotoesDeProvedor({super.key, required this.aoEscolher});

  final ValueChanged<Provedor>? aoEscolher;

  /// Apple só no iOS (inclui `debugDefaultTargetPlatformOverride` em teste).
  static bool get mostraApple => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final escolher = aoEscolher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotaoGrande(
          key: const Key('continuar-google'),
          rotulo: Provedor.google.rotulo,
          icone: Icons.account_circle_outlined,
          aoTocar: escolher == null ? null : () => escolher(Provedor.google),
        ),
        if (mostraApple) ...[
          const SizedBox(height: 12),
          BotaoGrande(
            key: const Key('continuar-apple'),
            rotulo: Provedor.apple.rotulo,
            icone: Icons.apple,
            variante: VarianteBotao.secundario,
            aoTocar: escolher == null ? null : () => escolher(Provedor.apple),
          ),
        ],
      ],
    );
  }
}

/// D5 — busca as contas do [provedor] pelo [controlador] e abre a folha
/// "Escolha uma conta". Devolve a escolhida, ou `null` se a pessoa fechou a
/// folha ou a busca falhou (o motivo fica na mensagem do controlador).
Future<IdentidadeProvedor?> escolherConta(
  BuildContext context,
  ControladorDeEntrada controlador,
  Provedor provedor,
) async {
  final contas = await controlador.contasDoAparelho(provedor);
  if (contas == null || !context.mounted) return null;
  return mostrarFolha<IdentidadeProvedor>(
    context: context,
    titulo: 'Escolha uma conta',
    construtor: (folha) => _ContasDoAparelho(
      provedor: provedor,
      contas: contas,
      aoEscolher: (conta) => Navigator.of(folha).pop(conta),
    ),
  );
}

class _ContasDoAparelho extends StatelessWidget {
  const _ContasDoAparelho({
    required this.provedor,
    required this.contas,
    required this.aoEscolher,
  });

  final Provedor provedor;
  final List<IdentidadeProvedor> contas;
  final ValueChanged<IdentidadeProvedor> aoEscolher;

  String get _nomeDoProvedor => switch (provedor) {
    Provedor.google => 'Google',
    Provedor.apple => 'Apple',
  };

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Contas $_nomeDoProvedor neste aparelho, para continuar no Terae.',
          style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro700),
        ),
        const SizedBox(height: MedidasTerae.espaco),
        if (contas.isEmpty)
          Text(
            'Nenhuma conta $_nomeDoProvedor neste aparelho.',
            style: textos.bodyLarge,
          ),
        for (final conta in contas) ...[
          Cartao(
            key: Key('conta-${conta.idProvedor}'),
            aoTocar: () => aoEscolher(conta),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 40,
                  color: CoresTerae.primaria600,
                ),
                const SizedBox(width: MedidasTerae.espaco),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(conta.nomeExibicao, style: textos.titleSmall),
                      Text(
                        conta.email,
                        style: textos.bodySmall?.copyWith(
                          color: CoresTerae.neutro600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
        ],
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Text(
          'Demonstração: a escolha da conta é simulada e nenhuma senha é '
          'pedida nem guardada.',
          style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
        ),
      ],
    );
  }
}
