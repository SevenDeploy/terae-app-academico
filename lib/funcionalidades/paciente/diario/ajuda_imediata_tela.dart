import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/modelos/profissional_saude.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/faixa_emergencia.dart';
import 'resultado_provisorio.dart';

/// TM05 — Ajuda imediata. RFM04, §7.1. Tela cheia, fora das abas, no fundo de
/// severidade crítica: CVV 188 e SAMU 192 em destaque, com um toque.
///
/// "Seu profissional foi avisado" só aparece com `envio.equipeAvisada`
/// (envio confirmado e alerta criado pelo servidor, §19, §23). Na fila, ainda
/// sem resposta ou em link direto: "Envio pendente", com os contatos de
/// emergência mantidos em destaque. A tela abre antes da resposta e se
/// atualiza quando ela chega ([ResultadoProvisorio]). Se o envio falhar:
/// "Não conseguimos enviar", com "Tentar de novo" (o mesmo registro), e o
/// 188/192 continuam em destaque — o registro nunca se perde em silêncio.
///
/// "Ciente" faz `context.go(Rotas.pacienteInicio)`; o voltar do Android tem o
/// mesmo efeito (roteador). A `Key('TM05')` no Scaffold raiz faz parte do
/// contrato (testes de navegação).
class AjudaImediataTela extends StatelessWidget {
  const AjudaImediataTela({super.key, this.envio});

  /// Resultado do envio, vindo do diário por `extra`; nulo em link direto.
  final ResultadoEnvio? envio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('TM05'),
      backgroundColor: CoresTerae.sevCriticaFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: MedidasTerae.paddingTela,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExcludeSemantics(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CoresTerae.sevCritica,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Icon(
                          Icons.volunteer_activism,
                          color: CoresTerae.branco,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MedidasTerae.espaco),
                Semantics(
                  header: true,
                  child: Text(
                    'Procure ajuda agora',
                    textAlign: TextAlign.center,
                    style: textos.headlineMedium,
                  ),
                ),
                const SizedBox(height: MedidasTerae.espacoPequeno),
                Text(
                  'Você não está só. Fale agora com alguém que pode ajudar:',
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge?.copyWith(
                    color: CoresTerae.neutro700,
                  ),
                ),
                const SizedBox(height: MedidasTerae.espacoGrande),
                const FaixaEmergencia(destaque: true),
                const SizedBox(height: MedidasTerae.espacoGrande),
                AcompanharEnvio(
                  envio: envio,
                  construtor: (context, envio, andamento, tentarDeNovo) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SituacaoDoAviso(
                            avisada: envio?.equipeAvisada ?? false,
                            andamento: andamento,
                            semEnvio: envio == null,
                          ),
                          if (tentarDeNovo != null) ...[
                            const SizedBox(height: MedidasTerae.espaco),
                            BotaoGrande(
                              key: const Key('tentar-de-novo'),
                              rotulo: 'Tentar de novo',
                              icone: Icons.refresh,
                              variante: VarianteBotao.secundario,
                              aoTocar: tentarDeNovo,
                            ),
                          ],
                        ],
                      ),
                ),
                const SizedBox(height: MedidasTerae.espacoGrande),
                BotaoGrande(
                  key: const Key('ciente'),
                  rotulo: 'Ciente',
                  icone: Icons.check,
                  variante: VarianteBotao.secundario,
                  aoTocar: () => context.go(Rotas.pacienteInicio),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Seu profissional foi avisado" (só com a confirmação) ou "Envio pendente".
class _SituacaoDoAviso extends StatefulWidget {
  const _SituacaoDoAviso({
    required this.avisada,
    required this.andamento,
    required this.semEnvio,
  });

  final bool avisada;
  final AndamentoDoEnvio andamento;
  final bool semEnvio;

  @override
  State<_SituacaoDoAviso> createState() => _SituacaoDoAvisoState();
}

class _SituacaoDoAvisoState extends State<_SituacaoDoAviso> {
  ProfissionalSaude? _profissional;

  @override
  void initState() {
    super.initState();
    _carregarProfissional();
  }

  /// Nome do profissional de referência, para dizer a quem o aviso chegou.
  /// Sem ele, a frase fica sem o nome.
  Future<void> _carregarProfissional() async {
    final paciente = context.read<Sessao>().perfilAtivo?.paciente;
    if (paciente == null) return;
    try {
      final profissional = await context
          .read<RepositorioPaciente>()
          .profissional(paciente.profissionalRefId);
      if (mounted) setState(() => _profissional = profissional);
    } catch (_) {
      // Sem o nome, a confirmação continua valendo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final String titulo;
    final String detalhe;
    final IconData icone;
    final ParDeCores cores;
    if (widget.avisada) {
      titulo = 'Seu profissional foi avisado.';
      final nome = _profissional?.nome;
      detalhe = nome == null
          ? 'O aviso chegou à sua equipe.'
          : 'O aviso chegou para $nome.';
      icone = Icons.check_circle;
      cores = const ParDeCores(CoresTerae.clinico700, CoresTerae.clinico50);
    } else {
      titulo = widget.andamento == AndamentoDoEnvio.falhou && !widget.semEnvio
          ? 'Não conseguimos enviar'
          : 'Envio pendente';
      detalhe = switch (widget.andamento) {
        _ when widget.semEnvio =>
          'Se precisar, ligue agora para um dos contatos acima.',
        AndamentoDoEnvio.aguardando =>
          'Estamos enviando seu registro. Enquanto isso, se precisar, ligue '
              'para um dos contatos acima.',
        AndamentoDoEnvio.falhou =>
          'Seu registro ainda não chegou à equipe. Toque em "Tentar de '
              'novo". Se precisar, ligue agora para um dos contatos acima.',
        AndamentoDoEnvio.respondido =>
          'Sem internet agora. Seu registro está guardado e será enviado '
              'quando houver conexão. Se precisar, ligue para um dos '
              'contatos acima.',
      };
      icone = Icons.schedule;
      cores = const ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50);
    }
    return Semantics(
      key: const Key('situacao-aviso'),
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cores.fundo,
          borderRadius: const BorderRadius.all(
            Radius.circular(MedidasTerae.raioCartao),
          ),
          border: Border.all(color: cores.texto.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MedidasTerae.espaco),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icone, color: cores.texto)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cores.texto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detalhe,
                      style: TextStyle(fontSize: 16, color: cores.texto),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
