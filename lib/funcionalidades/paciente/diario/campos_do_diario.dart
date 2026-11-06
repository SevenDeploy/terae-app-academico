import 'package:flutter/material.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/seletor_opcoes.dart';

/// Opções do sintoma predominante (RNFM02: escolher, nunca digitar). Partem
/// dos exemplos do protótipo ("dor de cabeça, tristeza, falta de ar…"), em
/// linguagem simples; o rótulo escolhido é o valor gravado no registro.
const List<String> sintomasDoDiario = [
  'Tristeza',
  'Ansiedade',
  'Cansaço',
  'Dor',
  'Sono ruim',
  'Falta de ar',
  'Outro',
  'Nenhum em especial',
];

/// As perguntas do diário (RFM03, RNFM02): adesão, intensidade, sintoma e a
/// observação opcional. Usadas no cadastro (TM03) e na correção (TM15, D17),
/// para as duas telas perguntarem igual.
class CamposDoDiario extends StatelessWidget {
  const CamposDoDiario({
    super.key,
    required this.adesao,
    required this.intensidade,
    required this.sintoma,
    required this.observacao,
    required this.aoMudarAdesao,
    required this.aoMudarIntensidade,
    required this.aoMudarSintoma,
  });

  final Adesao? adesao;
  final Intensidade? intensidade;
  final String? sintoma;
  final TextEditingController observacao;
  final ValueChanged<Adesao> aoMudarAdesao;
  final ValueChanged<Intensidade> aoMudarIntensidade;
  final ValueChanged<String> aoMudarSintoma;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeletorOpcoes<Adesao>(
          key: const Key('seletor-adesao'),
          rotulo: 'E os seus remédios de hoje?',
          valor: adesao,
          aoMudar: aoMudarAdesao,
          opcoes: [
            for (final a in Adesao.values)
              OpcaoSeletor(
                valor: a,
                rotulo: a.rotulo,
                icone: iconeDaAdesao(a),
                cores: CoresTerae.daAdesao(a),
              ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        SeletorOpcoes<Intensidade>(
          key: const Key('seletor-intensidade'),
          rotulo: 'Qual a intensidade do que você sente hoje?',
          colunas: 2,
          valor: intensidade,
          aoMudar: aoMudarIntensidade,
          opcoes: [
            for (final i in Intensidade.values)
              OpcaoSeletor(
                valor: i,
                rotulo: i.rotulo,
                icone: iconeDaIntensidade(i),
                cores: CoresTerae.daIntensidade(i),
              ),
          ],
        ),
        if (intensidade?.ehCritica ?? false) ...[
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
          valor: sintoma,
          aoMudar: aoMudarSintoma,
          opcoes: [
            for (final s in sintomasDoDiario) OpcaoSeletor(valor: s, rotulo: s),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        TextField(
          key: const Key('campo-observacao'),
          controller: observacao,
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
      ],
    );
  }
}

IconData iconeDaAdesao(Adesao a) => switch (a) {
  Adesao.total => Icons.check_circle_outline,
  Adesao.parcial => Icons.remove_circle_outline,
  Adesao.nenhuma => Icons.cancel_outlined,
};

IconData iconeDaIntensidade(Intensidade i) => switch (i) {
  Intensidade.leve => Icons.sentiment_satisfied,
  Intensidade.moderada => Icons.sentiment_neutral,
  Intensidade.grave => Icons.sentiment_dissatisfied,
  Intensidade.critica => Icons.warning_amber,
};
