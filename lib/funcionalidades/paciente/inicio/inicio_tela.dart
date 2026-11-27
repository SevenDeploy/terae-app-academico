import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../capacidades.dart';
import '../componentes_paciente.dart';
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
    final capacidades = capacidadesDaFonte(context);

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
            Text(
              formatarDiaPorExtenso(relogio.agora()),
              style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                '${saudacaoDoMomento(relogio.agora())}, $primeiroNome.',
                style: textos.headlineSmall,
              ),
            ),
            if (mostrarPerfil) ...[
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Align(
                alignment: Alignment.centerLeft,
                child: Etiqueta(
                  icone: LucideIcons.userRound,
                  texto: 'Perfil de ${paciente.nome}',
                ),
              ),
            ],
            const SizedBox(height: MedidasTerae.espacoCartao),
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
              // A ordem do 18d: o que é do dia (a sessão e o programa),
              // depois o diário, os avisos e os cartões fixos.
              _ProximaConsulta(
                controlador: controlador,
                relogio: relogio,
                perfil: perfil,
              ),
              const SizedBox(height: MedidasTerae.espacoCartao),
              // F1 — o programa em casa de hoje, para quem tem TO.
              if (controlador.emCasa case (:final registradas, :final total)
                  when total > 0) ...[
                _AtalhoEmCasa(registradas: registradas, total: total),
                const SizedBox(height: MedidasTerae.espacoCartao),
              ],
            ],
            // Terae local: o diário chega depois da P3 (CapacidadesDaFonte).
            if (capacidades.diario) ...[
              _AtalhoDoDiario(perfil: perfil),
              const SizedBox(height: MedidasTerae.espacoCartao),
            ],
            if (!controlador.carregando &&
                !controlador.falhou &&
                // D21 — receita e remédios só no acompanhamento clínico.
                paciente.temAcompanhamentoClinico) ...[
              if (controlador.receita case final receita?)
                _LembreteDeRenovacao(
                  receita: receita,
                  hoje: DataCivil.hoje(relogio),
                ),
              _OrientacaoVigente(
                receita: controlador.receita,
                itens: controlador.itens,
              ),
              const SizedBox(height: MedidasTerae.espacoCartao),
            ],
            if (capacidades.jornada) ...[
              Cartao(
                key: const Key('cartao-jornada'),
                aoTocar: () async {
                  await context.push<void>(Rotas.pacienteJornada);
                  await controlador.carregar(emSilencio: true);
                },
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.flag,
                      size: 22,
                      color: CoresTerae.primaria700,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            perfil.falaDeOutraPessoa
                                ? 'A jornada de ${paciente.primeiroNome}'
                                : 'A sua jornada',
                            style: textos.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'O que vem pela frente e os marcos até aqui',
                            style: textos.bodySmall?.copyWith(
                              color: CoresTerae.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: CoresTerae.neutro600,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoCartao),
            ],
            const CartaoDeAjudaAgora(),
          ],
        ),
      ),
    );
  }
}

/// "Bom dia", "Boa tarde" ou "Boa noite", pela hora de [agora] (o portal
/// cumprimenta assim no Início).
String saudacaoDoMomento(DateTime agora) => switch (agora.hour) {
  < 12 => 'Bom dia',
  < 18 => 'Boa tarde',
  _ => 'Boa noite',
};

/// "Precisa de ajuda agora?" — o cartão fixo do fim do Início do portal.
class CartaoDeAjudaAgora extends StatelessWidget {
  const CartaoDeAjudaAgora({super.key});

  @override
  Widget build(BuildContext context) {
    return Cartao(
      key: const Key('cartao-ajuda-agora'),
      titulo: 'Precisa de ajuda agora?',
      icone: LucideIcons.lifeBuoy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A qualquer hora, o atalho “Ajuda”, no topo, mostra os números do '
            'SAMU e do CVV.',
            style: TextStyle(fontSize: 15, color: CoresTerae.neutro700),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const Key('ver-numeros-de-emergencia'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => context.push(Rotas.ajuda),
            child: const Text('Ver os números de emergência'),
          ),
        ],
      ),
    );
  }
}

/// O cartão do diário do 18d: "Como foi o seu dia?" e "Escrever no diário"
/// (um toque do Início, §12).
class _AtalhoDoDiario extends StatelessWidget {
  const _AtalhoDoDiario({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final deOutro = perfil.falaDeOutraPessoa;
    final quemLe = perfil.paciente.temTerapiaOcupacional
        ? 'A terapeuta'
        : 'A equipe';
    return Cartao(
      key: const Key('cartao-diario'),
      sobre: 'Diário',
      titulo: deOutro
          ? 'Como foi o dia de ${perfil.paciente.primeiroNome}?'
          : 'Como foi o seu dia?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Conte em menos de um minuto. $quemLe lê o que '
            '${deOutro ? 'vocês registram' : 'você registra'}.',
            style: const TextStyle(fontSize: 15, color: CoresTerae.neutro700),
          ),
          const SizedBox(height: 12),
          BotaoGrande(
            key: const Key('atalho-diario'),
            rotulo: 'Escrever no diário',
            icone: LucideIcons.notebookPen,
            variante: VarianteBotao.secundario,
            aoTocar: () => context.go(Rotas.pacienteDiario),
          ),
        ],
      ),
    );
  }
}

/// "Programa em casa · hoje" (18d): quantas atividades já têm o registro de
/// hoje, a barra de progresso e o caminho à aba Em casa.
class _AtalhoEmCasa extends StatelessWidget {
  const _AtalhoEmCasa({required this.registradas, required this.total});

  final int registradas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      key: const Key('atalho-em-casa'),
      sobre: 'Programa em casa · hoje',
      titulo:
          '$registradas de $total '
          '${total == 1 ? 'atividade registrada' : 'atividades registradas'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BarraDeProgresso(feitas: registradas, total: total),
          const SizedBox(height: 12),
          BotaoGrande(
            key: const Key('abrir-programa-em-casa'),
            rotulo: 'Abrir o programa em casa',
            variante: VarianteBotao.secundario,
            aoTocar: () => context.go(Rotas.pacienteCasa),
          ),
        ],
      ),
    );
  }
}

/// A barra de progresso do portal (`BarraDeProgresso`): trilho slate e o
/// preenchimento turquesa; lida como "X de Y".
class BarraDeProgresso extends StatelessWidget {
  const BarraDeProgresso({
    super.key,
    required this.feitas,
    required this.total,
  });

  final int feitas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$feitas de $total',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : feitas / total,
          minHeight: 8,
          color: CoresTerae.clinico500,
          backgroundColor: CoresTerae.neutro100,
        ),
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
      sobre: _titulo(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
