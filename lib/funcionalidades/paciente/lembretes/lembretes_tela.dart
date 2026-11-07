import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/lembretes/lembrete.dart';
import '../../../dados/repositorios/lembretes_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../../nucleo/widgets/seletor_opcoes.dart';
import '../componentes_paciente.dart';
import 'lembretes_controlador.dart';

/// TM19 — Lembretes (evolução de TO, F2; D28). Aberta pelo menu do Início:
/// lembrete na véspera de cada sessão ou consulta e, para quem faz TO, das
/// atividades de casa, cada um com o horário; pede a permissão do Android ao
/// salvar; mostra os próximos agendados e manda um de teste.
///
/// Os lembretes ficam só neste celular, e o texto nunca diz com quem nem o
/// quê. A `Key('TM19')` no Scaffold raiz faz parte do contrato.
class LembretesTela extends StatelessWidget {
  const LembretesTela({super.key});

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final daFamilia = [
      for (final p in sessao.perfis)
        if (p.papel == Papel.pacienteFamilia) p.paciente,
    ];
    return Scaffold(
      key: const Key('TM19'),
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            final navegador = Navigator.of(context);
            if (navegador.canPop()) {
              navegador.pop();
            } else {
              context.go(Rotas.pacienteInicio);
            }
          },
        ),
        title: const Text('Lembretes'),
      ),
      body: ChangeNotifierProvider(
        create: (context) => LembretesControlador(
          lembretes: context.read<RepositorioLembretes>(),
          pacienteIds: [for (final p in daFamilia) p.id],
          temTerapiaOcupacional: daFamilia.any((p) => p.temTerapiaOcupacional),
        )..carregar(),
        child: const _ConteudoDosLembretes(),
      ),
    );
  }
}

class _ConteudoDosLembretes extends StatelessWidget {
  const _ConteudoDosLembretes();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LembretesControlador>();
    final textos = Theme.of(context).textTheme;
    final p = c.preferencias;
    return CorpoDaTela(
      children: [
        const CabecalhoDaTela(
          titulo: 'Lembretes',
          subtitulo:
              'Aparecem só neste celular. O texto não mostra nada do '
              'tratamento.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        if (c.carregando)
          const Carregando()
        else ...[
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const Key('lembrete-vespera'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Na véspera de cada sessão ou consulta'),
                  subtitle: const Text(
                    '"Amanhã às 14:00 tem compromisso na clínica."',
                  ),
                  value: p.vesperaDaSessao,
                  onChanged: (v) => c.mudar(p.copyWith(vesperaDaSessao: v)),
                ),
                if (p.vesperaDaSessao) ...[
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                  SeletorOpcoes<int>(
                    key: const Key('hora-da-vespera'),
                    rotulo: 'Em que horário?',
                    colunas: 2,
                    valor: p.horaDaVespera,
                    aoMudar: (h) => c.mudar(p.copyWith(horaDaVespera: h)),
                    opcoes: [
                      for (final h in horasDaVespera)
                        OpcaoSeletor(valor: h, rotulo: '${_doisDigitos(h)}:00'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (c.temTerapiaOcupacional) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Cartao(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const Key('lembrete-casa'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Atividades de casa, todo dia'),
                    subtitle: const Text('"Hora das atividades de casa."'),
                    value: p.atividadesDeCasa,
                    onChanged: (v) => c.mudar(p.copyWith(atividadesDeCasa: v)),
                  ),
                  if (p.atividadesDeCasa) ...[
                    const SizedBox(height: MedidasTerae.espacoPequeno),
                    SeletorOpcoes<int>(
                      key: const Key('hora-da-casa'),
                      rotulo: 'Em que horário?',
                      colunas: 2,
                      valor: p.horaDasAtividades,
                      aoMudar: (h) => c.mudar(p.copyWith(horaDasAtividades: h)),
                      opcoes: [
                        for (final h in horasDasAtividades)
                          OpcaoSeletor(
                            valor: h,
                            rotulo: '${_doisDigitos(h)}:00',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (p.algumLigado && !c.permissaoConcedida) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Text(
              key: const Key('motivo-da-permissao'),
              'Ao salvar, o Android pergunta se o Terae pode mostrar '
              'notificações. Sem essa permissão, os lembretes não aparecem.',
              style: textos.bodyMedium?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            ),
          ],
          const SizedBox(height: MedidasTerae.espaco),
          BotaoGrande(
            key: const Key('salvar-lembretes'),
            rotulo: c.salvando ? 'Salvando…' : 'Salvar',
            icone: Icons.check,
            aoTocar: c.salvando ? null : () => unawaited(c.salvar()),
          ),
          if (c.semPermissao) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Semantics(
              liveRegion: true,
              child: Cartaozinho(
                key: const Key('sem-permissao'),
                cores: const ParDeCores(
                  CoresTerae.aviso900,
                  CoresTerae.aviso50,
                ),
                icone: Icons.notifications_off_outlined,
                children: [
                  Text(
                    'O Android não deixou o Terae mostrar notificações. '
                    'Libere em Configurações > Apps > Terae > Notificações.',
                    style: textos.bodyMedium?.copyWith(
                      color: CoresTerae.aviso900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.mensagem case final mensagem?) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Semantics(
              liveRegion: true,
              child: Cartaozinho(
                key: const Key('mensagem-lembretes'),
                cores: const ParDeCores(
                  CoresTerae.clinico700,
                  CoresTerae.clinico50,
                ),
                icone: Icons.check_circle_outline,
                children: [
                  Text(
                    mensagem,
                    style: textos.bodyMedium?.copyWith(
                      color: CoresTerae.clinico700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: MedidasTerae.espacoGrande),
          const RotuloDeSecao(
            'Próximos lembretes',
            icone: Icons.notifications_outlined,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          if (c.agendados.isEmpty)
            Text('Nenhum lembrete agendado.', style: textos.bodyMedium)
          else
            for (final l in c.agendados.take(5))
              Padding(
                padding: const EdgeInsets.only(
                  bottom: MedidasTerae.espacoPequeno,
                ),
                child: Cartao(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${formatarDiaPorExtenso(l.quando)} às '
                        '${formatarHora(l.quando)}',
                        style: textos.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(l.texto, style: textos.bodyMedium),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: MedidasTerae.espaco),
          OutlinedButton.icon(
            key: const Key('lembrete-de-teste'),
            onPressed: () => unawaited(c.testar()),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Mandar um lembrete de teste'),
          ),
        ],
      ],
    );
  }
}

String _doisDigitos(int n) => n.toString().padLeft(2, '0');
