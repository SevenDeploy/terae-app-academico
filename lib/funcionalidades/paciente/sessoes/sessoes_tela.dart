import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/situacao_agendamento.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/paciente.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/presenca_repositorio.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../../nucleo/widgets/faixa_emergencia.dart';
import '../componentes_paciente.dart';
import '../registros/componentes_registros.dart';
import 'componentes_sessao.dart';
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
/// A aba "Agenda" da moldura (como `/portal/agenda`).
/// A `Key('TM18')` no Scaffold raiz faz parte do contrato.
class SessoesTela extends StatelessWidget {
  const SessoesTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM18'),
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
            if (c.proximas.isEmpty)
              Cartao(
                key: const Key('sem-proximas'),
                child: Text(
                  semEncontros(
                    paciente,
                    'Nenhuma ${palavraDoPaciente(paciente)} marcada. Fale com '
                    'a clínica para combinar.',
                  ),
                  style: textos.bodyMedium,
                ),
              )
            else
              for (final semana in c.semanas) ...[
                Semantics(
                  header: true,
                  child: Text(
                    semana.titulo,
                    key: Key('semana-${semana.segunda.paraIso()}'),
                    style: textos.titleSmall?.copyWith(
                      color: CoresTerae.neutro800,
                    ),
                  ),
                ),
                const SizedBox(height: MedidasTerae.espacoPequeno),
                for (final a in semana.sessoes) ...[
                  _CartaoDaProxima(agendamento: a, c: c, deOutro: deOutro),
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                ],
                const SizedBox(height: MedidasTerae.espacoPequeno),
              ],
            const SizedBox(height: MedidasTerae.espacoPequeno),
            _FalarComAClinica(paciente: paciente),
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

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final profissional = c.profissionalDe(a);
    return Cartao(
      key: Key('sessao-${a.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResumoDaSessao(agendamento: a, profissional: profissional),
          const SizedBox(height: 12),
          RespostasDaSessao(
            agendamento: a,
            profissional: profissional,
            resposta: c.respostaDe(a),
            perguntando: c.perguntando(a),
            podeMudar: c.podeMudar(a),
            ocupado: c.respondendo == a.id,
            erro: c.erroDe(a),
            deOutro: deOutro,
            aoResponder: (r) => c.responder(a, r),
            aoMudar: () => c.mudarResposta(a),
            chaveDoSelo: Key('resposta-${a.id}'),
          ),
        ],
      ),
    );
  }
}

class _FalarComAClinica extends StatelessWidget {
  const _FalarComAClinica({required this.paciente});

  final Paciente paciente;

  /// O telefone do portal só vale com pelo menos 8 dígitos (vazio, "abc" ou
  /// "--" viram "sem número", nunca um `tel:` vazio).
  static String? _telefoneValido(String? telefone) {
    if (telefone == null) return null;
    final digitos = telefone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitos.length >= 8 ? telefone : null;
  }

  /// `tel:+556530000000` a partir de "+55 65 3000-0000".
  static Uri _tel(String telefone) =>
      Uri(scheme: 'tel', path: telefone.replaceAll(RegExp(r'[^0-9+]'), ''));

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lancador = context.read<LancadorExterno>();
    // O Terae local manda o nome e o telefone da clínica no /eu; o Firebase
    // não, e lá vale o número fictício da demonstração.
    final doPortal =
        paciente.nomeDaClinica != null || paciente.telefoneDaClinica != null;
    final telefone = _telefoneValido(paciente.telefoneDaClinica);
    final semNumero = doPortal && telefone == null;
    return Cartao(
      key: const Key('falar-com-a-clinica'),
      titulo: 'Falar com a clínica',
      icone: LucideIcons.building2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            semNumero
                ? 'Para remarcar ou tirar dúvidas, fale com a clínica.'
                : 'Para remarcar, tirar uma dúvida ou avisar um imprevisto.',
            style: textos.bodyMedium,
          ),
          if (!semNumero) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Wrap(
              spacing: MedidasTerae.espacoPequeno,
              runSpacing: MedidasTerae.espacoPequeno,
              children: [
                OutlinedButton.icon(
                  key: const Key('ligar-para-a-clinica'),
                  onPressed: () => unawaited(
                    lancador.abrir(
                      telefone == null
                          ? ContatoDaClinica.telefone
                          : _tel(telefone),
                    ),
                  ),
                  icon: const Icon(LucideIcons.phone, size: 18),
                  label: const Text('Ligar'),
                ),
                // O portal não diz se o número atende por WhatsApp: só a
                // demonstração do Firebase oferece.
                if (!doPortal)
                  OutlinedButton.icon(
                    key: const Key('whatsapp-da-clinica'),
                    onPressed: () =>
                        unawaited(lancador.abrir(ContatoDaClinica.whatsapp)),
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: const Text('WhatsApp'),
                  ),
              ],
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              doPortal
                  ? telefone!
                  : '${ContatoDaClinica.exibido} · número fictício da '
                        'demonstração',
              key: const Key('telefone-da-clinica'),
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
