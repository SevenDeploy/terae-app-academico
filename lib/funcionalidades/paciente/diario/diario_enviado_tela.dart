import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../../../nucleo/widgets/faixa_emergencia.dart';
import '../registros/componentes_registros.dart';
import 'campos_do_diario.dart';
import 'resultado_provisorio.dart';

/// TM04 — Diário enviado (P3; quadros 18f "Registro enviado" e 19d "Registro
/// guardado" do portal). RFM05. Tela cheia, fora das abas.
///
/// - **Enviado**: "Registro enviado." (ou "Correção enviada.", da versão 2
///   em diante), o recibo com as quatro respostas e, enquanto o registro
///   pode mudar, "Corrigir agora" ao lado de "Voltar ao início".
/// - **Guardado** (`naFila`, §19): "Registro guardado neste aparelho." — diz
///   com todas as letras que ainda não foi enviado. Se ele disse "Bastante"
///   ou "Muito", os números de emergência vêm antes: a equipe só é avisada
///   quando o registro chegar.
/// - Enquanto o envio provisório não responde: "Enviando…". Se falhar: a
///   falha, com "Tentar de novo" (o mesmo registro).
///
/// O voltar do Android leva ao Início (roteador). A `Key('TM04')` no
/// Scaffold raiz faz parte do contrato (testes de navegação).
class DiarioEnviadoTela extends StatelessWidget {
  const DiarioEnviadoTela({super.key, this.envio});

  /// Resultado do envio, vindo do formulário por `extra`; nulo em link
  /// direto.
  final ResultadoEnvio? envio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final palavras = palavrasDoDiario(context);
    return Scaffold(
      key: const Key('TM04'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: MedidasTerae.paddingTela,
            child: AcompanharEnvio(
              envio: envio,
              construtor: (context, envio, andamento, tentarDeNovo) {
                final registro = envio?.registro;
                final naFila = envio != null && !envio.enviado;
                final falhou = andamento == AndamentoDoEnvio.falhou;
                final (titulo, mensagem) = switch (envio) {
                  null => (
                    'Tudo certo',
                    'Volte ao início para continuar cuidando de você.',
                  ),
                  _ when falhou => (
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
                    'Registro guardado neste aparelho.',
                    'Ele ainda não foi enviado. Quando a internet voltar, '
                        'enviamos, e você vê no diário. '
                        '${palavras.quemLeNaFrase} só lê depois que ele for '
                        'enviado.',
                  ),
                  _ => (
                    envio.registro.versao > 1
                        ? 'Correção enviada.'
                        : 'Registro enviado.',
                    '${palavras.quemLeNaFrase} vai ler com atenção.',
                  ),
                };
                final podeMudar =
                    registro != null &&
                    !naFila &&
                    andamento == AndamentoDoEnvio.respondido &&
                    regra.podeAlterar(registro);
                final comAjuda =
                    naFila &&
                    (registro?.intensidadeSintoma?.pedeAjudaSemInternet ??
                        false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Simbolo(naFila: naFila, falhou: falhou),
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
                    if (comAjuda) ...[
                      const SizedBox(height: MedidasTerae.espacoGrande),
                      Semantics(
                        header: true,
                        child: const Text(
                          'Se for urgente, não espere a internet',
                          key: Key('ajuda-sem-internet'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CoresTerae.neutro900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'A equipe da clínica só é avisada quando o registro '
                        'for enviado. Para uma situação de risco agora, '
                        'ligue:',
                        style: TextStyle(
                          fontSize: 15,
                          color: CoresTerae.neutro700,
                        ),
                      ),
                      const SizedBox(height: MedidasTerae.espacoPequeno),
                      const FaixaEmergencia(destaque: true),
                    ],
                    if (registro != null) ...[
                      const SizedBox(height: MedidasTerae.espacoGrande),
                      _Recibo(registro: registro, palavras: palavras),
                    ],
                    if (podeMudar) ...[
                      const SizedBox(height: MedidasTerae.espaco),
                      Cartao(
                        corFundo: CoresTerae.neutro50,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExcludeSemantics(
                              child: Icon(
                                LucideIcons.pencil,
                                size: 18,
                                color: CoresTerae.neutro700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enquanto a ${palavras.quemLe} não revisar, '
                                'você pode corrigir ou retirar este registro '
                                'no diário.',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: CoresTerae.neutro700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: MedidasTerae.espacoGrande),
                    if (tentarDeNovo != null) ...[
                      BotaoGrande(
                        key: const Key('tentar-de-novo'),
                        rotulo: 'Tentar de novo',
                        icone: LucideIcons.rotateCw,
                        aoTocar: tentarDeNovo,
                      ),
                      const SizedBox(height: MedidasTerae.espacoPequeno),
                    ],
                    if (naFila)
                      BotaoGrande(
                        key: const Key('ver-no-diario'),
                        rotulo: 'Ver no diário',
                        aoTocar: () => context.go(Rotas.pacienteDiario),
                      )
                    else
                      BotaoGrande(
                        key: const Key('voltar-ao-inicio'),
                        rotulo: 'Voltar ao início',
                        variante: tentarDeNovo == null
                            ? VarianteBotao.primario
                            : VarianteBotao.secundario,
                        aoTocar: () => context.go(Rotas.pacienteInicio),
                      ),
                    if (podeMudar) ...[
                      const SizedBox(height: MedidasTerae.espacoPequeno),
                      BotaoGrande(
                        key: const Key('corrigir-agora'),
                        rotulo: 'Corrigir agora',
                        icone: LucideIcons.pencil,
                        variante: VarianteBotao.secundario,
                        aoTocar: () =>
                            context.push(Rotas.corrigirRegistro(registro.id)),
                      ),
                    ],
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

class _Simbolo extends StatelessWidget {
  const _Simbolo({required this.naFila, required this.falhou});

  final bool naFila;
  final bool falhou;

  @override
  Widget build(BuildContext context) {
    final cores = falhou
        ? const ParDeCores(CoresTerae.erro, CoresTerae.erroFundo)
        : naFila
        ? const ParDeCores(CoresTerae.info, CoresTerae.infoFundo)
        : const ParDeCores(CoresTerae.sucesso, CoresTerae.sucessoFundo);
    return ExcludeSemantics(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: cores.fundo, shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Icon(
              falhou
                  ? LucideIcons.circleAlert
                  : naFila
                  ? LucideIcons.cloudOff
                  : LucideIcons.check,
              size: 30,
              color: cores.texto,
            ),
          ),
        ),
      ),
    );
  }
}

/// O recibo do 18f: as quatro respostas, com "Nada a contar", "Sem
/// resposta" e "Sem observação" para as opcionais em branco.
class _Recibo extends StatelessWidget {
  const _Recibo({required this.registro, required this.palavras});

  final RegistroDiario registro;
  final TextosDoDiario palavras;

  @override
  Widget build(BuildContext context) {
    final intensidade = registro.intensidadeSintoma;
    Widget item(
      String termo,
      Widget valor, {
      bool ultimo = false,
    }) => MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: ultimo
              ? null
              : const Border(bottom: BorderSide(color: CoresTerae.neutro100)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              termo,
              style: const TextStyle(fontSize: 14, color: CoresTerae.neutro600),
            ),
            const SizedBox(height: 2),
            valor,
          ],
        ),
      ),
    );
    const forte = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: CoresTerae.neutro900,
    );
    return Cartao(
      key: const Key('resumo-envio'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          item(
            palavras.termoDaAdesao,
            Text(palavras.tituloDaAdesao(registro.adesao), style: forte),
          ),
          item(
            'O que você contou',
            Text(registro.sintomas ?? 'Nada a contar', style: forte),
          ),
          item(
            'O quanto atrapalhou',
            intensidade == null
                ? const Text('Sem resposta', style: forte)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: SeloDaIntensidade(intensidade, curto: true),
                  ),
          ),
          item(
            'Observações',
            Text(registro.observacoes ?? 'Sem observação', style: forte),
            ultimo: true,
          ),
        ],
      ),
    );
  }
}
