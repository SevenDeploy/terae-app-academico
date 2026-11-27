import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/faixa_emergencia.dart';
import '../../nucleo/widgets/selo_academico.dart';
import '../autenticacao/moldura_de_entrada.dart';
import '../autenticacao/primeiro_acesso.dart';
import '../capacidades.dart';
import 'folha_inferior.dart';
import 'painel_demonstracao.dart';

/// TM00 — Boas-vindas (RFM10), com o painel marinho da entrada do portal da
/// família (`MolduraDeEntrada.tsx`, 18a): "O acompanhamento continua em
/// casa.", os três destaques (Programa em casa, Diário, Agenda), "Entrar"
/// (TM01), "Primeiro acesso" (TM09 ou TM10), a política de privacidade, o
/// selo acadêmico (D1b) e a faixa fixa do CVV 188 e do SAMU 192, que liga com
/// um toque sem login (§7.1). Pública e sem nenhum dado pessoal.
///
/// O painel de demonstração (D11) só aparece com [modoDepuracao], que por
/// padrão é `kDebugMode` — na versão de release ele não existe.
class BoasVindasTela extends StatelessWidget {
  const BoasVindasTela({super.key, this.modoDepuracao = kDebugMode});

  /// Mostra o acesso ao painel de demonstração (D11).
  final bool modoDepuracao;

  @override
  Widget build(BuildContext context) {
    final capacidades = capacidadesDaFonte(context);
    // Fundo marinho: relógio e ícones da barra de status em claro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('TM00'),
        backgroundColor: CoresTerae.marinho900,
        // A Column dá altura livre à faixa: no slot do rodapé a altura é
        // limitada à tela, e o `Center` de cada contato ocuparia tudo.
        bottomNavigationBar: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [FaixaEmergencia()],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: MarcaDoPortal(grande: true)),
                    if (modoDepuracao && capacidades.demonstracao)
                      IconButton(
                        key: const Key('abrir-painel-demonstracao'),
                        tooltip: 'Painel de demonstração',
                        icon: const Icon(
                          LucideIcons.slidersHorizontal,
                          color: CoresTerae.marinho200,
                        ),
                        onPressed: () =>
                            unawaited(abrirPainelDemonstracao(context)),
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                Semantics(
                  header: true,
                  child: const Text(
                    'O acompanhamento continua em casa.',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 30,
                      height: 38 / 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.75,
                      color: CoresTerae.branco,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'As orientações das terapeutas, o diário e as próximas '
                  'sessões num lugar só.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 26 / 16,
                    color: CoresTerae.marinho200,
                  ),
                ),
                const SizedBox(height: 28),
                for (final (icone, titulo, texto) in _fatos) ...[
                  _Fato(icone: icone, titulo: titulo, texto: texto),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                BotaoGrande(
                  key: const Key('ir-entrar'),
                  rotulo: 'Entrar',
                  icone: LucideIcons.logIn,
                  aoTocar: () => unawaited(context.push(Rotas.entrar)),
                ),
                if (capacidades.primeiroAcesso) ...[
                  const SizedBox(height: 12),
                  BotaoGrande(
                    key: const Key('ir-primeiro-acesso'),
                    rotulo: 'Primeiro acesso',
                    icone: LucideIcons.keyRound,
                    variante: VarianteBotao.secundario,
                    aoTocar: () => unawaited(abrirPrimeiroAcesso(context)),
                  ),
                ],
                const SizedBox(height: MedidasTerae.espaco),
                Center(
                  child: TextButton(
                    key: const Key('politica-privacidade'),
                    style: TextButton.styleFrom(
                      foregroundColor: CoresTerae.branco,
                    ),
                    onPressed: () =>
                        unawaited(abrirPoliticaDePrivacidade(context)),
                    child: const Text('Política de privacidade'),
                  ),
                ),
                const SizedBox(height: MedidasTerae.espaco),
                const Center(child: SeloAcademico()),
                const SizedBox(height: 12),
                const Text(
                  'A conta nasce pelo convite da clínica · LGPD',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: CoresTerae.marinho200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O que o painel afirma: só o que o app cumpre (como os fatos do 18a).
const List<(IconData, String, String)> _fatos = [
  (
    LucideIcons.house,
    'Programa em casa',
    'As orientações que a terapeuta publicou.',
  ),
  (LucideIcons.bookHeart, 'Diário', 'Conte como foram os dias. A equipe lê.'),
  (
    LucideIcons.calendarCheck,
    'Agenda',
    'Confirme a presença ou avise quando não der.',
  ),
];

class _Fato extends StatelessWidget {
  const _Fato({required this.icone, required this.titulo, required this.texto});

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CoresTerae.branco.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: ExcludeSemantics(
              child: Icon(icone, size: 18, color: CoresTerae.clinico300),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CoresTerae.branco,
                  ),
                ),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: CoresTerae.marinho200,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumo da política de privacidade em linguagem simples (RNFM01, RNFM04).
Future<void> abrirPoliticaDePrivacidade(BuildContext context) =>
    mostrarFolha<void>(
      context: context,
      titulo: 'Política de privacidade',
      construtor: (folha) {
        final textos = Theme.of(folha).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (titulo, texto) in _politica) ...[
              Text(titulo, style: textos.titleSmall),
              const SizedBox(height: 2),
              Text(texto, style: textos.bodyMedium),
              const SizedBox(height: MedidasTerae.espaco),
            ],
          ],
        );
      },
    );

const List<(String, String)> _politica = [
  (
    'Projeto acadêmico',
    'Este aplicativo é um trabalho da UNEMAT. Os dados são fictícios, de '
        'demonstração, e ficam num serviço de nuvem só da disciplina.',
  ),
  (
    'A sua senha',
    'Você entra com e-mail e senha. A senha não fica guardada no celular: '
        'quem confere é o serviço de login.',
  ),
  (
    'Quem vê os seus dados',
    'Você e a sua equipe de saúde. Se você autorizar, até dois cuidadores '
        'veem a agenda, os remédios e os avisos, mas nunca o diário.',
  ),
  (
    'Você decide',
    'Você pode remover um cuidador quando quiser. Para retirar o '
        'consentimento, fale com a clínica.',
  ),
];
