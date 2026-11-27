import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/cartao.dart';
import '../publico/folha_inferior.dart';

/// "Primeiro acesso" da TM00 e da TM01 (RFM09, RFM10): a pessoa diz o que
/// recebeu — código da clínica (TM09) ou convite de cuidador (TM10) — e a tela
/// do cadastro abre por cima, para o voltar trazer de volta.
Future<void> abrirPrimeiroAcesso(BuildContext context) async {
  final rota = await mostrarFolha<String>(
    context: context,
    titulo: 'Primeiro acesso',
    construtor: (folha) {
      final textos = Theme.of(folha).textTheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'O que você recebeu?',
            style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro700),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          _OpcaoDePrimeiroAcesso(
            key: const Key('primeiro-acesso-clinica'),
            icone: LucideIcons.hospital,
            titulo: 'Recebi um código da clínica',
            descricao: 'Para o paciente ou para quem responde por ele.',
            aoTocar: () => Navigator.of(folha).pop(Rotas.cadastroPaciente),
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          _OpcaoDePrimeiroAcesso(
            key: const Key('primeiro-acesso-cuidador'),
            icone: LucideIcons.handHeart,
            titulo: 'Recebi um convite de cuidador',
            descricao: 'Para quem vai acompanhar o cuidado de alguém.',
            aoTocar: () => Navigator.of(folha).pop(Rotas.cadastroCuidador),
          ),
        ],
      );
    },
  );
  if (rota == null || !context.mounted) return;
  unawaited(context.push(rota));
}

class _OpcaoDePrimeiroAcesso extends StatelessWidget {
  const _OpcaoDePrimeiroAcesso({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoTocar,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      aoTocar: aoTocar,
      child: Row(
        children: [
          Icon(icone, size: 28, color: CoresTerae.primaria700),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleSmall),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: textos.bodySmall?.copyWith(
                    color: CoresTerae.neutro600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: CoresTerae.neutro600),
        ],
      ),
    );
  }
}
