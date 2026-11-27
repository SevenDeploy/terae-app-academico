import 'package:flutter/material.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/cartao.dart';
import 'cadastro_controlador.dart';
import 'moldura_de_entrada.dart';
import 'widgets_entrada.dart';

/// Etapa do portal (1 a 3) de cada passo do cadastro (1 a 4): o
/// "Primeiro acesso" do portal tem três etapas (Confirmação, Termos, Senha,
/// 18c). O app pede mais na confirmação (quem vai usar, o que o cuidador
/// verá), então os passos 1 e 2 são a etapa 1. O termo vem antes da senha,
/// como sempre foi aqui: o aceite é a base para criar o acesso.
int etapaDoPasso(int passo) => switch (passo) {
  1 || 2 => 1,
  3 => 2,
  _ => 3,
};

/// Moldura dos cadastros (TM09, TM10) na [MolduraDeEntrada]: "Etapa X de 3 ·
/// nome", o conteúdo do passo, a recusa em linguagem simples e as ações. No
/// passo 2 em diante, o voltar (Android ou seta da faixa) volta um passo em
/// vez de sair. Um `Key('passo-N')` invisível marca o passo interno.
class MolduraDoCadastro extends StatelessWidget {
  const MolduraDoCadastro({
    super.key,
    required this.chaveDaTela,
    required this.titulo,
    required this.passo,
    required this.nomeDoPasso,
    required this.aoVoltarPasso,
    required this.mensagem,
    required this.ocupado,
    required this.conteudo,
    required this.acoes,
  });

  /// `Key('TM09')` ou `Key('TM10')`, posta no Scaffold (contrato).
  final Key chaveDaTela;
  final String titulo;
  final int passo;

  /// O rótulo da etapa ("Confirmação", "Termo de consentimento", "Senha").
  final String nomeDoPasso;
  final VoidCallback aoVoltarPasso;
  final String? mensagem;
  final bool ocupado;
  final List<Widget> conteudo;
  final List<Widget> acoes;

  /// Quantas etapas o primeiro acesso mostra.
  static const int totalDeEtapas = 3;

  @override
  Widget build(BuildContext context) {
    final mensagem = this.mensagem;
    return PopScope(
      canPop: passo == 1,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) aoVoltarPasso();
      },
      child: MolduraDeEntrada(
        chaveDaTela: chaveDaTela,
        titulo: titulo,
        etapa: EtapaDaEntrada(
          atual: etapaDoPasso(passo),
          total: totalDeEtapas,
          rotulo: nomeDoPasso,
        ),
        aoVoltar: passo == 1 ? null : aoVoltarPasso,
        children: [
          SizedBox.shrink(key: Key('passo-$passo')),
          ...conteudo,
          if (mensagem != null) ...[
            const SizedBox(height: MedidasTerae.espaco),
            AvisoDeRecusa(mensagem),
          ],
          const SizedBox(height: MedidasTerae.espacoGrande),
          if (ocupado) ...[
            const LinearProgressIndicator(semanticsLabel: 'Conferindo'),
            const SizedBox(height: MedidasTerae.espaco),
          ],
          for (final acao in acoes) ...[
            acao,
            if (acao != acoes.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Título de passo, marcado como cabeçalho para o leitor de tela.
class TituloDoPasso extends StatelessWidget {
  const TituloDoPasso(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Termo em linguagem simples: tópicos curtos com título (RNFM01).
class TextoDoTermo extends StatelessWidget {
  const TextoDoTermo({super.key, required this.topicos});

  final List<(String, String)> topicos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      corFundo: CoresTerae.neutro50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (titulo, texto) in topicos) ...[
            Text(titulo, style: textos.titleSmall),
            const SizedBox(height: 2),
            Text(texto, style: textos.bodyMedium),
            if (titulo != topicos.last.$1)
              const SizedBox(height: MedidasTerae.espaco),
          ],
        ],
      ),
    );
  }
}

/// Caixa de aceite do termo: a linha inteira é o alvo de toque.
class AceiteDoTermo extends StatelessWidget {
  const AceiteDoTermo({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
  });

  final String rotulo;
  final bool valor;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: const Key('aceite-termo'),
      value: valor,
      onChanged: (marcado) => aoMudar(marcado ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(rotulo, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Passo 4 da TM09 e da TM10 — "Crie seu acesso" (D14): nome, e-mail, senha
/// e confirmação. Os controladores de texto são da tela (sobrevivem à volta
/// de passo); os erros, do controlador do cadastro.
class FormularioDeAcesso extends StatelessWidget {
  const FormularioDeAcesso({
    super.key,
    required this.nome,
    required this.email,
    required this.senha,
    required this.confirmacao,
    required this.cadastro,
    required this.aoConcluir,
  });

  final TextEditingController nome;
  final TextEditingController email;
  final TextEditingController senha;
  final TextEditingController confirmacao;
  final CadastroControlador cadastro;
  final VoidCallback aoConcluir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloDoPasso('Crie a sua senha'),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            'Com este e-mail e esta senha você entra no Terae. Se você já '
            'tem acesso, use o mesmo e-mail e a mesma senha.',
            style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
          ),
          const SizedBox(height: MedidasTerae.espacoGrande),
          TextField(
            key: const Key('campo-nome'),
            controller: nome,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: 'Seu nome',
              errorText: cadastro.erroNome,
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          CampoDeEmail(
            key: const Key('campo-email'),
            controlador: email,
            erro: cadastro.erroEmail,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          CampoDeSenha(
            key: const Key('campo-senha'),
            controlador: senha,
            rotulo: 'Senha',
            ajuda: 'Pelo menos $tamanhoMinimoDaSenha caracteres',
            erro: cadastro.erroSenha,
            novaSenha: true,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          CampoDeSenha(
            key: const Key('campo-confirmacao'),
            controlador: confirmacao,
            rotulo: 'Repita a senha',
            erro: cadastro.erroConfirmacao,
            novaSenha: true,
            acao: TextInputAction.done,
            aoConcluir: aoConcluir,
          ),
          const SizedBox(height: MedidasTerae.espaco),
          const CaixaInformativa(
            icone: Icons.lock_outline,
            texto:
                'A senha não fica guardada neste celular. Quem confere a '
                'senha é o serviço de login do Terae.',
          ),
        ],
      ),
    );
  }
}
