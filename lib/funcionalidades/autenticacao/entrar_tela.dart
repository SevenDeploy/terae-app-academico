import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import 'entrar_controlador.dart';
import 'primeiro_acesso.dart';
import 'widgets_entrada.dart';

/// TM01 — Entrar (RFM01). Em `/entrar` (pública): e-mail e senha (D14), com
/// a recusa em linguagem simples; aviso de que a senha não fica no celular
/// (RNFM04); atalho para o primeiro acesso.
///
/// Em `/entrar/perfil` ([selecaoDePerfil], exige sessão): a lista de
/// `Sessao.perfis`, com papel e nome do paciente; tocar chama
/// `Sessao.escolherPerfil` e o roteador leva ao início do papel — a tela não
/// navega.
class EntrarTela extends StatelessWidget {
  const EntrarTela({super.key, this.selecaoDePerfil = false});

  final bool selecaoDePerfil;

  @override
  Widget build(BuildContext context) {
    if (selecaoDePerfil) return const _SelecaoDePerfil();
    return ChangeNotifierProvider(
      create: (contexto) => EntrarControlador(
        autenticacao: contexto.read<RepositorioAutenticacao>(),
        sessao: contexto.read<Sessao>(),
      ),
      child: const _Entrar(),
    );
  }
}

class _Entrar extends StatefulWidget {
  const _Entrar();

  @override
  State<_Entrar> createState() => _EntrarState();
}

class _EntrarState extends State<_Entrar> {
  final _email = TextEditingController();
  final _senha = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() => context.read<EntrarControlador>().entrar(
    email: _email.text,
    senha: _senha.text,
  );

  @override
  Widget build(BuildContext context) {
    final controlador = context.watch<EntrarControlador>();
    final textos = Theme.of(context).textTheme;
    final mensagem = controlador.mensagem;
    return Scaffold(
      key: const Key('TM01'),
      appBar: AppBar(title: const Text('Entrar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: MedidasTerae.paddingTela,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Entrar no Terae', style: textos.headlineSmall),
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Text(
                'Use o e-mail e a senha que você criou no primeiro acesso.',
                style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
              ),
              const SizedBox(height: MedidasTerae.espacoGrande),
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CampoDeEmail(
                      key: const Key('campo-email'),
                      controlador: _email,
                      erro: controlador.erroEmail,
                    ),
                    const SizedBox(height: MedidasTerae.espaco),
                    CampoDeSenha(
                      key: const Key('campo-senha'),
                      controlador: _senha,
                      rotulo: 'Senha',
                      erro: controlador.erroSenha,
                      acao: TextInputAction.done,
                      aoConcluir: () => unawaited(_entrar()),
                    ),
                  ],
                ),
              ),
              if (mensagem != null) ...[
                const SizedBox(height: MedidasTerae.espaco),
                AvisoDeRecusa(mensagem),
              ],
              const SizedBox(height: MedidasTerae.espaco),
              if (controlador.ocupado) ...[
                const LinearProgressIndicator(semanticsLabel: 'Entrando'),
                const SizedBox(height: MedidasTerae.espaco),
              ],
              BotaoGrande(
                key: const Key('entrar'),
                rotulo: controlador.ocupado ? 'Entrando…' : 'Entrar',
                icone: Icons.login,
                aoTocar: controlador.ocupado
                    ? null
                    : () => unawaited(_entrar()),
              ),
              const SizedBox(height: MedidasTerae.espacoGrande),
              const CaixaInformativa(
                icone: Icons.lock_outline,
                texto:
                    'A senha não fica guardada neste celular. Quem confere a '
                    'senha é o serviço de login do Terae.',
              ),
              const SizedBox(height: MedidasTerae.espacoGrande),
              const Divider(),
              const SizedBox(height: MedidasTerae.espaco),
              Text('É a sua primeira vez aqui?', style: textos.titleSmall),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              BotaoGrande(
                key: const Key('ir-primeiro-acesso'),
                rotulo: 'Primeiro acesso',
                icone: Icons.vpn_key_outlined,
                variante: VarianteBotao.secundario,
                aoTocar: () => unawaited(abrirPrimeiroAcesso(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/entrar/perfil`: conta com mais de um perfil escolhe com qual entrar
/// (§19: o perfil decorre dos vínculos; a lista só aparece com mais de um).
class _SelecaoDePerfil extends StatelessWidget {
  const _SelecaoDePerfil();

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final textos = Theme.of(context).textTheme;
    final nome = sessao.conta?.nomeExibicao.split(' ').first;
    return Scaffold(
      key: const Key('TM01'),
      appBar: AppBar(
        title: const Text('Escolha o perfil'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: MedidasTerae.paddingTela,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  nome == null ? 'Olá!' : 'Olá, $nome!',
                  style: textos.headlineSmall,
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              Text(
                'Esta conta tem mais de um perfil. '
                'Com qual você quer entrar agora?',
                style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
              ),
              const SizedBox(height: MedidasTerae.espacoGrande),
              for (final perfil in sessao.perfis) ...[
                _CartaoDePerfil(
                  perfil: perfil,
                  aoTocar: () => context.read<Sessao>().escolherPerfil(perfil),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: MedidasTerae.espaco),
              BotaoGrande(
                key: const Key('sair'),
                rotulo: 'Sair',
                icone: Icons.logout,
                variante: VarianteBotao.secundario,
                aoTocar: () => context.read<Sessao>().sair(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoDePerfil extends StatelessWidget {
  const _CartaoDePerfil({required this.perfil, required this.aoTocar});

  final Perfil perfil;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final icone = switch (perfil.papel) {
      Papel.pacienteFamilia => Icons.family_restroom,
      Papel.cuidador => Icons.volunteer_activism_outlined,
    };
    return Cartao(
      key: Key('perfil-${perfil.papel.name}-${perfil.pacienteId}'),
      aoTocar: aoTocar,
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: CoresTerae.primaria50,
              borderRadius: BorderRadius.all(
                Radius.circular(MedidasTerae.raioBotao),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icone, color: CoresTerae.primaria700),
            ),
          ),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perfil.papel.rotulo,
                  style: textos.labelMedium?.copyWith(
                    color: CoresTerae.neutro600,
                  ),
                ),
                Text(perfil.paciente.nome, style: textos.titleMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CoresTerae.neutro400),
        ],
      ),
    );
  }
}
