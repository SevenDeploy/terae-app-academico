import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/modelos/item_medicacao.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import 'inicio_controlador.dart';

/// TM02 — Início. RFM02. Aba 1: saudação, atalho grande ao diário (um toque
/// do Início, §12), próxima consulta e orientação/receita vigente só leitura
/// (esta só no acompanhamento clínico, D21); menu com "Sair" e, com vários
/// perfis, "Trocar perfil" (§21). A saudação fala do paciente quando quem usa
/// é o responsável (D24).
///
/// A `Key('TM02')` no Scaffold raiz faz parte do contrato (testes de
/// navegação). Sair e trocar perfil só chamam a [Sessao]: o roteador leva ao
/// lugar certo.
class InicioTela extends StatelessWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM02'),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => InicioControlador(
                repositorio: context.read<RepositorioPaciente>(),
                pacienteId: perfil.pacienteId,
              )..carregar(),
              child: _ConteudoInicio(perfil: perfil),
            ),
    );
  }
}

class _ConteudoInicio extends StatelessWidget {
  const _ConteudoInicio({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<InicioControlador>();
    final relogio = context.read<Relogio>();
    final conta = context.select<Sessao, String?>((s) => s.conta?.nomeExibicao);
    final variosPerfis = context.select<Sessao, bool>((s) => s.temVariosPerfis);
    final textos = Theme.of(context).textTheme;

    final paciente = perfil.paciente;
    final primeiroNome = (conta ?? paciente.nome).split(' ').first;
    final mostrarPerfil = variosPerfis || primeiroNome != paciente.primeiroNome;

    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        Row(
          children: [
            Expanded(
              child: Text(
                formatarDiaPorExtenso(relogio.agora()),
                style: textos.bodySmall?.copyWith(
                  color: CoresTerae.textoSecundario,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _MenuDoInicio(variosPerfis: variosPerfis),
          ],
        ),
        CabecalhoDaTela(
          titulo: 'Olá, $primeiroNome',
          subtitulo: perfil.falaDeOutraPessoa
              ? 'Que bom te ver por aqui. Vamos cuidar de '
                    '${paciente.primeiroNome} hoje?'
              : 'Que bom te ver por aqui. Vamos cuidar de você hoje?',
        ),
        if (mostrarPerfil) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Align(
            alignment: Alignment.centerLeft,
            child: Etiqueta(
              icone: Icons.person_outline,
              texto: 'Perfil de ${paciente.nome}',
            ),
          ),
        ],
        const SizedBox(height: MedidasTerae.espaco),
        const _AtalhoDoDiario(),
        const SizedBox(height: MedidasTerae.espaco),
        if (controlador.carregando)
          const Carregando()
        else if (controlador.falhou)
          AvisoDeFalha(
            mensagem:
                'Não foi possível mostrar sua consulta e sua receita '
                'agora.',
            aoTentarDeNovo: controlador.carregar,
          )
        else ...[
          // D21 — receita e remédios só no acompanhamento clínico.
          if (paciente.temAcompanhamentoClinico)
            if (controlador.receita case final receita?)
              _LembreteDeRenovacao(
                receita: receita,
                hoje: DataCivil.hoje(relogio),
              ),
          _ProximaConsulta(controlador: controlador, relogio: relogio),
          if (paciente.temAcompanhamentoClinico) ...[
            const SizedBox(height: MedidasTerae.espaco),
            _OrientacaoVigente(
              receita: controlador.receita,
              itens: controlador.itens,
            ),
          ],
        ],
      ],
    );
  }
}

enum _AcaoMenu { cuidadores, trocarPerfil, sair }

/// Menu da TM02: "Cuidadores" (a TM07, desde a D22), "Trocar perfil" (só com
/// vários perfis) e "Sair".
class _MenuDoInicio extends StatelessWidget {
  const _MenuDoInicio({required this.variosPerfis});

  final bool variosPerfis;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AcaoMenu>(
      key: const Key('menu-inicio'),
      tooltip: 'Abrir menu',
      icon: const Icon(Icons.account_circle_outlined, size: 28),
      onSelected: (acao) {
        final sessao = context.read<Sessao>();
        switch (acao) {
          case _AcaoMenu.cuidadores:
            context.push(Rotas.pacienteCuidadores);
          case _AcaoMenu.trocarPerfil:
            sessao.trocarPerfil();
          case _AcaoMenu.sair:
            sessao.sair();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          key: Key('menu-cuidadores'),
          value: _AcaoMenu.cuidadores,
          child: ListTile(
            leading: Icon(Icons.group_outlined),
            title: Text('Cuidadores'),
          ),
        ),
        if (variosPerfis)
          const PopupMenuItem(
            key: Key('menu-trocar-perfil'),
            value: _AcaoMenu.trocarPerfil,
            child: ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('Trocar perfil'),
            ),
          ),
        const PopupMenuItem(
          key: Key('menu-sair'),
          value: _AcaoMenu.sair,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Sair')),
        ),
      ],
    );
  }
}

/// Atalho grande ao diário: um toque do Início (§12: no máximo dois).
class _AtalhoDoDiario extends StatelessWidget {
  const _AtalhoDoDiario();

  @override
  Widget build(BuildContext context) {
    const branco = TextStyle(color: CoresTerae.branco);
    return Cartao(
      key: const Key('atalho-diario'),
      corFundo: CoresTerae.primaria600,
      corBorda: CoresTerae.primaria600,
      padding: const EdgeInsets.all(MedidasTerae.espaco + 4),
      aoTocar: () => context.go(Rotas.pacienteDiario),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.favorite, color: CoresTerae.branco, size: 32),
          ),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como você está hoje?',
                  style: branco.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registre seu dia no diário. Leva menos de 1 minuto.',
                  style: branco.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          const ExcludeSemantics(
            child: Icon(Icons.chevron_right, color: CoresTerae.branco),
          ),
        ],
      ),
    );
  }
}

/// Lembrete quando faltam 7 dias ou menos para pedir a nova receita.
class _LembreteDeRenovacao extends StatelessWidget {
  const _LembreteDeRenovacao({required this.receita, required this.hoje});

  final ReceitaUsoContinuo receita;
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    final dias = hoje.diasAte(receita.dataRenovacao);
    if (dias > 7) return const SizedBox.shrink();
    final titulo = dias < 0
        ? 'Já é hora de pedir a renovação da sua receita'
        : 'Peça a renovação da sua receita '
              '${descricaoRelativa(receita.dataRenovacao, hoje: hoje)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: MedidasTerae.espaco),
      child: Cartaozinho(
        key: const Key('lembrete-renovacao'),
        cores: const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
        icone: Icons.autorenew,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CoresTerae.aviso900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'É rapidinho: fale com seu profissional na próxima consulta ou '
            'avise a clínica.',
            style: TextStyle(fontSize: 14, color: CoresTerae.aviso900),
          ),
        ],
      ),
    );
  }
}

class _ProximaConsulta extends StatelessWidget {
  const _ProximaConsulta({required this.controlador, required this.relogio});

  final InicioControlador controlador;
  final Relogio relogio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final consulta = controlador.proximaConsulta;
    final profissional = controlador.profissionalDaConsulta;
    return Cartao(
      key: const Key('proxima-consulta'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao('Sua próxima consulta', icone: Icons.event),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          if (consulta == null)
            Text(
              'Nenhuma consulta marcada. Combine o retorno com a clínica.',
              style: textos.bodyMedium,
            )
          else ...[
            if (profissional != null) ...[
              Text(profissional.nome, style: textos.titleMedium),
              Text(
                profissional.especialidade,
                style: textos.bodySmall?.copyWith(
                  color: CoresTerae.textoSecundario,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              '${formatarDiaPorExtenso(consulta.dataHora)} às '
              '${formatarHora(consulta.dataHora)}',
              style: textos.bodyMedium,
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Align(
              alignment: Alignment.centerLeft,
              child: Etiqueta(
                texto: _maiuscula(
                  descricaoRelativa(
                    DataCivil.doInstante(consulta.dataHora),
                    hoje: DataCivil.hoje(relogio),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Orientação e itens da receita vigente — só leitura (RFM02, RF03).
class _OrientacaoVigente extends StatelessWidget {
  const _OrientacaoVigente({required this.receita, required this.itens});

  final ReceitaUsoContinuo? receita;
  final List<ItemMedicacao> itens;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final receita = this.receita;
    return Cartao(
      key: const Key('orientacao-vigente'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao(
            'Sua orientação e seus remédios',
            icone: Icons.medication_outlined,
            cor: CoresTerae.clinico700,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          if (receita == null)
            Text('Nenhuma receita em uso no momento.', style: textos.bodyMedium)
          else ...[
            if (receita.orientacao case final orientacao?)
              Text(orientacao, style: textos.bodyMedium),
            for (final item in itens) ...[
              const Divider(height: MedidasTerae.espacoGrande),
              ItemDaReceita(item: item),
            ],
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              'Receita válida até ${formatarDataCivil(receita.vigenciaFim)}.',
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

/// Um remédio da receita: nome, posologia e horários (ou "quando precisar").
class ItemDaReceita extends StatelessWidget {
  const ItemDaReceita({super.key, required this.item});

  final ItemMedicacao item;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    const horario = ParDeCores(CoresTerae.clinico700, CoresTerae.clinico50);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.medicamento, style: textos.titleMedium),
        Text(
          item.posologia,
          style: textos.bodySmall?.copyWith(color: CoresTerae.textoSecundario),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: MedidasTerae.espacoPequeno,
          runSpacing: MedidasTerae.espacoPequeno,
          children: [
            if (item.horarios.isEmpty)
              const Etiqueta(texto: 'Quando precisar', cores: horario)
            else
              for (final h in item.horarios)
                Etiqueta(icone: Icons.alarm, texto: h, cores: horario),
          ],
        ),
      ],
    );
  }
}

String _maiuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
