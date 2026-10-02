import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/seletor_opcoes.dart';
import '../componentes_paciente.dart';
import 'diario_controlador.dart';

/// TM03 — Diário. RFM03/RFM04, RNFM02. Aba 2: adesão (3 opções), intensidade
/// (4 níveis, cor de severidade sempre com o nome), sintoma predominante
/// escolhido entre opções, observação opcional e "Enviar".
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
              ),
              child: const _FormularioDoDiario(),
            ),
    );
  }
}

class _FormularioDoDiario extends StatelessWidget {
  const _FormularioDoDiario();

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
        const CabecalhoDaTela(
          titulo: 'Como você está hoje?',
          subtitulo:
              'Suas respostas ajudam sua equipe a cuidar melhor de você.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        SeletorOpcoes<Adesao>(
          key: const Key('seletor-adesao'),
          rotulo: 'E os seus remédios de hoje?',
          valor: c.adesao,
          aoMudar: c.escolherAdesao,
          opcoes: [
            for (final a in Adesao.values)
              OpcaoSeletor(
                valor: a,
                rotulo: a.rotulo,
                icone: _iconeDaAdesao(a),
                cores: CoresTerae.daAdesao(a),
              ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        SeletorOpcoes<Intensidade>(
          key: const Key('seletor-intensidade'),
          rotulo: 'Qual a intensidade do que você sente hoje?',
          colunas: 2,
          valor: c.intensidade,
          aoMudar: c.escolherIntensidade,
          opcoes: [
            for (final i in Intensidade.values)
              OpcaoSeletor(
                valor: i,
                rotulo: i.rotulo,
                icone: _iconeDaIntensidade(i),
                cores: CoresTerae.daIntensidade(i),
              ),
          ],
        ),
        if (c.intensidade?.ehCritica ?? false) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Ao enviar, vamos mostrar na hora os contatos de ajuda.',
            style: textos.bodySmall?.copyWith(color: CoresTerae.sevCritica),
          ),
        ],
        const SizedBox(height: MedidasTerae.espacoGrande),
        SeletorOpcoes<String>(
          key: const Key('seletor-sintoma'),
          rotulo: 'O que mais incomoda hoje?',
          colunas: 2,
          valor: c.sintoma,
          aoMudar: c.escolherSintoma,
          opcoes: [
            for (final s in sintomasDoDiario) OpcaoSeletor(valor: s, rotulo: s),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        TextField(
          key: const Key('campo-observacao'),
          controller: c.observacao,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Quer contar mais alguma coisa? (opcional)',
            hintText: 'Escreva com suas palavras, se quiser.',
            alignLabelWithHint: true,
          ),
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
          rotulo: c.enviando ? 'Enviando…' : 'Enviar meu registro',
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

IconData _iconeDaAdesao(Adesao a) => switch (a) {
  Adesao.total => Icons.check_circle_outline,
  Adesao.parcial => Icons.remove_circle_outline,
  Adesao.nenhuma => Icons.cancel_outlined,
};

IconData _iconeDaIntensidade(Intensidade i) => switch (i) {
  Intensidade.leve => Icons.sentiment_satisfied,
  Intensidade.moderada => Icons.sentiment_neutral,
  Intensidade.grave => Icons.sentiment_dissatisfied,
  Intensidade.critica => Icons.warning_amber,
};

/// "a", "a e b", "a, b e c".
String _juntar(List<String> partes) {
  if (partes.length <= 1) return partes.join();
  return '${partes.sublist(0, partes.length - 1).join(', ')} '
      'e ${partes.last}';
}
