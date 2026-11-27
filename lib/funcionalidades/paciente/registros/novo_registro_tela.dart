import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import 'componentes_registros.dart';
import 'novo_registro_controlador.dart';

/// TM13 — Novo registro (P3; quadro 18e do portal da família). RFM03,
/// RFM04, RNFM02. Uma página só, com as quatro perguntas; só a primeira é
/// obrigatória, e o formulário nunca diz "alerta": "Muito — precisamos de
/// ajuda" leva, depois do envio, à ajuda imediata (TM05).
///
/// Sem internet (quadro 18m), "Enviar" fica travado com o motivo à vista e
/// aparece "Guardar e enviar depois": o registro vai para a fila deste
/// aparelho e a TM04 diz que ainda não foi enviado. Empilhada sobre as abas;
/// ao enviar, `context.go` para a TM04 ou a TM05 (voltar nunca reabre o
/// formulário preenchido).
///
/// A `Key('TM13')` no Scaffold raiz faz parte do contrato.
class NovoRegistroTela extends StatelessWidget {
  const NovoRegistroTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM13'),
      appBar: AppBar(title: const Text('Novo registro')),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => NovoRegistroControlador(
                repositorio: context.read<RepositorioDiario>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
              ),
              child: _Formulario(palavras: TextosDoDiario.para(perfil)),
            ),
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({required this.palavras});

  final TextosDoDiario palavras;

  Future<void> _seguir(
    BuildContext context,
    Future<DesfechoDoEnvio?> Function() acao,
  ) async {
    final roteador = GoRouter.of(context);
    final desfecho = await acao();
    if (desfecho == null) return;
    roteador.go(desfecho.rota, extra: desfecho.resultado);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NovoRegistroControlador>();
    final agora = context.read<Relogio>().agora();
    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        CabecalhoDaTela(
          titulo: palavras.tituloDoNovo,
          subtitulo:
              '${formatarHojeDoRegistro(agora)}. Leva menos de um minuto. Só '
              'a primeira pergunta é obrigatória.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        CamposDoDiario(respostas: c, palavras: palavras),
        const SizedBox(height: MedidasTerae.espaco),
        if (c.erro case final erro?) ...[
          Semantics(
            liveRegion: true,
            child: Cartaozinho(
              cores: const ParDeCores(CoresTerae.erro, CoresTerae.erroFundo),
              icone: LucideIcons.circleAlert,
              children: [
                Text(
                  erro,
                  style: const TextStyle(fontSize: 16, color: CoresTerae.erro),
                ),
              ],
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
        ],
        ComConexao(
          construtor: (context, online) => _Rodape(
            online: online,
            enviando: c.enviando,
            houveErro: c.erro != null,
            aoEnviar: () => unawaited(_seguir(context, c.enviar)),
            aoGuardar: () => unawaited(_seguir(context, c.guardar)),
          ),
        ),
      ],
    );
  }
}

/// O rodapé do 18e: "Enviar"; sem internet, "Enviar · precisa de internet"
/// travado, "Guardar e enviar depois" e a frase do porquê.
class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.online,
    required this.enviando,
    required this.houveErro,
    required this.aoEnviar,
    required this.aoGuardar,
  });

  final bool online;
  final bool enviando;
  final bool houveErro;
  final VoidCallback aoEnviar;
  final VoidCallback aoGuardar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotaoGrande(
          key: const Key('enviar-diario'),
          // Depois de uma falha, reenvia o mesmo registro (mesmo UUID).
          rotulo: enviando
              ? 'Enviando…'
              : !online
              ? 'Enviar · precisa de internet'
              : houveErro
              ? 'Tentar de novo'
              : 'Enviar',
          icone: online ? LucideIcons.send : LucideIcons.cloudOff,
          aoTocar: online && !enviando ? aoEnviar : null,
        ),
        if (!online) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          BotaoGrande(
            key: const Key('guardar-e-enviar-depois'),
            rotulo: enviando ? 'Guardando…' : 'Guardar e enviar depois',
            icone: LucideIcons.cloudOff,
            variante: VarianteBotao.secundario,
            aoTocar: enviando ? null : aoGuardar,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          const Text(
            'Sem internet agora. Você pode guardar e enviar depois: o registro '
            'fica neste aparelho e só vai para a equipe quando a internet '
            'voltar.',
            key: Key('motivo-sem-internet'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
          ),
        ],
      ],
    );
  }
}
