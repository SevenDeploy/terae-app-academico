import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import 'componentes_registros.dart';
import 'registro_controlador.dart';

/// TM14 — Registro (Atividade 4: visualização e exclusão do item principal,
/// D13, D17). Empilhada sobre a TM13, com o id do registro na consulta.
///
/// Mostra dia e hora, as respostas, a situação do envio e se a equipe já foi
/// avisada — só quando o envio foi confirmado e houve alerta (§19). No mesmo
/// dia, "Corrigir" abre a TM15 e "Excluir" pede confirmação e faz a exclusão
/// lógica; depois disso, a TM14 explica que o registro é só de leitura.
class RegistroTela extends StatelessWidget {
  const RegistroTela({super.key, required this.registroId});

  final String registroId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (contexto) => RegistroControlador(
        repositorio: contexto.read<RepositorioDiario>(),
        relogio: contexto.read<Relogio>(),
        registroId: registroId,
      )..carregar(),
      child: Builder(
        builder: (contexto) => RecarregaAoSincronizar(
          aoMudar: () =>
              unawaited(contexto.read<RegistroControlador>().carregar()),
          child: const _Registro(),
        ),
      ),
    );
  }
}

class _Registro extends StatelessWidget {
  const _Registro();

  Future<void> _corrigir(BuildContext context, RegistroDiario r) async {
    final controlador = context.read<RegistroControlador>();
    final mensageiro = ScaffoldMessenger.of(context);
    final corrigiu = await context.push<bool>(Rotas.corrigirRegistro(r.id));
    if (corrigiu ?? false) {
      mensageiro.showSnackBar(
        const SnackBar(content: Text('Registro corrigido.')),
      );
    }
    await controlador.carregar();
  }

  Future<void> _excluir(BuildContext context) async {
    final controlador = context.read<RegistroControlador>();
    final navegador = GoRouter.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Excluir este registro?'),
        content: const Text(
          'Ele sai da sua lista. Se a equipe já foi avisada por causa dele, o '
          'aviso continua valendo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirmar-exclusao'),
            onPressed: () => Navigator.of(dialogo).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: CoresTerae.negativo700,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!(confirmou ?? false)) return;
    if (await controlador.excluir()) navegador.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RegistroControlador>();
    final registro = c.registro;
    return Scaffold(
      key: const Key('TM14'),
      appBar: AppBar(title: const Text('Registro do diário')),
      body: c.carregando && registro == null
          ? const Carregando()
          : registro == null
          ? CorpoDaTela(
              children: [
                AvisoDeFalha(
                  mensagem: c.erro ?? falhaAoCarregarRegistro,
                  aoTentarDeNovo: () => unawaited(c.carregar()),
                ),
              ],
            )
          : CorpoDaTela(
              children: [
                const AvisoDeConexao(),
                _Detalhes(registro: registro, equipeAvisada: c.alerta != null),
                const SizedBox(height: MedidasTerae.espacoGrande),
                if (c.erro case final erro?) ...[
                  Semantics(
                    liveRegion: true,
                    child: Cartaozinho(
                      cores: const ParDeCores(
                        CoresTerae.negativo700,
                        CoresTerae.negativo50,
                      ),
                      icone: Icons.error_outline,
                      children: [Text(erro)],
                    ),
                  ),
                  const SizedBox(height: MedidasTerae.espaco),
                ],
                if (c.podeAlterar) ...[
                  BotaoGrande(
                    key: const Key('corrigir-registro'),
                    rotulo: 'Corrigir',
                    icone: Icons.edit_outlined,
                    aoTocar: c.excluindo
                        ? null
                        : () => unawaited(_corrigir(context, registro)),
                  ),
                  const SizedBox(height: 12),
                  BotaoGrande(
                    key: const Key('excluir-registro'),
                    rotulo: c.excluindo ? 'Excluindo…' : 'Excluir',
                    icone: Icons.delete_outline,
                    variante: VarianteBotao.secundario,
                    aoTocar: c.excluindo
                        ? null
                        : () => unawaited(_excluir(context)),
                  ),
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                  Text(
                    'Você pode corrigir ou excluir até o fim do dia em que '
                    'registrou.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: CoresTerae.textoSecundario),
                  ),
                ] else if (!registro.excluido)
                  const Cartaozinho(
                    key: Key('registro-so-leitura'),
                    cores: ParDeCores(
                      CoresTerae.neutro700,
                      CoresTerae.neutro100,
                    ),
                    icone: Icons.lock_outline,
                    children: [
                      Text(
                        'Este registro é de outro dia e não pode mais ser '
                        'mudado. Se precisar, conte na próxima consulta.',
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.registro, required this.equipeAvisada});

  final RegistroDiario registro;
  final bool equipeAvisada;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final palavras = palavrasDoDiario(context);
    final atualizado = registro.atualizadoEm;
    final enviado = registro.situacaoEnvio == SituacaoEnvio.enviado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CabecalhoDaTela(
          titulo: formatarDiaPorExtenso(registro.registradoEm),
          subtitulo:
              'Registrado às ${formatarHora(registro.registradoEm)}'
              '${atualizado == null ? '' : ' · corrigido às ${formatarHora(atualizado)}'}',
        ),
        const SizedBox(height: MedidasTerae.espaco),
        Wrap(
          spacing: MedidasTerae.espacoPequeno,
          runSpacing: MedidasTerae.espacoPequeno,
          children: [
            EtiquetaDeIntensidade(registro.intensidade),
            EtiquetaDeEnvio(registro.situacaoEnvio),
            if (registro.excluido)
              const Etiqueta(
                texto: 'Excluído',
                cores: ParDeCores(
                  CoresTerae.negativo700,
                  CoresTerae.negativo50,
                ),
                icone: Icons.delete_outline,
              ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espaco),
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Linha(
                palavras.resumoAdesao,
                palavras.rotuloDaAdesao(registro.adesao),
              ),
              _Linha('Intensidade', registro.intensidade.rotulo),
              _Linha(
                palavras.resumoSintomaNoRegistro,
                registro.sintomaPredominante,
              ),
              _Linha(
                'Observação',
                registro.observacao ?? 'Sem observação',
                ultima: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: MedidasTerae.espaco),
        Text(
          !enviado
              ? 'Este registro ainda está no celular e vai para a equipe '
                    'quando houver conexão.'
              : equipeAvisada
              ? 'Sua equipe de saúde foi avisada por causa deste registro.'
              : 'Sua equipe de saúde já recebeu este registro.',
          style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro700),
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor, {this.ultima = false});

  final String rotulo;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: ultima ? 0 : MedidasTerae.espaco),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: textos.labelMedium?.copyWith(color: CoresTerae.neutro600),
            ),
            Text(valor, style: textos.bodyLarge),
          ],
        ),
      ),
    );
  }
}
