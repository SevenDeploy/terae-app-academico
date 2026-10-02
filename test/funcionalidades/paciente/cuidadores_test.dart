import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import 'apoio_paciente.dart';

final Finder _formulario = find.byKey(const Key('formulario-convite'));
final Finder _campoNome = find.byKey(const Key('campo-nome-cuidador'));
final Finder _campoCpf = find.byKey(const Key('campo-cpf-cuidador'));
final Finder _convidar = find.byKey(const Key('convidar'));

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// Rótulo semântico do contador ("n de 2 cuidadores…").
String _contador(WidgetTester tester) =>
    tester.getSemantics(find.byKey(const Key('contador-cuidadores'))).label;

void main() {
  group('TM07 Cuidadores (RFM07, §7.4)', () {
    testWidgets('2/2 contando o pendente: esconde o convite e avisa', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await abrirAppDoPaciente(tester, em: Rotas.pacienteCuidadores);
      expect(find.byKey(const Key('TM07')), findsOneWidget);

      expect(find.text('2/2'), findsOneWidget);
      expect(_contador(tester), startsWith('2 de 2 cuidadores'));
      expect(_formulario, findsNothing);
      expect(find.byKey(const Key('aviso-limite')), findsOneWidget);

      // Situação de cada um; o pendente mostra o código a repassar.
      expect(find.text('Autorizado'), findsOneWidget);
      expect(find.text('Convite em aberto'), findsOneWidget);
      expect(find.text('Código PAU456, vale até 09/10/2026'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('revogar pede confirmação e chama o repositório', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteCuidadores,
      );

      // O botão diz quem será revogado.
      final revogarPaulo = find.bySemanticsLabel('Revogar Paulo Martins');
      expect(revogarPaulo, findsOneWidget);
      expect(find.bySemanticsLabel('Revogar Regina Martins'), findsOneWidget);

      // Cancelar não revoga.
      await _tocar(tester, find.byKey(const Key('revogar-vc-paulo')));
      expect(find.text('Revogar o acesso de Paulo Martins?'), findsOneWidget);
      await _tocar(tester, find.byKey(const Key('cancelar-revogar')));
      expect(app.cuidadores.revogados, isEmpty);

      await _tocar(tester, find.byKey(const Key('revogar-vc-paulo')));
      await _tocar(tester, find.byKey(const Key('confirmar-revogar')));
      expect(app.cuidadores.revogados, ['vc-paulo']);

      // Não some: fica como "Acesso removido", e abre vaga para convidar.
      expect(find.text('Acesso removido'), findsOneWidget);
      expect(find.text('Removido em 02/10/2026'), findsOneWidget);
      expect(find.byKey(const Key('revogar-vc-paulo')), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
      expect(_formulario, findsOneWidget);
      semantica.dispose();
    });

    testWidgets('convite por nome e CPF mostra o código para repassar', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteCuidadores,
        cuidadores: CuidadoresEmMemoria([reginaAtiva()]),
      );
      expect(find.text('1/2'), findsOneWidget);

      await tester.enterText(_campoNome, 'Maria da Silva');
      await tester.enterText(_campoCpf, '52998224725');
      await tester.pump();
      expect(find.text('529.982.247-25'), findsOneWidget, reason: 'máscara');

      await _tocar(tester, _convidar);
      expect(app.cuidadores.convidados.single, (
        nome: 'Maria da Silva',
        cpf: '52998224725',
      ));
      expect(find.byKey(const Key('codigo-gerado')), findsOneWidget);
      expect(find.text('Convite criado para Maria da Silva'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('codigo-convite'))).data,
        'NOV001',
      );

      // Agora 2/2: o formulário some, o código continua à vista.
      expect(find.text('2/2'), findsOneWidget);
      expect(_formulario, findsNothing);
      expect(find.byKey(const Key('codigo-gerado')), findsOneWidget);
    });

    testWidgets('CPF inválido ou nome vazio não vão ao repositório', (
      tester,
    ) async {
      final app = await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteCuidadores,
        cuidadores: CuidadoresEmMemoria(const []),
      );
      expect(find.text('0/2'), findsOneWidget);
      expect(find.text('Nenhum cuidador por enquanto.'), findsOneWidget);

      await _tocar(tester, _convidar);
      expect(find.text('Escreva o nome completo da pessoa.'), findsOneWidget);
      expect(find.text('Escreva o CPF da pessoa.'), findsOneWidget);

      await tester.enterText(_campoNome, 'Maria da Silva');
      await tester.enterText(_campoCpf, '52998224700');
      await _tocar(tester, _convidar);
      expect(find.text(MotivoRecusa.cpfInvalido.mensagem), findsOneWidget);
      expect(app.cuidadores.convidados, isEmpty);
    });

    testWidgets('recusa do repositório vira mensagem simples', (tester) async {
      final cuidadores = CuidadoresEmMemoria([reginaAtiva()])
        ..recusar = MotivoRecusa.cpfJaConvidado;
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteCuidadores,
        cuidadores: cuidadores,
      );
      await tester.enterText(_campoNome, 'Regina Martins');
      await tester.enterText(_campoCpf, '52998224725');
      await _tocar(tester, _convidar);
      expect(find.text(MotivoRecusa.cpfJaConvidado.mensagem), findsOneWidget);
      expect(find.byKey(const Key('codigo-gerado')), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
    });
  });
}
