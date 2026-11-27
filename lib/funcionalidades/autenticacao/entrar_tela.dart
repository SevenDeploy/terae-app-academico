import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import '../capacidades.dart';
import '../moldura/moldura_do_portal.dart';
import 'codigo_de_acesso.dart';
import 'entrar_controlador.dart';
import 'moldura_de_entrada.dart';
import 'primeiro_acesso.dart';
import 'widgets_entrada.dart';

/// TM01 — Entrar (RFM01), na [MolduraDeEntrada] e com os textos do "Entrar
/// no portal" do portal da família (18a). Em `/entrar` (pública): e-mail e
/// senha (D14), com a recusa em linguagem simples; aviso de que a senha não
/// fica no celular (RNFM04); o bloco "Primeiro acesso?". Na fonte Terae
/// local, a senha certa leva à etapa 2 do portal ([EtapaDoCodigo]) e o
/// "Primeiro acesso?" some (o convite do portal é por link do e-mail).
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
        relogio: contexto.read<Relogio>(),
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
    // Fonte Terae local: a senha conferiu e o código foi pedido (etapa 2).
    if (controlador.etapaDoCodigo case final etapa?) {
      return EtapaDoCodigo(etapa: etapa);
    }
    final mensagem = controlador.mensagem;
    // Fonte Terae local: a entrada tem duas etapas, como a do portal ("Etapa
    // 1 de 2" e "Continuar"); no Firebase é uma só.
    final emDuasEtapas = controlador.temCodigoPorEmail;
    return MolduraDeEntrada(
      chaveDaTela: const Key('TM01'),
      etapa: emDuasEtapas ? const EtapaDaEntrada(atual: 1, total: 2) : null,
      titulo: 'Entrar no portal',
      descricao: 'Use o e-mail em que a clínica mandou o convite.',
      children: [
        if (mensagem != null) ...[
          AvisoDeRecusa(mensagem),
          const SizedBox(height: MedidasTerae.espacoCartao),
        ],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampoDeEmail(
                key: const Key('campo-email'),
                controlador: _email,
                erro: controlador.erroEmail,
              ),
              const SizedBox(height: MedidasTerae.espacoCartao),
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
        const SizedBox(height: MedidasTerae.espacoCartao),
        if (controlador.ocupado) ...[
          const LinearProgressIndicator(semanticsLabel: 'Entrando'),
          const SizedBox(height: MedidasTerae.espaco),
        ],
        BotaoGrande(
          key: const Key('entrar'),
          rotulo: controlador.ocupado
              ? 'Entrando…'
              : emDuasEtapas
              ? 'Continuar'
              : 'Entrar',
          icone: emDuasEtapas ? LucideIcons.arrowRight : LucideIcons.logIn,
          aoTocar: controlador.ocupado ? null : () => unawaited(_entrar()),
        ),
        const SizedBox(height: 12),
        if (emDuasEtapas) ...[
          const Text(
            'Depois da senha, enviamos um código para o seu e-mail.',
            key: Key('frase-do-codigo'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
          ),
          const SizedBox(height: 8),
        ],
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                LucideIcons.lock,
                size: 16,
                color: CoresTerae.neutro600,
              ),
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'A senha não fica guardada neste celular.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
              ),
            ),
          ],
        ),
        if (capacidadesDaFonte(context).primeiroAcesso) ...[
          const SizedBox(height: MedidasTerae.espacoGrande),
          const _PrimeiroAcessoNaEntrada(),
        ],
      ],
    );
  }
}

/// O bloco "Primeiro acesso?" do 18a, cinza, com o caminho do convite.
class _PrimeiroAcessoNaEntrada extends StatelessWidget {
  const _PrimeiroAcessoNaEntrada();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoresTerae.neutro50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: CoresTerae.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: const Text(
                'Primeiro acesso?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CoresTerae.texto,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use o código ou o convite que a clínica mandou. Ainda não '
              'recebeu? Fale com a clínica.',
              style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
            ),
            const SizedBox(height: 12),
            BotaoGrande(
              key: const Key('ir-primeiro-acesso'),
              rotulo: 'Primeiro acesso',
              icone: LucideIcons.keyRound,
              variante: VarianteBotao.secundario,
              aoTocar: () => unawaited(abrirPrimeiroAcesso(context)),
            ),
          ],
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
    final nome = sessao.conta?.nomeExibicao.split(' ').first;
    return MolduraDeEntrada(
      chaveDaTela: const Key('TM01'),
      titulo: 'De quem você quer ver?',
      descricao:
          '${nome == null ? 'Esta' : '$nome, esta'} conta acompanha mais de '
          'uma pessoa. Escolha por onde começar; depois dá para trocar no '
          'topo.',
      children: [
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
          icone: LucideIcons.logOut,
          variante: VarianteBotao.secundario,
          aoTocar: () => context.read<Sessao>().sair(),
        ),
      ],
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
    return Cartao(
      key: Key('perfil-${perfil.papel.name}-${perfil.pacienteId}'),
      aoTocar: aoTocar,
      padding: const EdgeInsets.all(MedidasTerae.espaco),
      child: Row(
        children: [
          Avatar(nome: perfil.paciente.nome, tamanho: 44),
          const SizedBox(width: MedidasTerae.espaco),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(perfil.paciente.nome, style: textos.titleSmall),
                const SizedBox(height: 2),
                Text(
                  rotuloDoPerfil(perfil),
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
