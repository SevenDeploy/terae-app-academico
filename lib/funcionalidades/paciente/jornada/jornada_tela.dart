import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/situacao_agendamento.dart';
import '../../../dados/modelos/paciente.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import '../metas/componentes_metas.dart';
import '../registros/componentes_registros.dart';
import 'jornada_controlador.dart';

/// TM06 — Jornada. RFM06. Aba 3: orientação vigente, próximos passos
/// (consultas marcadas e marcos à frente) e a história até aqui, em linguagem
/// simples (RNFM01) — nada da evolução clínica chega aqui (só `MarcoJornada`).
/// Tocar numa sessão ou consulta abre a TM18 (F2), para responder a presença.
/// Para quem faz TO, "Nossas metas" (F3) mostra as metas por área da vida, e
/// a meta ou o marco dela abre a TM20.
///
/// A `Key('TM06')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class JornadaTela extends StatelessWidget {
  const JornadaTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM06'),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => JornadaControlador(
                repositorio: context.read<RepositorioPaciente>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
                metas: perfil.paciente.temTerapiaOcupacional
                    ? context.read<RepositorioMetas>()
                    : null,
              )..carregar(),
              child: const _ConteudoJornada(),
            ),
    );
  }
}

class _ConteudoJornada extends StatelessWidget {
  const _ConteudoJornada();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<JornadaControlador>();
    final textos = Theme.of(context).textTheme;
    final paciente = context.select<Sessao, Paciente?>(
      (s) => s.perfilAtivo?.paciente,
    );
    final clinico = paciente?.temAcompanhamentoClinico ?? false;
    final encontros = paciente == null
        ? 'consultas'
        : encontrosDoPaciente(paciente);
    // F3 (revisão): "puxar para atualizar" e a releitura quando a
    // sincronização termina trazem de volta o que não pôde ser lido (as
    // metas, sem cópia e sem conexão).
    return RecarregaAoSincronizar(
      aoMudar: () => c.carregar(emSilencio: true),
      child: CorpoDaTela(
        aoAtualizar: () => c.carregar(emSilencio: true),
        children: [
          const CabecalhoDaTela(
            titulo: 'Sua jornada',
            subtitulo: 'Cada passo seu conta. Veja o que já aconteceu e o que vem por aí.',
          ),
          const SizedBox(height: MedidasTerae.espacoGrande),
          if (c.carregando)
            const Carregando()
          else if (c.falhou)
            AvisoDeFalha(
              mensagem: 'Não foi possível mostrar sua jornada agora.',
              aoTentarDeNovo: c.carregar,
            )
          else if (c.vazia)
            Cartao(
              child: Text(
                'Sua jornada começa agora. Quando houver $encontros e '
                'orientações, tudo aparece aqui.',
                style: textos.bodyMedium,
              ),
            )
          else ...[
            // D21 — a orientação do remédio só no acompanhamento clínico.
            if (clinico) ...[
              _OrientacaoAgora(receita: c.receita),
              const SizedBox(height: MedidasTerae.espacoGrande),
            ],
            // F3 — as metas da terapia ocupacional, por área da vida (D25).
            if (c.nossasMetas.isNotEmpty) ...[
              NossasMetas(grupos: c.nossasMetas),
              const SizedBox(height: MedidasTerae.espacoGrande),
            ],
            const RotuloDeSecao('Próximos passos', icone: Icons.flag_outlined),
            const SizedBox(height: MedidasTerae.espaco),
            if (c.proximos.isEmpty)
              Text(
                'Nada marcado por enquanto. Combine o próximo passo com a '
                'clínica.',
                style: textos.bodyMedium,
              )
            else
              _LinhaDoTempo(key: const Key('proximos'), itens: c.proximos),
            if (c.historia.isNotEmpty) ...[
              const SizedBox(height: MedidasTerae.espacoGrande),
              const RotuloDeSecao(
                'Sua história até aqui',
                icone: Icons.history,
                cor: CoresTerae.neutro600,
              ),
              const SizedBox(height: MedidasTerae.espaco),
              _LinhaDoTempo(key: const Key('historia'), itens: c.historia),
            ],
          ],
        ],
      ),
    );
  }
}

/// Orientação da receita vigente, só leitura (RF03).
class _OrientacaoAgora extends StatelessWidget {
  const _OrientacaoAgora({required this.receita});

  final ReceitaUsoContinuo? receita;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final receita = this.receita;
    return Cartao(
      key: const Key('orientacao-agora'),
      corBorda: CoresTerae.clinico100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao(
            'Sua orientação agora',
            icone: Icons.lightbulb_outline,
            cor: CoresTerae.clinico700,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          if (receita == null)
            Text(
              'Nenhuma orientação de remédio no momento.',
              style: textos.bodyMedium,
            )
          else ...[
            if (receita.orientacao case final orientacao?)
              Text(orientacao, style: textos.bodyMedium),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              'Peça a renovação da receita até '
              '${formatarDataCivil(receita.dataRenovacao)}.',
              style: textos.bodySmall?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({super.key, required this.itens});

  final List<ItemJornada> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < itens.length; i++)
          _PontoDaLinha(item: itens[i], ultimo: i == itens.length - 1),
      ],
    );
  }
}

class _PontoDaLinha extends StatelessWidget {
  const _PontoDaLinha({required this.item, required this.ultimo});

  final ItemJornada item;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final (icone, cor, tipo) = switch (item.tipo) {
      TipoItemJornada.consulta => (
        Icons.event,
        CoresTerae.primaria700,
        'Consulta',
      ),
      TipoItemJornada.reavaliacao => (
        Icons.fact_check_outlined,
        CoresTerae.clinico700,
        'Reavaliação',
      ),
      TipoItemJornada.orientacao => (
        Icons.lightbulb_outline,
        CoresTerae.aviso700,
        'Orientação',
      ),
      TipoItemJornada.proximoPasso => (
        Icons.flag_outlined,
        CoresTerae.primaria700,
        'Próximo passo',
      ),
      TipoItemJornada.metaAlcancada => (
        Icons.emoji_events_outlined,
        CoresTerae.clinico700,
        'Meta alcançada',
      ),
      TipoItemJornada.alta => (
        Icons.verified_outlined,
        CoresTerae.clinico700,
        'Alta',
      ),
    };
    final situacao = item.situacao;
    final rotulo = item.rotulo ?? tipo;
    final ehEncontro = item.tipo == TipoItemJornada.consulta;
    final metaId = item.metaId;
    // F2 — a sessão ou consulta abre a TM18 (presença); F3 — o marco de uma
    // meta abre a TM20.
    final VoidCallback? aoTocar = ehEncontro
        ? () => context.push(Rotas.pacienteSessoes)
        : metaId != null
        ? () => context.push(Rotas.meta(metaId))
        : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 40,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: CoresTerae.branco,
                      shape: BoxShape.circle,
                      border: Border.all(color: CoresTerae.borda),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(icone, size: 22, color: cor),
                    ),
                  ),
                  if (!ultimo)
                    const Expanded(
                      child: VerticalDivider(
                        width: 2,
                        thickness: 1.5,
                        color: CoresTerae.neutro200,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: ultimo ? 0 : MedidasTerae.espaco,
              ),
              child: MergeSemantics(
                child: Cartao(
                  key: aoTocar != null ? Key('jornada-${item.id}') : null,
                  aoTocar: aoTocar,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rotulo,
                        style: textos.labelMedium?.copyWith(color: cor),
                      ),
                      Text(item.titulo, style: textos.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        item.quando,
                        style: textos.bodySmall?.copyWith(
                          color: CoresTerae.textoSecundario,
                        ),
                      ),
                      if (situacao != null) ...[
                        const SizedBox(height: 6),
                        Etiqueta(
                          texto: situacao.rotulo,
                          cores: situacao == SituacaoAgendamento.cancelado
                              ? const ParDeCores(
                                  CoresTerae.negativo700,
                                  CoresTerae.negativo50,
                                )
                              : const ParDeCores(
                                  CoresTerae.clinico700,
                                  CoresTerae.clinico50,
                                ),
                        ),
                      ],
                      if (item.texto case final texto?) ...[
                        const SizedBox(height: 6),
                        Text(texto, style: textos.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
