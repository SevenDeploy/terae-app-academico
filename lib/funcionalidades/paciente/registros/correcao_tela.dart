import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';
import 'correcao_controlador.dart';

/// TM15 — Corrigir registro (Atividade 4: atualização do item principal,
/// D13, D17). Empilhada sobre a TM14, com o id do registro na consulta.
///
/// As mesmas perguntas da TM03, já respondidas. Salvar segue a fila do
/// envio; se a correção deixar o registro crítico, abre a ajuda imediata
/// (TM05) na hora, como no cadastro (RFM04). Registro de outro dia não abre
/// para correção.
class CorrecaoTela extends StatelessWidget {
  const CorrecaoTela({super.key, required this.registroId});

  final String registroId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (contexto) => CorrecaoControlador(
        repositorio: contexto.read<RepositorioDiario>(),
        relogio: contexto.read<Relogio>(),
        registroId: registroId,
      )..carregar(),
      child: const _Correcao(),
    );
  }
}

class _Correcao extends StatelessWidget {
  const _Correcao();

  Future<void> _salvar(BuildContext context) async {
    final controlador = context.read<CorrecaoControlador>();
    final roteador = GoRouter.of(context);
    final resultado = await controlador.salvar();
    if (resultado == null) return;
    if (resultado.registro.intensidade.ehCritica) {
      roteador.go(Rotas.pacienteDiarioAjuda, extra: resultado);
    } else {
      roteador.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CorrecaoControlador>();
    return Scaffold(
      key: const Key('TM15'),
      appBar: AppBar(title: const Text('Corrigir registro')),
      body: c.carregando
          ? const Carregando()
          : CorpoDaTela(
              children: [
                if (c.podeCorrigir) ...[
                  CamposDoDiario(
                    adesao: c.adesao,
                    intensidade: c.intensidade,
                    sintoma: c.sintoma,
                    observacao: c.observacao,
                    aoMudarAdesao: c.escolherAdesao,
                    aoMudarIntensidade: c.escolherIntensidade,
                    aoMudarSintoma: c.escolherSintoma,
                  ),
                  const SizedBox(height: MedidasTerae.espaco),
                ],
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
                if (c.podeCorrigir)
                  BotaoGrande(
                    key: const Key('salvar-correcao'),
                    rotulo: c.salvando ? 'Salvando…' : 'Salvar correção',
                    icone: Icons.check,
                    aoTocar: c.podeSalvar
                        ? () => unawaited(_salvar(context))
                        : null,
                  ),
              ],
            ),
    );
  }
}
