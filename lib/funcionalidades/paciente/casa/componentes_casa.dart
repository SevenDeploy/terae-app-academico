import 'package:flutter/material.dart';

import '../../../dados/enums/adesao_em_casa.dart';
import '../../../dados/regras/programa_em_casa.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../componentes_paciente.dart';

/// Peças da TM16 Em casa e da TM17 Atividade (evolução de TO, F1).

IconData iconeDaAdesaoEmCasa(AdesaoEmCasa? a) => switch (a) {
  AdesaoEmCasa.feito => Icons.check_circle_outline,
  AdesaoEmCasa.emParte => Icons.timelapse,
  AdesaoEmCasa.naoFeito => Icons.bedtime_outlined,
  null => Icons.radio_button_unchecked,
};

/// Como a resposta aparece numa etiqueta: "Feito", "Em parte", "Não deu" ou,
/// sem registro, "Ainda não".
String rotuloCurtoDaAdesao(AdesaoEmCasa? a) => switch (a) {
  AdesaoEmCasa.feito => 'Feito',
  AdesaoEmCasa.emParte => 'Em parte',
  AdesaoEmCasa.naoFeito => 'Não deu',
  null => 'Ainda não',
};

/// "3 vezes por semana", "Todos os dias", "1 vez por semana".
String descreverFrequencia(int vezesPorSemana) => switch (vezesPorSemana) {
  7 => 'Todos os dias',
  1 => '1 vez por semana',
  final n => '$n vezes por semana',
};

/// Etiqueta da resposta do dia (cor sempre com o nome, nunca só cor).
class EtiquetaDeAdesaoEmCasa extends StatelessWidget {
  const EtiquetaDeAdesaoEmCasa({super.key, required this.adesao});

  final AdesaoEmCasa? adesao;

  @override
  Widget build(BuildContext context) {
    final adesao = this.adesao;
    return Etiqueta(
      icone: iconeDaAdesaoEmCasa(adesao),
      texto: rotuloCurtoDaAdesao(adesao),
      cores: adesao == null
          ? const ParDeCores(CoresTerae.neutro600, CoresTerae.branco)
          : CoresTerae.daAdesaoEmCasa(adesao),
    );
  }
}

/// A faixa dos últimos 14 dias: um quadrado por dia, do mais antigo (à
/// esquerda) a hoje (à direita, com contorno). A cor vem com ícone e cada dia
/// tem rótulo para o leitor de tela ("Terça-feira, 3 de novembro: feito").
class FaixaDeDias extends StatelessWidget {
  const FaixaDeDias({super.key, required this.dias, required this.hoje});

  final List<DiaDaFaixa> dias;
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (i, d) in dias.indexed) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: _QuadradoDoDia(dia: d, ehHoje: d.dia == hoje),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'há ${dias.length - 1} dias',
                  style: textos.bodySmall?.copyWith(
                    color: CoresTerae.textoSecundario,
                  ),
                ),
              ),
              Text(
                'hoje',
                style: textos.bodySmall?.copyWith(
                  color: CoresTerae.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuadradoDoDia extends StatelessWidget {
  const _QuadradoDoDia({required this.dia, required this.ehHoje});

  final DiaDaFaixa dia;
  final bool ehHoje;

  @override
  Widget build(BuildContext context) {
    final adesao = dia.adesao;
    final cores = adesao == null
        ? const ParDeCores(CoresTerae.neutro300, CoresTerae.branco)
        : CoresTerae.daAdesaoEmCasa(adesao);
    final resposta = switch (adesao) {
      AdesaoEmCasa.feito => 'feito',
      AdesaoEmCasa.emParte => 'em parte',
      AdesaoEmCasa.naoFeito => 'não deu',
      null => 'sem registro',
    };
    return Semantics(
      label:
          '${ehHoje ? 'Hoje, ' : ''}'
          '${formatarDataCivilPorExtenso(dia.dia)}: $resposta',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 0.7,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: adesao == null ? CoresTerae.branco : cores.fundo,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            border: Border.all(
              color: ehHoje ? CoresTerae.texto : cores.texto,
              width: ehHoje ? 2 : 1,
            ),
          ),
          child: adesao == null
              ? null
              : FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      iconeDaAdesaoEmCasa(adesao),
                      color: cores.texto,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Espaço padrão entre blocos da TM16/TM17.
const SizedBox espacoDaCasa = SizedBox(height: MedidasTerae.espacoGrande);
