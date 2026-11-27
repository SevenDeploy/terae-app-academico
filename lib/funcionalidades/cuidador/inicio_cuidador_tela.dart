import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/textos/encontros.dart';
import '../../nucleo/widgets/aviso_de_conexao.dart';
import '../../nucleo/widgets/cartao.dart';
import 'visao_cuidador_controlador.dart';
import 'widgets_cuidador.dart';

/// TM08 — Início do cuidador (RFM08, §7.4). O que fazer hoje, numa tela: nome
/// de quem ele acompanha e aviso de acesso limitado; próximo horário de
/// remédio e próxima consulta; atalhos para a Medicação (TM11) e a Agenda e
/// avisos (TM12), empilhadas com `context.push`; bloco "conteúdo clínico
/// bloqueado"; menu com "Sair" e, se a conta tiver mais de um perfil, "Trocar
/// perfil". Sem barra de abas e sem rota para conteúdo clínico (RNFM05).
class InicioCuidadorTela extends StatelessWidget {
  const InicioCuidadorTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: criarControladorDoCuidador,
      child: const _InicioCuidador(),
    );
  }
}

class _InicioCuidador extends StatelessWidget {
  const _InicioCuidador();

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final controlador = context.watch<VisaoCuidadorControlador>();
    final textos = Theme.of(context).textTheme;
    final paciente = sessao.perfilAtivo?.paciente;
    final nomeCuidador = sessao.conta?.nomeExibicao.split(' ').first;
    return Scaffold(
      key: const Key('TM08'),
      backgroundColor: CoresTerae.superficie,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: MedidasTerae.paddingTela,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AvisoDeConexao(),
                  Semantics(
                    header: true,
                    child: Text(
                      nomeCuidador == null ? 'Olá!' : 'Olá, $nomeCuidador!',
                      style: textos.headlineSmall,
                    ),
                  ),
                  if (paciente != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Você acompanha ${paciente.nome}',
                      key: const Key('quem-acompanha'),
                      style: textos.bodyLarge?.copyWith(
                        color: CoresTerae.neutro600,
                      ),
                    ),
                  ],
                  const SizedBox(height: MedidasTerae.espacoGrande),
                  ConteudoCarregado(
                    controlador: controlador,
                    construtor: (_) => _ProximosCompromissos(
                      controlador,
                      clinico: paciente?.temAcompanhamentoClinico ?? true,
                    ),
                  ),
                  const SizedBox(height: MedidasTerae.espacoGrande),
                  const TituloDeSecao('Ver mais', icone: Icons.apps),
                  // D21 — remédios só no acompanhamento clínico.
                  if (paciente?.temAcompanhamentoClinico ?? true) ...[
                    _Atalho(
                      key: const Key('atalho-medicacao'),
                      icone: Icons.medication_outlined,
                      titulo: 'Medicação',
                      descricao: 'Horários de hoje e dos próximos dias',
                      aoTocar: () =>
                          unawaited(context.push(Rotas.cuidadorMedicacao)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Atalho(
                    key: const Key('atalho-agenda'),
                    icone: Icons.event_note_outlined,
                    titulo: 'Agenda e avisos',
                    descricao: (paciente?.temAcompanhamentoClinico ?? true)
                        ? '${_maiusculaInicial(paciente == null ? 'consultas' : encontrosDoPaciente(paciente))}, '
                              'receita e avisos à equipe'
                        : 'Sessões e avisos à equipe',
                    aoTocar: () => context.go(Rotas.cuidadorAgenda),
                  ),
                  const SizedBox(height: MedidasTerae.espacoGrande),
                  BlocoClinicoBloqueado(
                    primeiroNome: paciente?.primeiroNome ?? 'o paciente',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Próximo remédio e próxima consulta.
class _ProximosCompromissos extends StatelessWidget {
  const _ProximosCompromissos(this.controlador, {required this.clinico});

  final VisaoCuidadorControlador controlador;

  /// D21 — sem acompanhamento clínico, sem o bloco do próximo remédio.
  final bool clinico;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoje = controlador.hoje;
    final dose = controlador.proximaDoseAgora;
    final consulta = controlador.proximaConsultaAgora;
    final profissional = consulta == null
        ? null
        : controlador.profissionalDe(consulta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clinico) ...[
          const TituloDeSecao(
            'Próximo remédio',
            icone: Icons.alarm,
            cor: CoresTerae.clinico700,
          ),
          Cartao(
            key: const Key('proximo-remedio'),
            corBorda: CoresTerae.clinico100,
            child: dose == null
                ? Text(
                    controlador.receita == null
                        ? 'Nenhuma receita em uso agora.'
                        : 'Nenhum horário de remédio pela frente.',
                    style: textos.bodyLarge,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diaEHora(dose.instante, hoje),
                        style: textos.titleLarge?.copyWith(
                          color: CoresTerae.clinico700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final item in dose.itens)
                        Text(
                          '${item.medicamento} — ${item.posologia}',
                          style: textos.bodyLarge,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: MedidasTerae.espacoGrande),
        ],
        TituloDeSecao(
          // F2 — "Próxima sessão" quando o profissional é de TO.
          consulta == null
              ? (clinico ? 'Próxima consulta' : 'Próxima sessão')
              : 'Próxima ${palavraDoEncontro(profissional)}',
          icone: Icons.event,
          cor: CoresTerae.primaria700,
        ),
        Cartao(
          key: const Key('proxima-consulta'),
          corBorda: CoresTerae.primaria100,
          child: consulta == null
              ? Text(
                  clinico
                      ? 'Nenhuma consulta marcada.'
                      : 'Nenhuma sessão marcada.',
                  style: textos.bodyLarge,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profissional != null)
                      Text(profissional.nome, style: textos.titleMedium),
                    Text(
                      '${formatarDiaPorExtenso(consulta.dataHora)} às '
                      '${formatarHora(consulta.dataHora)}',
                      style: textos.bodyLarge?.copyWith(
                        color: CoresTerae.neutro700,
                      ),
                    ),
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
        ),
      ],
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      aoTocar: aoTocar,
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: CoresTerae.primaria50,
              borderRadius: BorderRadius.all(
                Radius.circular(MedidasTerae.raioBotao),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icone, color: CoresTerae.primaria700),
            ),
          ),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleMedium),
                Text(
                  descricao,
                  style: textos.bodySmall?.copyWith(
                    color: CoresTerae.neutro600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CoresTerae.neutro400),
        ],
      ),
    );
  }
}

String _maiusculaInicial(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
