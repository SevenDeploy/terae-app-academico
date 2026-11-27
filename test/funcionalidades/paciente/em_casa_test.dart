/// TM16 Em casa e TM17 Atividade (evolução de TO, F1; D21–D26), com a memória
/// real da demonstração: o resumo de hoje, os cartões, registrar, corrigir,
/// desfazer, a fila sem conexão, a voz de quem usa o app e o cartão do
/// Início.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../dados/memoria_apoio.dart';

String _atividade(int n) =>
    'ca000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// Antônio: "Abotoar…" (sem registro hoje) e "Segurar o copo…" (feito hoje).
final String _abotoar = _atividade(5);
final String _copo = _atividade(6);

/// Abre como Patrícia, escolhe [nome] na seleção e vai para [aba].
Future<MemoriaDemonstracao> _comoPatricia(
  WidgetTester tester, {
  required String nome,
  String? aba,
}) async {
  final m = await abrirComMemoria(
    tester,
    persona: Persona.patricia,
    em: Rotas.entrarPerfil,
  );
  await tocar(tester, find.text(nome));
  if (aba != null) await tocar(tester, find.byKey(Key(aba)));
  return m;
}

Finder _naTm17(Finder alvo) =>
    find.descendant(of: find.byKey(const Key('TM17')), matching: alvo);

/// A opção [rotulo] do seletor "Conseguiu fazer hoje?" (o histórico também
/// mostra "Em parte" e "Sim" nas etiquetas).
Finder _opcao(String rotulo) => find.descendant(
  of: find.byKey(const Key('seletor-adesao-casa')),
  matching: find.text(rotulo),
);

void main() {
  group('TM16 Em casa', () {
    testWidgets('Antônio: resumo de hoje, um cartão por atividade e a '
        'faixa', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteCasa,
      );
      expect(find.text('Hoje: 1 de 2 atividades registradas'), findsOneWidget);
      expect(
        find.text('O que fazer entre uma sessão e outra.'),
        findsOneWidget,
      );
      final abotoar = find.byKey(Key('atividade-$_abotoar'));
      final copo = find.byKey(Key('atividade-$_copo'));
      for (final (cartao, textos) in [
        (abotoar, ['Esta semana: 4 de 5 vezes', 'Ainda não']),
        (copo, ['Esta semana: 7 de 7 vezes', 'Feito', 'Todos os dias']),
      ]) {
        for (final texto in textos) {
          expect(
            find.descendant(of: cartao, matching: find.text(texto)),
            findsOneWidget,
            reason: texto,
          );
        }
      }
      expect(
        find.descendant(
          of: abotoar,
          matching: find.text('Combinada com Tiago Moreira'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('faixa-de-dias')), findsOneWidget);
    });

    testWidgets('tocar no cartão abre a TM17; voltar leva à TM16', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteCasa,
      );
      await tocar(tester, find.byKey(Key('atividade-$_abotoar')));
      expect(find.byKey(const Key('TM17')), findsOneWidget);
      expect(
        _naTm17(find.text('Abotoar a camisa com a mão mais fraca')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('TM16')), findsOneWidget);
    });

    testWidgets('Laura ainda não tem atividades: estado vazio, falando dela', (
      tester,
    ) async {
      await _comoPatricia(tester, nome: 'Laura Andrade Neves', aba: 'aba-casa');
      expect(find.byKey(const Key('em-casa-vazio')), findsOneWidget);
      expect(
        find.textContaining('Quando a terapia ocupacional de Laura'),
        findsOneWidget,
      );
    });
  });

  group('depois de registrar (achado da revisão da F1)', () {
    testWidgets('com conexão, a TM16 e o cartão do Início mostram o dia '
        'atualizado ao voltar', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteInicio,
      );
      await tocar(tester, find.byKey(const Key('abrir-programa-em-casa')));
      expect(find.text('Hoje: 1 de 2 atividades registradas'), findsOneWidget);
      await tocar(tester, find.byKey(Key('atividade-$_abotoar')));
      await tocar(tester, _opcao('Sim'));
      await tocar(tester, find.byKey(const Key('registrar-atividade')));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Hoje: 2 de 2 atividades registradas'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(Key('atividade-$_abotoar')),
          matching: find.text('Feito'),
        ),
        findsOneWidget,
      );
      await tocar(tester, find.byKey(const Key('aba-inicio')));
      expect(
        find.descendant(
          of: find.byKey(const Key('atalho-em-casa')),
          matching: find.text('2 de 2 atividades registradas'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('puxar para atualizar envia a fila e relê', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteCasa,
        preparar: (m) async {
          await m.repositorios.demonstracao.definirSemConexao(semConexao: true);
          await m.repositorios.programaEmCasa.registrar(
            pacienteId: idAntonio,
            atividadeId: _abotoar,
            adesao: AdesaoEmCasa.feito,
            quem: QuemRegistrou.paciente,
          );
          // A rede volta sem o painel esvaziar a fila.
          m.semConexao = false;
        },
      );
      expect(m.estado.filaCasa, hasLength(1));
      await tester.fling(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(m.estado.filaCasa, isEmpty);
      expect(find.text('Hoje: 2 de 2 atividades registradas'), findsOneWidget);
    });
  });

  group('TM17 Atividade (D26)', () {
    testWidgets('registrar "Em parte" com reflexão; corrigir para "Sim"; '
        'desfazer', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade(_abotoar),
      );
      final registrar = find.byKey(const Key('registrar-atividade'));
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: registrar,
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
        reason: 'sem resposta, não registra',
      );
      expect(find.text('Conseguiu fazer hoje?'), findsOneWidget);

      await tocar(tester, _opcao('Em parte'));
      await tester.enterText(
        find.byKey(const Key('campo-reflexao')),
        'Dois botões, sem pressa.',
      );
      await tocar(tester, registrar);
      expect(find.text('Registrado. Obrigado por contar!'), findsOneWidget);
      expect(find.byKey(const Key('registro-de-hoje')), findsOneWidget);
      final hoje = DataCivil.doInstante(agoraDaMemoria);
      final gravado = m.estado.registrosCasa.values.singleWhere(
        (r) => r.atividadeId == _abotoar && r.dia == hoje,
      );
      expect(gravado.adesao, AdesaoEmCasa.emParte);
      expect(gravado.reflexao, 'Dois botões, sem pressa.');
      expect(gravado.quem, QuemRegistrou.paciente);

      await tocar(tester, find.byKey(const Key('corrigir-atividade')));
      expect(find.text('Dois botões, sem pressa.'), findsOneWidget);
      await tocar(tester, _opcao('Sim'));
      await tocar(tester, find.byKey(const Key('registrar-atividade')));
      expect(find.text('Correção registrada.'), findsOneWidget);
      expect(m.estado.registrosCasa[gravado.id]!.adesao, AdesaoEmCasa.feito);

      await tocar(tester, find.byKey(const Key('desfazer-atividade')));
      await tocar(tester, find.byKey(const Key('confirmar-desfazer')));
      expect(find.text('Registro de hoje desfeito.'), findsOneWidget);
      expect(find.byKey(const Key('seletor-adesao-casa')), findsOneWidget);
      expect(m.estado.registrosCasa[gravado.id]!.excluido, isTrue);
    });

    testWidgets('"Não deu hoje" acolhe, sem cobrança', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade(_abotoar),
      );
      expect(find.byKey(const Key('acolhimento-nao-deu')), findsNothing);
      await tocar(tester, _opcao('Não deu hoje'));
      expect(
        find.text('O dia não permitiu. Tudo bem, é comum.'),
        findsOneWidget,
      );
    });

    testWidgets('sem conexão: guardado no aparelho e na fila', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade(_abotoar),
        preparar: (m) =>
            m.repositorios.demonstracao.definirSemConexao(semConexao: true),
      );
      await tocar(tester, _opcao('Sim'));
      await tocar(tester, find.byKey(const Key('registrar-atividade')));
      expect(find.text('Registrado, sem conexão agora.'), findsOneWidget);
      expect(find.byKey(const Key('registro-na-fila')), findsOneWidget);
      expect(find.textContaining('Guardado no aparelho'), findsOneWidget);
      expect(
        m.estado.filaCasa.values.single.situacaoEnvio,
        SituacaoEnvio.naFila,
      );
    });

    testWidgets('o histórico mostra o que foi contado nos outros dias', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade(_abotoar),
      );
      // O rótulo de seção aparece em caixa alta.
      expect(find.text('O QUE VOCÊ CONTOU'), findsOneWidget);
      expect(find.text('Os 5 botões! Demorou, mas foi.'), findsOneWidget);
      expect(find.text('Esta semana: 4 de 5 vezes'), findsOneWidget);
    });

    testWidgets('a responsável: "Conseguiram fazer hoje?" e o registro é de '
        'quem cuida (D24)', (tester) async {
      final m = await _comoPatricia(
        tester,
        nome: 'Miguel Andrade Neves',
        aba: 'aba-casa',
      );
      await tocar(tester, find.byKey(Key('atividade-${_atividade(1)}')));
      expect(find.text('Conseguiram fazer hoje?'), findsOneWidget);
      expect(find.text('O QUE VOCÊS CONTARAM'), findsOneWidget);
      await tocar(tester, _opcao('Sim'));
      await tocar(tester, find.byKey(const Key('registrar-atividade')));
      final hoje = DataCivil.doInstante(agoraDaMemoria);
      final gravado = m.estado.registrosCasa.values.singleWhere(
        (r) => r.atividadeId == _atividade(1) && r.dia == hoje,
      );
      expect(gravado.quem, QuemRegistrou.responsavel);
    });

    testWidgets('aberta por link direto, a seta leva à TM16', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade(_abotoar),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('TM16')), findsOneWidget);
    });

    testWidgets('atividade que não existe: aviso simples', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.atividade('nao-existe'),
      );
      expect(find.byKey(const Key('atividade-inexistente')), findsOneWidget);
    });
  });

  group('Início e diário de quem faz TO (F1)', () {
    testWidgets('Antônio: atalho "Atividades de casa" e diário com as '
        'palavras da TO', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteInicio,
      );
      final atalho = find.byKey(const Key('atalho-em-casa'));
      expect(
        find.descendant(
          of: atalho,
          matching: find.text('1 de 2 atividades registradas'),
        ),
        findsOneWidget,
      );
      expect(find.text('Como foi o seu dia?'), findsOneWidget);
      expect(find.byKey(const Key('orientacao-vigente')), findsNothing);
      await tocar(tester, find.byKey(const Key('abrir-programa-em-casa')));
      expect(find.byKey(const Key('TM16')), findsOneWidget);

      await tocar(tester, find.byKey(const Key('aba-diario')));
      for (final texto in [
        'Como foi o seu dia?',
        'E a rotina combinada, deu para seguir?',
        'Segui',
        'O quanto o dia foi difícil?',
        'Crise ou desregulação',
      ]) {
        expect(find.text(texto), findsWidgets, reason: texto);
      }
    });

    testWidgets('Ana (psiquiatria e TO): diário das Atividades 3 e 4 e o '
        'atalho de casa', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteInicio,
      );
      expect(find.text('Como foi o seu dia?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('atalho-em-casa')),
          matching: find.text('0 de 2 atividades registradas'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('orientacao-vigente')), findsOneWidget);
    });

    testWidgets('Miguel, pela mãe: diário de TO na voz dela até o resumo do '
        'envio', (tester) async {
      await _comoPatricia(
        tester,
        nome: 'Miguel Andrade Neves',
        aba: 'aba-diario',
      );
      expect(find.text('Como foi o dia de Miguel?'), findsOneWidget);
      expect(
        find.text(
          'Para enviar, escolha a rotina, a intensidade e o que mais pesou.',
        ),
        findsOneWidget,
      );
      await preencherDiario(
        tester,
        adesao: 'Seguimos',
        intensidade: 'Leve',
        sintoma: 'Sono ruim',
      );
      await tocar(tester, find.byKey(const Key('enviar-diario')));
      final resumo = find.byKey(const Key('resumo-envio'));
      for (final texto in ['Rotina', 'Seguimos', 'O que mais pesou']) {
        expect(
          find.descendant(of: resumo, matching: find.text(texto)),
          findsOneWidget,
          reason: texto,
        );
      }
    });
  });
}
