import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/modelos/agendamento.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/textos/encontros.dart';
import '../../nucleo/widgets/cartao.dart';
import 'cronograma.dart';
import 'visao_cuidador_controlador.dart';
import 'widgets_cuidador.dart';

/// TM12 — Agenda e avisos (RFM08). Próximas consultas com data, hora e
/// profissional — nunca o motivo (RNFM05) —; avisos de consulta cancelada, de
/// renovação próxima da receita e de alerta enviado à equipe, este só com
/// data, hora e ciência do profissional, nunca com o conteúdo do registro.
///
/// Empilhada sobre a TM08; o voltar (seta ou Android) leva à TM08 (roteador).
class AgendaAvisosTela extends StatelessWidget {
  const AgendaAvisosTela({super.key});

  @override
  Widget build(BuildContext context) {
    // Revisão da P4 (B3): trocar de paciente pela folha refaz o controlador;
    // a aba fica montada no `StatefulShellRoute`.
    final pacienteId = context.select<Sessao, String?>(
      (s) => s.perfilAtivo?.pacienteId,
    );
    return ChangeNotifierProvider(
      key: ValueKey(pacienteId),
      create: criarControladorDoCuidador,
      child: const _AgendaAvisos(),
    );
  }
}

class _AgendaAvisos extends StatelessWidget {
  const _AgendaAvisos();

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<VisaoCuidadorControlador>();
    return Scaffold(
      key: const Key('TM12'),
      backgroundColor: CoresTerae.superficie,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: MedidasTerae.paddingTela,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Agenda e avisos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoCartao),
              ConteudoCarregado(
                controlador: controlador,
                construtor: (_) => _Agenda(controlador),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda(this.controlador);

  final VisaoCuidadorControlador controlador;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoje = controlador.hoje;
    final marcadas = consultasMarcadas(
      controlador.consultas,
      controlador.agora,
    );
    final avisos = _avisos(controlador, hoje);
    final paciente = context
        .select<Sessao, Perfil?>((s) => s.perfilAtivo)
        ?.paciente;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloDeSecao(
          // F2 — "Próximas sessões" para quem só faz TO.
          'Próximas ${paciente == null ? 'consultas' : encontrosDoPaciente(paciente)}',
          icone: Icons.event,
          cor: CoresTerae.primaria700,
        ),
        if (marcadas.isEmpty)
          Cartao(
            child: Text(
              'Nenhuma ${paciente == null ? 'consulta' : palavraDoPaciente(paciente)} marcada.',
              style: textos.bodyLarge,
            ),
          ),
        for (final consulta in marcadas) ...[
          _CartaoDaConsulta(
            consulta: consulta,
            controlador: controlador,
            hoje: hoje,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: MedidasTerae.espaco),
        const TituloDeSecao('Avisos', icone: Icons.notifications_outlined),
        if (avisos.isEmpty)
          Cartao(child: Text('Nenhum aviso agora.', style: textos.bodyLarge)),
        for (final aviso in avisos) ...[aviso, const SizedBox(height: 12)],
      ],
    );
  }

  /// Consulta cancelada → renovação próxima → alertas (mais recentes antes).
  List<Widget> _avisos(VisaoCuidadorControlador c, DataCivil hoje) {
    final receita = c.receita;
    return [
      for (final consulta in consultasCanceladas(c.consultas, hoje))
        _CartaoDeAviso(
          chave: Key('aviso-cancelada-${consulta.id}'),
          icone: Icons.event_busy,
          cor: CoresTerae.negativo700,
          corFundo: CoresTerae.negativo50,
          titulo: '${tituloDoEncontro(c.profissionalDe(consulta))} cancelada',
          linhas: [
            '${formatarDiaPorExtenso(consulta.dataHora)} às '
                '${formatarHora(consulta.dataHora)}',
            if (c.profissionalDe(consulta) case final profissional?)
              'Com ${profissional.nome}',
          ],
        ),
      if (receita != null && renovacaoProxima(receita, hoje))
        _CartaoDeAviso(
          chave: const Key('aviso-renovacao'),
          icone: Icons.event_repeat,
          cor: CoresTerae.aviso700,
          corFundo: CoresTerae.aviso50,
          titulo: 'Receita para renovar',
          linhas: [textoDaRenovacao(receita, hoje)],
        ),
      for (final (i, alerta) in c.alertas.indexed)
        _CartaoDeAviso(
          chave: Key('aviso-alerta-$i'),
          icone: Icons.notifications_active_outlined,
          cor: CoresTerae.primaria700,
          corFundo: CoresTerae.primaria50,
          titulo: 'Aviso enviado à equipe',
          linhas: [
            'Em ${formatarDataHora(alerta.emitidoEm)}',
            switch (alerta.cienteEm) {
              final ciente? =>
                'O profissional viu em ${formatarDataHora(ciente)}.',
              null => 'O profissional ainda não viu.',
            },
          ],
        ),
    ];
  }
}

class _CartaoDaConsulta extends StatelessWidget {
  const _CartaoDaConsulta({
    required this.consulta,
    required this.controlador,
    required this.hoje,
  });

  final Agendamento consulta;
  final VisaoCuidadorControlador controlador;
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final profissional = controlador.profissionalDe(consulta);
    return Cartao(
      key: Key('consulta-${consulta.id}'),
      corBorda: CoresTerae.primaria100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatarDiaPorExtenso(consulta.dataHora),
            style: textos.titleMedium,
          ),
          Text(
            'às ${formatarHora(consulta.dataHora)}',
            style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro700),
          ),
          if (profissional != null) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(profissional.nome, style: textos.titleSmall),
            Text(
              profissional.especialidade,
              style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
            ),
          ],
          const SizedBox(height: MedidasTerae.espacoPequeno),
          EtiquetaRelativa(
            descricaoRelativa(
              DataCivil.doInstante(consulta.dataHora),
              hoje: hoje,
            ),
          ),
          if (controlador.respostaDe(consulta) case final r?) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            EtiquetaDaPresenca(r),
          ],
        ],
      ),
    );
  }
}

/// Um aviso: ícone e título (não depende só da cor) e linhas curtas.
class _CartaoDeAviso extends StatelessWidget {
  const _CartaoDeAviso({
    required this.chave,
    required this.icone,
    required this.cor,
    required this.corFundo,
    required this.titulo,
    required this.linhas,
  });

  final Key chave;
  final IconData icone;
  final Color cor;
  final Color corFundo;
  final String titulo;
  final List<String> linhas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: chave,
      corFundo: corFundo,
      corBorda: cor.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icone, color: cor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleSmall?.copyWith(color: cor)),
                for (final linha in linhas)
                  Text(
                    linha,
                    style: textos.bodyMedium?.copyWith(
                      color: CoresTerae.neutro900,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
