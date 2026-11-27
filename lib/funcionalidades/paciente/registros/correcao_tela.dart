import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import 'componentes_registros.dart';
import 'correcao_controlador.dart';
import 'registro_controlador.dart' show falhaAoCarregarRegistro;
import 'retirar_registro.dart';

/// TM15 — Corrigir registro (P3; quadro 18f do portal; D17 revista).
/// Empilhada sobre as abas, com o id do registro na consulta.
///
/// O mesmo formulário do registro novo, preenchido com a versão vigente.
/// "Salvar a correção" cria uma versão nova (a anterior fica guardada, e
/// quem lê vê que houve correção) e abre a TM04 ("Correção enviada.") ou,
/// se a correção avisou a equipe, a TM05. Corrigir pede internet: sem ela, o
/// botão fica travado com o motivo à vista. Revisado no meio (o 409 do
/// portal): "Este registro não pode mais mudar." e "Fazer um registro novo".
class CorrecaoTela extends StatelessWidget {
  const CorrecaoTela({super.key, required this.registroId});

  final String registroId;

  @override
  Widget build(BuildContext context) {
    final palavras = palavrasDoDiario(context);
    return ChangeNotifierProvider(
      create: (contexto) => CorrecaoControlador(
        repositorio: contexto.read<RepositorioDiario>(),
        registroId: registroId,
      )..carregar(),
      child: Scaffold(
        key: const Key('TM15'),
        appBar: AppBar(title: const Text('Corrigir registro')),
        body: _Correcao(palavras: palavras),
      ),
    );
  }
}

class _Correcao extends StatelessWidget {
  const _Correcao({required this.palavras});

  final TextosDoDiario palavras;

  Future<void> _salvar(BuildContext context) async {
    final roteador = GoRouter.of(context);
    final resultado = await context.read<CorrecaoControlador>().salvar();
    if (resultado == null) return;
    roteador.go(
      resultado.equipeAvisada
          ? Rotas.pacienteDiarioAjuda
          : Rotas.pacienteDiarioEnviado,
      extra: resultado,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CorrecaoControlador>();
    final registro = c.registro;
    final titulo = 'Corrigir registro${palavras.deQuemNoTitulo}';
    if (c.carregando && registro == null) return const Carregando();
    if (registro == null) {
      return CorpoDaTela(
        children: [
          AvisoDeFalha(
            mensagem: c.erro ?? falhaAoCarregarRegistro,
            aoTentarDeNovo: () => unawaited(c.carregar()),
          ),
        ],
      );
    }
    if (c.naoMudaMais) {
      return CorpoDaTela(
        children: [
          CabecalhoDaTela(titulo: titulo),
          const SizedBox(height: MedidasTerae.espaco),
          const AvisoNaoMudaMais(),
          const SizedBox(height: MedidasTerae.espaco),
          const Text(
            'A correção não foi salva. Se quiser contar algo a mais, faça um '
            'registro novo.',
            style: TextStyle(fontSize: 15, color: CoresTerae.neutro700),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          BotaoGrande(
            key: const Key('fazer-registro-novo'),
            rotulo: 'Fazer um registro novo',
            icone: LucideIcons.plus,
            aoTocar: () => context.pushReplacement(Rotas.pacienteNovoRegistro),
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          BotaoGrande(
            rotulo: 'Voltar ao diário',
            variante: VarianteBotao.secundario,
            aoTocar: () => context.go(Rotas.pacienteDiario),
          ),
        ],
      );
    }
    final agora = context.read<Relogio>().agora();
    final momento = formatarMomentoDoRegistro(
      registro.enviadoEm ?? registro.registradoEm,
      agora,
    );
    return CorpoDaTela(
      children: [
        const AvisoDeConexao(),
        CabecalhoDaTela(titulo: titulo),
        const SizedBox(height: MedidasTerae.espaco),
        const Cartaozinho(
          key: Key('aviso-versao-nova'),
          cores: ParDeCores(CoresTerae.info, CoresTerae.infoFundo),
          icone: LucideIcons.history,
          children: [
            Text(
              'Corrigir cria uma versão nova. A versão anterior fica '
              'guardada, e quem lê vê que houve correção.',
              style: TextStyle(fontSize: 15, color: CoresTerae.info),
            ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Text(
          'Registro de ${momento[0].toLowerCase()}${momento.substring(1)} · '
          'versão ${registro.versao}',
          key: const Key('registro-e-versao'),
          style: const TextStyle(fontSize: 14, color: CoresTerae.neutro600),
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        CamposDoDiario(respostas: c, palavras: palavras),
        const SizedBox(height: MedidasTerae.espaco),
        if (c.erro case final erro?) ...[
          Semantics(
            liveRegion: true,
            child: Cartaozinho(
              cores: const ParDeCores(CoresTerae.erro, CoresTerae.erroFundo),
              icone: LucideIcons.circleAlert,
              children: [
                Text(erro, style: const TextStyle(color: CoresTerae.erro)),
              ],
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
        ],
        ComConexao(
          construtor: (context, online) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BotaoGrande(
                key: const Key('salvar-correcao'),
                rotulo: c.salvando
                    ? 'Salvando…'
                    : online
                    ? 'Salvar a correção'
                    : 'Salvar a correção · precisa de internet',
                icone: online ? LucideIcons.check : LucideIcons.cloudOff,
                aoTocar: online && !c.salvando
                    ? () => unawaited(_salvar(context))
                    : null,
              ),
              if (!online) ...[
                const SizedBox(height: MedidasTerae.espacoPequeno),
                const Text(
                  'Para enviar, espere a internet voltar. O texto fica nesta '
                  'tela enquanto ela estiver aberta.',
                  key: Key('motivo-sem-internet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
                ),
              ],
              const SizedBox(height: MedidasTerae.espacoPequeno),
              BotaoGrande(
                key: const Key('cancelar-correcao'),
                rotulo: 'Cancelar',
                variante: VarianteBotao.secundario,
                aoTocar: () => context.canPop()
                    ? context.pop()
                    : context.go(Rotas.pacienteDiario),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
