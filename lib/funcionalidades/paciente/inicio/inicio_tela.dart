import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/resposta_presenca.dart';
import '../../../dados/modelos/item_medicacao.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/presenca_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import '../registros/componentes_registros.dart';
import 'inicio_controlador.dart';

/// TM02 — Início. RFM02. Aba 1: saudação, atalho grande ao diário (um toque
/// do Início, §12), próxima consulta e orientação/receita vigente só leitura
/// (esta só no acompanhamento clínico, D21). "Sair", lembretes e cuidadores
/// ficam na aba Conta; trocar de paciente, no topo da moldura. A saudação fala do paciente quando quem usa
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
                programa: perfil.paciente.temTerapiaOcupacional
                    ? context.read<RepositorioProgramaEmCasa>()
                    : null,
                relogio: context.read<Relogio>(),
                presenca: context.read<RepositorioPresenca>(),
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

    // A5 (ensaio): relê também quando a sincronização termina. Logo depois
    // de entrar, a cópia local ainda não tem a presença já respondida nem os
    // registros de casa do servidor, e o cartão dizia "Você vai? Responda".
    return RecarregaAoVoltar(
      rota: Rotas.pacienteInicio,
      aoVoltar: () => controlador.carregar(emSilencio: true),
      child: RecarregaAoSincronizar(
        aoMudar: () => controlador.carregar(emSilencio: true),
        child: CorpoDaTela(
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
              // F1 — o resumo das atividades de casa, para quem tem TO.
              if (controlador.emCasa case (:final registradas, :final total)
                  when total > 0) ...[
                _AtalhoEmCasa(registradas: registradas, total: total),
                const SizedBox(height: MedidasTerae.espaco),
              ],
              // D21 — receita e remédios só no acompanhamento clínico.
              if (paciente.temAcompanhamentoClinico)
                if (controlador.receita case final receita?)
                  _LembreteDeRenovacao(
                    receita: receita,
                    hoje: DataCivil.hoje(relogio),
                  ),
              _ProximaConsulta(
                controlador: controlador,
                relogio: relogio,
                perfil: perfil,
              ),
              if (paciente.temAcompanhamentoClinico) ...[
                const SizedBox(height: MedidasTerae.espaco),
                _OrientacaoVigente(
                  receita: controlador.receita,
                  itens: controlador.itens,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Atalho grande ao diário: um toque do Início (§12: no máximo dois).
class _AtalhoDoDiario extends StatelessWidget {
  const _AtalhoDoDiario();

  @override
  Widget build(BuildContext context) {
    const branco = TextStyle(color: CoresTerae.branco);
    final palavras = palavrasDoDiario(context);
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
                  palavras.titulo,
                  style: branco.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  palavras.subtituloDoAtalho,
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

/// F1 — atalho à aba Em casa com o resumo de hoje (um toque do Início).
class _AtalhoEmCasa extends StatelessWidget {
  const _AtalhoEmCasa({required this.registradas, required this.total});

  final int registradas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: const Key('atalho-em-casa'),
      aoTocar: () => context.go(Rotas.pacienteCasa),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.extension_outlined,
              size: 32,
              color: CoresTerae.primaria600,
            ),
          ),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Atividades de casa', style: textos.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Hoje: $registradas de $total '
                  '${total == 1 ? 'registrada' : 'registradas'}',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
          const ExcludeSemantics(child: Icon(Icons.chevron_right)),
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
  const _ProximaConsulta({
    required this.controlador,
    required this.relogio,
    required this.perfil,
  });

  final InicioControlador controlador;
  final Relogio relogio;
  final Perfil perfil;

  /// F2 — "Sua próxima consulta" ou, na TO, "sessão"; para quem cuida,
  /// "Próxima sessão de Miguel".
  String _titulo() {
    final consulta = controlador.proximaConsulta;
    final palavra = consulta == null
        ? palavraDoPaciente(perfil.paciente)
        : palavraDoEncontro(controlador.profissionalDaConsulta);
    return perfil.falaDeOutraPessoa
        ? 'Próxima $palavra de ${perfil.paciente.primeiroNome}'
        : 'Sua próxima $palavra';
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final consulta = controlador.proximaConsulta;
    final profissional = controlador.profissionalDaConsulta;
    final resposta = controlador.respostaDaProxima;
    final deOutro = perfil.falaDeOutraPessoa;
    return Cartao(
      key: const Key('proxima-consulta'),
      // A agenda é uma aba; o Início relê tudo quando volta a ser a atual.
      aoTocar: () => context.go(Rotas.pacienteSessoes),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: RotuloDeSecao(_titulo(), icone: Icons.event)),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          if (consulta == null)
            Text(
              'Nenhuma ${palavraDoPaciente(perfil.paciente)} marcada. '
              'Combine com a clínica.',
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
            Wrap(
              spacing: MedidasTerae.espacoPequeno,
              runSpacing: MedidasTerae.espacoPequeno,
              children: [
                Etiqueta(
                  texto: _maiuscula(
                    descricaoRelativa(
                      DataCivil.doInstante(consulta.dataHora),
                      hoje: DataCivil.hoje(relogio),
                    ),
                  ),
                ),
                Etiqueta(
                  key: const Key('presenca-da-proxima'),
                  icone: switch (resposta) {
                    RespostaPresenca.vamos => Icons.check_circle_outline,
                    RespostaPresenca.naoVamos => Icons.event_busy,
                    null => Icons.help_outline,
                  },
                  texto: switch (resposta) {
                    RespostaPresenca.vamos => 'Presença confirmada',
                    RespostaPresenca.naoVamos =>
                      deOutro ? 'Avisaram que não vão' : 'Avisou que não vai',
                    null =>
                      deOutro ? 'Vocês vão? Responda' : 'Você vai? Responda',
                  },
                  cores: switch (resposta) {
                    RespostaPresenca.vamos => const ParDeCores(
                      CoresTerae.clinico700,
                      CoresTerae.clinico50,
                    ),
                    RespostaPresenca.naoVamos => const ParDeCores(
                      CoresTerae.aviso900,
                      CoresTerae.aviso50,
                    ),
                    null => const ParDeCores(
                      CoresTerae.primaria700,
                      CoresTerae.primaria50,
                    ),
                  },
                ),
              ],
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
