import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/cartao_de_opcao.dart';

/// Os textos do diário conforme o paciente e quem está com o aparelho (P3;
/// D24, D32 revista).
///
/// As quatro perguntas são as do portal (`textos.ts`, quadros 18e e 18f).
/// Muda só a primeira, pela linha de cuidado: quem faz terapia ocupacional
/// conta das atividades em casa ("Vocês conseguiram fazer as atividades em
/// casa?"); quem só tem acompanhamento clínico, do tratamento combinado
/// ("Você conseguiu seguir o tratamento combinado?"). A voz segue a D24: o
/// titular lê sobre si; o responsável legal, sobre o paciente, no plural.
@immutable
class TextosDoDiario {
  const TextosDoDiario._({
    required this.tituloDoDiario,
    required this.subtituloDoDiario,
    required this.tituloDoNovo,
    required this.deQuemNoTitulo,
    required this.oDia,
    required this.sobreNaFrase,
    required this.perguntaAdesao,
    required this.faltaAdesao,
    required this.termoDaAdesao,
    required this.prefixoNaLista,
    required this.exemploDoQueContar,
    required this.quemLe,
    required this.quemLeNaFrase,
    required this.subtituloDoAtalho,
    required this.opcoesDaAdesao,
  });

  /// Os textos para o [perfil] ativo.
  factory TextosDoDiario.para(Perfil perfil) {
    final paciente = perfil.paciente;
    final nome = paciente.primeiroNome;
    final deOutro = perfil.falaDeOutraPessoa;
    final to = paciente.temTerapiaOcupacional;
    final String pergunta;
    final String falta;
    final Map<Adesao, OpcaoDeCartao<Adesao>> opcoes;
    if (to) {
      pergunta = deOutro
          ? 'Vocês conseguiram fazer as atividades em casa?'
          : 'Você conseguiu fazer as atividades em casa?';
      falta = deOutro
          ? 'Conte se vocês conseguiram fazer as atividades em casa.'
          : 'Conte se você conseguiu fazer as atividades em casa.';
      opcoes = _opcoes(
        tudo: deOutro ? 'Fizemos tudo' : 'Fiz tudo',
        parte: deOutro ? 'Fizemos parte' : 'Fiz parte',
        nada: 'Não deu para fazer',
        descricaoDeTudo: 'Deu para seguir as orientações da terapeuta.',
      );
    } else {
      pergunta = deOutro
          ? 'Vocês conseguiram seguir o tratamento combinado?'
          : 'Você conseguiu seguir o tratamento combinado?';
      falta = deOutro
          ? 'Conte se vocês conseguiram seguir o tratamento combinado.'
          : 'Conte se você conseguiu seguir o tratamento combinado.';
      opcoes = _opcoes(
        tudo: deOutro ? 'Seguimos tudo' : 'Segui tudo',
        parte: deOutro ? 'Seguimos uma parte' : 'Segui uma parte',
        nada: 'Não deu para seguir',
        descricaoDeTudo: 'Os remédios e as orientações da equipe.',
      );
    }
    return TextosDoDiario._(
      tituloDoDiario: deOutro ? 'Diário de $nome' : 'Seu diário',
      subtituloDoDiario:
          'O que você registra em casa. ${to ? 'A terapeuta' : 'A equipe'} '
          'lê e marca como revisado.',
      tituloDoNovo: deOutro
          ? 'Como foi o dia de $nome?'
          : 'Como foi o seu dia?',
      deQuemNoTitulo: deOutro ? ' de $nome' : '',
      oDia: deOutro ? 'o dia de $nome' : 'o seu dia',
      sobreNaFrase: deOutro ? ' sobre $nome' : '',
      perguntaAdesao: pergunta,
      faltaAdesao: falta,
      termoDaAdesao: to ? 'Atividades em casa' : 'Tratamento',
      prefixoNaLista: to ? 'Atividades' : 'Tratamento',
      exemploDoQueContar: to
          ? 'Pode escrever do seu jeito. Por exemplo: “recusou o jantar duas '
                'vezes”.'
          : 'Pode escrever do seu jeito. Por exemplo: “dormi mal e acordei '
                'com dor de cabeça”.',
      quemLe: to ? 'terapeuta' : 'equipe',
      quemLeNaFrase: deOutro
          ? '${to ? 'A terapeuta' : 'A equipe'} de $nome'
          : (to ? 'A sua terapeuta' : 'A sua equipe'),
      subtituloDoAtalho: deOutro
          ? 'Conte como foi o dia de $nome. Leva menos de 1 minuto.'
          : 'Conte como foi o seu dia. Leva menos de 1 minuto.',
      opcoesDaAdesao: opcoes,
    );
  }

  static Map<Adesao, OpcaoDeCartao<Adesao>> _opcoes({
    required String tudo,
    required String parte,
    required String nada,
    required String descricaoDeTudo,
  }) => {
    Adesao.total: OpcaoDeCartao(
      valor: Adesao.total,
      titulo: tudo,
      descricao: descricaoDeTudo,
    ),
    Adesao.parcial: OpcaoDeCartao(
      valor: Adesao.parcial,
      titulo: parte,
      descricao: 'Deu para fazer algumas coisas, outras não.',
    ),
    Adesao.nenhuma: OpcaoDeCartao(
      valor: Adesao.nenhuma,
      titulo: nada,
      descricao: 'O dia não permitiu. Tudo bem, é comum.',
    ),
  };

  /// "Diário de Miguel" | "Seu diário".
  final String tituloDoDiario;
  final String subtituloDoDiario;

  /// "Como foi o dia de Miguel?" | "Como foi o seu dia?".
  final String tituloDoNovo;

  /// " de Miguel" | "" ("Corrigir registro de Miguel").
  final String deQuemNoTitulo;

  /// "o dia de Miguel" | "o seu dia".
  final String oDia;

  /// " sobre Miguel" | "" ("O que você contou sobre Miguel chegou…").
  final String sobreNaFrase;

  /// A primeira pergunta, a única obrigatória (D32).
  final String perguntaAdesao;

  /// A mensagem quando a primeira pergunta fica sem resposta.
  final String faltaAdesao;

  /// "Atividades em casa" | "Tratamento", no recibo.
  final String termoDaAdesao;

  /// "Atividades" | "Tratamento", na lista ("Atividades: fizemos parte").
  final String prefixoNaLista;
  final String exemploDoQueContar;

  /// "terapeuta" | "equipe" ("Aguardando a terapeuta").
  final String quemLe;

  /// "A terapeuta de Miguel" | "A sua terapeuta" | "A sua equipe".
  final String quemLeNaFrase;

  /// O cartão do diário no Início.
  final String subtituloDoAtalho;
  final Map<Adesao, OpcaoDeCartao<Adesao>> opcoesDaAdesao;

  /// O título da opção de adesão ("Fizemos parte").
  String tituloDaAdesao(Adesao a) => opcoesDaAdesao[a]!.titulo;

  /// "Atividades: fizemos parte" (quadro 18e).
  String adesaoNaLista(Adesao a) =>
      '$prefixoNaLista: ${tituloDaAdesao(a).toLowerCase()}';
}

/// As [TextosDoDiario] do perfil ativo, para as telas que mostram ou pedem
/// um registro. Sem perfil (teste isolado), a voz do titular só com TO.
TextosDoDiario palavrasDoDiario(BuildContext context) {
  final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
  return perfil == null ? _semPerfil : TextosDoDiario.para(perfil);
}

final TextosDoDiario _semPerfil = TextosDoDiario._(
  tituloDoDiario: 'Seu diário',
  subtituloDoDiario:
      'O que você registra em casa. A terapeuta lê e marca como revisado.',
  tituloDoNovo: 'Como foi o seu dia?',
  deQuemNoTitulo: '',
  oDia: 'o seu dia',
  sobreNaFrase: '',
  perguntaAdesao: 'Você conseguiu fazer as atividades em casa?',
  faltaAdesao: 'Conte se você conseguiu fazer as atividades em casa.',
  termoDaAdesao: 'Atividades em casa',
  prefixoNaLista: 'Atividades',
  exemploDoQueContar:
      'Pode escrever do seu jeito. Por exemplo: “recusou o jantar duas '
      'vezes”.',
  quemLe: 'terapeuta',
  quemLeNaFrase: 'A sua terapeuta',
  subtituloDoAtalho: 'Conte como foi o seu dia. Leva menos de 1 minuto.',
  opcoesDaAdesao: TextosDoDiario._opcoes(
    tudo: 'Fiz tudo',
    parte: 'Fiz parte',
    nada: 'Não deu para fazer',
    descricaoDeTudo: 'Deu para seguir as orientações da terapeuta.',
  ),
);

/// O estado das quatro perguntas (quadros 18e e 18f), para o registro novo
/// (TM13) e a correção (TM15) perguntarem igual. Só a primeira é obrigatória
/// (RNFM02: nenhum texto é exigido).
class RespostasDoDiario extends ChangeNotifier {
  RespostasDoDiario({EntradaDoDiario? inicial})
    : _adesao = inicial?.adesao,
      _intensidade = inicial?.intensidadeSintoma,
      sintomas = TextEditingController(text: inicial?.sintomas ?? ''),
      observacoes = TextEditingController(text: inicial?.observacoes ?? '');

  /// "Aconteceu alguma coisa que você queira contar?"
  final TextEditingController sintomas;

  /// "Quer deixar mais alguma observação?"
  final TextEditingController observacoes;

  Adesao? _adesao;
  Intensidade? _intensidade;
  bool _faltaAdesao = false;
  bool _descartado = false;

  Adesao? get adesao => _adesao;
  Intensidade? get intensidade => _intensidade;

  /// A primeira pergunta ficou sem resposta na última tentativa de enviar.
  bool get faltaAdesao => _faltaAdesao;

  void escolherAdesao(Adesao valor) {
    _adesao = valor;
    _faltaAdesao = false;
    avisar();
  }

  /// `null` = "Deixar sem resposta".
  void escolherIntensidade(Intensidade? valor) {
    _intensidade = valor;
    avisar();
  }

  /// As respostas como o corpo da API, ou `null` (e [faltaAdesao]) sem a
  /// primeira.
  EntradaDoDiario? entrada() {
    final adesao = _adesao;
    if (adesao == null) {
      _faltaAdesao = true;
      avisar();
      return null;
    }
    return EntradaDoDiario(
      adesao: adesao,
      sintomas: sintomas.text,
      intensidadeSintoma: _intensidade,
      observacoes: observacoes.text,
    );
  }

  /// Volta tudo ao começo.
  void limpar() {
    _adesao = null;
    _intensidade = null;
    _faltaAdesao = false;
    sintomas.clear();
    observacoes.clear();
    avisar();
  }

  @protected
  void avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    sintomas.dispose();
    observacoes.dispose();
    super.dispose();
  }
}

/// As quatro perguntas do diário (quadros 18e e 18f): a adesão em cartões,
/// "Aconteceu alguma coisa que você queira contar?", "O quanto isso
/// atrapalhou o dia?" (quatro cartões e "Deixar sem resposta") e "Quer
/// deixar mais alguma observação?". O formulário nunca diz "alerta" nem
/// "crítico".
class CamposDoDiario extends StatelessWidget {
  const CamposDoDiario({
    super.key,
    required this.respostas,
    required this.palavras,
  });

  final RespostasDoDiario respostas;
  final TextosDoDiario palavras;

  static const TextStyle _pergunta = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: CoresTerae.neutro900,
  );

  @override
  Widget build(BuildContext context) {
    final r = respostas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrupoDeCartoes<Adesao>(
          key: const Key('seletor-adesao'),
          pergunta: palavras.perguntaAdesao,
          valor: r.adesao,
          aoMudar: r.escolherAdesao,
          erro: r.faltaAdesao ? palavras.faltaAdesao : null,
          opcoes: [for (final a in Adesao.values) palavras.opcoesDaAdesao[a]!],
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        _CampoDeTexto(
          chave: const Key('campo-sintomas'),
          pergunta: 'Aconteceu alguma coisa que você queira contar?',
          ajuda: palavras.exemploDoQueContar,
          controlador: r.sintomas,
          linhas: 4,
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        GrupoDeCartoes<Intensidade>(
          key: const Key('seletor-intensidade'),
          pergunta: 'O quanto isso atrapalhou o dia?',
          opcional: true,
          estiloDaPergunta: _pergunta,
          valor: r.intensidade,
          aoMudar: r.escolherIntensidade,
          opcoes: [
            for (final i in Intensidade.values)
              OpcaoDeCartao(valor: i, titulo: i.rotulo),
          ],
        ),
        if (r.intensidade != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('deixar-sem-resposta'),
              onPressed: () => r.escolherIntensidade(null),
              child: const Text('Deixar sem resposta'),
            ),
          ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        _CampoDeTexto(
          chave: const Key('campo-observacoes'),
          pergunta: 'Quer deixar mais alguma observação?',
          controlador: r.observacoes,
          linhas: 3,
        ),
      ],
    );
  }
}

class _CampoDeTexto extends StatelessWidget {
  const _CampoDeTexto({
    required this.chave,
    required this.pergunta,
    required this.controlador,
    required this.linhas,
    this.ajuda,
  });

  final Key chave;
  final String pergunta;
  final String? ajuda;
  final TextEditingController controlador;
  final int linhas;

  @override
  Widget build(BuildContext context) {
    final ajuda = this.ajuda;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text.rich(
            TextSpan(
              text: pergunta,
              children: const [
                TextSpan(
                  text: ' (opcional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: CoresTerae.neutro600,
                  ),
                ),
              ],
            ),
            style: CamposDoDiario._pergunta,
          ),
        ),
        if (ajuda != null) ...[
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              ajuda,
              style: const TextStyle(fontSize: 14, color: CoresTerae.neutro600),
            ),
          ),
        ],
        const SizedBox(height: MedidasTerae.espacoPequeno),
        TextField(
          key: chave,
          controller: controlador,
          minLines: linhas,
          maxLines: linhas + 3,
          maxLength: limiteDoTextoDoDiario,
          textCapitalization: TextCapitalization.sentences,
          // A pergunta já está à vista acima; o rótulo do campo fica só
          // para o leitor de tela (transparente e sem flutuar).
          decoration: InputDecoration(
            labelText: ajuda == null
                ? '$pergunta (opcional)'
                : '$pergunta (opcional). $ajuda',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            labelStyle: const TextStyle(color: Colors.transparent),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
