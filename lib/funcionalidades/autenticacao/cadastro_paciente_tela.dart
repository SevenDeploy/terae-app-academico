import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/enums/canal_autorizado.dart';
import '../../dados/enums/qualidade_consentimento.dart';
import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/validacao/formatador_cpf.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/seletor_opcoes.dart';
import 'cadastro_controlador.dart';
import 'campos_cadastro.dart';
import 'escolha_de_conta.dart';
import 'widgets_cadastro.dart';
import 'widgets_entrada.dart';

/// TM09 — Cadastro do paciente/família (RFM09). O app não cria paciente
/// (RF07): ativa a conta de quem já é paciente da clínica, em três passos —
/// (1) código de seis caracteres, CPF e nascimento do paciente; (2) quem vai
/// usar, o próprio paciente ou o responsável legal (LGPD art. 14, § 1º) —
/// criança (menos de 12 anos, ECA art. 2º) só pelo responsável legal;
/// (3) termo de consentimento em linguagem simples, com versão, canal
/// autorizado (R05) e aceite, seguido de "Continuar com Google".
///
/// Estado em `CadastroPacienteControlador`; depois da ativação o roteador leva
/// ao Início — a tela não navega.
class CadastroPacienteTela extends StatelessWidget {
  const CadastroPacienteTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (contexto) => CadastroPacienteControlador(
        autenticacao: contexto.read<RepositorioAutenticacao>(),
        sessao: contexto.read<Sessao>(),
        relogio: contexto.read<Relogio>(),
      ),
      child: const _CadastroPaciente(),
    );
  }
}

const List<String> _nomesDosPassos = [
  'Código da clínica',
  'Quem vai usar',
  'Termo de consentimento',
];

/// Termo de consentimento, versão [versaoTermoConsentimento]. Mudou o texto,
/// muda a versão (termo novo gera Consentimento novo, §22).
const List<(String, String)> _termo = [
  (
    'Para que serve',
    'O Terae ajuda você e a sua equipe de saúde a acompanhar o tratamento '
        'entre uma consulta e outra.',
  ),
  (
    'O que fica registrado',
    'O que você conta no diário, os horários dos remédios e as consultas. '
        'São dados de saúde, e por isso pedimos a sua permissão.',
  ),
  (
    'Quem vê',
    'Você e a sua equipe de saúde. Se você autorizar, até dois cuidadores '
        'veem a agenda, os remédios e os avisos, mas nunca o diário.',
  ),
  (
    'Quando algo grave acontece',
    'Se o diário mostrar risco, a equipe é avisada. Em crise, ligue para o '
        'CVV 188 ou o SAMU 192.',
  ),
  (
    'Você pode mudar de ideia',
    'Para retirar esta permissão, fale com a clínica.',
  ),
];

class _CadastroPaciente extends StatefulWidget {
  const _CadastroPaciente();

  @override
  State<_CadastroPaciente> createState() => _CadastroPacienteState();
}

class _CadastroPacienteState extends State<_CadastroPaciente> {
  final _codigo = TextEditingController();
  final _cpf = TextEditingController();
  final _nascimento = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    _cpf.dispose();
    _nascimento.dispose();
    super.dispose();
  }

  CadastroPacienteControlador get _controlador =>
      context.read<CadastroPacienteControlador>();

  Future<void> _conferir() => _controlador.conferir(
    codigo: _codigo.text,
    cpf: _cpf.text,
    nascimento: _nascimento.text,
  );

  Future<void> _ativar(Provedor provedor) async {
    final controlador = _controlador;
    final conta = await escolherConta(context, controlador, provedor);
    if (conta != null) await controlador.ativar(conta);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CadastroPacienteControlador>();
    final (conteudo, acoes) = switch (c.passo) {
      1 => (_passo1(c), _acoesDoPasso1(c)),
      2 => (_passo2(c), _acoesDoPasso2(c)),
      _ => (_passo3(c), _acoesDoPasso3(c)),
    };
    return MolduraDoCadastro(
      chaveDaTela: const Key('TM09'),
      titulo: 'Primeiro acesso',
      passo: c.passo,
      nomeDoPasso: _nomesDosPassos[c.passo - 1],
      aoVoltarPasso: c.voltar,
      mensagem: c.mensagem,
      ocupado: c.ocupado,
      conteudo: conteudo,
      acoes: acoes,
    );
  }

  List<Widget> _passo1(CadastroPacienteControlador c) {
    final textos = Theme.of(context).textTheme;
    return [
      const TituloDoPasso('Confirme quem é o paciente'),
      const SizedBox(height: MedidasTerae.espacoPequeno),
      Text(
        'Use o código que a clínica entregou e os dados do paciente.',
        style: textos.bodyLarge?.copyWith(color: CoresTerae.neutro600),
      ),
      const SizedBox(height: MedidasTerae.espacoGrande),
      TextField(
        key: const Key('campo-codigo'),
        controller: _codigo,
        decoration: InputDecoration(
          labelText: 'Código da clínica',
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
          labelText: 'CPF do paciente',
          hintText: '000.000.000-00',
          errorText: c.erroCpf,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: const [FormatadorCpf()],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: MedidasTerae.espaco),
      TextField(
        key: const Key('campo-nascimento'),
        controller: _nascimento,
        decoration: InputDecoration(
          labelText: 'Data de nascimento do paciente',
          hintText: 'dd/mm/aaaa',
          errorText: c.erroNascimento,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: const [FormatadorData()],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => unawaited(_conferir()),
      ),
    ];
  }

  List<Widget> _acoesDoPasso1(CadastroPacienteControlador c) => [
    BotaoGrande(
      key: const Key('continuar'),
      rotulo: 'Continuar',
      aoTocar: c.ocupado ? null : () => unawaited(_conferir()),
    ),
  ];

  List<Widget> _passo2(CadastroPacienteControlador c) {
    final textos = Theme.of(context).textTheme;
    final nome = c.conferido?.nomePaciente;
    return [
      if (nome != null) ...[
        CaixaInformativa(
          icone: Icons.check_circle_outline,
          corIcone: CoresTerae.clinico700,
          texto: 'Encontramos o cadastro de $nome.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
      ],
      const TituloDoPasso('Quem vai usar o aplicativo?'),
      const SizedBox(height: MedidasTerae.espaco),
      SeletorOpcoes<QualidadeConsentimento>(
        rotulo: 'Quem vai usar o aplicativo?',
        mostrarRotulo: false,
        colunas: 1,
        valor: c.qualidade,
        aoMudar: c.escolherQualidade,
        opcoes: [
          for (final q in QualidadeConsentimento.values)
            OpcaoSeletor(
              valor: q,
              rotulo: q.rotulo,
              habilitada: c.qualidadePermitida(q),
              icone: switch (q) {
                QualidadeConsentimento.titular => Icons.person_outline,
                QualidadeConsentimento.responsavelLegal =>
                  Icons.family_restroom,
              },
            ),
        ],
      ),
      const SizedBox(height: MedidasTerae.espaco),
      Text(
        c.pacienteEhCrianca
            ? 'Como o paciente tem menos de 12 anos, quem usa o aplicativo e '
                  'aceita o termo é a mãe, o pai ou o responsável legal.'
            : 'Se o paciente for criança (menos de 12 anos), quem usa o '
                  'aplicativo e aceita o termo é a mãe, o pai ou o '
                  'responsável legal.',
        style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro600),
      ),
    ];
  }

  List<Widget> _acoesDoPasso2(CadastroPacienteControlador c) => [
    BotaoGrande(
      key: const Key('continuar'),
      rotulo: 'Continuar',
      aoTocar: c.qualidade == null ? null : c.irParaTermo,
    ),
    BotaoGrande(
      key: const Key('voltar-passo'),
      rotulo: 'Voltar',
      variante: VarianteBotao.secundario,
      aoTocar: c.voltar,
    ),
  ];

  List<Widget> _passo3(CadastroPacienteControlador c) {
    final textos = Theme.of(context).textTheme;
    return [
      const TituloDoPasso('Termo de consentimento'),
      const SizedBox(height: 2),
      Text(
        'Versão $versaoTermoConsentimento',
        style: textos.labelMedium?.copyWith(color: CoresTerae.neutro600),
      ),
      const SizedBox(height: MedidasTerae.espaco),
      const TextoDoTermo(topicos: _termo),
      const SizedBox(height: MedidasTerae.espacoGrande),
      SeletorOpcoes<CanalAutorizado>(
        rotulo: 'Como você quer receber os resumos do tratamento?',
        colunas: 1,
        valor: c.canal,
        aoMudar: c.escolherCanal,
        opcoes: [
          for (final canal in CanalAutorizado.values)
            OpcaoSeletor(
              valor: canal,
              rotulo: canal.rotulo,
              icone: switch (canal) {
                CanalAutorizado.impresso => Icons.description_outlined,
                CanalAutorizado.email => Icons.mail_outline,
                CanalAutorizado.aplicativo => Icons.smartphone,
              },
            ),
        ],
      ),
      const SizedBox(height: MedidasTerae.espaco),
      AceiteDoTermo(
        rotulo: 'Li e aceito o termo de consentimento',
        valor: c.aceite,
        aoMudar: (aceite) => c.marcarAceite(aceite: aceite),
      ),
      if (!c.podeAtivar && !c.ocupado) ...[
        const SizedBox(height: MedidasTerae.espacoPequeno),
        Text(
          'Escolha como receber os resumos e marque o aceite para continuar.',
          style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
        ),
      ],
    ];
  }

  List<Widget> _acoesDoPasso3(CadastroPacienteControlador c) => [
    BotoesDeProvedor(
      aoEscolher: c.podeAtivar ? (p) => unawaited(_ativar(p)) : null,
    ),
    BotaoGrande(
      key: const Key('voltar-passo'),
      rotulo: 'Voltar',
      variante: VarianteBotao.secundario,
      aoTocar: c.ocupado ? null : c.voltar,
    ),
  ];
}
