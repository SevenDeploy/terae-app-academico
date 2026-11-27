import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../dados/enums/resposta_presenca.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/confirmacao_de_presenca.dart';
import '../../../dados/modelos/profissional_saude.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';

/// As três primeiras letras com a primeira em maiúscula: `Qui`, `Sáb`.
String _curto(String nome, {required bool maiuscula}) {
  final tres = nome.substring(0, 3);
  return maiuscula ? tres[0].toUpperCase() + tres.substring(1) : tres;
}

/// "50 minutos" (o `formatarDuracao` do portal).
String formatarDuracao(int minutos) =>
    minutos == 1 ? '1 minuto' : '$minutos minutos';

/// O bloco da data do portal (`ResumoDaSessao`): "Qui", "12", "nov", num
/// quadro azul-claro (cinza quando a sessão foi avisada ou desmarcada).
class BlocoDaData extends StatelessWidget {
  const BlocoDaData({super.key, required this.instante, this.apagado = false});

  final DateTime instante;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final data = DataCivil.doInstante(instante);
    final cor = apagado ? CoresTerae.neutro600 : CoresTerae.primaria700;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: apagado ? CoresTerae.neutro50 : CoresTerae.primaria50,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: apagado ? CoresTerae.borda : CoresTerae.primaria200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _curto(nomeDiaDaSemana(data.diaDaSemana), maiuscula: true),
              style: TextStyle(fontSize: 14, color: cor),
            ),
            Text(
              '${data.dia}',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: cor,
              ),
            ),
            Text(
              _curto(nomeDoMes(data.mes), maiuscula: false),
              style: TextStyle(fontSize: 14, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quando e com quem, ao lado do bloco da data: "14:00 · 50 minutos" e "Com
/// Ana · Terapia ocupacional". A duração só aparece se a fonte a tem.
class ResumoDaSessao extends StatelessWidget {
  const ResumoDaSessao({
    super.key,
    required this.agendamento,
    required this.profissional,
    this.prefixoDoTerapeuta = '',
    this.apagado = false,
  });

  final Agendamento agendamento;
  final ProfissionalSaude? profissional;
  final String prefixoDoTerapeuta;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final minutos = a.duracaoMinutos;
    final hora = formatarHora(a.dataHora);
    final quando = minutos == null
        ? hora
        : '$hora · ${formatarDuracao(minutos)}';
    final data = DataCivil.doInstante(a.dataHora);
    final p = profissional;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BlocoDaData(instante: a.dataHora, apagado: apagado),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            container: true,
            label:
                '${formatarDataCivilPorExtenso(data)}, $quando'
                '${p == null ? '' : ', $prefixoDoTerapeuta${p.nome}'}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quando,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CoresTerae.texto,
                  ),
                ),
                if (p != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.userRound,
                          size: 16,
                          color: CoresTerae.neutro600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$prefixoDoTerapeuta${p.nome} · ${p.especialidade}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CoresTerae.neutro700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// O selo do estado da presença (18d/18i): "Falta confirmar", "Presença
/// confirmada" ou o aviso de que não vão. [noInicio] usa a frase do Início.
class SeloDaPresenca extends StatelessWidget {
  const SeloDaPresenca({
    super.key,
    required this.resposta,
    required this.deOutro,
    this.noInicio = false,
  });

  final RespostaPresenca? resposta;
  final bool deOutro;
  final bool noInicio;

  @override
  Widget build(BuildContext context) => switch (resposta) {
    null => Selo(
      texto: noInicio ? 'Falta confirmar a presença' : 'Falta confirmar',
      tom: TomDoSelo.atencao,
      icone: LucideIcons.clock,
    ),
    RespostaPresenca.vamos => const Selo(
      texto: 'Presença confirmada',
      tom: TomDoSelo.sucesso,
      icone: LucideIcons.circleCheck,
    ),
    RespostaPresenca.naoVamos => Selo(
      texto: deOutro ? 'Avisaram que não vão' : 'Avisou que não vai',
      tom: TomDoSelo.neutro,
      icone: LucideIcons.phone,
    ),
  };
}

/// As respostas da família à sessão, como `RespostasDaSessao` do portal:
/// "Confirmar presença" e "Avisar que não vamos" (este pergunta antes: o aviso
/// não cancela, a sessão continua marcada). Depois de responder, o recado e,
/// enquanto der, "Mudar a resposta" (D27).
///
/// Quem usa decide o estado ([perguntando], [podeMudar]) e executa a
/// resposta: o Início e a Agenda têm cada um o seu controlador.
class RespostasDaSessao extends StatelessWidget {
  const RespostasDaSessao({
    super.key,
    required this.agendamento,
    required this.profissional,
    required this.resposta,
    required this.perguntando,
    required this.podeMudar,
    required this.ocupado,
    required this.erro,
    required this.deOutro,
    required this.aoResponder,
    required this.aoMudar,
    this.chaveDoSelo,
    this.noInicio = false,
  });

  final Agendamento agendamento;
  final ProfissionalSaude? profissional;
  final ConfirmacaoDePresenca? resposta;

  /// Mostra os botões (sem resposta, ou "Mudar a resposta" tocado).
  final bool perguntando;
  final bool podeMudar;
  final bool ocupado;
  final String? erro;
  final bool deOutro;
  final Future<void> Function(RespostaPresenca resposta) aoResponder;
  final VoidCallback aoMudar;

  /// `Key` do selo de estado (testes).
  final Key? chaveDoSelo;
  final bool noInicio;

  Future<void> _perguntarAntesDeAvisar(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        key: const Key('avisar-que-nao-vamos'),
        title: Text(
          deOutro ? 'Avisar que vocês não vêm?' : 'Avisar que você não vem?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResumoDaSessao(
              agendamento: agendamento,
              profissional: profissional,
            ),
            const SizedBox(height: 12),
            const Text('• A sessão continua marcada.'),
            const Text('• A recepção liga para combinar outro horário.'),
            const Text('• As outras sessões não mudam.'),
          ],
        ),
        actions: [
          OutlinedButton(
            key: const Key('avisar-voltar'),
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('avisar-a-clinica'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Avisar a clínica'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await aoResponder(RespostaPresenca.naoVamos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final r = resposta;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SeloDaPresenca(
            key: chaveDoSelo,
            resposta: r?.resposta,
            deOutro: deOutro,
            noInicio: noInicio,
          ),
        ),
        if (perguntando) ...[
          const SizedBox(height: 12),
          BotaoGrande(
            key: Key('vamos-${a.id}'),
            rotulo: 'Confirmar presença',
            icone: LucideIcons.calendarCheck,
            aoTocar: ocupado
                ? null
                : () => unawaited(aoResponder(RespostaPresenca.vamos)),
          ),
          const SizedBox(height: 8),
          BotaoGrande(
            key: Key('nao-vamos-${a.id}'),
            rotulo: 'Avisar que não vamos',
            variante: VarianteBotao.secundario,
            aoTocar: ocupado
                ? null
                : () => unawaited(_perguntarAntesDeAvisar(context)),
          ),
        ] else if (r != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              r.situacaoEnvio == SituacaoEnvio.naFila
                  ? 'Guardado no aparelho. Vai para a clínica quando a '
                        'conexão voltar.'
                  : r.resposta == RespostaPresenca.vamos
                  ? 'Combinado! A clínica recebeu a resposta. Chegue uns 10 '
                        'minutos antes.'
                  : 'Obrigado por avisar. A recepção vai ligar para combinar '
                        'outro horário. A '
                        '${palavraDoEncontro(profissional)} continua marcada '
                        'até lá.',
              style: textos.bodyMedium,
            ),
          ),
          if (podeMudar)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('mudar-${a.id}'),
                onPressed: aoMudar,
                icon: const Icon(LucideIcons.pencil, size: 18),
                label: const Text('Mudar a resposta'),
              ),
            ),
        ],
        if (erro != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              erro!,
              style: textos.bodyMedium?.copyWith(color: CoresTerae.erro),
            ),
          ),
        ],
      ],
    );
  }
}
