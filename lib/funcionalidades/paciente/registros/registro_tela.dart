import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import 'componentes_registros.dart';
import 'registro_controlador.dart';
import 'retirar_registro.dart';

/// TM14 — Registro (P3; quadros 18e e 18f do portal). Um registro do diário,
/// com o id na consulta: o mesmo cartão da lista (situação, selos, o que foi
/// contado, "Corrigir", "Retirar" e "Ver a versão 1") e, se ainda está no
/// aparelho, que ele vai quando a internet voltar. Abre pelos "Guardados
/// neste aparelho" da TM03 e por link direto.
class RegistroTela extends StatelessWidget {
  const RegistroTela({super.key, required this.registroId});

  final String registroId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (contexto) => RegistroControlador(
        repositorio: contexto.read<RepositorioDiario>(),
        registroId: registroId,
      )..carregar(),
      child: Builder(
        builder: (contexto) => RecarregaAoSincronizar(
          aoMudar: () =>
              unawaited(contexto.read<RegistroControlador>().carregar()),
          child: const _Registro(),
        ),
      ),
    );
  }
}

class _Registro extends StatelessWidget {
  const _Registro();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RegistroControlador>();
    final registro = c.registro;
    final palavras = palavrasDoDiario(context);
    final agora = context.read<Relogio>().agora();
    return Scaffold(
      key: const Key('TM14'),
      appBar: AppBar(title: const Text('Registro do diário')),
      body: c.carregando && registro == null
          ? const Carregando()
          : registro == null
          ? CorpoDaTela(
              children: [
                AvisoDeFalha(
                  mensagem: c.erro ?? falhaAoCarregarRegistro,
                  aoTentarDeNovo: () => unawaited(c.carregar()),
                ),
              ],
            )
          : CorpoDaTela(
              children: [
                const AvisoDeConexao(),
                if (c.retirou) ...[
                  const Cartaozinho(
                    key: Key('aviso-retirado'),
                    cores: ParDeCores(
                      CoresTerae.sucesso,
                      CoresTerae.sucessoFundo,
                    ),
                    icone: LucideIcons.archive,
                    children: [
                      Text(
                        'Registro retirado. Ele continua no diário, marcado '
                        'como retirado, com o motivo.',
                        style: TextStyle(
                          fontSize: 15,
                          color: CoresTerae.sucesso,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MedidasTerae.espaco),
                ],
                if (!registro.enviado) ...[
                  const Cartaozinho(
                    key: Key('registro-no-aparelho'),
                    cores: ParDeCores(
                      CoresTerae.atencao,
                      CoresTerae.atencaoFundo,
                    ),
                    icone: LucideIcons.cloudOff,
                    children: [
                      Text(
                        'Guardado neste aparelho. Ele ainda não foi enviado e '
                        'vai quando a internet voltar.',
                        style: TextStyle(
                          fontSize: 15,
                          color: CoresTerae.atencao,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MedidasTerae.espaco),
                ],
                CartaoDoRegistro(
                  registro: registro,
                  agora: agora,
                  palavras: palavras,
                  aoCorrigir: () =>
                      context.push(Rotas.corrigirRegistro(registro.id)),
                  aoRetirar: () async {
                    final retirou = await mostrarRetirarRegistro(
                      context,
                      registro: registro,
                      quando: formatarMomentoDoRegistro(
                        regra.momentoNaLista(registro),
                        agora,
                      ),
                    );
                    if (retirou) await c.aoRetirar();
                  },
                ),
              ],
            ),
    );
  }
}
