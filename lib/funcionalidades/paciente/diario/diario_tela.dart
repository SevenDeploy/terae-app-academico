import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import '../registros/componentes_registros.dart';
import '../registros/retirar_registro.dart';
import 'campos_do_diario.dart';
import 'diario_controlador.dart';

/// TM03 — Diário (aba 2; P3, quadro 18e do portal da família). RFM03.
///
/// - **A lista** dos registros que chegaram, do mais novo ao mais antigo, 30
///   por vez ("Ver registros mais antigos"), cada um com a situação em ícone
///   e palavra: aguardando quem lê, revisado, a equipe foi avisada, retirado.
/// - **"Corrigir" e "Retirar"** só enquanto o registro pode mudar
///   (`podeAlterar`, D17 revista). O retirado continua na lista, tachado, com
///   o motivo: nada é apagado.
/// - **"Guardados neste aparelho"**: os registros feitos sem internet, com
///   "Enviar agora".
/// - "Novo registro" abre a TM13; vazio, "Fazer o primeiro registro".
///
/// A `Key('TM03')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class DiarioTela extends StatelessWidget {
  const DiarioTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM03'),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => DiarioControlador(
                repositorio: context.read<RepositorioDiario>(),
                pacienteId: perfil.pacienteId,
              )..carregar(),
              child: Builder(
                builder: (contexto) {
                  void recarregar() =>
                      unawaited(contexto.read<DiarioControlador>().carregar());
                  return RecarregaAoVoltar(
                    rota: Rotas.pacienteDiario,
                    aoVoltar: recarregar,
                    child: RecarregaAoSincronizar(
                      aoMudar: recarregar,
                      child: _Lista(palavras: TextosDoDiario.para(perfil)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.palavras});

  final TextosDoDiario palavras;

  Future<void> _retirar(BuildContext context, RegistroDiario r) async {
    final controlador = context.read<DiarioControlador>()..esquecerRetirada();
    final agora = context.read<Relogio>().agora();
    final retirou = await mostrarRetirarRegistro(
      context,
      registro: r,
      quando: formatarMomentoDoRegistro(regra.momentoNaLista(r), agora),
    );
    if (retirou) await controlador.aoRetirar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiarioControlador>();
    final agora = context.read<Relogio>().agora();
    return CorpoDaTela(
      aoAtualizar: c.enviarPendentes,
      children: [
        const AvisoDeConexao(),
        CabecalhoDaTela(
          titulo: palavras.tituloDoDiario,
          subtitulo: palavras.subtituloDoDiario,
        ),
        const SizedBox(height: MedidasTerae.espaco),
        BotaoGrande(
          key: const Key('novo-registro'),
          rotulo: 'Novo registro',
          icone: LucideIcons.plus,
          aoTocar: () {
            c.esquecerRetirada();
            context.push(Rotas.pacienteNovoRegistro);
          },
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                LucideIcons.info,
                size: 15,
                color: CoresTerae.neutro600,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aqui ficam os registros que você enviou pelo app.',
                style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
              ),
            ),
          ],
        ),
        const SizedBox(height: MedidasTerae.espaco),
        if (c.retirou) ...[
          const Cartaozinho(
            key: Key('aviso-retirado'),
            cores: ParDeCores(CoresTerae.sucesso, CoresTerae.sucessoFundo),
            icone: LucideIcons.archive,
            children: [
              Text(
                'Registro retirado. Ele continua na lista, marcado como '
                'retirado, com o motivo.',
                style: TextStyle(fontSize: 15, color: CoresTerae.sucesso),
              ),
            ],
          ),
          const SizedBox(height: MedidasTerae.espaco),
        ],
        if (c.pendentes.isNotEmpty) ...[
          _Pendentes(palavras: palavras, agora: agora),
          const SizedBox(height: MedidasTerae.espacoGrande),
        ],
        if (c.carregando)
          const Carregando()
        else if (c.erro case final erro?)
          AvisoDeFalha(
            mensagem: erro,
            aoTentarDeNovo: () => unawaited(c.carregar()),
          )
        else if (c.registros.isEmpty && c.pendentes.isEmpty)
          Cartao(
            key: const Key('diario-vazio'),
            padding: EdgeInsets.zero,
            child: EstadoVazio(
              icone: LucideIcons.notebookPen,
              titulo: 'Você ainda não fez nenhum registro.',
              descricao:
                  'Conte como foi ${palavras.oDia}: o que deu para fazer e o '
                  'que você observou. A ${palavras.quemLe} lê.',
              acao: FilledButton.icon(
                key: const Key('primeiro-registro'),
                onPressed: () => context.push(Rotas.pacienteNovoRegistro),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Fazer o primeiro registro'),
              ),
            ),
          )
        else ...[
          Semantics(
            label: 'Registros ${palavras.tituloDoDiario.toLowerCase()}',
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, r) in c.registros.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  CartaoDoRegistro(
                    registro: r,
                    agora: agora,
                    palavras: palavras,
                    aoCorrigir: () {
                      c.esquecerRetirada();
                      context.push(Rotas.corrigirRegistro(r.id));
                    },
                    aoRetirar: () => unawaited(_retirar(context, r)),
                  ),
                ],
              ],
            ),
          ),
          if (c.erroDosAntigos case final erro?) ...[
            const SizedBox(height: 12),
            Text(erro, style: const TextStyle(color: CoresTerae.erro)),
          ],
          if (c.haMais) ...[
            const SizedBox(height: MedidasTerae.espaco),
            BotaoGrande(
              key: const Key('ver-mais-antigos'),
              rotulo: c.carregandoMais
                  ? 'Abrindo…'
                  : 'Ver registros mais antigos',
              variante: VarianteBotao.secundario,
              aoTocar: c.carregandoMais
                  ? null
                  : () => unawaited(c.verMaisAntigos()),
            ),
          ],
        ],
      ],
    );
  }
}

/// Os registros guardados para enviar depois, no alto da lista (19d do
/// portal): cada um com "Guardado, aguardando a internet", a hora em que foi
/// guardado e o que foi escrito (o toque abre a TM14); "Enviar agora" tenta
/// já.
class _Pendentes extends StatelessWidget {
  const _Pendentes({required this.palavras, required this.agora});

  final TextosDoDiario palavras;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DiarioControlador>();
    return ComConexao(
      construtor: (context, online) => Column(
        key: const Key('pendentes-do-diario'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Guardados neste aparelho',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CoresTerae.neutro900,
              ),
            ),
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          BotaoGrande(
            key: const Key('enviar-agora'),
            rotulo: c.enviandoPendentes ? 'Enviando…' : 'Enviar agora',
            icone: LucideIcons.send,
            variante: VarianteBotao.secundario,
            aoTocar: online && !c.enviandoPendentes
                ? () => unawaited(c.enviarPendentes())
                : null,
          ),
          if (!online) ...[
            const SizedBox(height: 6),
            const Text(
              'Sem internet agora. Eles vão sozinhos quando a internet voltar.',
              style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
            ),
          ],
          for (final r in c.pendentes) ...[
            const SizedBox(height: 12),
            Cartao(
              key: ValueKey('pendente-${r.id}'),
              padding: const EdgeInsets.all(MedidasTerae.espaco),
              aoTocar: () => context.push(Rotas.registro(r.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Selo(
                      texto: 'Guardado, aguardando a internet',
                      tom: TomDoSelo.atencao,
                      icone: LucideIcons.cloudOff,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guardado em '
                    '${formatarMomentoDoRegistro(r.registradoEm, agora)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CoresTerae.neutro600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    palavras.adesaoNaLista(r.adesao),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CoresTerae.neutro800,
                    ),
                  ),
                  if (r.sintomas case final s?) ...[
                    const SizedBox(height: 4),
                    Text(
                      s,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CoresTerae.neutro800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
