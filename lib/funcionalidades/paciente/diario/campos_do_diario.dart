import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../nucleo/sessao/sessao.dart';
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

/// O que mais pesou no dia para quem só faz terapia ocupacional (F1): o
/// que famílias de crianças atípicas e adultos em reabilitação costumam
/// contar. Também escolhido, nunca digitado (RNFM02).
const List<String> acontecimentosDaTerapiaOcupacional = [
  'Crise ou desregulação',
  'Sono ruim',
  'Alimentação',
  'Agitação',
  'Dor',
  'Cansaço',
  'Outro',
  'Nada em especial',
];

/// Os textos do diário conforme o paciente (evolução de TO, F1; D21, D24).
///
/// Quem tem acompanhamento clínico (com ou sem TO) vê o diário das
/// Atividades 3 e 4: remédios e sintomas. Quem só faz terapia ocupacional vê
/// o mesmo registro com outras palavras (a rotina combinada no lugar dos
/// remédios e o que mais pesou no dia no lugar do sintoma), na voz de quem
/// está com o aparelho. Os dados gravados são os mesmos, e o alerta da
/// crítica vale igual.
@immutable
class TextosDoDiario {
  const TextosDoDiario._({
    required this.titulo,
    required this.subtitulo,
    required this.perguntaAdesao,
    required this.perguntaIntensidade,
    required this.perguntaSintoma,
    required this.sintomas,
    required this.resumoAdesao,
    required this.resumoSintoma,
    required this.resumoSintomaNoRegistro,
    required this.adesaoQueFalta,
    required this.sintomaQueFalta,
    required this.subtituloDoAtalho,
    required this._rotulos,
  });

  /// O diário das Atividades 3 e 4.
  static const TextosDoDiario clinico = TextosDoDiario._(
    titulo: 'Como você está hoje?',
    subtitulo: 'Suas respostas ajudam sua equipe a cuidar melhor de você.',
    perguntaAdesao: 'E os seus remédios de hoje?',
    perguntaIntensidade: 'Qual a intensidade do que você sente hoje?',
    perguntaSintoma: 'O que mais incomoda hoje?',
    sintomas: sintomasDoDiario,
    resumoAdesao: 'Remédios',
    resumoSintoma: 'O que mais incomoda',
    resumoSintomaNoRegistro: 'O que mais incomodou',
    adesaoQueFalta: 'os remédios',
    sintomaQueFalta: 'o sintoma',
    subtituloDoAtalho: 'Registre seu dia no diário. Leva menos de 1 minuto.',
    rotulos: {},
  );

  /// Os textos para o [perfil] ativo.
  factory TextosDoDiario.para(Perfil perfil) {
    final paciente = perfil.paciente;
    if (paciente.temAcompanhamentoClinico) return clinico;
    final nome = paciente.primeiroNome;
    final deOutro = perfil.falaDeOutraPessoa;
    return TextosDoDiario._(
      titulo: deOutro ? 'Como foi o dia de $nome?' : 'Como foi o seu dia?',
      subtitulo: deOutro
          ? 'Suas respostas ajudam a terapia de $nome a acompanhar a semana.'
          : 'Suas respostas ajudam a sua terapia a acompanhar a semana.',
      perguntaAdesao: 'E a rotina combinada, deu para seguir?',
      perguntaIntensidade: 'O quanto o dia foi difícil?',
      perguntaSintoma: 'O que mais pesou hoje?',
      sintomas: acontecimentosDaTerapiaOcupacional,
      resumoAdesao: 'Rotina',
      resumoSintoma: 'O que mais pesou',
      resumoSintomaNoRegistro: 'O que mais pesou',
      adesaoQueFalta: 'a rotina',
      sintomaQueFalta: 'o que mais pesou',
      subtituloDoAtalho: 'Registre o dia no diário. Leva menos de 1 minuto.',
      rotulos: {
        Adesao.total: deOutro ? 'Seguimos' : 'Segui',
        Adesao.parcial: 'Em parte',
        Adesao.nenhuma: 'Não deu hoje',
      },
    );
  }

  final String titulo;
  final String subtitulo;
  final String perguntaAdesao;
  final String perguntaIntensidade;
  final String perguntaSintoma;
  final List<String> sintomas;

  /// Rótulo da adesão nos resumos (TM04, TM14).
  final String resumoAdesao;

  /// Rótulo do sintoma no resumo do envio (TM04).
  final String resumoSintoma;

  /// Rótulo do sintoma num registro já feito (TM14).
  final String resumoSintomaNoRegistro;

  /// "Para enviar, escolha os remédios" ou "a rotina".
  final String adesaoQueFalta;

  /// "… e o sintoma" ou "… e o que mais pesou".
  final String sintomaQueFalta;
  final String subtituloDoAtalho;
  final Map<Adesao, String> _rotulos;

  /// O texto da opção de adesão (o do enum no diário clínico).
  String rotuloDaAdesao(Adesao a) => _rotulos[a] ?? a.rotulo;
}

/// As [TextosDoDiario] do perfil ativo, para as telas que mostram ou pedem
/// um registro (TM02, TM04, TM14, TM15).
TextosDoDiario palavrasDoDiario(BuildContext context) {
  final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
  return perfil == null ? TextosDoDiario.clinico : TextosDoDiario.para(perfil);
}

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
    this.palavras = TextosDoDiario.clinico,
  });

  final Adesao? adesao;
  final Intensidade? intensidade;
  final String? sintoma;
  final TextEditingController observacao;
  final ValueChanged<Adesao> aoMudarAdesao;
  final ValueChanged<Intensidade> aoMudarIntensidade;
  final ValueChanged<String> aoMudarSintoma;

  /// As palavras do diário para o paciente (F1).
  final TextosDoDiario palavras;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeletorOpcoes<Adesao>(
          key: const Key('seletor-adesao'),
          rotulo: palavras.perguntaAdesao,
          valor: adesao,
          aoMudar: aoMudarAdesao,
          opcoes: [
            for (final a in Adesao.values)
              OpcaoSeletor(
                valor: a,
                rotulo: palavras.rotuloDaAdesao(a),
                icone: iconeDaAdesao(a),
                cores: CoresTerae.daAdesao(a),
              ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        SeletorOpcoes<Intensidade>(
          key: const Key('seletor-intensidade'),
          rotulo: palavras.perguntaIntensidade,
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
          rotulo: palavras.perguntaSintoma,
          colunas: 2,
          valor: sintoma,
          aoMudar: aoMudarSintoma,
          opcoes: [
            for (final s in palavras.sintomas)
              OpcaoSeletor(valor: s, rotulo: s),
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
