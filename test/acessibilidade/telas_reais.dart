/// As 13 telas (TM00–TM12) montadas como no aparelho: o `TeraeApp` com a
/// memória real (`lib/dados/memoria/` sobre `assets/dados/demonstracao.json`),
/// o relógio parado em 2/10/2026 10:00 na clínica e a sessão de cada persona
/// (sem sessão, Ana, Patrícia ou Regina). Base dos testes de acessibilidade e
/// das capturas (`test/capturas/`).
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../dados/memoria_apoio.dart';

/// Quem está com o aparelho na mão.
enum Persona {
  semSessao(null),

  /// Paciente titular, um perfil só (TM02–TM07).
  ana('Ana Lúcia Martins'),

  /// Mãe de Miguel e de Laura: dois perfis, abre na seleção.
  patricia('Patrícia Andrade Neves'),

  /// Cuidadora de Ana (TM08, TM11, TM12).
  regina('Regina Martins');

  const Persona(this.nomeNaConta);

  final String? nomeNaConta;
}

/// O app inteiro com a memória de demonstração, na sessão de [persona],
/// partindo de [em]. Devolve a memória, para o teste conferir o estado.
Future<MemoriaDemonstracao> abrirComMemoria(
  WidgetTester tester, {
  required Persona persona,
  required String em,
}) async {
  final memoria = memoriaDeTeste();
  final sessao = Sessao();
  if (persona.nomeNaConta case final nome?) {
    final vinculos = await memoria.repositorios.autenticacao.entrar(
      identidadeDe(memoria, nome),
    );
    sessao.entrar(vinculos);
  }
  await tester.pumpWidget(
    TeraeApp(
      repositorios: memoria.repositorios,
      sessao: sessao,
      relogio: memoria.relogio,
      localInicial: em,
    ),
  );
  await tester.pumpAndSettle();
  return memoria;
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
    descricao: 'TM01 Entrar, com a folha "Escolha uma conta" aberta',
    abrir: (t) async {
      await abrirComMemoria(
        t,
        persona: Persona.semSessao,
        em: Rotas.boasVindas,
      );
      await tocar(t, find.byKey(const Key('ir-entrar')));
      await tocar(t, find.byKey(const Key('continuar-google')));
      expect(find.text('Escolha uma conta'), findsOneWidget);
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
];

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

/// Carrega a fonte Lexend de verdade (`assets/fonts/*.ttf`, os pesos do
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

  await carregar('Lexend', [
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Lexend-$peso.ttf',
  ]);
  await carregar('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
}
