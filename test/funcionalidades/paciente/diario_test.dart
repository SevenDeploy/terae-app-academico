/// O registro novo do diário (TM13), o recibo (TM04) e a ajuda imediata
/// (TM05), iguais aos do portal da família (P3; quadros 18e, 18f, 18g e 19d).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/funcionalidades/paciente/registros/correcao_tela.dart';
import 'package:terae_app/funcionalidades/paciente/registros/novo_registro_controlador.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/uuid.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

/// As telas cheias e a do formulário: só [tela] está aberta entre elas.
void _naTela(String tela) {
  // As abas ficam montadas (IndexedStack); TM04/TM05/TM13 saem de verdade.
  expect(find.byKey(Key(tela)), findsOneWidget, reason: 'esperava $tela');
  for (final outra in ['TM04', 'TM05', 'TM13']) {
    if (outra != tela) {
      expect(find.byKey(Key(outra)), findsNothing, reason: '$outra aberta');
    }
  }
}

/// O cartão de opção com [texto] está marcado (semântica `checked`)?
Matcher _marcada({required bool sim}) => isSemantics(
  isInMutuallyExclusiveGroup: true,
  hasCheckedState: true,
  isChecked: sim,
);

const String _muito = 'Muito — precisamos de ajuda';
const String _bastante = 'Bastante — atrapalhou o dia';
const String _maisOuMenos = 'Mais ou menos — atrapalhou um pouco';

/// Abre o "Novo registro" (TM13).
Future<AppDoPaciente> _abrirNovo(
  WidgetTester tester, {
  DiarioControlavel? diario,
}) =>
    abrirAppDoPaciente(tester, em: Rotas.pacienteNovoRegistro, diario: diario);

void main() {
  group('Início → novo registro → TM04 em até cinco toques (§12, RNFM02)', () {
    testWidgets('do Início ao registro enviado, contando os toques', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(tester);
      final toques = ContadorDeToques(tester);
      _naTela('TM02');

      await toques.tocar(find.byKey(const Key('atalho-diario')));
      expect(toques.total, lessThanOrEqualTo(2), reason: '§12: até 2 toques');
      _naTela('TM13');

      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);

      expect(toques.total, lessThanOrEqualTo(5));
      _naTela('TM04');
      expect(find.text('Registro enviado.'), findsOneWidget);
      expect(find.text('A sua equipe vai ler com atenção.'), findsOneWidget);

      final registro = app.diario.enviados.single;
      expect(uuidV4Valido(registro.id), isTrue, reason: 'UUID do aparelho');
      expect(registro.pacienteId, 'p-ana');
      expect(registro.registradoEm, agoraDeTeste);
      expect(registro.adesao, Adesao.total);
      expect(registro.intensidadeSintoma, Intensidade.leve);
      expect(registro.sintomas, isNull, reason: 'opcional');
      expect(registro.observacoes, isNull, reason: 'opcional');
      expect(registro.versao, 1);
      expect(registro.situacaoEnvio, SituacaoEnvio.naFila);

      // O recibo do 18f: as quatro respostas, com a palavra curta do selo.
      final recibo = find.byKey(const Key('resumo-envio'));
      for (final texto in [
        'Segui tudo',
        'Nada a contar',
        'Pouco',
        'Sem observação',
      ]) {
        expect(
          find.descendant(of: recibo, matching: find.text(texto)),
          findsOneWidget,
          reason: texto,
        );
      }
      expect(find.byKey(const Key('corrigir-agora')), findsOneWidget);
      expect(
        find.textContaining('Enquanto a equipe não revisar'),
        findsOneWidget,
      );
    });

    testWidgets('pela aba: a lista e o "Novo registro"', (tester) async {
      await abrirAppDoPaciente(tester);
      final toques = ContadorDeToques(tester);
      await toques.tocar(find.byKey(const Key('aba-diario')));
      expect(localDe(tester), Rotas.pacienteDiario);
      await toques.tocar(find.byKey(const Key('novo-registro')));
      _naTela('TM13');
      expect(find.text('Como foi o seu dia?'), findsOneWidget);
      expect(
        find.text('Você conseguiu seguir o tratamento combinado?'),
        findsOneWidget,
      );
    });

    testWidgets('depois de enviar, "Voltar ao início" e a aba Diário mostram o '
        'registro novo (a lista relê ao voltar)', (tester) async {
      await abrirAppDoPaciente(tester);
      final toques = ContadorDeToques(tester);
      await toques.tocar(find.byKey(const Key('aba-diario')));
      expect(find.textContaining('Registro de emulador'), findsNothing);
      await toques.tocar(find.byKey(const Key('novo-registro')));
      await preencherDiario(toques, sintomas: 'Registro de emulador');
      await toques.tocar(botaoEnviar);
      await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
      _naTela('TM02');
      await toques.tocar(find.byKey(const Key('aba-diario')));
      expect(localDe(tester), Rotas.pacienteDiario);
      expect(find.textContaining('Registro de emulador'), findsOneWidget);
    });

    testWidgets('só a primeira pergunta é obrigatória: sem ela, a tela '
        'explica e nada é enviado', (tester) async {
      final app = await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await toques.tocar(botaoEnviar);
      expect(
        find.text('Conte se você conseguiu seguir o tratamento combinado.'),
        findsOneWidget,
      );
      expect(app.diario.enviados, isEmpty);
      _naTela('TM13');

      await toques.tocar(find.text('Não deu para seguir'));
      expect(
        find.text('Conte se você conseguiu seguir o tratamento combinado.'),
        findsNothing,
      );
      await toques.tocar(botaoEnviar);
      _naTela('TM04');
      final registro = app.diario.enviados.single;
      expect(registro.adesao, Adesao.nenhuma);
      expect(registro.intensidadeSintoma, isNull);
      expect(find.text('Sem resposta'), findsOneWidget);
    });

    testWidgets('os textos opcionais vão no registro, sem os espaços', (
      tester,
    ) async {
      final app = await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, sintomas: '  Dormi pouco.  ');
      await tester.enterText(
        find.byKey(const Key('campo-observacoes')),
        '  Tomei café tarde.  ',
      );
      await toques.tocar(botaoEnviar);
      final registro = app.diario.enviados.single;
      expect(registro.sintomas, 'Dormi pouco.');
      expect(registro.observacoes, 'Tomei café tarde.');
      expect(find.text('Dormi pouco.'), findsOneWidget, reason: 'no recibo');
      expect(find.text('Tomei café tarde.'), findsOneWidget);
    });

    testWidgets('"Deixar sem resposta" desmarca o quanto atrapalhou', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final app = await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _maisOuMenos);
      expect(tester.getSemantics(find.text(_maisOuMenos)), _marcada(sim: true));
      await toques.tocar(find.byKey(const Key('deixar-sem-resposta')));
      expect(
        tester.getSemantics(find.text(_maisOuMenos)),
        _marcada(sim: false),
      );
      expect(find.byKey(const Key('deixar-sem-resposta')), findsNothing);
      await toques.tocar(botaoEnviar);
      expect(app.diario.enviados.single.intensidadeSintoma, isNull);
      semantica.dispose();
    });

    testWidgets('trocar a escolha desmarca a anterior', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, adesao: 'Segui uma parte');
      await toques.tocar(find.text('Segui tudo'));
      expect(tester.getSemantics(find.text('Segui tudo')), _marcada(sim: true));
      expect(
        tester.getSemantics(find.text('Segui uma parte')),
        _marcada(sim: false),
      );
      semantica.dispose();
    });

    testWidgets('cada registro ganha um UUID novo', (tester) async {
      final app = await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      for (var i = 0; i < 2; i++) {
        await preencherDiario(toques);
        await toques.tocar(botaoEnviar);
        await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
        await toques.tocar(find.byKey(const Key('atalho-diario')));
      }
      final ids = app.diario.enviados.map((r) => r.id).toList();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2));
    });

    testWidgets('dois toques em Enviar mandam um registro só', (tester) async {
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.tap(botaoEnviar, warnIfMissed: false);
      await tester.pump();
      expect(app.diario.enviados, hasLength(1));
      expect(find.text('Enviando…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_filledDe(botaoEnviar)).enabled,
        false,
      );

      app.diario.responder();
      await tester.pumpAndSettle();
      _naTela('TM04');
      expect(app.diario.enviados, hasLength(1));
    });

    testWidgets('falha inesperada mantém o preenchimento e explica', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.falha),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      _naTela('TM13');
      expect(
        find.textContaining('Não foi possível guardar seu registro'),
        findsOneWidget,
      );
      expect(app.diario.enviados, hasLength(1));
      expect(tester.getSemantics(find.text('Segui tudo')), _marcada(sim: true));
      semantica.dispose();
    });
  });

  group('"Muito" → TM05 sem esperar a rede (RFM04, §7.1; 18g)', () {
    testWidgets('abre a TM05 na hora mesmo com envio lento', (tester) async {
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _muito);
      await toques.tocar(botaoEnviar);

      _naTela('TM05');
      expect(localDe(tester), Rotas.pacienteDiarioAjuda);
      expect(find.byKey(const Key('ligar-188')), findsOneWidget);
      expect(find.byKey(const Key('ligar-192')), findsOneWidget);
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);

      // A resposta chega depois: só então "avisada".
      app.diario.responder();
      await tester.pumpAndSettle();
      expect(find.text('A equipe da clínica foi avisada.'), findsOneWidget);
      expect(
        find.text(
          'O que você contou chegou agora para a equipe e vai ser lido por '
          'Dra. Helena Prado.',
        ),
        findsOneWidget,
      );
      expect(find.text('Envio pendente'), findsNothing);
    });

    testWidgets('o formulário nunca diz "alerta" nem "crítico"', (
      tester,
    ) async {
      await _abrirNovo(tester);
      expect(find.textContaining('alerta'), findsNothing);
      expect(find.textContaining('rítico'), findsNothing);
      expect(find.text(_muito), findsOneWidget);
    });

    testWidgets('sem conexão: envio pendente, nunca "avisado"', (tester) async {
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.semConexao),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _muito);
      await toques.tocar(botaoEnviar);

      _naTela('TM05');
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(find.textContaining('quando houver conexão'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);
      expect(
        app.diario.enviados.single.intensidadeSintoma,
        Intensidade.critico,
      );

      // CVV com um toque.
      await tester.tap(find.byKey(const Key('ligar-188')));
      await tester.pump();
      expect(app.lancador.abertos, [Uri(scheme: 'tel', path: '188')]);
    });

    testWidgets('falha do envio: "Não conseguimos enviar", sem "avisado" '
        'nem "guardado"', (tester) async {
      await _abrirNovo(tester, diario: DiarioControlavel(ModoDoDiario.falha));
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _muito);
      await toques.tocar(botaoEnviar);
      _naTela('TM05');
      expect(find.text('Não conseguimos enviar'), findsOneWidget);
      expect(falaEmAvisado, findsNothing);
      expect(find.textContaining('guardado'), findsNothing);
      expect(find.textContaining('ainda não chegou'), findsOneWidget);
    });

    testWidgets('"Ciente" leva ao Início', (tester) async {
      await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _muito);
      await toques.tocar(botaoEnviar);
      expect(find.text('A equipe da clínica foi avisada.'), findsOneWidget);
      await toques.tocar(find.byKey(const Key('ciente')));
      expect(localDe(tester), Rotas.pacienteInicio);
      _naTela('TM02');
    });
  });

  group('TM04: guardado neste aparelho, lento e falha (RFM05, §19; 19d)', () {
    testWidgets('na fila: "Registro guardado neste aparelho.", com os '
        'números de emergência para "Bastante"', (tester) async {
      await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.semConexao),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _bastante);
      await toques.tocar(botaoEnviar);
      _naTela('TM04');
      expect(find.text('Registro guardado neste aparelho.'), findsOneWidget);
      expect(find.textContaining('ainda não foi enviado'), findsOneWidget);
      expect(find.byKey(const Key('ajuda-sem-internet')), findsOneWidget);
      expect(find.byKey(const Key('ligar-192')), findsOneWidget);
      // Diz que a equipe só é avisada quando chegar; nunca que "foi".
      expect(find.textContaining('foi avisad'), findsNothing);
      expect(find.byKey(const Key('corrigir-agora')), findsNothing);

      // "Ver no diário": o guardado aparece no alto da lista.
      await toques.tocar(find.byKey(const Key('ver-no-diario')));
      expect(localDe(tester), Rotas.pacienteDiario);
      expect(find.byKey(const Key('pendentes-do-diario')), findsOneWidget);
      expect(find.text('Guardado, aguardando a internet'), findsOneWidget);
    });

    testWidgets('sem internet a lista não abre, mas o guardado continua na '
        'tela (não se escreve de novo)', (tester) async {
      final diario = DiarioControlavel(ModoDoDiario.semConexao)
        ..listaForaDoAr = true;
      diario.fila['g-1'] = RegistroDiario(
        id: 'g-1',
        pacienteId: 'p-ana',
        registradoEm: agoraDeTeste,
        adesao: Adesao.total,
        situacaoEnvio: SituacaoEnvio.naFila,
      );
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: diario,
      );
      expect(find.byKey(const Key('pendentes-do-diario')), findsOneWidget);
      expect(find.byKey(const ValueKey('pendente-g-1')), findsOneWidget);
      expect(
        find.textContaining('Não conseguimos abrir o diário'),
        findsOneWidget,
      );
    });

    testWidgets('na fila com "Pouco": sem os números de emergência', (
      tester,
    ) async {
      await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.semConexao),
      );
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      expect(find.text('Registro guardado neste aparelho.'), findsOneWidget);
      expect(find.byKey(const Key('ajuda-sem-internet')), findsNothing);
    });

    testWidgets('envio lento abre a TM04 em 2 s e se atualiza depois', (
      tester,
    ) async {
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(const Duration(milliseconds: 1900));
      _naTela('TM13');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // a transição
      _naTela('TM04');
      expect(find.text('Enviando…'), findsOneWidget);
      expect(find.textContaining('guardado'), findsNothing);

      app.diario.responder();
      await tester.pump();
      expect(find.text('Registro enviado.'), findsOneWidget);
    });

    testWidgets('falha depois do prazo: TM04 não promete que ficou guardado', (
      tester,
    ) async {
      final app = await _abrirNovo(
        tester,
        diario: DiarioControlavel(ModoDoDiario.lento),
      );
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(prazoDeResposta);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // a transição
      _naTela('TM04');

      app.diario.falharPendente();
      await tester.pump();
      expect(find.text('Registro não enviado'), findsOneWidget);
      expect(find.textContaining('guardado'), findsNothing);
      expect(falaEmAvisado, findsNothing);
    });

    testWidgets('não volta sozinha (como o recibo do portal); "Voltar ao '
        'início" volta', (tester) async {
      await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      _naTela('TM04');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      _naTela('TM04');
      await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
      expect(localDe(tester), Rotas.pacienteInicio);
      _naTela('TM02');
    });

    testWidgets('"Corrigir agora" abre a correção do mesmo registro', (
      tester,
    ) async {
      final app = await _abrirNovo(tester);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      await toques.tocar(find.byKey(const Key('corrigir-agora')));
      expect(find.byKey(const Key('TM15')), findsOneWidget);
      expect(
        tester.widget<CorrecaoTela>(find.byType(CorrecaoTela)).registroId,
        app.diario.enviados.single.id,
      );
    });
  });

  group('sem internet no aparelho (18m, 19d)', () {
    testWidgets('"Enviar" fica travado com o motivo; "Guardar e enviar '
        'depois" guarda e abre a TM04', (tester) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteNovoRegistro,
        diario: DiarioControlavel(ModoDoDiario.semConexao),
        conexao: semInternet(),
      );
      final toques = ContadorDeToques(tester);
      expect(find.text('Enviar · precisa de internet'), findsOneWidget);
      expect(find.byKey(const Key('motivo-sem-internet')), findsOneWidget);
      await preencherDiario(toques);
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(app.diario.enviados, isEmpty, reason: 'travado sem internet');

      await toques.tocar(find.byKey(const Key('guardar-e-enviar-depois')));
      _naTela('TM04');
      expect(find.text('Registro guardado neste aparelho.'), findsOneWidget);
      expect(app.diario.enviados.single.situacaoEnvio, SituacaoEnvio.naFila);
    });

    testWidgets('com internet não aparece "Guardar e enviar depois"', (
      tester,
    ) async {
      await _abrirNovo(tester);
      expect(find.byKey(const Key('guardar-e-enviar-depois')), findsNothing);
      expect(find.text('Enviar'), findsOneWidget);
    });
  });

  group('envio sem volta ao formulário (§21)', () {
    for (final critica in [false, true]) {
      final saida = critica ? 'TM05' : 'TM04';
      testWidgets(
        'depois da $saida, voltar não reabre o formulário preenchido',
        (tester) async {
          final semantica = tester.ensureSemantics();
          await abrirAppDoPaciente(tester);
          final toques = ContadorDeToques(tester);
          await toques.tocar(find.byKey(const Key('atalho-diario')));
          await preencherDiario(
            toques,
            intensidade: critica ? _muito : _maisOuMenos,
          );
          await tester.enterText(
            find.byKey(const Key('campo-observacoes')),
            'Texto enviado',
          );
          await toques.tocar(botaoEnviar);
          _naTela(saida);

          // Voltar do Android: Início, nunca o formulário.
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(localDe(tester), Rotas.pacienteInicio);
          _naTela('TM02');

          await toques.tocar(find.byKey(const Key('atalho-diario')));
          _naTela('TM13');
          for (final opcao in ['Segui tudo', _muito, _maisOuMenos]) {
            expect(
              tester.getSemantics(find.text(opcao)),
              _marcada(sim: false),
              reason: opcao,
            );
          }
          expect(find.text('Texto enviado'), findsNothing);
          semantica.dispose();
        },
      );
    }
  });

  group('reenvio do mesmo registro (§23: o UUID do aparelho evita '
      'duplicidade)', () {
    final tentarDeNovo = find.byKey(const Key('tentar-de-novo'));
    String tituloDaTm04(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('titulo-confirmacao'))).data!;

    testWidgets('falha no formulário: "Tentar de novo" reenvia o mesmo UUID; '
        'o próximo registro ganha outro', (tester) async {
      final diario = DiarioControlavel(ModoDoDiario.falha);
      await _abrirNovo(tester, diario: diario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      _naTela('TM13');
      expect(
        find.descendant(of: botaoEnviar, matching: find.text('Tentar de novo')),
        findsOneWidget,
      );

      diario.modo = ModoDoDiario.comConexao;
      await toques.tocar(botaoEnviar);
      _naTela('TM04');
      expect(diario.enviados, hasLength(2));
      expect(diario.enviados[1].id, diario.enviados[0].id);

      await toques.tocar(find.byKey(const Key('voltar-ao-inicio')));
      await toques.tocar(find.byKey(const Key('atalho-diario')));
      await preencherDiario(toques);
      await toques.tocar(botaoEnviar);
      expect(diario.enviados, hasLength(3));
      expect(diario.enviados[2].id, isNot(diario.enviados[0].id));
    });

    testWidgets('TM05: envio de "Muito" que falha mostra "Não conseguimos '
        'enviar", mantém 188/192 e "Tentar de novo" reenvia o mesmo '
        'registro', (tester) async {
      final diario = DiarioControlavel(ModoDoDiario.lento);
      await _abrirNovo(tester, diario: diario);
      final toques = ContadorDeToques(tester);
      await preencherDiario(toques, intensidade: _muito);
      await toques.tocar(botaoEnviar);
      _naTela('TM05');
      expect(tentarDeNovo, findsNothing, reason: 'ainda enviando');

      diario.falharPendente();
      await tester.pumpAndSettle();
      expect(find.text('Não conseguimos enviar'), findsOneWidget);
      expect(find.byKey(const Key('ligar-188')), findsOneWidget);
      expect(find.byKey(const Key('ligar-192')), findsOneWidget);
      expect(falaEmAvisado, findsNothing);
      expect(tentarDeNovo, findsOneWidget);

      await toques.tocar(tentarDeNovo);
      expect(diario.enviados, hasLength(2));
      expect(diario.enviados[1], diario.enviados[0], reason: 'mesmo registro');
      expect(find.text('Envio pendente'), findsOneWidget);
      expect(tentarDeNovo, findsNothing);

      diario.responder();
      await tester.pumpAndSettle();
      expect(find.text('A equipe da clínica foi avisada.'), findsOneWidget);
      _naTela('TM05');
    });

    testWidgets('TM04: enquanto o envio não resolve diz "Enviando…"', (
      tester,
    ) async {
      final diario = DiarioControlavel(ModoDoDiario.lento);
      await _abrirNovo(tester, diario: diario);
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(prazoDeResposta);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // a transição
      _naTela('TM04');
      expect(tituloDaTm04(tester), 'Enviando…');
      expect(find.textContaining('guardado'), findsNothing);
      expect(find.byKey(const Key('corrigir-agora')), findsNothing);

      diario.responder();
      // Sem quadro agendado, o primeiro pump só roda a resposta.
      await tester.pump();
      await tester.pump();
      expect(tituloDaTm04(tester), 'Registro enviado.');
      expect(find.byKey(const Key('corrigir-agora')), findsOneWidget);
    });

    testWidgets('TM04: falha depois do prazo; "Tentar de novo" reenvia o '
        'mesmo registro', (tester) async {
      final diario = DiarioControlavel(ModoDoDiario.lento);
      await _abrirNovo(tester, diario: diario);
      await preencherDiario(ContadorDeToques(tester));
      await tester.ensureVisible(botaoEnviar);
      await tester.tap(botaoEnviar);
      await tester.pump(prazoDeResposta);
      await tester.pump();
      diario.falharPendente();
      await tester.pump();
      expect(tituloDaTm04(tester), 'Registro não enviado');

      diario.modo = ModoDoDiario.comConexao;
      await ContadorDeToques(tester).tocar(tentarDeNovo, assentar: false);
      await tester.pump();
      expect(diario.enviados, hasLength(2));
      expect(diario.enviados[1], diario.enviados[0], reason: 'mesmo registro');
      expect(tituloDaTm04(tester), 'Registro enviado.');
    });
  });

  group('voltar do Android (§21)', () {
    testWidgets('no Diário volta ao Início; no Início fecha o app', (
      tester,
    ) async {
      await abrirAppDoPaciente(tester, em: Rotas.pacienteDiario);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(localDe(tester), Rotas.pacienteInicio);
      expect(await tester.binding.handlePopRoute(), isFalse);
    });
  });

  group('TM03: "Não deu para enviar" (TL8)', () {
    testWidgets('o guardado vencido aparece com o motivo, não conta como '
        'pendente, e "Descartar" o tira', (tester) async {
      final diario = _DiarioComVencido(
        registroEnviado(
          'vencido-1',
          em: agoraDeTeste.subtract(const Duration(days: 9)),
        ).copyWith(situacaoEnvio: SituacaoEnvio.naFila),
      );
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteDiario,
        diario: diario,
      );
      expect(find.byKey(const Key('vencidos-do-diario')), findsOneWidget);
      expect(find.text('Não será enviado'), findsOneWidget);
      expect(
        find.textContaining('Ficou guardado por mais de 7 dias'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pendentes-do-diario')), findsNothing);
      expect(find.byKey(const Key('diario-vazio')), findsNothing);

      final descartar = find.byKey(const ValueKey('descartar-vencido-1'));
      await tester.ensureVisible(descartar);
      await tester.pumpAndSettle();
      await tester.tap(descartar);
      await tester.pumpAndSettle();
      expect(diario.descartados, ['vencido-1']);
      expect(find.byKey(const Key('vencidos-do-diario')), findsNothing);
      expect(find.byKey(const Key('diario-vazio')), findsOneWidget);
    });
  });
}

Finder _filledDe(Finder botao) =>
    find.descendant(of: botao, matching: find.byType(FilledButton));

/// Diário com um guardado vencido (TL8), que só sai pelo "Descartar".
class _DiarioComVencido extends DiarioControlavel {
  _DiarioComVencido(RegistroDiario vencido) : _vencidos = [vencido];

  final List<RegistroDiario> _vencidos;
  final List<String> descartados = [];

  @override
  Future<List<RegistroDiario>> vencidos(String pacienteId) async =>
      List.unmodifiable(_vencidos);

  @override
  Future<void> descartarVencido(String registroId) async {
    descartados.add(registroId);
    _vencidos.removeWhere((r) => r.id == registroId);
  }
}
