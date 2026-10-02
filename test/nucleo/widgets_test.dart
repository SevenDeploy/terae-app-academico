import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/nucleo/tema/cores.dart';
import 'package:terae_app/nucleo/tema/tema.dart';
import 'package:terae_app/nucleo/widgets/botao_grande.dart';
import 'package:terae_app/nucleo/widgets/cartao.dart';
import 'package:terae_app/nucleo/widgets/faixa_emergencia.dart';
import 'package:terae_app/nucleo/widgets/seletor_opcoes.dart';
import 'package:terae_app/nucleo/widgets/selo_academico.dart';

class _LancadorDuble extends LancadorExterno {
  final List<Uri> abertos = [];

  @override
  Future<bool> abrir(Uri uri) async {
    abertos.add(uri);
    return true;
  }
}

Widget _app(Widget filho) => MaterialApp(
  theme: temaTerae(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: MedidasTerae.paddingTela,
      child: filho,
    ),
  ),
);

class _SeletorDeAdesao extends StatefulWidget {
  const _SeletorDeAdesao();

  @override
  State<_SeletorDeAdesao> createState() => _SeletorDeAdesaoState();
}

class _SeletorDeAdesaoState extends State<_SeletorDeAdesao> {
  Adesao? _valor;

  @override
  Widget build(BuildContext context) => SeletorOpcoes<Adesao>(
    rotulo: 'E os seus remédios de hoje?',
    valor: _valor,
    aoMudar: (v) => setState(() => _valor = v),
    opcoes: [
      for (final a in Adesao.values)
        OpcaoSeletor(
          valor: a,
          rotulo: a.rotulo,
          icone: Icons.check_circle_outline,
          cores: CoresTerae.daAdesao(a),
        ),
    ],
  );
}

void main() {
  group('SeletorOpcoes', () {
    testWidgets('cada opção expõe botão, grupo exclusivo e selected', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _SeletorDeAdesao()));

      expect(
        tester.getSemantics(find.text('Tomei tudo')),
        isSemantics(
          label: 'Tomei tudo',
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Tomei uma parte'));
      await tester.pump();

      expect(
        tester.getSemantics(find.text('Tomei uma parte')),
        isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
      );
      expect(
        tester.getSemantics(find.text('Tomei tudo')),
        isSemantics(isSelected: false),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('o grupo leva a pergunta como rótulo', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _SeletorDeAdesao()));
      expect(
        find.bySemanticsLabel('E os seus remédios de hoje?'),
        findsOneWidget,
      );
      semantica.dispose();
    });

    testWidgets('cada opção tem ao menos 64 de altura', (tester) async {
      await tester.pumpWidget(_app(const _SeletorDeAdesao()));
      for (final a in Adesao.values) {
        final caixa = find
            .ancestor(of: find.text(a.rotulo), matching: find.byType(InkWell))
            .first;
        expect(
          tester.getSize(caixa).height,
          greaterThanOrEqualTo(MedidasTerae.alturaMinimaSeletor),
        );
      }
    });
  });

  group('BotaoGrande', () {
    testWidgets('tem 56 de altura, largura total e desabilita sem ação', (
      tester,
    ) async {
      var tocou = 0;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              BotaoGrande(rotulo: 'Enviar', aoTocar: () => tocou++),
              const BotaoGrande(
                rotulo: 'Desligado',
                aoTocar: null,
                variante: VarianteBotao.secundario,
              ),
            ],
          ),
        ),
      );
      final tamanho = tester.getSize(find.byType(FilledButton));
      expect(tamanho.height, greaterThanOrEqualTo(56));
      expect(tamanho.width, 800 - 2 * MedidasTerae.margemLateral);
      await tester.tap(find.text('Enviar'));
      expect(tocou, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).enabled,
        isFalse,
      );
    });
  });

  group('FaixaEmergencia', () {
    testWidgets('liga para 188 e 192 com um toque', (tester) async {
      final lancador = _LancadorDuble();
      await tester.pumpWidget(_app(FaixaEmergencia(lancador: lancador)));
      await tester.tap(find.byKey(const Key('ligar-188')));
      await tester.tap(find.byKey(const Key('ligar-192')));
      expect(lancador.abertos, [Uri.parse('tel:188'), Uri.parse('tel:192')]);
    });

    testWidgets('versão em destaque também liga e tem rótulo falado', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final lancador = _LancadorDuble();
      await tester.pumpWidget(
        _app(FaixaEmergencia(destaque: true, lancador: lancador)),
      );
      expect(find.text('CVV — 188'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('ligar-192'))),
        isSemantics(
          label: 'Ligar para o SAMU, 192. Atendimento médico de urgência',
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(const Key('ligar-192')));
      expect(lancador.abertos, [Uri.parse('tel:192')]);
      semantica.dispose();
    });
  });

  testWidgets('Cartao tocável vira um botão', (tester) async {
    final semantica = tester.ensureSemantics();
    var tocou = false;
    await tester.pumpWidget(
      _app(Cartao(aoTocar: () => tocou = true, child: const Text('Diário'))),
    );
    expect(
      tester.getSemantics(find.text('Diário')),
      isSemantics(label: 'Diário', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.text('Diário'));
    expect(tocou, isTrue);
    semantica.dispose();
  });

  testWidgets('SeloAcademico diz que é projeto acadêmico', (tester) async {
    await tester.pumpWidget(_app(const SeloAcademico()));
    expect(find.text('Projeto acadêmico — UNEMAT 2026'), findsOneWidget);
  });

  test('tema: texto mínimo de 14 e fonte Lexend', () {
    final tema = temaTerae();
    final estilos = [
      tema.textTheme.bodySmall,
      tema.textTheme.labelSmall,
      tema.textTheme.labelMedium,
      tema.textTheme.bodyMedium,
      tema.textTheme.titleSmall,
    ];
    for (final estilo in estilos) {
      expect(estilo?.fontSize, greaterThanOrEqualTo(14));
      expect(estilo?.fontFamily, 'Lexend');
    }
    expect(tema.colorScheme.primary, CoresTerae.primaria600);
  });
}
