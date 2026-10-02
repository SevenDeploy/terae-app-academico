import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/modelos/item_medicacao.dart';
import '../../dados/modelos/receita_uso_continuo.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/widgets/cartao.dart';
import 'cronograma.dart';
import 'visao_cuidador_controlador.dart';
import 'widgets_cuidador.dart';

/// TM11 — Medicação (RFM08). Cronograma da receita vigente: lista do dia
/// agrupada por horário, com medicamento e posologia; próximos dias; data de
/// renovação da receita. Somente leitura.
///
/// Empilhada sobre a TM08; o voltar (seta ou Android) leva à TM08, mesmo
/// aberta por link direto (roteador).
class MedicacaoTela extends StatelessWidget {
  const MedicacaoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: criarControladorDoCuidador,
      child: const _Medicacao(),
    );
  }
}

class _Medicacao extends StatelessWidget {
  const _Medicacao();

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<VisaoCuidadorControlador>();
    return Scaffold(
      key: const Key('TM11'),
      backgroundColor: CoresTerae.superficie,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Medicação'),
        backgroundColor: CoresTerae.superficie,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: MedidasTerae.paddingTela,
          child: ConteudoCarregado(
            controlador: controlador,
            construtor: (_) => _Cronograma(controlador),
          ),
        ),
      ),
    );
  }
}

class _Cronograma extends StatelessWidget {
  const _Cronograma(this.controlador);

  final VisaoCuidadorControlador controlador;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final receita = controlador.receita;
    final hoje = controlador.hoje;
    final aviso = Text(
      'Somente para consulta. Quem muda a receita é a equipe de saúde.',
      style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
    );
    if (receita == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Cartao(
            child: Text(
              'Nenhuma receita em uso agora.',
              style: textos.bodyLarge,
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          aviso,
        ],
      );
    }
    final grupos = agruparPorHorario(controlador.itens);
    final quandoPrecisar = itensQuandoPrecisar(controlador.itens);
    final proxima = controlador.proximaDoseAgora;
    final dias = proximosDias(receita, hoje);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloDeSecao(
          'Hoje',
          icone: Icons.today,
          cor: CoresTerae.clinico700,
        ),
        Text(
          formatarDataCivilPorExtenso(hoje),
          style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro600),
        ),
        const SizedBox(height: 12),
        if (grupos.isEmpty && quandoPrecisar.isEmpty)
          Cartao(
            child: Text(
              'Nenhum remédio nesta receita.',
              style: textos.bodyLarge,
            ),
          ),
        for (final grupo in grupos) ...[
          _CartaoDoHorario(
            horario: formatarHora(instanteDoHorario(hoje, grupo.horario)),
            itens: grupo.itens,
            proximo:
                proxima != null &&
                proxima.instante == instanteDoHorario(hoje, grupo.horario),
          ),
          const SizedBox(height: 12),
        ],
        if (quandoPrecisar.isNotEmpty) ...[
          _CartaoDoHorario(horario: 'Quando precisar', itens: quandoPrecisar),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: MedidasTerae.espaco),
        const TituloDeSecao('Próximos dias', icone: Icons.date_range),
        if (dias.isEmpty || grupos.isEmpty)
          Text(
            'A receita vale até ${formatarDataCivil(receita.vigenciaFim)}.',
            style: textos.bodyLarge,
          ),
        if (grupos.isNotEmpty)
          for (final dia in dias) ...[
            _ProximoDia(dia: dia, grupos: grupos),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: MedidasTerae.espaco),
        const TituloDeSecao(
          'Renovação da receita',
          icone: Icons.event_repeat,
          cor: CoresTerae.aviso700,
        ),
        _Renovacao(receita: receita, hoje: hoje),
        const SizedBox(height: MedidasTerae.espacoGrande),
        aviso,
      ],
    );
  }
}

class _CartaoDoHorario extends StatelessWidget {
  const _CartaoDoHorario({
    required this.horario,
    required this.itens,
    this.proximo = false,
  });

  final String horario;
  final List<ItemMedicacao> itens;
  final bool proximo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      corBorda: proximo ? CoresTerae.clinico600 : CoresTerae.clinico100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                horario,
                style: textos.titleLarge?.copyWith(
                  color: CoresTerae.clinico700,
                ),
              ),
              if (proximo) const EtiquetaRelativa('Próximo horário'),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in itens)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: item.medicamento,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' — ${item.posologia}'),
                  ],
                ),
                style: textos.bodyLarge,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProximoDia extends StatelessWidget {
  const _ProximoDia({required this.dia, required this.grupos});

  final DataCivil dia;
  final List<GrupoDeHorario> grupos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatarDataCivilPorExtenso(dia), style: textos.titleSmall),
          const SizedBox(height: 4),
          for (final grupo in grupos)
            Text(
              '${formatarHora(instanteDoHorario(dia, grupo.horario))} — '
              '${grupo.itens.map((i) => i.medicamento).join(', ')}',
              style: textos.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _Renovacao extends StatelessWidget {
  const _Renovacao({required this.receita, required this.hoje});

  final ReceitaUsoContinuo receita;
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      key: const Key('renovacao'),
      corFundo: CoresTerae.aviso50,
      corBorda: CoresTerae.aviso200,
      child: Text(
        textoDaRenovacao(receita, hoje),
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: CoresTerae.aviso900),
      ),
    );
  }
}
