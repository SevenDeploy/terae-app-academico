/// As 21 telas (TM00–TM20), e a TM16 também depois da alta, montadas como no
/// aparelho: o `TeraeApp` com a
/// memória real (`lib/dados/memoria/` sobre `assets/dados/demonstracao.json`),
/// o relógio parado em 2/10/2026 10:00 na clínica e a sessão de cada persona
/// (sem sessão, Ana, Patrícia, Regina ou Antônio). Base dos testes de acessibilidade e
/// das capturas (`test/capturas/`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/memoria/estado_memoria.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/modelos/atividade_de_casa.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/dados/sincronizacao/situacao_sincronizacao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../dados/memoria_apoio.dart';

/// Quem está com o aparelho na mão.
enum Persona {
  semSessao(null),

  /// Paciente titular, um perfil só (TM02–TM07).
  ana('Ana Lúcia Martins'),

  /// Mãe de Miguel e de Laura: dois perfis, abre na seleção.
  patricia('Patrícia Andrade Neves'),

  /// Cuidadora de Ana (TM08, TM11, TM12).
  regina('Regina Martins'),

  /// Titular de 71 anos, só terapia ocupacional (D23; TM16).
  antonio('Antônio Carlos Ribeiro');

  const Persona(this.nomeNaConta);

  final String? nomeNaConta;
}

/// O app inteiro com a memória de demonstração, na sessão de [persona],
/// partindo de [em]. Devolve a memória, para o teste conferir o estado.
Future<MemoriaDemonstracao> abrirComMemoria(
  WidgetTester tester, {
  required Persona persona,
  required String em,
  Future<void> Function(MemoriaDemonstracao memoria)? preparar,
  ValueListenable<SituacaoSincronizacao>? conexao,
  CapacidadesDaFonte? capacidades,
}) async {
  final memoria = memoriaDeTeste();
  await preparar?.call(memoria);
  final sessao = Sessao();
  if (persona.nomeNaConta case final nome?) {
    final vinculos = await memoria.repositorios.autenticacao.entrarCom(
      identidadeDe(memoria, nome),
    );
    sessao.entrar(vinculos);
  }
  final r = memoria.repositorios;
  await tester.pumpWidget(
    TeraeApp(
      // Com [conexao], a mesma memória com a situação da sincronização
      // controlada pelo teste (releitura ao fim da sincronização).
      // Com [capacidades], as telas como a fonte Terae local as mostra.
      repositorios: conexao == null && capacidades == null
          ? r
          : Repositorios(
              autenticacao: r.autenticacao,
              paciente: r.paciente,
              diario: r.diario,
              cuidadores: r.cuidadores,
              visaoCuidador: r.visaoCuidador,
              demonstracao: r.demonstracao,
              programaEmCasa: r.programaEmCasa,
              presenca: r.presenca,
              lembretes: r.lembretes,
              metas: r.metas,
              conexao: conexao ?? r.conexao,
              capacidades: capacidades ?? r.capacidades,
            ),
      sessao: sessao,
      relogio: memoria.relogio,
      localInicial: em,
    ),
  );
  await tester.pumpAndSettle();
  return memoria;
}

/// Registro de Ana feito hoje às 8h30 (D17: ainda dá para corrigir e excluir).
const String registroDeHoje = 'f0000000-0000-4000-8000-000000000001';

/// Envia o [registroDeHoje] de Ana pela memória (TM14, TM15).
Future<void> registrarHoje(MemoriaDemonstracao memoria) async {
  await memoria.repositorios.diario.enviar(
    RegistroDiario(
      id: registroDeHoje,
      pacienteId: idAna,
      registradoEm: instanteNaClinica(2026, 10, 2, 8, 30),
      adesao: Adesao.total,
      intensidade: Intensidade.moderada,
      sintomaPredominante: 'Ansiedade',
      observacao: 'Acordei preocupada com a prova.',
      situacaoEnvio: SituacaoEnvio.naFila,
    ),
  );
}

/// Rola até [alvo], toca e espera assentar.
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// Marca adesão, intensidade e sintoma no diário (TM03).
Future<void> preencherDiario(
  WidgetTester tester, {
  required String adesao,
  required String intensidade,
  required String sintoma,
}) async {
  for (final opcao in [adesao, intensidade, sintoma]) {
    await tocar(tester, find.text(opcao));
  }
}

/// TM00 → "Primeiro acesso" → [opcao] da folha (TM09 ou TM10), como no
/// aparelho: o cadastro abre empilhado, com a seta de voltar.
Future<void> abrirPrimeiroAcesso(WidgetTester tester, String opcao) async {
  await abrirComMemoria(
    tester,
    persona: Persona.semSessao,
    em: Rotas.boasVindas,
  );
  await tocar(tester, find.byKey(const Key('ir-primeiro-acesso')));
  await tocar(tester, find.byKey(Key(opcao)));
}

/// Volta ao topo a rolagem da tela [chave] (a captura mostra o começo).
Future<void> voltarAoTopo(WidgetTester tester, String chave) async {
  final rolagens = find.descendant(
    of: find.byKey(Key(chave)),
    matching: find.byType(Scrollable),
  );
  for (final estado in tester.stateList<ScrollableState>(rolagens)) {
    estado.position.jumpTo(0);
  }
  await tester.pumpAndSettle();
}

/// Uma tela no estado a conferir e a capturar.
class TelaReal {
  const TelaReal({
    required this.tela,
    required this.arquivo,
    required this.descricao,
    required this.abrir,
  });

  /// `TM00` … `TM12` — a chave do Scaffold (contrato).
  final String tela;

  /// Nome da captura em `docs/capturas/`, sem acento nem extensão.
  final String arquivo;

  final String descricao;

  /// Monta o app e deixa a tela no estado descrito, já assentada.
  final Future<void> Function(WidgetTester tester) abrir;
}

/// As 13 telas, mais a seleção de perfil da TM01 (Patrícia).
final List<TelaReal> telasReais = [
  TelaReal(
    tela: 'TM00',
    arquivo: 'TM00-boas-vindas',
    descricao: 'TM00 Boas-vindas, sem sessão',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.semSessao, em: Rotas.boasVindas),
  ),
  TelaReal(
    tela: 'TM01',
    arquivo: 'TM01-entrar',
    descricao: 'TM01 Entrar, com e-mail e senha preenchidos',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.semSessao,
        em: Rotas.boasVindas,
      );
      await tocar(t, find.byKey(const Key('ir-entrar')));
      await t.enterText(
        find.byKey(const Key('campo-email')),
        emailDe['Ana Lúcia Martins']!,
      );
      await t.enterText(
        find.byKey(const Key('campo-senha')),
        senhaDeDemonstracao,
      );
      await t.pumpAndSettle();
    },
  ),
  TelaReal(
    tela: 'TM01',
    arquivo: 'TM01b-selecao-de-perfil',
    descricao: 'TM01 seleção de perfil (Patrícia: Miguel e Laura)',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.patricia, em: Rotas.entrarPerfil),
  ),
  TelaReal(
    tela: 'TM02',
    arquivo: 'TM02-inicio',
    descricao: 'TM02 Início (Ana)',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteInicio),
  ),
  TelaReal(
    tela: 'TM03',
    arquivo: 'TM03-diario',
    descricao: 'TM03 Diário com adesão, intensidade e sintoma marcados',
    abrir: (t) async {
      await abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteDiario);
      await preencherDiario(
        t,
        adesao: 'Tomei tudo',
        intensidade: 'Leve',
        sintoma: 'Cansaço',
      );
      await voltarAoTopo(t, 'TM03');
    },
  ),
  TelaReal(
    tela: 'TM04',
    arquivo: 'TM04-diario-enviado',
    descricao: 'TM04 Diário enviado, com conexão',
    abrir: (t) async {
      await abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteDiario);
      await preencherDiario(
        t,
        adesao: 'Tomei tudo',
        intensidade: 'Moderada',
        sintoma: 'Cansaço',
      );
      await tocar(t, find.byKey(const Key('enviar-diario')));
      expect(find.text('Registro enviado!'), findsOneWidget);
    },
  ),
  TelaReal(
    tela: 'TM05',
    arquivo: 'TM05-ajuda-imediata',
    descricao: 'TM05 Ajuda imediata, crítica com "profissional avisado"',
    abrir: (t) async {
      await abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteDiario);
      await preencherDiario(
        t,
        adesao: 'Tomei uma parte',
        intensidade: 'Crítica',
        sintoma: 'Tristeza',
      );
      await tocar(t, find.byKey(const Key('enviar-diario')));
      expect(find.text('Seu profissional foi avisado.'), findsOneWidget);
    },
  ),
  TelaReal(
    tela: 'TM06',
    arquivo: 'TM06-jornada',
    descricao: 'TM06 Jornada (Ana)',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteJornada),
  ),
  TelaReal(
    tela: 'TM07',
    arquivo: 'TM07-cuidadores',
    descricao: 'TM07 Cuidadores 2/2: Regina ativa e Paulo pendente',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.ana,
        em: Rotas.pacienteCuidadores,
      );
      expect(find.text('2/2'), findsOneWidget);
    },
  ),
  TelaReal(
    tela: 'TM08',
    arquivo: 'TM08-inicio-cuidador',
    descricao: 'TM08 Início do cuidador (Regina)',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.regina, em: Rotas.cuidadorInicio),
  ),
  TelaReal(
    tela: 'TM09',
    arquivo: 'TM09-cadastro-paciente',
    descricao: 'TM09 Cadastro do paciente, passo 1',
    abrir: (t) => abrirPrimeiroAcesso(t, 'primeiro-acesso-clinica'),
  ),
  TelaReal(
    tela: 'TM10',
    arquivo: 'TM10-cadastro-cuidador',
    descricao: 'TM10 Cadastro do cuidador, passo 1',
    abrir: (t) => abrirPrimeiroAcesso(t, 'primeiro-acesso-cuidador'),
  ),
  TelaReal(
    tela: 'TM11',
    arquivo: 'TM11-medicacao',
    descricao: 'TM11 Medicação, aberta pela TM08 (Regina)',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.regina,
        em: Rotas.cuidadorInicio,
      );
      await tocar(t, find.byKey(const Key('atalho-medicacao')));
    },
  ),
  TelaReal(
    tela: 'TM12',
    arquivo: 'TM12-agenda-avisos',
    descricao: 'TM12 Agenda e avisos, aberta pela TM08 (Regina)',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.regina,
        em: Rotas.cuidadorInicio,
      );
      await tocar(t, find.byKey(const Key('atalho-agenda')));
    },
  ),
  TelaReal(
    tela: 'TM13',
    arquivo: 'TM13-meus-registros',
    descricao: 'TM13 Meus registros (Ana), com a lista do diário',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.ana, em: Rotas.pacienteRegistros),
  ),
  TelaReal(
    tela: 'TM14',
    arquivo: 'TM14-registro',
    descricao: 'TM14 Registro de hoje (Ana), com Corrigir e Excluir',
    abrir: (t) => abrirComMemoria(
      t,
      persona: Persona.ana,
      em: Rotas.registro(registroDeHoje),
      preparar: registrarHoje,
    ),
  ),
  TelaReal(
    tela: 'TM15',
    arquivo: 'TM15-corrigir-registro',
    descricao: 'TM15 Corrigir o registro de hoje (Ana)',
    abrir: (t) => abrirComMemoria(
      t,
      persona: Persona.ana,
      em: Rotas.corrigirRegistro(registroDeHoje),
      preparar: registrarHoje,
    ),
  ),
  TelaReal(
    tela: 'TM16',
    arquivo: 'TM16-em-casa',
    descricao: 'TM16 Em casa (Antônio), com 1 de 2 atividades registradas',
    abrir: (t) =>
        abrirComMemoria(t, persona: Persona.antonio, em: Rotas.pacienteCasa),
  ),
  TelaReal(
    tela: 'TM17',
    arquivo: 'TM17-atividade',
    descricao: 'TM17 Atividade (Antônio), "Em parte" marcado para hoje',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.antonio,
        em: Rotas.atividade(atividadeAbotoar),
      );
      await tocar(
        t,
        find.descendant(
          of: find.byKey(const Key('seletor-adesao-casa')),
          matching: find.text('Em parte'),
        ),
      );
      await voltarAoTopo(t, 'TM17');
    },
  ),
  telaDasSessoes,
  TelaReal(
    tela: 'TM19',
    arquivo: 'TM19-lembretes',
    descricao: 'TM19 Lembretes (Antônio), com a véspera ligada',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.antonio,
        em: Rotas.pacienteLembretes,
      );
      await tocar(t, find.byKey(const Key('lembrete-vespera')));
      await voltarAoTopo(t, 'TM19');
    },
  ),
  TelaReal(
    tela: 'TM20',
    arquivo: 'TM20-meta',
    descricao: 'TM20 Meta (Antônio), "Vestir a camisa de botão sozinho"',
    abrir: (t) => abrirComMemoria(
      t,
      persona: Persona.antonio,
      em: Rotas.meta(metaCamisaDoAntonio),
    ),
  ),
  TelaReal(
    tela: 'TM16',
    arquivo: 'TM16-em-casa-alta',
    descricao:
        'TM16 Em casa (Antônio) depois da alta (D36, preparada no teste)',
    abrir: (t) => abrirComMemoria(
      t,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
      preparar: darAltaAoAntonio,
    ),
  ),
];

/// "Vestir a camisa de botão sozinho", meta do Antônio (F3).
const String metaCamisaDoAntonio = 'ce000000-0000-4000-8000-000000000007';

/// D36 — a alta da terapia ocupacional do Antônio hoje, às 10h, como a
/// clínica a faria: o marco "Alta" e as atividades encerradas na hora, depois
/// do registro das 8h10 (que fica na faixa). Só nos testes: nenhuma persona
/// da demonstração tem alta.
Future<void> darAltaAoAntonio(MemoriaDemonstracao memoria) async {
  final hoje = memoria.hoje();
  memoria.estado.marcos['f0000000-0000-4000-8000-000000000099'] = MarcoJornada(
    id: 'f0000000-0000-4000-8000-000000000099',
    pacienteId: idAntonio,
    tipo: TipoMarco.alta,
    data: hoje,
    titulo: 'Alta da terapia ocupacional',
    textoSimples:
        'Você e o Tiago encerraram a terapia ocupacional. Parabéns pelo '
        'caminho!',
  );
  for (final a in [...memoria.estado.atividadesCasa.values]) {
    if (a.pacienteId != idAntonio) continue;
    memoria.estado.atividadesCasa[a.id] = AtividadeDeCasa(
      id: a.id,
      pacienteId: a.pacienteId,
      profissionalId: a.profissionalId,
      titulo: a.titulo,
      texto: a.texto,
      vezesPorSemana: a.vezesPorSemana,
      ocupacao: a.ocupacao,
      publicadaEm: a.publicadaEm,
      encerradaEm: memoria.agora(),
      metaId: a.metaId,
    );
  }
}

/// TM18 (F2): a agenda do Antônio, com a sessão de daqui a 7 dias sem
/// resposta de presença.
final TelaReal telaDasSessoes = TelaReal(
  tela: 'TM18',
  arquivo: 'TM18-sessoes',
  descricao: 'TM18 Sessões (Antônio), com "Você vai?" na próxima',
  abrir: (t) =>
      abrirComMemoria(t, persona: Persona.antonio, em: Rotas.pacienteSessoes),
);

/// "Abotoar a camisa com a mão mais fraca" (Antônio, F1), sem registro hoje.
const String atividadeAbotoar = 'ca000000-0000-4000-8000-000000000005';

/// Celular de 360×800 lógicos com [densidade] e a fonte do aparelho em
/// [escala]. Desfaz tudo no fim do teste.
void aparelho(WidgetTester tester, {double escala = 1, double densidade = 2}) {
  tester.view.devicePixelRatio = densidade;
  tester.view.physicalSize = const Size(360, 800) * densidade;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Carrega as fontes Inter e Lexend de verdade (`assets/fonts/*.ttf`, os pesos do
/// `pubspec.yaml`) e os ícones Material (`MaterialIcons-Regular.otf`, que o
/// `flutter test` copia de `bin/cache/artifacts/material_fonts/` para o pacote
/// de assets por causa do `uses-material-design`). Sem isso o teste desenha
/// cada letra e cada ícone como um quadrado (fonte FlutterTest). Vale para o
/// arquivo de teste inteiro: chame no `setUpAll`.
Future<void> carregarFontesReais() async {
  Future<void> carregar(String familia, List<String> arquivos) async {
    final carregador = FontLoader(familia);
    for (final arquivo in arquivos) {
      carregador.addFont(rootBundle.load(arquivo));
    }
    await carregador.load();
  }

  await carregar('Inter', [
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Inter-$peso.ttf',
  ]);
  await carregar('Lexend', [
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Lexend-$peso.ttf',
  ]);
  await carregar('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  await carregar('packages/lucide_icons_flutter/Lucide', [
    'packages/lucide_icons_flutter/assets/lucide.ttf',
  ]);
}
