import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/aviso_de_conexao.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import '../capacidades.dart';
import '../moldura/moldura_do_portal.dart';

/// TM21 — Conta (a aba "Conta" do portal, `MinhaConta.tsx`, quadro 18k):
/// seus dados, quem você acompanha, os lembretes deste aparelho, os
/// cuidadores que você autorizou e "Sair". Juntou o antigo menu do Início
/// (Lembretes, Cuidadores, Trocar perfil, Sair).
///
/// A `Key('TM21')` no Scaffold raiz faz parte do contrato.
class ContaTela extends StatelessWidget {
  const ContaTela({super.key});

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final perfil = sessao.perfilAtivo;
    final conta = sessao.conta;
    final textos = Theme.of(context).textTheme;
    final ehFamilia = perfil?.papel == Papel.pacienteFamilia;
    return Scaffold(
      key: const Key('TM21'),
      body: ListView(
        padding: MedidasTerae.paddingTela,
        children: [
          const AvisoDeConexao(),
          Semantics(
            header: true,
            child: Text('Minha conta', style: textos.headlineSmall),
          ),
          const SizedBox(height: MedidasTerae.espacoCartao),
          if (conta != null)
            Cartao(
              key: const Key('conta-seus-dados'),
              titulo: 'Seus dados',
              icone: LucideIcons.userRound,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conta.nomeExibicao, style: textos.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    conta.email,
                    style: textos.bodySmall?.copyWith(
                      color: CoresTerae.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MedidasTerae.espacoCartao),
          Cartao(
            key: const Key('conta-quem-acompanha'),
            titulo: 'Quem você acompanha',
            icone: LucideIcons.users,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              children: [
                for (final p in sessao.perfis)
                  _PerfilDaConta(
                    perfil: p,
                    atual: p == perfil,
                    aoEscolher: () => sessao.escolherPerfil(p),
                  ),
              ],
            ),
          ),
          if (ehFamilia) ...[
            const SizedBox(height: MedidasTerae.espacoCartao),
            _ItemDaConta(
              chave: 'conta-lembretes',
              icone: LucideIcons.bell,
              titulo: 'Lembretes neste aparelho',
              descricao: 'Véspera da sessão e horário das atividades',
              aoTocar: () => context.push(Rotas.pacienteLembretes),
            ),
            // Terae local: chave CUIDADOR_PELO_PORTAL desligada.
            if (capacidadesDaFonte(context).cuidadores) ...[
              const SizedBox(height: 12),
              _ItemDaConta(
                chave: 'conta-cuidadores',
                icone: LucideIcons.heartHandshake,
                titulo: 'Cuidadores que você autorizou',
                descricao: 'Convidar ou retirar o acesso de um cuidador',
                aoTocar: () => context.push(Rotas.pacienteCuidadores),
              ),
            ],
          ],
          const SizedBox(height: MedidasTerae.espacoGrande),
          BotaoGrande(
            key: const Key('conta-sair'),
            rotulo: 'Sair',
            icone: LucideIcons.logOut,
            variante: VarianteBotao.secundario,
            aoTocar: sessao.sair,
          ),
        ],
      ),
    );
  }
}

class _ItemDaConta extends StatelessWidget {
  const _ItemDaConta({
    required this.chave,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.aoTocar,
  });

  final String chave;
  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: Key(chave),
      aoTocar: aoTocar,
      child: Row(
        children: [
          Icon(icone, size: 22, color: CoresTerae.primaria700),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleSmall),
                const SizedBox(height: 2),
                Text(
                  descricao,
                  style: textos.bodySmall?.copyWith(
                    color: CoresTerae.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: 20,
            color: CoresTerae.neutro600,
          ),
        ],
      ),
    );
  }
}

/// Uma linha de "Quem você acompanha": avatar, nome inteiro, o vínculo e, no
/// perfil que está aberto, o selo "Vendo agora" embaixo (ao lado do nome ele o
/// espremia em quatro linhas a 360 dp).
class _PerfilDaConta extends StatelessWidget {
  const _PerfilDaConta({
    required this.perfil,
    required this.atual,
    required this.aoEscolher,
  });

  final Perfil perfil;
  final bool atual;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final linha = ConstrainedBox(
      key: Key('conta-perfil-${perfil.chave}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(nome: perfil.paciente.nome),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(perfil.paciente.nome, style: textos.bodyLarge),
                  Text(
                    rotuloDoPerfil(perfil),
                    style: textos.bodySmall?.copyWith(
                      color: CoresTerae.textoSecundario,
                    ),
                  ),
                  if (atual) ...[
                    const SizedBox(height: 6),
                    const Selo(
                      texto: 'Vendo agora',
                      tom: TomDoSelo.info,
                      icone: LucideIcons.eye,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (atual) return linha;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: aoEscolher,
        child: linha,
      ),
    );
  }
}
