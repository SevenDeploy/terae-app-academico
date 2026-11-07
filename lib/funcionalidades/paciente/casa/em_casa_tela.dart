import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao_em_casa.dart';
import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
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
    final textos = Theme.of(context).textTheme;
    final nome = perfil.paciente.primeiroNome;
    final deOutro = perfil.falaDeOutraPessoa;
    return RecarregaAoSincronizar(
      aoMudar: c.carregar,
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
          else if (c.atividades.isEmpty)
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
            const SizedBox(height: MedidasTerae.espacoPequeno),
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
        ],
      ),
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
        await context.push<void>(Rotas.atividade(a.id));
        await controlador.carregar();
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
