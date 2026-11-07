/// TM16 Em casa (D21, D22, D24), na F0: o estado vazio, na voz de quem está
/// com o aparelho.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../../apoio/dubles.dart';
import 'apoio_paciente.dart';

void main() {
  group('TM16 Em casa, sem atividades (F0)', () {
    testWidgets('o titular lê sobre si (Antônio)', (tester) async {
      await abrirAppDoPaciente(
        tester,
        em: Rotas.pacienteCasa,
        sessao: Sessao()..entrar(vinculosAntonio()),
      );
      expect(find.byKey(const Key('TM16')), findsOneWidget);
      expect(find.byKey(const Key('em-casa-vazio')), findsOneWidget);
      expect(
        find.text('O que fazer entre uma sessão e outra.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Quando a sua terapia ocupacional'),
        findsOneWidget,
      );
    });

    testWidgets('a responsável lê sobre o filho (Patrícia → Miguel)', (
      tester,
    ) async {
      final sessao = Sessao()..entrar(vinculosPatricia());
      sessao.escolherPerfil(
        sessao.perfis.firstWhere((p) => p.paciente.id == 'p-miguel'),
      );
      await abrirAppDoPaciente(tester, em: Rotas.pacienteCasa, sessao: sessao);
      expect(find.byKey(const Key('TM16')), findsOneWidget);
      expect(
        find.text('O que fazer com Miguel entre uma sessão e outra.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Quando a terapia ocupacional de Miguel'),
        findsOneWidget,
      );
    });
  });
}
