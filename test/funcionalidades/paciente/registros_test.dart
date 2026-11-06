/// TM13 Meus registros, TM14 Registro e TM15 Corrigir registro (Atividade 4:
/// listagem, busca, visualização, atualização e exclusão do item principal),
/// com o app inteiro sobre a memória de demonstração.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../dados/memoria_apoio.dart';

void main() {
  testWidgets('TM03 → TM13: lista do mais recente, busca e filtro', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteDiario,
    );
    await tocar(tester, find.byKey(const Key('abrir-registros')));
    expect(find.byKey(const Key('TM13')), findsOneWidget);
    expect(find.text('13 registros'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-busca')), 'sono');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('2 registros'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('filtro-moderada')));
    expect(find.text('1 registro'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-busca')), 'xyz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum registro com essa busca.'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('limpar-filtros')));
    expect(find.text('13 registros'), findsOneWidget);
  });

  testWidgets('TM14 de hoje: excluir pede confirmação e some da TM13', (
    tester,
  ) async {
    final memoria = await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteRegistros,
      preparar: registrarHoje,
    );
    expect(find.text('14 registros'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('registro-$registroDeHoje')));
    expect(find.byKey(const Key('TM14')), findsOneWidget);
    expect(find.text('Acordei preocupada com a prova.'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('excluir-registro')));
    expect(find.text('Excluir este registro?'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('confirmar-exclusao')));

    expect(find.byKey(const Key('TM13')), findsOneWidget);
    expect(find.text('Registro excluído.'), findsOneWidget);
    expect(
      find.byKey(const Key('registro-$registroDeHoje')),
      findsNothing,
      reason: 'o excluído some da lista',
    );
    expect(memoria.estado.registros[registroDeHoje]!.excluido, isTrue);
  });

  testWidgets('TM15: corrigir o de hoje volta à TM14 com as respostas novas', (
    tester,
  ) async {
    final memoria = await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteRegistros,
      preparar: registrarHoje,
    );
    await tocar(tester, find.byKey(const Key('registro-$registroDeHoje')));
    await tocar(tester, find.byKey(const Key('corrigir-registro')));
    expect(find.byKey(const Key('TM15')), findsOneWidget);

    await tocar(tester, find.text('Leve'));
    await tocar(tester, find.text('Sono ruim'));
    await tocar(tester, find.byKey(const Key('salvar-correcao')));

    expect(find.byKey(const Key('TM14')), findsOneWidget);
    expect(find.text('Registro corrigido.'), findsOneWidget);
    final corrigido = memoria.estado.registros[registroDeHoje]!;
    expect(corrigido.intensidade, Intensidade.leve);
    expect(corrigido.sintomaPredominante, 'Sono ruim');
    expect(corrigido.atualizadoEm, agoraDaMemoria);
  });

  testWidgets('TM15: corrigir para crítico abre a ajuda imediata (TM05)', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.corrigirRegistro(registroDeHoje),
      preparar: registrarHoje,
    );
    await tocar(tester, find.text('Crítica'));
    await tocar(tester, find.byKey(const Key('salvar-correcao')));
    expect(find.byKey(const Key('TM05')), findsOneWidget);
  });

  testWidgets('TM14 de outro dia: só leitura, sem Corrigir nem Excluir', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteRegistros,
    );
    // O mais recente da demonstração é de ontem às 20:40.
    await tocar(
      tester,
      find.byKey(const Key('registro-dd000000-0000-4000-8000-000000000013')),
    );
    expect(find.byKey(const Key('TM14')), findsOneWidget);
    expect(find.byKey(const Key('registro-so-leitura')), findsOneWidget);
    expect(find.byKey(const Key('corrigir-registro')), findsNothing);
    expect(find.byKey(const Key('excluir-registro')), findsNothing);
  });

  testWidgets('link direto para um registro que não existe: mensagem simples', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.registro('nao-existe'),
    );
    expect(
      find.text(MotivoRecusa.registroInexistente.mensagem),
      findsOneWidget,
    );
  });

  testWidgets('a cuidadora não chega à TM13 nem por link direto (RNFM05)', (
    tester,
  ) async {
    await abrirComMemoria(
      tester,
      persona: Persona.regina,
      em: Rotas.pacienteRegistros,
    );
    expect(find.byKey(const Key('TM13')), findsNothing);
    expect(find.byKey(const Key('TM08')), findsOneWidget);
  });

  testWidgets('sem conexão: a TM13 avisa e o selo mostra a fila', (
    tester,
  ) async {
    final memoria = await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteRegistros,
      preparar: (m) async {
        m.semConexao = true;
        await registrarHoje(m);
      },
    );
    expect(memoria.estado.fila, contains(registroDeHoje));
    expect(find.byKey(const Key('aviso-conexao')), findsOneWidget);
    expect(find.textContaining('1 registro aguardando envio'), findsOneWidget);
    expect(find.byKey(const Key('etiqueta-na-fila')), findsOneWidget);

    // Conferido no emulador em 06/11: a fila sai e a TM13 se atualiza sozinha,
    // sem "puxar para atualizar".
    await memoria.repositorios.demonstracao.definirSemConexao(
      semConexao: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-conexao')), findsNothing);
    expect(find.byKey(const Key('etiqueta-na-fila')), findsNothing);
  });
}
