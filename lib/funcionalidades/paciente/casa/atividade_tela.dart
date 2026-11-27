import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao_em_casa.dart';
import '../../../dados/enums/quem_registrou.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/modelos/registro_de_atividade.dart';
import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../../nucleo/widgets/seletor_opcoes.dart';
import '../../capacidades.dart';
import '../componentes_paciente.dart';
import '../metas/componentes_metas.dart';
import 'atividade_controlador.dart';
import 'componentes_casa.dart';

/// TM17 — Atividade (D26; evolução de TO, F1). Uma atividade de casa: o que
/// fazer, nas palavras da terapia; "Conseguiu fazer hoje?" (Sim, Em parte,
/// Não deu hoje) com "Quer contar como foi?" opcional; corrigir e desfazer só
/// hoje; e os últimos 14 dias com o que foi contado.
///
/// Empilhada sobre as abas, com a seta de voltar: desempilha para a TM16, que
/// relê o dia; aberta por link direto, a seta vai à TM16.
/// A `Key('TM17')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class AtividadeTela extends StatelessWidget {
  const AtividadeTela({super.key, required this.atividadeId});

  final String atividadeId;

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM17'),
      appBar: AppBar(
        // Desempilha (a TM16 espera a volta para reler); aberta por link
        // direto, sem nada embaixo, vai à TM16.
        leading: BackButton(
          onPressed: () {
            final navegador = Navigator.of(context);
            if (navegador.canPop()) {
              navegador.pop();
            } else {
              context.go(Rotas.casaDe(perfil?.papel ?? Papel.pacienteFamilia));
            }
          },
        ),
        title: const Text('Atividade de casa'),
      ),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey('${perfil.pacienteId}/$atividadeId'),
              create: (context) => AtividadeControlador(
                programa: context.read<RepositorioProgramaEmCasa>(),
                paciente: context.read<RepositorioPaciente>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
                atividadeId: atividadeId,
                quem: perfil.falaDeOutraPessoa
                    ? QuemRegistrou.responsavel
                    : QuemRegistrou.paciente,
                metas: context.read<RepositorioMetas>(),
              )..carregar(),
              child: _ConteudoDaAtividade(perfil: perfil),
            ),
    );
  }
}

class _ConteudoDaAtividade extends StatelessWidget {
  const _ConteudoDaAtividade({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AtividadeControlador>();
    final atividade = c.atividade;
    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        if (c.carregando)
          const Carregando()
        else if (c.naoEncontrada)
          Cartaozinho(
            key: const Key('atividade-inexistente'),
            cores: const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
            icone: Icons.search_off,
            children: [
              Text(
                'Não encontramos esta atividade. Ela pode ter sido '
                'encerrada na terapia.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          )
        else if (c.falhou || atividade == null)
          AvisoDeFalha(
            mensagem: 'Não foi possível mostrar a atividade agora.',
            aoTentarDeNovo: c.carregar,
          )
        else ...[
          _OQueFazer(atividade: atividade, profissional: c.profissional),
          // F3 — a meta que a atividade ajuda; abre a TM20.
          if (c.meta case final meta?) ...[
            const SizedBox(height: MedidasTerae.espaco),
            CartaoDaMetaLigada(
              meta: meta,
              aoVoltar: () => c.carregar(emSilencio: true),
            ),
          ],
          espacoDaCasa,
          const RotuloDeSecao('Hoje', icone: Icons.today),
          const SizedBox(height: MedidasTerae.espaco),
          if (c.mostrarFormulario)
            _Formulario(controlador: c, deOutro: perfil.falaDeOutraPessoa)
          else
            _RegistroDeHoje(controlador: c, registro: c.registroDeHoje!),
          if (c.mensagem case final mensagem?) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Semantics(
              liveRegion: true,
              child: Cartaozinho(
                key: const Key('mensagem-atividade'),
                cores: const ParDeCores(
                  CoresTerae.clinico700,
                  CoresTerae.clinico50,
                ),
                icone: Icons.check_circle_outline,
                children: [
                  Text(
                    mensagem,
                    style: const TextStyle(
                      fontSize: 16,
                      color: CoresTerae.clinico700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.erro case final erro?) ...[
            const SizedBox(height: MedidasTerae.espaco),
            RolaAteAparecer(
              key: ValueKey(erro),
              child: Semantics(
                liveRegion: true,
                child: Cartaozinho(
                  key: const Key('erro-atividade'),
                  cores: const ParDeCores(
                    CoresTerae.negativo700,
                    CoresTerae.negativo50,
                  ),
                  icone: Icons.error_outline,
                  children: [
                    Text(
                      erro,
                      style: const TextStyle(
                        fontSize: 16,
                        color: CoresTerae.negativo700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Terae local: o portal só tem o registro de hoje.
          if (capacidadesDaFonte(context).faixaDosDias) ...[
            espacoDaCasa,
            const RotuloDeSecao('Últimos 14 dias', icone: Icons.calendar_month),
            const SizedBox(height: MedidasTerae.espaco),
            Cartao(
              key: const Key('faixa-da-atividade'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Esta semana: ${c.vezesEstaSemana} de '
                    '${atividade.vezesPorSemana} '
                    '${atividade.vezesPorSemana == 1 ? 'vez' : 'vezes'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: MedidasTerae.espaco),
                  FaixaDeDias(dias: c.faixa, hoje: c.hoje),
                ],
              ),
            ),
          ],
          if (c.historico.isNotEmpty) ...[
            espacoDaCasa,
            RotuloDeSecao(
              perfil.falaDeOutraPessoa
                  ? 'O que vocês contaram'
                  : 'O que você contou',
              icone: Icons.chat_bubble_outline,
            ),
            const SizedBox(height: MedidasTerae.espaco),
            for (final r in c.historico) ...[
              _ItemDoHistorico(registro: r),
              const SizedBox(height: MedidasTerae.espacoPequeno),
            ],
          ],
        ],
      ],
    );
  }
}

class _OQueFazer extends StatelessWidget {
  const _OQueFazer({required this.atividade, required this.profissional});

  final AtividadeDeCasa atividade;
  final String profissional;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final a = atividade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoDaTela(
          titulo: a.titulo,
          subtitulo: profissional.isEmpty
              ? null
              : 'Combinada com $profissional em '
                    '${formatarData(a.publicadaEm)}',
        ),
        const SizedBox(height: MedidasTerae.espaco),
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
        const SizedBox(height: MedidasTerae.espaco),
        Cartao(
          key: const Key('texto-da-atividade'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const RotuloDeSecao(
                'O que fazer',
                icone: Icons.lightbulb_outline,
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Text(a.texto, style: textos.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _Formulario extends StatelessWidget {
  const _Formulario({required this.controlador, required this.deOutro});

  final AtividadeControlador controlador;
  final bool deOutro;

  @override
  Widget build(BuildContext context) {
    final c = controlador;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeletorOpcoes<AdesaoEmCasa>(
          key: const Key('seletor-adesao-casa'),
          rotulo: deOutro ? 'Conseguiram fazer hoje?' : 'Conseguiu fazer hoje?',
          valor: c.adesao,
          aoMudar: c.escolherAdesao,
          opcoes: [
            for (final a in AdesaoEmCasa.values)
              OpcaoSeletor(
                valor: a,
                rotulo: a.rotulo,
                icone: iconeDaAdesaoEmCasa(a),
                cores: CoresTerae.daAdesaoEmCasa(a),
              ),
          ],
        ),
        if (c.adesao == AdesaoEmCasa.naoFeito) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'O dia não permitiu. Tudo bem, é comum.',
            key: const Key('acolhimento-nao-deu'),
            style: textos.bodyMedium?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
        ],
        const SizedBox(height: MedidasTerae.espacoGrande),
        TextField(
          key: const Key('campo-reflexao'),
          controller: c.reflexao,
          minLines: 2,
          maxLines: 5,
          maxLength: RegistroDeAtividade.tamanhoMaximoDaReflexao,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Quer contar como foi? (opcional)',
            hintText: 'Uma conquista, uma dificuldade, o que ajudou.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: MedidasTerae.espaco),
        BotaoGrande(
          key: const Key('registrar-atividade'),
          rotulo: c.salvando
              ? 'Salvando…'
              : c.corrigindo
              ? 'Salvar a correção'
              : 'Registrar',
          icone: Icons.check,
          aoTocar: c.podeRegistrar ? c.registrar : null,
        ),
        if (c.corrigindo) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          BotaoGrande(
            key: const Key('cancelar-correcao'),
            rotulo: 'Cancelar',
            variante: VarianteBotao.secundario,
            aoTocar: c.salvando ? null : c.cancelarCorrecao,
          ),
        ],
        if (c.adesao == null) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Para registrar, escolha uma resposta.',
            textAlign: TextAlign.center,
            style: textos.bodySmall?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

class _RegistroDeHoje extends StatelessWidget {
  const _RegistroDeHoje({required this.controlador, required this.registro});

  final AtividadeControlador controlador;
  final RegistroDeAtividade registro;

  Future<void> _confirmarDesfazer(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer o registro de hoje?'),
        content: const Text(
          'A resposta de hoje deixa de valer. Você pode registrar de novo '
          'até o fim do dia.',
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-desfazer'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter'),
          ),
          TextButton(
            key: const Key('confirmar-desfazer'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desfazer'),
          ),
        ],
      ),
    );
    if (confirmou ?? false) await controlador.desfazer();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = controlador;
    return Cartao(
      key: const Key('registro-de-hoje'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Resposta de hoje:', style: textos.bodyMedium),
              EtiquetaDeAdesaoEmCasa(adesao: registro.adesao),
            ],
          ),
          if (registro.reflexao case final texto?) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text('"$texto"', style: textos.bodyLarge),
          ],
          if (registro.situacaoEnvio == SituacaoEnvio.naFila) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              'Guardado no aparelho. Vai para a clínica quando a conexão '
              'voltar.',
              key: const Key('registro-na-fila'),
              style: textos.bodySmall?.copyWith(color: CoresTerae.aviso900),
            ),
          ],
          const SizedBox(height: MedidasTerae.espaco),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: MedidasTerae.espacoPequeno,
            children: [
              OutlinedButton.icon(
                key: const Key('corrigir-atividade'),
                onPressed: c.salvando ? null : c.corrigir,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corrigir'),
              ),
              if (capacidadesDaFonte(context).desfazerEmCasa)
                OutlinedButton.icon(
                  key: const Key('desfazer-atividade'),
                  onPressed: c.salvando
                      ? null
                      : () => _confirmarDesfazer(context),
                  icon: const Icon(Icons.undo),
                  label: const Text('Desfazer'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemDoHistorico extends StatelessWidget {
  const _ItemDoHistorico({required this.registro});

  final RegistroDeAtividade registro;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatarDataCivilPorExtenso(registro.dia),
                style: textos.titleSmall,
              ),
              EtiquetaDeAdesaoEmCasa(adesao: registro.adesao),
            ],
          ),
          const SizedBox(height: 4),
          Text(registro.reflexao!, style: textos.bodyMedium),
        ],
      ),
    );
  }
}
