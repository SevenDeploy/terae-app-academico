import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import 'resultado_provisorio.dart';

/// Quanto a TM04 espera antes de voltar sozinha ao Início (§21).
const Duration esperaDaConfirmacao = Duration(seconds: 3);

/// TM04 — Diário enviado. RFM05. Tela cheia, fora das abas: confirmação e
/// resumo do que foi enviado. Volta sozinha ao Início 3 s depois que o envio
/// responde — exceto com `MediaQuery.accessibleNavigation` (leitor de tela,
/// D10, WCAG 2.2.1), que mostra só o botão "Voltar ao início". O voltar do
/// Android já leva ao Início (roteador).
///
/// Com o registro na fila (`naFila`, §19): "será enviado quando houver
/// conexão" — nunca "chegou à equipe". Enquanto o envio provisório não
/// responde: "Enviando…", sem volta automática. Se falhar: a falha, com
/// "Tentar de novo" (o mesmo registro), e a tela não volta sozinha.
///
/// A `Key('TM04')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class DiarioEnviadoTela extends StatefulWidget {
  const DiarioEnviadoTela({super.key, this.envio});

  /// Resultado do envio, vindo do diário por `extra`; nulo em link direto.
  final ResultadoEnvio? envio;

  @override
  State<DiarioEnviadoTela> createState() => _DiarioEnviadoTelaState();
}

class _DiarioEnviadoTelaState extends State<DiarioEnviadoTela> {
  Timer? _volta;
  bool _semVoltaAutomatica = false;

  /// O envio já respondeu (ou não há envio a esperar)?
  late bool _respondido = widget.envio is! ResultadoProvisorio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _semVoltaAutomatica = MediaQuery.accessibleNavigationOf(context);
    _armarVolta();
  }

  void _aoMudarAndamento(AndamentoDoEnvio andamento) {
    _respondido = andamento == AndamentoDoEnvio.respondido;
    _armarVolta();
  }

  /// A volta de 3 s só corre com o envio respondido e sem navegação
  /// acessível.
  void _armarVolta() {
    if (_semVoltaAutomatica || !_respondido) {
      _volta?.cancel();
      _volta = null;
    } else {
      _volta ??= Timer(esperaDaConfirmacao, _voltarAoInicio);
    }
  }

  void _voltarAoInicio() {
    _volta?.cancel();
    if (mounted) context.go(Rotas.pacienteInicio);
  }

  @override
  void dispose() {
    _volta?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('TM04'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: MedidasTerae.paddingTela,
            child: AcompanharEnvio(
              envio: widget.envio,
              aoMudarAndamento: _aoMudarAndamento,
              construtor: (context, envio, andamento, tentarDeNovo) {
                final naFila = envio != null && !envio.enviado;
                final (titulo, mensagem) = switch (envio) {
                  null => (
                    'Tudo certo',
                    'Volte ao início para continuar cuidando de você.',
                  ),
                  _ when andamento == AndamentoDoEnvio.falhou => (
                    'Registro não enviado',
                    'Não conseguimos enviar seu registro agora. Toque em '
                        '"Tentar de novo".',
                  ),
                  _ when andamento == AndamentoDoEnvio.aguardando => (
                    'Enviando…',
                    'A internet está lenta. Estamos enviando seu registro; '
                        'espere só um pouco.',
                  ),
                  _ when naFila => (
                    'Registro guardado',
                    'Sem internet agora. Seu registro está guardado no '
                        'aparelho e será enviado quando houver conexão.',
                  ),
                  _ => (
                    'Registro enviado!',
                    'Sua equipe vai ver o que você contou. Obrigado por '
                        'cuidar de você hoje.',
                  ),
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Selo(
                      naFila: naFila,
                      falhou: andamento == AndamentoDoEnvio.falhou,
                    ),
                    const SizedBox(height: MedidasTerae.espaco),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        titulo,
                        key: const Key('titulo-confirmacao'),
                        textAlign: TextAlign.center,
                        style: textos.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: MedidasTerae.espacoPequeno),
                    Text(
                      mensagem,
                      key: const Key('mensagem-confirmacao'),
                      textAlign: TextAlign.center,
                      style: textos.bodyLarge?.copyWith(
                        color: CoresTerae.neutro600,
                      ),
                    ),
                    if (envio != null) ...[
                      const SizedBox(height: MedidasTerae.espacoGrande),
                      _Resumo(registro: envio.registro),
                    ],
                    const SizedBox(height: MedidasTerae.espacoGrande),
                    if (tentarDeNovo != null) ...[
                      BotaoGrande(
                        key: const Key('tentar-de-novo'),
                        rotulo: 'Tentar de novo',
                        icone: Icons.refresh,
                        aoTocar: tentarDeNovo,
                      ),
                      const SizedBox(height: MedidasTerae.espacoPequeno),
                    ],
                    if (!_semVoltaAutomatica &&
                        andamento == AndamentoDoEnvio.respondido) ...[
                      Text(
                        'A tela inicial abre sozinha em instantes.',
                        textAlign: TextAlign.center,
                        style: textos.bodySmall?.copyWith(
                          color: CoresTerae.textoSecundario,
                        ),
                      ),
                      const SizedBox(height: MedidasTerae.espacoPequeno),
                    ],
                    BotaoGrande(
                      key: const Key('voltar-ao-inicio'),
                      rotulo: 'Voltar ao início',
                      icone: Icons.home_outlined,
                      variante: VarianteBotao.secundario,
                      aoTocar: _voltarAoInicio,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.naFila, required this.falhou});

  final bool naFila;
  final bool falhou;

  @override
  Widget build(BuildContext context) {
    final cores = naFila
        ? const ParDeCores(CoresTerae.aviso700, CoresTerae.aviso50)
        : const ParDeCores(CoresTerae.clinico600, CoresTerae.clinico50);
    return ExcludeSemantics(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: cores.fundo, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Icon(
              falhou
                  ? Icons.error_outline
                  : naFila
                  ? Icons.cloud_upload_outlined
                  : Icons.check_circle_outline,
              size: 56,
              color: cores.texto,
            ),
          ),
        ),
      ),
    );
  }
}

/// O que foi registrado: adesão, intensidade (cor + nome), sintoma e
/// observação.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.registro});

  final RegistroDiario registro;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    Widget linha(String rotulo, Widget valor) => Padding(
      padding: const EdgeInsets.only(top: MedidasTerae.espacoPequeno),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rotulo,
              style: textos.bodySmall?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            ),
            valor,
          ],
        ),
      ),
    );
    final observacao = registro.observacao;
    return Cartao(
      key: const Key('resumo-envio'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RotuloDeSecao(
            'O que você registrou',
            cor: CoresTerae.neutro600,
          ),
          linha(
            'Remédios',
            Text(registro.adesao.rotulo, style: textos.titleSmall),
          ),
          linha(
            'Intensidade',
            Align(
              alignment: Alignment.centerLeft,
              child: Etiqueta(
                texto: registro.intensidade.rotulo,
                cores: CoresTerae.daIntensidade(registro.intensidade),
              ),
            ),
          ),
          linha(
            'O que mais incomoda',
            Text(registro.sintomaPredominante, style: textos.titleSmall),
          ),
          if (observacao != null)
            linha('Observação', Text(observacao, style: textos.bodyMedium)),
        ],
      ),
    );
  }
}
