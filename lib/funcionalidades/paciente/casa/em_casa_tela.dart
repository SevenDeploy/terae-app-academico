import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao_em_casa.dart';
import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../capacidades.dart';
import '../componentes_paciente.dart';
import '../metas/componentes_metas.dart';
import '../registros/componentes_registros.dart';
import 'componentes_casa.dart';
import 'em_casa_controlador.dart';

/// TM16 — Em casa (D21, D22, D26; evolução de TO, F1). Aba só do paciente com
/// terapia ocupacional: quantas atividades de hoje já têm registro, um cartão
/// por atividade (o que é, quantas vezes por semana, "Esta semana: 2 de 3" e
/// a resposta de hoje) que abre a TM17, e a faixa dos últimos 14 dias.
///
/// Fala com quem está com o aparelho (D24): o titular ("você") ou quem cuida
/// do paciente (com o primeiro nome dele). Recarrega quando a fila sai.
///
/// A `Key('TM16')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class EmCasaTela extends StatelessWidget {
  const EmCasaTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM16'),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => EmCasaControlador(
                programa: context.read<RepositorioProgramaEmCasa>(),
                paciente: context.read<RepositorioPaciente>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
                metas: context.read<RepositorioMetas>(),
              )..carregar(),
              child: _ConteudoEmCasa(perfil: perfil),
            ),
    );
  }
}

class _ConteudoEmCasa extends StatelessWidget {
  const _ConteudoEmCasa({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<EmCasaControlador>();
    final capacidades = capacidadesDaFonte(context);
    final nome = perfil.paciente.primeiroNome;
    final deOutro = perfil.falaDeOutraPessoa;
    // F3 (revisão): relê também ao voltar à aba, porque a TM17 abre pela
    // TM20 (Jornada), e um registro com conexão não muda os pendentes.
    return RecarregaAoVoltar(
      rota: Rotas.pacienteCasa,
      aoVoltar: () => c.carregar(emSilencio: true),
      child: RecarregaAoSincronizar(
        aoMudar: () => c.carregar(emSilencio: true),
        child: CorpoDaTela(
          aoAtualizar: c.atualizar,
          children: [
            const AvisoDeConexao(),
            CabecalhoDaTela(
              titulo: 'Em casa',
              subtitulo: deOutro
                  ? 'O que fazer com $nome entre uma sessão e outra.'
                  : 'O que fazer entre uma sessão e outra.',
            ),
            espacoDaCasa,
            if (c.carregando)
              const Carregando()
            else if (c.falhou)
              AvisoDeFalha(
                mensagem: 'Não foi possível mostrar as atividades agora.',
                aoTentarDeNovo: c.carregar,
              )
            else if (c.programaEncerradoEm case final alta?) ...[
              // D36 — com alta, o programa está encerrado: só leitura.
              _ProgramaEncerrado(alta: alta, nome: nome, deOutro: deOutro),
              if (capacidades.faixaDosDias) ...[
                const SizedBox(height: MedidasTerae.espacoGrande),
                _UltimosDias(controlador: c),
              ],
            ] else if (c.atividades.isEmpty)
              _SemAtividades(nome: nome, deOutro: deOutro)
            else ...[
              _ResumoDeHoje(
                registradas: c.resumo.registradas,
                total: c.resumo.total,
              ),
              const SizedBox(height: MedidasTerae.espaco),
              for (final a in c.atividades) ...[
                _CartaoDaAtividade(atividade: a, controlador: c),
                const SizedBox(height: MedidasTerae.espaco),
              ],
              if (capacidades.faixaDosDias) ...[
                const SizedBox(height: MedidasTerae.espacoPequeno),
                _UltimosDias(controlador: c),
              ],
            ],
            // Terae local: sem metas nem Jornada (CapacidadesDaFonte).
            if (!c.carregando && !c.falhou && capacidades.jornada) ...[
              if (c.nossasMetas.isNotEmpty) ...[
                const SizedBox(height: MedidasTerae.espacoGrande),
                NossasMetas(
                  grupos: c.nossasMetas,
                  aoAbrirMeta: (id) async {
                    await context.push<void>(Rotas.meta(id));
                    await c.carregar(emSilencio: true);
                  },
                ),
              ],
              const SizedBox(height: MedidasTerae.espaco),
              BotaoGrande(
                key: const Key('ver-a-jornada-completa'),
                rotulo: deOutro
                    ? 'Ver a jornada de $nome'
                    : 'Ver a sua jornada',
                icone: LucideIcons.flag,
                variante: VarianteBotao.secundario,
                aoTocar: () async {
                  await context.push<void>(Rotas.pacienteJornada);
                  await c.carregar(emSilencio: true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A faixa dos últimos 14 dias, com a legenda (também depois da alta, só
/// para leitura).
class _UltimosDias extends StatelessWidget {
  const _UltimosDias({required this.controlador});

  final EmCasaControlador controlador;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RotuloDeSecao('Últimos 14 dias', icone: Icons.calendar_month),
        const SizedBox(height: MedidasTerae.espaco),
        Cartao(
          key: const Key('faixa-de-dias'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FaixaDeDias(dias: c.faixa, hoje: c.hoje),
              const SizedBox(height: MedidasTerae.espaco),
              const ExcludeSemantics(child: _Legenda()),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Text(
                'Cada quadrado é um dia, com a melhor resposta dele.',
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

/// D36 — "Programa encerrado": a alta da terapia ocupacional encerra as
/// atividades de casa; o caminho fica na Jornada.
class _ProgramaEncerrado extends StatelessWidget {
  const _ProgramaEncerrado({
    required this.alta,
    required this.nome,
    required this.deOutro,
  });

  final DataCivil alta;
  final String nome;
  final bool deOutro;

  @override
  Widget build(BuildContext context) {
    return Cartaozinho(
      key: const Key('programa-encerrado'),
      cores: const ParDeCores(CoresTerae.clinico700, CoresTerae.clinico50),
      icone: Icons.verified_outlined,
      children: [
        const Text(
          'Programa encerrado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: CoresTerae.clinico700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${deOutro ? 'A terapia ocupacional de $nome' : 'A sua terapia ocupacional'}'
          ' teve alta em ${formatarDataCivil(alta)}. As atividades de casa '
          'terminaram, e o caminho até aqui fica na Jornada.',
          style: const TextStyle(fontSize: 14, color: CoresTerae.clinico700),
        ),
        const SizedBox(height: MedidasTerae.espacoPequeno),
        OutlinedButton.icon(
          key: const Key('ver-a-jornada'),
          onPressed: () => context.push(Rotas.pacienteJornada),
          icon: const Icon(LucideIcons.flag),
          label: const Text('Ver a Jornada'),
        ),
      ],
    );
  }
}

class _ResumoDeHoje extends StatelessWidget {
  const _ResumoDeHoje({required this.registradas, required this.total});

  final int registradas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tudo = registradas >= total;
    return Cartaozinho(
      key: const Key('resumo-de-hoje'),
      cores: tudo
          ? const ParDeCores(CoresTerae.clinico700, CoresTerae.clinico50)
          : const ParDeCores(CoresTerae.primaria700, CoresTerae.primaria50),
      icone: tudo ? Icons.task_alt : Icons.today,
      children: [
        Text(
          'Hoje: $registradas de $total '
          '${total == 1 ? 'atividade registrada' : 'atividades registradas'}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tudo ? CoresTerae.clinico700 : CoresTerae.primaria700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tudo
              ? 'Tudo contado por hoje. Obrigado!'
              : 'Toque numa atividade para contar como foi.',
          style: TextStyle(
            fontSize: 14,
            color: tudo ? CoresTerae.clinico700 : CoresTerae.primaria700,
          ),
        ),
      ],
    );
  }
}

class _CartaoDaAtividade extends StatelessWidget {
  const _CartaoDaAtividade({
    required this.atividade,
    required this.controlador,
  });

  final AtividadeDeCasa atividade;
  final EmCasaControlador controlador;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final a = atividade;
    final vezes = controlador.vezesNaSemanaDe(a);
    final hoje = controlador.registroDeHoje(a);
    final profissional = controlador.profissionalDe(a);
    return Cartao(
      key: Key('atividade-${a.id}'),
      aoTocar: () async {
        // Volta da TM17 com o dia possivelmente mudado: relê (com conexão
        // os pendentes não mudam, e a recarga pela sincronização não vem).
        // A volta pela aba (TM17 aberta pela TM20) fica com o
        // `RecarregaAoVoltar`.
        await context.push<void>(Rotas.atividade(a.id));
        await controlador.carregar(emSilencio: true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(a.titulo, style: textos.titleMedium)),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: MedidasTerae.espacoPequeno,
            children: [
              if (capacidadesDaFonte(context).ocupacaoDaAtividade)
                Etiqueta(texto: a.ocupacao.rotulo),
              Etiqueta(
                icone: Icons.repeat,
                texto: descreverFrequencia(a.vezesPorSemana),
                cores: const ParDeCores(
                  CoresTerae.neutro700,
                  CoresTerae.neutro100,
                ),
              ),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Esta semana: $vezes de ${a.vezesPorSemana} '
            '${a.vezesPorSemana == 1 ? 'vez' : 'vezes'}',
            style: textos.bodyMedium,
          ),
          if (profissional.isNotEmpty)
            Text(
              'Combinada com $profissional',
              style: textos.bodySmall?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            ),
          // F3 — a meta que a atividade ajuda.
          if (controlador.metaDe(a) case final meta?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ajuda na meta: ${meta.descricao}',
                key: Key('meta-da-atividade-${a.id}'),
                style: textos.bodySmall?.copyWith(
                  color: CoresTerae.primaria700,
                ),
              ),
            ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Hoje:', style: textos.bodyMedium),
              EtiquetaDeAdesaoEmCasa(adesao: hoje?.adesao),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MedidasTerae.espacoPequeno,
      runSpacing: MedidasTerae.espacoPequeno,
      children: [
        for (final a in AdesaoEmCasa.values) EtiquetaDeAdesaoEmCasa(adesao: a),
        const EtiquetaDeAdesaoEmCasa(adesao: null),
      ],
    );
  }
}

class _SemAtividades extends StatelessWidget {
  const _SemAtividades({required this.nome, required this.deOutro});

  final String nome;
  final bool deOutro;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: const Key('em-casa-vazio'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Nenhuma atividade por enquanto',
                  style: textos.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  deOutro
                      ? 'Quando a terapia ocupacional de $nome tiver '
                            'atividades de casa, elas aparecem aqui, com o '
                            'que fazer e quantas vezes por semana.'
                      : 'Quando a sua terapia ocupacional tiver atividades '
                            'de casa, elas aparecem aqui, com o que fazer e '
                            'quantas vezes por semana.',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
