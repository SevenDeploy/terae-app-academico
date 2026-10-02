import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/faixa_emergencia.dart';
import '../../nucleo/widgets/selo_academico.dart';
import '../autenticacao/primeiro_acesso.dart';
import 'folha_inferior.dart';
import 'painel_demonstracao.dart';

/// TM00 — Boas-vindas (RFM10). Pública e sem nenhum dado pessoal: marca,
/// frase de propósito, "Entrar" (TM01), "Primeiro acesso" (TM09 ou TM10),
/// política de privacidade, selo acadêmico (D1b) e a faixa fixa do CVV 188 e
/// do SAMU 192, que liga com um toque sem login (§7.1).
///
/// O painel de demonstração (D11) só aparece com [modoDepuracao], que por
/// padrão é `kDebugMode` — na versão de release ele não existe.
class BoasVindasTela extends StatelessWidget {
  const BoasVindasTela({super.key, this.modoDepuracao = kDebugMode});

  /// Mostra o acesso ao painel de demonstração (D11).
  final bool modoDepuracao;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      key: const Key('TM00'),
      backgroundColor: CoresTerae.superficie,
      // A Column dá altura livre à faixa: no slot do rodapé a altura é
      // limitada à tela, e o `Center` de cada contato ocuparia tudo.
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [FaixaEmergencia()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: MedidasTerae.paddingTela,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (modoDepuracao)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('abrir-painel-demonstracao'),
                    tooltip: 'Painel de demonstração',
                    icon: const Icon(Icons.tune, color: CoresTerae.neutro600),
                    onPressed: () =>
                        unawaited(abrirPainelDemonstracao(context)),
                  ),
                )
              else
                const SizedBox(height: MedidasTerae.alturaMinimaBotao),
              const SizedBox(height: MedidasTerae.espaco),
              const _Marca(),
              const SizedBox(height: MedidasTerae.espacoGrande),
              Text(
                'Acompanhe o seu tratamento entre uma consulta e outra.',
                style: textos.headlineSmall,
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Text(
                'Conte como você está, veja o caminho do tratamento e '
                'peça ajuda quando precisar.',
                style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
              ),
              const SizedBox(height: MedidasTerae.espacoGrande),
              BotaoGrande(
                key: const Key('ir-entrar'),
                rotulo: 'Entrar',
                icone: Icons.login,
                aoTocar: () => unawaited(context.push(Rotas.entrar)),
              ),
              const SizedBox(height: 12),
              BotaoGrande(
                key: const Key('ir-primeiro-acesso'),
                rotulo: 'Primeiro acesso',
                icone: Icons.vpn_key_outlined,
                variante: VarianteBotao.secundario,
                aoTocar: () => unawaited(abrirPrimeiroAcesso(context)),
              ),
              const SizedBox(height: MedidasTerae.espaco),
              Center(
                child: TextButton(
                  key: const Key('politica-privacidade'),
                  onPressed: () =>
                      unawaited(abrirPoliticaDePrivacidade(context)),
                  child: const Text('Política de privacidade'),
                ),
              ),
              const SizedBox(height: MedidasTerae.espaco),
              const Center(child: SeloAcademico()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone de coração com pulso e o nome "Terae".
class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: CoresTerae.primaria50,
            borderRadius: BorderRadius.all(
              Radius.circular(MedidasTerae.raioCartao),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(
              Icons.monitor_heart_outlined,
              size: 36,
              color: CoresTerae.primaria700,
            ),
          ),
        ),
        const SizedBox(width: MedidasTerae.espaco),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              'Terae',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(color: CoresTerae.primaria700),
            ),
          ),
        ),
      ],
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
    'Este aplicativo é um trabalho da UNEMAT. Os dados são de demonstração '
        'e ficam só na memória do aparelho enquanto ele está aberto.',
  ),
  (
    'Sem senha',
    'O Terae não pede nem guarda senha. Você entra com a conta do Google ou '
        'da Apple que já usa.',
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
