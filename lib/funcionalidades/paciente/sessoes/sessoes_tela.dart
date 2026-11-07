import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/resposta_presenca.dart';
import '../../../dados/enums/situacao_agendamento.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/presenca_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../../nucleo/widgets/faixa_emergencia.dart';
import '../componentes_paciente.dart';
import '../registros/componentes_registros.dart';
import 'sessoes_controlador.dart';

/// Contato da clínica da demonstração (F2). **Número fictício**: começa com
/// 0, que não existe como número de telefone no Brasil, para nunca chamar
/// ninguém de verdade.
abstract final class ContatoDaClinica {
  static const String exibido = '(65) 0000-0000';
  static final Uri telefone = Uri(scheme: 'tel', path: '+556500000000');
  static final Uri whatsapp = Uri.https('wa.me', '/556500000000');
}

/// TM18 — Sessões (evolução de TO, F2; D27). Aberta pelo cartão da próxima
/// sessão no Início e por uma sessão ou consulta da Jornada: as marcadas, com "Vocês vão?" / "Você vai?" ("Sim,
/// vamos" ou "Não vamos conseguir", que só avisa a clínica e nunca cancela),
/// "Falar com a clínica" (ligar ou WhatsApp) e as anteriores.
///
/// Empilhada sobre as abas; voltar desempilha (o Início relê a resposta).
/// A `Key('TM18')` no Scaffold raiz faz parte do contrato.
class SessoesTela extends StatelessWidget {
  const SessoesTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM18'),
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            final navegador = Navigator.of(context);
            if (navegador.canPop()) {
              navegador.pop();
            } else {
              context.go(Rotas.pacienteInicio);
            }
          },
        ),
        title: Text(
          perfil == null
              ? 'Agenda'
              : _maiuscula(encontrosDoPaciente(perfil.paciente)),
        ),
      ),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => SessoesControlador(
                paciente: context.read<RepositorioPaciente>(),
                presenca: context.read<RepositorioPresenca>(),
                relogio: context.read<Relogio>(),
                pacienteId: perfil.pacienteId,
              )..carregar(),
              child: _ConteudoDasSessoes(perfil: perfil),
            ),
    );
  }
}

class _ConteudoDasSessoes extends StatelessWidget {
  const _ConteudoDasSessoes({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SessoesControlador>();
    final textos = Theme.of(context).textTheme;
    final paciente = perfil.paciente;
    final deOutro = perfil.falaDeOutraPessoa;
    final encontros = encontrosDoPaciente(paciente);
    // Como na TM13, TM14 e TM16: quando a fila sai, o "Guardado no aparelho"
    // vira a resposta enviada sem a pessoa precisar sair da tela.
    return RecarregaAoSincronizar(
      aoMudar: () => c.carregar(emSilencio: true),
      child: CorpoDaTela(
        aoAtualizar: c.atualizar,
        children: [
          const AvisoDeConexao(),
          CabecalhoDaTela(
            titulo: deOutro
                ? 'Agenda de ${paciente.primeiroNome}'
                : 'Sua agenda',
            subtitulo: deOutro
                ? 'Avise a clínica se vocês vão. Para remarcar, fale com ela.'
                : 'Avise a clínica se você vai. Para remarcar, fale com ela.',
          ),
          const SizedBox(height: MedidasTerae.espacoGrande),
          if (c.carregando)
            const Carregando()
          else if (c.falhou)
            AvisoDeFalha(
              mensagem: 'Não foi possível mostrar as $encontros agora.',
              aoTentarDeNovo: c.carregar,
            )
          else ...[
            const RotuloDeSecao('Próximas', icone: Icons.event),
            const SizedBox(height: MedidasTerae.espaco),
            if (c.proximas.isEmpty)
              Cartao(
                key: const Key('sem-proximas'),
                child: Text(
                  'Nenhuma ${palavraDoPaciente(paciente)} marcada. Fale com a '
                  'clínica para combinar.',
                  style: textos.bodyMedium,
                ),
              )
            else
              for (final a in c.proximas) ...[
                _CartaoDaProxima(agendamento: a, c: c, deOutro: deOutro),
                const SizedBox(height: MedidasTerae.espaco),
              ],
            const SizedBox(height: MedidasTerae.espaco),
            const _FalarComAClinica(),
            if (c.anteriores.isNotEmpty) ...[
              const SizedBox(height: MedidasTerae.espacoGrande),
              const RotuloDeSecao(
                'Anteriores',
                icone: Icons.history,
                cor: CoresTerae.neutro600,
              ),
              const SizedBox(height: MedidasTerae.espaco),
              for (final a in c.anteriores) ...[
                _LinhaDaAnterior(agendamento: a, c: c),
                const SizedBox(height: MedidasTerae.espacoPequeno),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _CartaoDaProxima extends StatelessWidget {
  const _CartaoDaProxima({
    required this.agendamento,
    required this.c,
    required this.deOutro,
  });

  final Agendamento agendamento;
  final SessoesControlador c;
  final bool deOutro;

  String _rotulo(RespostaPresenca r) =>
      deOutro ? r.rotulo : r.rotuloNaPrimeiraPessoa;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final a = agendamento;
    final profissional = c.profissionalDe(a);
    final resposta = c.respostaDe(a);
    final hoje = DataCivil.hoje(c.relogio);
    final ocupado = c.respondendo == a.id;
    return Cartao(
      key: Key('sessao-${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(nomeDoEncontro(profissional), style: textos.titleMedium),
          if (profissional != null)
            Text(
              'com ${profissional.nome}',
              style: textos.bodyMedium?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${formatarDiaPorExtenso(a.dataHora)} às '
            '${formatarHora(a.dataHora)}',
            style: textos.bodyMedium,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Align(
            alignment: Alignment.centerLeft,
            child: Etiqueta(
              texto: _maiuscula(
                descricaoRelativa(DataCivil.doInstante(a.dataHora), hoje: hoje),
              ),
            ),
          ),
          const Divider(height: MedidasTerae.espacoGrande),
          if (c.perguntando(a)) ...[
            Text(
              deOutro ? 'Vocês vão?' : 'Você vai?',
              style: textos.titleSmall,
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Wrap(
              spacing: MedidasTerae.espacoPequeno,
              runSpacing: MedidasTerae.espacoPequeno,
              children: [
                FilledButton.icon(
                  key: Key('vamos-${a.id}'),
                  onPressed: ocupado
                      ? null
                      : () => unawaited(c.responder(a, RespostaPresenca.vamos)),
                  icon: const Icon(Icons.check),
                  label: Text(_rotulo(RespostaPresenca.vamos)),
                ),
                OutlinedButton.icon(
                  key: Key('nao-vamos-${a.id}'),
                  onPressed: ocupado
                      ? null
                      : () => unawaited(
                          c.responder(a, RespostaPresenca.naoVamos),
                        ),
                  icon: const Icon(Icons.close),
                  label: Text(_rotulo(RespostaPresenca.naoVamos)),
                ),
              ],
            ),
          ] else if (resposta != null) ...[
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Etiqueta(
                      key: Key('resposta-${a.id}'),
                      icone: resposta.resposta == RespostaPresenca.vamos
                          ? Icons.check_circle_outline
                          : Icons.event_busy,
                      texto: _rotulo(resposta.resposta),
                      cores: resposta.resposta == RespostaPresenca.vamos
                          ? const ParDeCores(
                              CoresTerae.clinico700,
                              CoresTerae.clinico50,
                            )
                          : const ParDeCores(
                              CoresTerae.aviso900,
                              CoresTerae.aviso50,
                            ),
                    ),
                  ),
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                  Text(
                    resposta.situacaoEnvio == SituacaoEnvio.naFila
                        ? 'Guardado no aparelho. Vai para a clínica quando a '
                              'conexão voltar.'
                        : resposta.resposta == RespostaPresenca.vamos
                        ? 'A clínica recebeu sua resposta.'
                        : 'A clínica foi avisada. A '
                              '${palavraDoEncontro(profissional)} continua '
                              'marcada até vocês combinarem outra data.',
                    style: textos.bodyMedium,
                  ),
                ],
              ),
            ),
            if (c.podeMudar(a)) ...[
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('mudar-${a.id}'),
                  onPressed: () => c.mudarResposta(a),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Mudar a resposta'),
                ),
              ),
            ],
          ],
          if (c.erroDe(a) case final erro?) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Semantics(
              liveRegion: true,
              child: Text(
                erro,
                style: textos.bodyMedium?.copyWith(
                  color: CoresTerae.negativo700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FalarComAClinica extends StatelessWidget {
  const _FalarComAClinica();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lancador = context.read<LancadorExterno>();
    return Cartao(
      key: const Key('falar-com-a-clinica'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao(
            'Falar com a clínica',
            icone: Icons.support_agent,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Para remarcar, tirar uma dúvida ou avisar um imprevisto.',
            style: textos.bodyMedium,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: MedidasTerae.espacoPequeno,
            children: [
              OutlinedButton.icon(
                key: const Key('ligar-para-a-clinica'),
                onPressed: () =>
                    unawaited(lancador.abrir(ContatoDaClinica.telefone)),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Ligar'),
              ),
              OutlinedButton.icon(
                key: const Key('whatsapp-da-clinica'),
                onPressed: () =>
                    unawaited(lancador.abrir(ContatoDaClinica.whatsapp)),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
            ],
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            '${ContatoDaClinica.exibido} · número fictício da demonstração',
            style: textos.bodySmall?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaDaAnterior extends StatelessWidget {
  const _LinhaDaAnterior({required this.agendamento, required this.c});

  final Agendamento agendamento;
  final SessoesControlador c;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final a = agendamento;
    final profissional = c.profissionalDe(a);
    final cancelada = a.situacao == SituacaoAgendamento.cancelado;
    return Cartao(
      key: Key('anterior-${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            profissional == null
                ? nomeDoEncontro(null)
                : '${nomeDoEncontro(profissional)} com ${profissional.nome}',
            style: textos.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(formatarData(a.dataHora), style: textos.bodySmall),
              // Marcada que já passou e a clínica ainda não fechou: sem
              // etiqueta (não é "realizada" nem "cancelada").
              if (a.situacao != SituacaoAgendamento.agendado)
                Etiqueta(
                  texto: cancelada ? 'Cancelada' : 'Realizada',
                  cores: cancelada
                      ? const ParDeCores(
                          CoresTerae.negativo700,
                          CoresTerae.negativo50,
                        )
                      : const ParDeCores(
                          CoresTerae.neutro700,
                          CoresTerae.neutro100,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _maiuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
