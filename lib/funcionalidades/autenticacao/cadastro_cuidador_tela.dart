import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/validacao/formatador_cpf.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import 'cadastro_controlador.dart';
import 'campos_cadastro.dart';
import 'widgets_cadastro.dart';
import 'widgets_entrada.dart';

/// TM10 — Cadastro do cuidador (RFM09, §7.4). Transforma o convite feito pelo
/// paciente na TM07 em acesso restrito, em quatro passos: (1) código do
/// convite e CPF do cuidador, que tem de ser o informado pelo paciente; (2)
/// quadro "o que você verá / o que não verá" (RNFM05); (3) aceite do termo de
/// acesso; (4) "Crie seu acesso", com nome, e-mail e senha (D14).
///
/// Estado em `CadastroCuidadorControlador`; depois do aceite o roteador leva à
/// TM08 — a tela não navega.
class CadastroCuidadorTela extends StatelessWidget {
  const CadastroCuidadorTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (contexto) => CadastroCuidadorControlador(
        autenticacao: contexto.read<RepositorioAutenticacao>(),
        sessao: contexto.read<Sessao>(),
      ),
      child: const _CadastroCuidador(),
    );
  }
}

const List<String> _nomesDosPassos = [
  'Código do convite',
  'O que você verá',
  'Termo de acesso',
  'Seu acesso',
];

class _CadastroCuidador extends StatefulWidget {
  const _CadastroCuidador();

  @override
  State<_CadastroCuidador> createState() => _CadastroCuidadorState();
}

class _CadastroCuidadorState extends State<_CadastroCuidador> {
  final _codigo = TextEditingController();
  final _cpf = TextEditingController();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();

  @override
  void dispose() {
    for (final c in [_codigo, _cpf, _nome, _email, _senha, _confirmacao]) {
      c.dispose();
    }
    super.dispose();
  }

  CadastroCuidadorControlador get _controlador =>
      context.read<CadastroCuidadorControlador>();

  Future<void> _conferir() =>
      _controlador.conferir(codigo: _codigo.text, cpf: _cpf.text);

  Future<void> _aceitar() => _controlador.aceitar(
    nome: _nome.text,
    email: _email.text,
    senha: _senha.text,
    confirmacao: _confirmacao.text,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CadastroCuidadorControlador>();
    final nome = c.conferido?.nomePaciente ?? 'o paciente';
    final primeiroNome = nome.split(' ').first;
    final (conteudo, acoes) = switch (c.passo) {
      1 => (_passo1(c), _acoesDoPasso1(c)),
      2 => (_passo2(nome, primeiroNome), _acoesDoPasso2(c)),
      3 => (_passo3(c, primeiroNome), _acoesDoPasso3(c)),
      _ => (_passo4(c), _acoesDoPasso4(c)),
    };
    return MolduraDoCadastro(
      chaveDaTela: const Key('TM10'),
      titulo: 'Convite de cuidador',
      passo: c.passo,
      nomeDoPasso: _nomesDosPassos[c.passo - 1],
      aoVoltarPasso: c.voltar,
      mensagem: c.mensagem,
      ocupado: c.ocupado,
      conteudo: conteudo,
      acoes: acoes,
    );
  }

  List<Widget> _passo1(CadastroCuidadorControlador c) {
    final textos = Theme.of(context).textTheme;
    return [
      const TituloDoPasso('Digite o seu convite'),
      const SizedBox(height: MedidasTerae.espacoPequeno),
      Text(
        'Use o código que a pessoa que você acompanha enviou. O CPF precisa '
        'ser o mesmo que ela informou no convite.',
        style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
      ),
      const SizedBox(height: MedidasTerae.espacoGrande),
      TextField(
        key: const Key('campo-codigo'),
        controller: _codigo,
        decoration: InputDecoration(
          labelText: 'Código do convite',
          helperText: '$tamanhoDoCodigo letras ou números',
          errorText: c.erroCodigo,
        ),
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: const [FormatadorCodigo()],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: MedidasTerae.espaco),
      TextField(
        key: const Key('campo-cpf'),
        controller: _cpf,
        decoration: InputDecoration(
          labelText: 'O seu CPF',
          hintText: '000.000.000-00',
          errorText: c.erroCpf,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: const [FormatadorCpf()],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => unawaited(_conferir()),
      ),
    ];
  }

  List<Widget> _acoesDoPasso1(CadastroCuidadorControlador c) => [
    BotaoGrande(
      key: const Key('continuar'),
      rotulo: 'Continuar',
      aoTocar: c.ocupado ? null : () => unawaited(_conferir()),
    ),
  ];

  List<Widget> _passo2(String nome, String primeiroNome) => [
    CaixaInformativa(
      icone: Icons.volunteer_activism_outlined,
      corIcone: CoresTerae.clinico700,
      texto: '$nome convidou você para acompanhar o cuidado.',
    ),
    const SizedBox(height: MedidasTerae.espacoGrande),
    const TituloDoPasso('O que você verá'),
    const SizedBox(height: MedidasTerae.espacoPequeno),
    const _Quadro(
      chave: Key('quadro-vera'),
      icone: Icons.check_circle,
      cor: CoresTerae.clinico700,
      corFundo: CoresTerae.clinico50,
      // O convite só traz o nome: antes da conta, a TM10 não sabe se o
      // paciente tem acompanhamento clínico ou só TO. Por isso os textos
      // servem aos dois, e os remédios aparecem "se houver" (D29; roteiro da
      // A5, CT06).
      itens: [
        'A agenda: dia, hora e profissional de cada sessão ou consulta',
        'Se houver remédios no tratamento: os horários e a data de '
            'renovação da receita',
        'Os avisos: sessão ou consulta cancelada, receita para renovar e '
            'aviso enviado à equipe',
      ],
    ),
    const SizedBox(height: MedidasTerae.espacoGrande),
    const TituloDoPasso('O que você não verá'),
    const SizedBox(height: MedidasTerae.espacoPequeno),
    _Quadro(
      chave: const Key('quadro-nao-vera'),
      icone: Icons.lock_outline,
      cor: CoresTerae.neutro600,
      corFundo: CoresTerae.neutro50,
      itens: [
        'A evolução clínica e as anotações da equipe',
        'O que $primeiroNome conta no diário',
        'O motivo das consultas',
        'O CPF e a data de nascimento',
      ],
    ),
  ];

  List<Widget> _acoesDoPasso2(CadastroCuidadorControlador c) => [
    BotaoGrande(
      key: const Key('continuar'),
      rotulo: 'Continuar',
      aoTocar: c.irParaTermo,
    ),
    BotaoGrande(
      key: const Key('voltar-passo'),
      rotulo: 'Voltar',
      variante: VarianteBotao.secundario,
      aoTocar: c.voltar,
    ),
  ];

  List<Widget> _passo3(CadastroCuidadorControlador c, String primeiroNome) {
    final textos = Theme.of(context).textTheme;
    return [
      const TituloDoPasso('Termo de acesso'),
      const SizedBox(height: MedidasTerae.espaco),
      TextoDoTermo(
        topicos: [
          (
            'Para que serve',
            'Você vai ver a agenda, os avisos e, se houver, os horários '
                'dos remédios de $primeiroNome para ajudar no cuidado.',
          ),
          (
            'Cuide dessas informações',
            'Não repasse o que você vê aqui para outras pessoas.',
          ),
          (
            'Quem decide',
            '$primeiroNome pode remover o seu acesso quando quiser.',
          ),
        ],
      ),
      const SizedBox(height: MedidasTerae.espaco),
      AceiteDoTermo(
        rotulo: 'Li e aceito o termo de acesso',
        valor: c.aceite,
        aoMudar: (aceite) => c.marcarAceite(aceite: aceite),
      ),
      if (!c.podeAceitar && !c.ocupado) ...[
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Text(
          'Marque o aceite para continuar.',
          style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
        ),
      ],
    ];
  }

  List<Widget> _acoesDoPasso3(CadastroCuidadorControlador c) => [
    BotaoGrande(
      key: const Key('continuar'),
      rotulo: 'Continuar',
      aoTocar: c.podeAceitar ? c.irParaAcesso : null,
    ),
    BotaoGrande(
      key: const Key('voltar-passo'),
      rotulo: 'Voltar',
      variante: VarianteBotao.secundario,
      aoTocar: c.ocupado ? null : c.voltar,
    ),
  ];

  List<Widget> _passo4(CadastroCuidadorControlador c) => [
    FormularioDeAcesso(
      nome: _nome,
      email: _email,
      senha: _senha,
      confirmacao: _confirmacao,
      cadastro: c,
      aoConcluir: () => unawaited(_aceitar()),
    ),
  ];

  List<Widget> _acoesDoPasso4(CadastroCuidadorControlador c) => [
    BotaoGrande(
      key: const Key('criar-acesso'),
      rotulo: 'Criar acesso e entrar',
      icone: Icons.login,
      aoTocar: c.ocupado ? null : () => unawaited(_aceitar()),
    ),
    BotaoGrande(
      key: const Key('voltar-passo'),
      rotulo: 'Voltar',
      variante: VarianteBotao.secundario,
      aoTocar: c.ocupado ? null : c.voltar,
    ),
  ];
}

/// Uma coluna do quadro "o que você verá / o que não verá": a marca de cada
/// item é ícone, não só cor.
class _Quadro extends StatelessWidget {
  const _Quadro({
    required this.chave,
    required this.icone,
    required this.cor,
    required this.corFundo,
    required this.itens,
  });

  final Key chave;
  final IconData icone;
  final Color cor;
  final Color corFundo;
  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: chave,
      corFundo: corFundo,
      corBorda: cor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in itens) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(icone, color: cor, size: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: textos.bodyMedium)),
              ],
            ),
            if (item != itens.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
