import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../casa/componentes_casa.dart';
import '../componentes_paciente.dart';
import 'componentes_metas.dart';
import 'meta_controlador.dart';

/// TM20 — Meta (evolução de TO, F3; D25, D35). Aberta pela Jornada (TM06) e
/// pela atividade (TM17): a meta na língua da família, a área da vida, a
/// situação, o prazo, com quem foi combinada, as atividades de casa que
/// ajudam nela e os marcos ligados. Nunca escore, nível GAS nem
/// interpretação (D25).
///
/// Empilhada sobre as abas: voltar desempilha; aberta por link direto, a seta
/// vai à Jornada. A `Key('TM20')` no Scaffold raiz faz parte do contrato.
class MetaTela extends StatelessWidget {
  const MetaTela({super.key, required this.metaId});

  final String metaId;

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM20'),
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            final navegador = Navigator.of(context);
            if (navegador.canPop()) {
              navegador.pop();
            } else {
              context.go(Rotas.pacienteJornada);
            }
          },
        ),
        title: const Text('Meta'),
      ),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey('${perfil.pacienteId}/$metaId'),
              create: (context) => MetaControlador(
                metas: context.read<RepositorioMetas>(),
                programa: context.read<RepositorioProgramaEmCasa>(),
                paciente: context.read<RepositorioPaciente>(),
                pacienteId: perfil.pacienteId,
                metaId: metaId,
              )..carregar(),
              child: const _ConteudoDaMeta(),
            ),
    );
  }
}

class _ConteudoDaMeta extends StatelessWidget {
  const _ConteudoDaMeta();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MetaControlador>();
    final textos = Theme.of(context).textTheme;
    final secundario = textos.bodySmall?.copyWith(
      color: CoresTerae.textoSecundario,
    );
    final meta = c.meta;
    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        if (c.carregando)
          const Carregando()
        else if (c.naoEncontrada)
          Cartaozinho(
            key: const Key('meta-inexistente'),
            cores: const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
            icone: Icons.search_off,
            children: [
              Text(
                'Não encontramos esta meta. Fale com a clínica.',
                style: textos.bodyMedium,
              ),
            ],
          )
        else if (c.falhou || meta == null)
          AvisoDeFalha(
            mensagem: 'Não foi possível mostrar a meta agora.',
            aoTentarDeNovo: c.carregar,
          )
        else ...[
          CabecalhoDaTela(
            titulo: meta.descricao,
            subtitulo: 'Combinada com ${meta.combinadaCom}',
          ),
          const SizedBox(height: MedidasTerae.espaco),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: MedidasTerae.espacoPequeno,
            children: [
              EtiquetaDaMeta(situacao: meta.situacao),
              Etiqueta(
                texto: meta.ocupacao.rotulo,
                cores: const ParDeCores(
                  CoresTerae.neutro700,
                  CoresTerae.neutro100,
                ),
              ),
              if (textoDoPrazo(meta) case final prazo?)
                Etiqueta(
                  key: const Key('prazo-da-meta'),
                  icone: Icons.event,
                  texto: prazo,
                  cores: const ParDeCores(
                    CoresTerae.neutro700,
                    CoresTerae.neutro100,
                  ),
                ),
            ],
          ),
          if (c.profissional.isNotEmpty) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text('Acompanhada por ${c.profissional}', style: secundario),
          ],
          const SizedBox(height: MedidasTerae.espacoGrande),
          const RotuloDeSecao(
            'O que ajuda em casa',
            icone: Icons.extension_outlined,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          if (c.atividades case null)
            Text(
              key: const Key('atividades-da-meta-falharam'),
              'Não foi possível mostrar as atividades de casa agora.',
              style: textos.bodyMedium,
            )
          else if (c.atividades case [])
            Text(
              key: const Key('sem-atividades-da-meta'),
              'Nenhuma atividade de casa ligada a esta meta agora.',
              style: textos.bodyMedium,
            )
          else
            for (final a in c.atividades!) ...[
              Cartao(
                key: Key('atividade-da-meta-${a.id}'),
                aoTocar: () => context.push(Rotas.atividade(a.id)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.titulo, style: textos.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            descreverFrequencia(a.vezesPorSemana),
                            style: secundario,
                          ),
                        ],
                      ),
                    ),
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                  ],
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
            ],
          if (c.marcos.isNotEmpty) ...[
            const SizedBox(height: MedidasTerae.espacoGrande),
            const RotuloDeSecao('Marcos', icone: Icons.outlined_flag),
            const SizedBox(height: MedidasTerae.espaco),
            for (final m in c.marcos) ...[
              Cartao(
                key: Key('marco-da-meta-${m.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      m.tipo.rotulo,
                      style: textos.labelMedium?.copyWith(
                        color: CoresTerae.primaria700,
                      ),
                    ),
                    Text(m.titulo, style: textos.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      formatarDataCivilPorExtenso(m.data),
                      style: secundario,
                    ),
                    const SizedBox(height: 6),
                    Text(m.textoSimples, style: textos.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
            ],
          ],
          const SizedBox(height: MedidasTerae.espacoGrande),
          Cartaozinho(
            key: const Key('nota-das-metas'),
            cores: const ParDeCores(CoresTerae.neutro700, CoresTerae.neutro50),
            icone: Icons.info_outline,
            children: [
              Text(
                'As metas são combinadas com a terapia e mudam com o tempo. '
                'Para mudar uma meta, fale com a clínica.',
                style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro700),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
