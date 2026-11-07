/// Metas da terapia ocupacional (evolução de TO, F3; D25, D35, D36), com a
/// memória real: "Nossas metas" na Jornada, a TM20, as ligações com a TM16 e
/// a TM17, e o programa encerrado depois da alta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/ocupacao.dart';
import 'package:terae_app/dados/enums/situacao_meta.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/meta_terapeutica.dart';
import 'package:terae_app/dados/modelos/paciente.dart';
import 'package:terae_app/dados/repositorios/metas_repositorio.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../apoio/dubles.dart';
import '../../dados/memoria_apoio.dart';
import 'apoio_paciente.dart';

String _meta(int n) =>
    'ce000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

const String _abotoar = 'ca000000-0000-4000-8000-000000000005';
const String _copo = 'ca000000-0000-4000-8000-000000000006';

/// O que a família nunca lê (D25).
final Finder _escore = find.textContaining(
  RegExp(r'escore|\bGAS\b|nível|pontuaç', caseSensitive: false),
);

Finder _em(Key chave, Finder alvo) =>
    find.descendant(of: find.byKey(chave), matching: alvo);

Finder _opcao(String rotulo) => find.descendant(
  of: find.byKey(const Key('seletor-adesao-casa')),
  matching: find.text(rotulo),
);

/// Metas que falham até [falhar] virar `false` (a leitura que não deu certo
/// e volta depois).
class _MetasQueFalham implements RepositorioMetas {
  bool falhar = true;

  final MetaTerapeutica _meta = MetaTerapeutica(
    id: 'm-1',
    pacienteId: 'p-antonio',
    profissionalId: 'pr-tiago',
    ocupacao: Ocupacao.autocuidado,
    descricao: 'Tomar o café da manhã sem ajuda',
    combinadaCom: 'Antônio',
    prazo: DataCivil(2026, 12, 1),
    situacao: SituacaoMeta.ativa,
  );

  @override
  Future<List<MetaTerapeutica>> metas(String pacienteId) async {
    if (falhar) throw StateError('leitura falhou');
    return [_meta];
  }

  @override
  Future<MetaTerapeutica> meta(String pacienteId, String metaId) async {
    if (falhar) throw StateError('leitura falhou');
    return _meta;
  }
}

void main() {
  testWidgets('Jornada do Antônio: "Nossas metas" por área da vida, com a '
      'situação e o prazo, sem escore (D25)', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteJornada,
    );
    expect(find.byKey(const Key('nossas-metas')), findsOneWidget);
    expect(find.text('NOSSAS METAS'), findsOneWidget);
    expect(
      _em(const Key('nossas-metas'), find.text('Autocuidado')),
      findsOneWidget,
    );
    final camisa = find.byKey(Key('meta-${_meta(7)}'));
    final cafe = find.byKey(Key('meta-${_meta(6)}'));
    final dentes = find.byKey(Key('meta-${_meta(8)}'));
    // Em andamento pelo prazo (45 e 60 dias), depois a alcançada.
    expect(tester.getTopLeft(camisa).dy, lessThan(tester.getTopLeft(cafe).dy));
    expect(tester.getTopLeft(cafe).dy, lessThan(tester.getTopLeft(dentes).dy));
    final prazo = formatarDataCivil(DataCivil(2026, 10, 2).somarDias(45));
    expect(
      _em(Key('meta-${_meta(7)}'), find.text('Em andamento')),
      findsOneWidget,
    );
    expect(
      _em(Key('meta-${_meta(7)}'), find.text('Prazo: $prazo')),
      findsOneWidget,
    );
    expect(
      _em(Key('meta-${_meta(8)}'), find.text('Alcançada')),
      findsOneWidget,
    );
    expect(
      _em(Key('meta-${_meta(8)}'), find.textContaining('Prazo')),
      findsNothing,
    );
    expect(_escore, findsNothing);
  });

  testWidgets('a meta abre a TM20: com quem foi combinada, quem acompanha, a '
      'atividade e o marco; a atividade abre a TM17, e o voltar traz de '
      'volta', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteJornada,
    );
    await tocar(tester, find.byKey(Key('meta-${_meta(7)}')));
    expect(find.byKey(const Key('TM20')), findsOneWidget);
    expect(find.text('Vestir a camisa de botão sozinho'), findsWidgets);
    expect(find.text('Combinada com Antônio e a família'), findsOneWidget);
    expect(find.text('Acompanhada por Tiago Moreira'), findsOneWidget);
    expect(find.byKey(const Key('prazo-da-meta')), findsOneWidget);
    expect(
      find.byKey(
        const Key('marco-da-meta-f0000000-0000-4000-8000-000000000012'),
      ),
      findsOneWidget,
    );
    expect(_escore, findsNothing);

    await tocar(tester, find.byKey(const Key('atividade-da-meta-$_abotoar')));
    expect(find.byKey(const Key('TM17')), findsOneWidget);
    expect(find.byKey(const Key('meta-da-atividade')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM20')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM06')), findsOneWidget);
  });

  testWidgets('TM17: "Esta atividade ajuda na meta" abre a TM20', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.atividade(_copo),
    );
    final cartao = find.byKey(const Key('meta-da-atividade'));
    expect(
      find.descendant(
        of: cartao,
        matching: find.text('Tomar o café da manhã sem ajuda'),
      ),
      findsOneWidget,
    );
    await tocar(tester, cartao);
    expect(find.byKey(const Key('TM20')), findsOneWidget);
    expect(find.text('Tomar o café da manhã sem ajuda'), findsWidgets);
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM17')), findsOneWidget);
  });

  testWidgets('TM16: cada atividade diz a meta que ajuda', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
    );
    expect(
      find.text('Ajuda na meta: Vestir a camisa de botão sozinho'),
      findsOneWidget,
    );
    expect(
      find.text('Ajuda na meta: Tomar o café da manhã sem ajuda'),
      findsOneWidget,
    );
  });

  testWidgets('Jornada: o marco "Meta alcançada" abre a TM20 da meta, sem '
      'prazo', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteJornada,
    );
    await tocar(
      tester,
      find.byKey(const Key('jornada-f0000000-0000-4000-8000-000000000014')),
    );
    expect(find.byKey(const Key('TM20')), findsOneWidget);
    expect(find.text('Escovar os dentes com a mão mais fraca'), findsWidgets);
    expect(find.text('Alcançada'), findsOneWidget);
    expect(find.byKey(const Key('prazo-da-meta')), findsNothing);
  });

  testWidgets('meta de outro paciente: "Não encontramos esta meta"', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.meta(_meta(1)),
    );
    expect(find.byKey(const Key('meta-inexistente')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM06')), findsOneWidget);
  });

  testWidgets('quem não faz TO não vê "Nossas metas", mesmo havendo metas '
      'no repositório', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteJornada,
      preparar: (m) async {
        // A Ana da demonstração tem as duas linhas e 2 metas; aqui fica só
        // com o acompanhamento clínico, e as metas continuam na memória.
        final ana = m.estado.pacientes[idAna]!;
        m.estado.pacientes[idAna] = Paciente.fromMap({
          ...ana.toMap(),
          'linhasDeCuidado': ['acompanhamentoClinico'],
        });
        expect(await m.repositorios.metas.metas(idAna), hasLength(2));
      },
    );
    expect(find.byKey(const Key('TM06')), findsOneWidget);
    expect(find.byKey(const Key('nossas-metas')), findsNothing);
  });

  testWidgets('a mesma Ana, com TO, vê as metas dela', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteJornada,
    );
    expect(find.byKey(const Key('nossas-metas')), findsOneWidget);
    expect(find.text('Ir à escola 4 de 5 dias da semana'), findsOneWidget);
  });

  testWidgets('registrar pelo caminho Jornada → meta → atividade e voltar à '
      'aba Em casa: a TM16 mostra o dia novo (revisão da F3)', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
    );
    expect(find.text('Hoje: 1 de 2 atividades registradas'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('aba-jornada')));
    await tocar(tester, find.byKey(Key('meta-${_meta(7)}')));
    await tocar(tester, find.byKey(const Key('atividade-da-meta-$_abotoar')));
    await tocar(tester, _opcao('Sim'));
    await tocar(tester, find.byKey(const Key('registrar-atividade')));
    expect(find.byKey(const Key('registro-de-hoje')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    await tocar(tester, find.byType(BackButton));
    await tocar(tester, find.byKey(const Key('aba-casa')));
    expect(find.text('Hoje: 2 de 2 atividades registradas'), findsOneWidget);
  });

  testWidgets('atividade → meta → a mesma atividade por cima: ao voltar, a '
      'de baixo relê e não oferece registrar de novo (revisão da F3)', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
    );
    await tocar(tester, find.byKey(const Key('atividade-$_abotoar')));
    await tocar(tester, find.byKey(const Key('meta-da-atividade')));
    await tocar(tester, find.byKey(const Key('atividade-da-meta-$_abotoar')));
    await tocar(tester, _opcao('Sim'));
    await tocar(tester, find.byKey(const Key('registrar-atividade')));
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM20')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    expect(find.byKey(const Key('TM17')), findsOneWidget);
    expect(find.byKey(const Key('registro-de-hoje')), findsOneWidget);
    expect(find.byKey(const Key('seletor-adesao-casa')), findsNothing);
  });

  testWidgets('D36 — de volta à TO depois de uma alta antiga: as atividades '
      'que valem hoje aparecem, sem "Programa encerrado" (revisão da F3)', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
      preparar: (m) async {
        m.estado.marcos['f0000000-0000-4000-8000-000000000098'] = MarcoJornada(
          id: 'f0000000-0000-4000-8000-000000000098',
          pacienteId: idAntonio,
          tipo: TipoMarco.alta,
          data: m.hoje().somarDias(-20),
          titulo: 'Alta da terapia ocupacional',
          textoSimples: 'Você e o Tiago encerraram a primeira etapa.',
        );
      },
    );
    expect(find.byKey(const Key('programa-encerrado')), findsNothing);
    expect(find.byKey(const Key('atividade-$_abotoar')), findsOneWidget);
  });

  testWidgets(
    'TM20 de meta sem atividade ligada diz que não há nenhuma agora',
    (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.meta(_meta(8)),
      );
      expect(find.byKey(const Key('sem-atividades-da-meta')), findsOneWidget);
      expect(
        find.byKey(const Key('atividades-da-meta-falharam')),
        findsNothing,
      );
    },
  );

  testWidgets('TM20: a leitura que falha oferece "Tentar de novo", que '
      'carrega a meta', (tester) async {
    final metas = _MetasQueFalham();
    await abrirAppDoPaciente(
      tester,
      sessao: Sessao()..entrar(vinculosAntonio()),
      metas: metas,
      em: Rotas.meta('m-1'),
    );
    expect(find.text('Não foi possível mostrar a meta agora.'), findsOneWidget);
    metas.falhar = false;
    await tocar(tester, find.text('Tentar de novo'));
    expect(find.text('Tomar o café da manhã sem ajuda'), findsOneWidget);
  });

  testWidgets('Jornada: "Nossas metas" que não pôde ser lida volta com o '
      '"puxar para atualizar" (revisão da F3)', (tester) async {
    final metas = _MetasQueFalham();
    await abrirAppDoPaciente(
      tester,
      sessao: Sessao()..entrar(vinculosAntonio()),
      metas: metas,
      em: Rotas.pacienteJornada,
    );
    expect(find.byKey(const Key('nossas-metas')), findsNothing);
    metas.falhar = false;
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nossas-metas')), findsOneWidget);
  });

  testWidgets('D36 — depois da alta: a TM16 diz "Programa encerrado", só '
      'para leitura, e a Jornada mostra a alta', (tester) async {
    await abrirComMemoria(
      tester,
      persona: Persona.antonio,
      em: Rotas.pacienteCasa,
      preparar: darAltaAoAntonio,
    );
    expect(find.byKey(const Key('programa-encerrado')), findsOneWidget);
    expect(find.textContaining('teve alta em 02/10/2026'), findsOneWidget);
    expect(find.byKey(const Key('atividade-$_abotoar')), findsNothing);
    expect(find.byKey(const Key('faixa-de-dias')), findsOneWidget);
    await tocar(tester, find.byKey(const Key('ver-a-jornada')));
    expect(find.byKey(const Key('TM06')), findsOneWidget);
    expect(find.text('Alta da terapia ocupacional'), findsOneWidget);
  });
}
