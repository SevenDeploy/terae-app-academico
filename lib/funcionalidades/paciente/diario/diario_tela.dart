import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../componentes_paciente.dart';
import 'campos_do_diario.dart';
import 'diario_controlador.dart';

/// TM03 — Diário. RFM03/RFM04, RNFM02. Aba 2: adesão (3 opções), intensidade
/// (4 níveis, cor de severidade sempre com o nome), sintoma predominante
/// escolhido entre opções, observação opcional e "Enviar". O botão
/// "Meus registros" no canto abre a TM13 (Atividade 4).
///
/// O estado mora no [DiarioControlador], criado aqui e mantido pela pilha da
/// aba (o preenchimento sobrevive à troca de aba). Ao enviar, navega com
/// `context.go(Rotas.pacienteDiarioAjuda ou pacienteDiarioEnviado, extra:
/// resultado)` — substitui em vez de empilhar, e o formulário já foi limpo.
///
/// A `Key('TM03')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class DiarioTela extends StatelessWidget {
  const DiarioTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM03'),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => DiarioControlador(
                repositorio: context.read<RepositorioDiario>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
                adesaoQueFalta: TextosDoDiario.para(perfil).adesaoQueFalta,
                sintomaQueFalta: TextosDoDiario.para(perfil).sintomaQueFalta,
              ),
              child: _FormularioDoDiario(palavras: TextosDoDiario.para(perfil)),
            ),
    );
  }
}

class _FormularioDoDiario extends StatelessWidget {
  const _FormularioDoDiario({required this.palavras});

  final TextosDoDiario palavras;

  Future<void> _enviar(BuildContext context) async {
    final controlador = context.read<DiarioControlador>();
    final roteador = GoRouter.of(context);
    final desfecho = await controlador.enviar();
    if (desfecho == null) return;
    roteador.go(desfecho.rota, extra: desfecho.resultado);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiarioControlador>();
    final textos = Theme.of(context).textTheme;
    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        CabecalhoDaTela(
          titulo: palavras.titulo,
          subtitulo: palavras.subtitulo,
          acao: IconButton(
            key: const Key('abrir-registros'),
            tooltip: 'Meus registros',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(Rotas.pacienteRegistros),
          ),
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        CamposDoDiario(
          adesao: c.adesao,
          intensidade: c.intensidade,
          sintoma: c.sintoma,
          observacao: c.observacao,
          aoMudarAdesao: c.escolherAdesao,
          aoMudarIntensidade: c.escolherIntensidade,
          aoMudarSintoma: c.escolherSintoma,
          palavras: palavras,
        ),
        const SizedBox(height: MedidasTerae.espaco),
        if (c.erro case final erro?) ...[
          Semantics(
            liveRegion: true,
            child: Cartaozinho(
              cores: const ParDeCores(
                CoresTerae.negativo700,
                CoresTerae.negativo50,
              ),
              icone: Icons.error_outline,
              children: [
                Text(
                  erro,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CoresTerae.negativo700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
        ],
        BotaoGrande(
          key: const Key('enviar-diario'),
          // Depois de uma falha, reenvia o mesmo registro (mesmo UUID).
          rotulo: c.enviando
              ? 'Enviando…'
              : c.erro != null
              ? 'Tentar de novo'
              : 'Enviar meu registro',
          icone: Icons.send,
          aoTocar: c.podeEnviar ? () => _enviar(context) : null,
        ),
        if (!c.completo) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Para enviar, escolha ${_juntar(c.faltando)}.',
            textAlign: TextAlign.center,
            style: textos.bodySmall?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

/// "a", "a e b", "a, b e c".
String _juntar(List<String> partes) {
  if (partes.length <= 1) return partes.join();
  return '${partes.sublist(0, partes.length - 1).join(', ')} '
      'e ${partes.last}';
}
