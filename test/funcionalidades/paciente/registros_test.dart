/// O diário igual ao do portal (P3; quadros 18e e 18f): a lista da TM03 com
/// os selos, "Ver a versão 1", a TM15 (corrigir cria versão nova), a folha
/// de retirar com motivo, a TM14 e os guardados neste aparelho — com o app
/// inteiro sobre a memória de demonstração.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/sincronizacao/situacao_sincronizacao.dart';
import 'package:terae_app/nucleo/rotas/rotas.dart';

import '../../acessibilidade/telas_reais.dart';
import '../../dados/memoria_apoio.dart';

/// Ana na demonstração: o revisado, o retirado e o que avisou a equipe.
const String _revisado = 'dd000000-0000-4000-8000-000000000011';
const String _retirado = 'dd000000-0000-4000-8000-000000000012';
const String _avisou = 'dd000000-0000-4000-8000-000000000002';
const String _esperou = 'dd000000-0000-4000-8000-000000000010';

Finder _doRegistro(String id, Finder alvo) =>
    find.descendant(of: find.byKey(ValueKey('registro-$id')), matching: alvo);

ValueNotifier<SituacaoSincronizacao> _semInternet() =>
    ValueNotifier(const SituacaoSincronizacao(online: false));

/// A terapeuta revisa [id] no servidor (o que a clínica faz no Terae web).
void _revisar(MemoriaDemonstracao m, String id) {
  final r = m.estado.registros[id]!;
  m.estado.registros[id] = RegistroDiario.fromMap({
    ...r.toMap(),
    'revisadoEm': escreverInstante(agoraDaMemoria),
  });
}

void main() {
  group('TM03: a lista do diário (18e)', () {
    testWidgets('os selos do portal: aguardando, revisado, retirado e a '
        'equipe avisada', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      expect(find.text('Seu diário'), findsOneWidget);
      expect(find.byKey(const Key('novo-registro')), findsOneWidget);
      expect(
        _doRegistro(registroCorrigido, find.text('Aguardando a terapeuta')),
        findsOneWidget,
      );
      expect(
        _doRegistro(registroCorrigido, find.text('Corrigido · versão 2')),
        findsOneWidget,
      );
      expect(
        _doRegistro(registroCorrigido, find.text('Atividades: fiz tudo')),
        findsOneWidget,
      );
      expect(
        _doRegistro(registroCorrigido, find.text('Quase não atrapalhou')),
        findsOneWidget,
      );
      expect(
        _doRegistro(_revisado, find.text('Revisado pela terapeuta')),
        findsOneWidget,
      );
      expect(
        _doRegistro(_revisado, find.textContaining('Não dá mais para')),
        findsOneWidget,
      );
      expect(
        _doRegistro(_retirado, find.text('Retirado por você')),
        findsOneWidget,
      );
      expect(
        _doRegistro(
          _retirado,
          find.text('Motivo: registrei no dia errado. Nada foi apagado.'),
        ),
        findsOneWidget,
      );
      expect(
        _doRegistro(_avisou, find.text('A equipe foi avisada')),
        findsOneWidget,
      );
      expect(
        _doRegistro(_avisou, find.textContaining('Este registro avisou')),
        findsOneWidget,
      );
      expect(
        _doRegistro(_esperou, find.textContaining('Escrito em ')),
        findsOneWidget,
      );
      // Corrigir e Retirar só no que ainda pode mudar.
      expect(find.byKey(const Key('corrigir-$registroCorrigido')), findsOne);
      for (final id in [_revisado, _retirado, _avisou]) {
        expect(find.byKey(Key('corrigir-$id')), findsNothing, reason: id);
        expect(find.byKey(Key('retirar-$id')), findsNothing, reason: id);
      }
    });

    testWidgets('"Ver a versão 1" abre a versão anterior ali mesmo', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      final versoes = find.byKey(const Key('versoes-$registroCorrigido'));
      expect(
        find.descendant(of: versoes, matching: find.text('Ver a versão 1')),
        findsOneWidget,
      );
      await tocar(tester, versoes);
      final anteriores = find.byKey(
        const Key('versoes-anteriores-$registroCorrigido'),
      );
      expect(
        find.descendant(
          of: anteriores,
          matching: find.textContaining('Versão 1 · Ontem'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: anteriores,
          matching: find.text('Atividades: fiz parte'),
        ),
        findsOneWidget,
      );
      await tocar(tester, versoes);
      expect(anteriores, findsNothing);
    });

    testWidgets('vazio: "Você ainda não fez nenhum registro." e o primeiro '
        'registro (Antônio, só TO)', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.antonio,
        em: Rotas.pacienteDiario,
      );
      expect(find.text('Você ainda não fez nenhum registro.'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('primeiro-registro')));
      expect(find.byKey(const Key('TM13')), findsOneWidget);
      expect(
        find.text('Você conseguiu fazer as atividades em casa?'),
        findsOneWidget,
      );
    });

    testWidgets('de 30 em 30: "Ver registros mais antigos"', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
        preparar: (m) async {
          for (var i = 0; i < 25; i++) {
            await m.repositorios.diario.enviar(
              RegistroDiario(
                id: 'f0000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
                pacienteId: idAna,
                registradoEm: agoraDaMemoria.subtract(Duration(minutes: i)),
                adesao: Adesao.total,
                situacaoEnvio: SituacaoEnvio.naFila,
              ),
            );
          }
        },
      );
      // 25 novos + 13 da demonstração = 38: a primeira página traz 30.
      final cartoes = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('registro-'),
      );
      expect(cartoes, findsNWidgets(30));
      await tocar(tester, find.byKey(const Key('ver-mais-antigos')));
      expect(cartoes, findsNWidgets(38));
      expect(find.byKey(const Key('ver-mais-antigos')), findsNothing);
    });

    testWidgets('a família (Patrícia) lê "Diário de Miguel" e a pergunta '
        'no plural', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.patricia,
        em: Rotas.entrarPerfil,
      );
      await tocar(tester, find.text('Miguel Andrade Neves'));
      await tocar(tester, find.byKey(const Key('aba-diario')));
      expect(find.text('Diário de Miguel'), findsOneWidget);
      expect(find.text('Atividades: fizemos tudo'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('novo-registro')));
      expect(find.text('Como foi o dia de Miguel?'), findsOneWidget);
      expect(
        find.text('Vocês conseguiram fazer as atividades em casa?'),
        findsOneWidget,
      );
      expect(find.text('Fizemos parte'), findsOneWidget);
    });
  });

  group('TM15: corrigir cria uma versão nova (18f)', () {
    testWidgets('preenchido com a versão vigente; salvar abre "Correção '
        'enviada." e guarda a versão 3', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      await tocar(tester, find.byKey(const Key('corrigir-$registroCorrigido')));
      expect(find.byKey(const Key('TM15')), findsOneWidget);
      expect(find.byKey(const Key('aviso-versao-nova')), findsOneWidget);
      expect(
        find.textContaining('· versão 2'),
        findsOneWidget,
        reason: 'Registro de ontem, … · versão 2',
      );
      expect(
        find.text('Me senti cansada à tarde, mas deu para fazer tudo.'),
        findsOneWidget,
      );
      await tocar(tester, find.text('Fiz parte'));
      await tocar(tester, find.byKey(const Key('salvar-correcao')));
      expect(find.byKey(const Key('TM04')), findsOneWidget);
      expect(find.text('Correção enviada.'), findsOneWidget);
      final salvo = m.estado.registros[registroCorrigido]!;
      expect(salvo.versao, 3);
      expect(salvo.adesao, Adesao.parcial);
      expect([for (final v in salvo.versoesAnteriores) v.versao], [1, 2]);
    });

    testWidgets('corrigir para "Muito" abre a ajuda imediata (TM05)', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.corrigirRegistro(registroCorrigido),
      );
      await tocar(tester, find.text('Muito — precisamos de ajuda'));
      await tocar(tester, find.byKey(const Key('salvar-correcao')));
      expect(find.byKey(const Key('TM05')), findsOneWidget);
      expect(find.text('A equipe da clínica foi avisada.'), findsOneWidget);
    });

    testWidgets('revisado no meio (o 409): "Este registro não pode mais '
        'mudar." e "Fazer um registro novo"', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.corrigirRegistro(registroCorrigido),
      );
      _revisar(m, registroCorrigido);
      await tocar(tester, find.text('Fiz parte'));
      await tocar(tester, find.byKey(const Key('salvar-correcao')));
      expect(find.byKey(const Key('registro-nao-muda-mais')), findsOneWidget);
      expect(find.textContaining('A correção não foi salva'), findsOneWidget);
      expect(m.estado.registros[registroCorrigido]!.versao, 2);
      await tocar(tester, find.byKey(const Key('fazer-registro-novo')));
      expect(find.byKey(const Key('TM13')), findsOneWidget);
    });

    testWidgets('link direto para um revisado já mostra que não muda', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.corrigirRegistro(_revisado),
      );
      expect(find.byKey(const Key('registro-nao-muda-mais')), findsOneWidget);
      expect(find.byKey(const Key('salvar-correcao')), findsNothing);
    });

    testWidgets('sem internet: "Salvar a correção" travado com o motivo', (
      tester,
    ) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.corrigirRegistro(registroCorrigido),
        conexao: _semInternet(),
      );
      expect(
        find.text('Salvar a correção · precisa de internet'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('motivo-sem-internet')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('salvar-correcao')));
      await tester.tap(
        find.byKey(const Key('salvar-correcao')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('TM15')), findsOneWidget);
      expect(m.estado.registros[registroCorrigido]!.versao, 2);
    });

    testWidgets('"Cancelar" volta ao diário sem mudar nada', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      await tocar(tester, find.byKey(const Key('corrigir-$registroCorrigido')));
      await tocar(tester, find.byKey(const Key('cancelar-correcao')));
      expect(find.byKey(const Key('TM15')), findsNothing);
      expect(find.byKey(const Key('TM03')), findsOneWidget);
      expect(m.estado.registros[registroCorrigido]!.versao, 2);
    });
  });

  group('retirar com motivo (18f)', () {
    testWidgets('pede o motivo; "Outro" pede o detalhe; retira e continua na '
        'lista, com o motivo', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      await tocar(tester, find.byKey(const Key('retirar-$registroCorrigido')));
      expect(find.byKey(const Key('folha-retirar')), findsOneWidget);
      expect(find.text('Retirar este registro?'), findsOneWidget);
      expect(find.textContaining('Nada é apagado.'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('confirmar-retirada')));
      expect(find.text('Escolha por que retirar o registro.'), findsOneWidget);

      await tocar(tester, find.text('Outro'));
      await tocar(tester, find.byKey(const Key('confirmar-retirada')));
      expect(
        find.text('Conte em poucas palavras por que retirar.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('detalhe-retirada')),
        'Era sobre o Miguel',
      );
      await tester.pumpAndSettle();
      expect(find.text('18 de 300 caracteres'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('confirmar-retirada')));

      expect(find.byKey(const Key('folha-retirar')), findsNothing);
      expect(find.byKey(const Key('aviso-retirado')), findsOneWidget);
      final retirado = m.estado.registros[registroCorrigido]!;
      expect(retirado.retirado, isTrue);
      expect(retirado.motivoDaRetirada!.categoria, MotivoDaRetirada.outro);
      expect(retirado.motivoDaRetirada!.detalhe, 'Era sobre o Miguel');
      expect(
        _doRegistro(
          registroCorrigido,
          find.text('Motivo: outro (“Era sobre o Miguel”). Nada foi apagado.'),
        ),
        findsOneWidget,
      );
      expect(
        _doRegistro(registroCorrigido, find.text('Retirado por você')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('retirar-$registroCorrigido')), findsNothing);
    });

    testWidgets('"Cancelar" fecha a folha sem retirar', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      await tocar(tester, find.byKey(const Key('retirar-$registroCorrigido')));
      await tocar(tester, find.text('Registrei no dia errado'));
      await tocar(tester, find.byKey(const Key('cancelar-retirada')));
      expect(find.byKey(const Key('folha-retirar')), findsNothing);
      expect(m.estado.registros[registroCorrigido]!.retirado, isFalse);
    });

    testWidgets('sem internet: "Retirar o registro" travado com o motivo', (
      tester,
    ) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
        conexao: _semInternet(),
      );
      await tocar(tester, find.byKey(const Key('retirar-$registroCorrigido')));
      await tocar(tester, find.text('Enviei sem querer'));
      expect(find.byKey(const Key('retirar-sem-internet')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('confirmar-retirada')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('folha-retirar')), findsOneWidget);
      expect(m.estado.registros[registroCorrigido]!.retirado, isFalse);
    });

    testWidgets('revisado no meio: a folha diz que não muda mais e não '
        'retira', (tester) async {
      final m = await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.pacienteDiario,
      );
      await tocar(tester, find.byKey(const Key('retirar-$registroCorrigido')));
      _revisar(m, registroCorrigido);
      await tocar(tester, find.text('Registrei no dia errado'));
      await tocar(tester, find.byKey(const Key('confirmar-retirada')));
      expect(find.byKey(const Key('registro-nao-muda-mais')), findsOneWidget);
      expect(m.estado.registros[registroCorrigido]!.retirado, isFalse);
    });
  });

  group('TM14: o registro', () {
    testWidgets('mostra o cartão do registro, com "Corrigir" e "Retirar"', (
      tester,
    ) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.registro(registroCorrigido),
      );
      expect(find.byKey(const Key('TM14')), findsOneWidget);
      expect(find.text('Corrigido · versão 2'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('corrigir-$registroCorrigido')));
      expect(find.byKey(const Key('TM15')), findsOneWidget);
    });

    testWidgets('retirar pela TM14 mostra o aviso e o selo', (tester) async {
      await abrirComMemoria(
        tester,
        persona: Persona.ana,
        em: Rotas.registro(registroCorrigido),
      );
      await tocar(tester, find.byKey(const Key('retirar-$registroCorrigido')));
      await tocar(tester, find.text('Registrei no paciente errado'));
      await tocar(tester, find.byKey(const Key('confirmar-retirada')));
      expect(find.byKey(const Key('aviso-retirado')), findsOneWidget);
      expect(find.text('Retirado por você'), findsOneWidget);
    });

    testWidgets('link direto para um registro que não existe: mensagem '
        'simples', (tester) async {
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
  });

  testWidgets('a cuidadora não chega ao novo registro nem à TM14 por link '
      'direto (RNFM05)', (tester) async {
    for (final rota in [
      Rotas.pacienteNovoRegistro,
      Rotas.registro(registroCorrigido),
    ]) {
      await abrirComMemoria(tester, persona: Persona.regina, em: rota);
      expect(find.byKey(const Key('TM13')), findsNothing);
      expect(find.byKey(const Key('TM14')), findsNothing);
      expect(find.byKey(const Key('TM08')), findsOneWidget);
    }
  });

  testWidgets('sem conexão: "Guardados neste aparelho" e o aviso; a fila '
      'sai e a lista se atualiza sozinha', (tester) async {
    final memoria = await abrirComMemoria(
      tester,
      persona: Persona.ana,
      em: Rotas.pacienteDiario,
      preparar: (m) async {
        m.semConexao = true;
        await registrarHoje(m);
      },
    );
    expect(memoria.estado.fila, contains(registroDeHoje));
    expect(find.byKey(const Key('aviso-conexao')), findsOneWidget);
    expect(find.textContaining('1 registro aguardando envio'), findsOneWidget);
    expect(find.byKey(const Key('pendentes-do-diario')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pendente-$registroDeHoje')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('registro-$registroDeHoje')),
      findsNothing,
    );

    // O guardado abre a TM14, que diz que ele ainda está no aparelho.
    await tocar(tester, find.byKey(const ValueKey('pendente-$registroDeHoje')));
    expect(find.byKey(const Key('registro-no-aparelho')), findsOneWidget);
    expect(find.byKey(const Key('corrigir-$registroDeHoje')), findsNothing);
    await tocar(tester, find.byTooltip('Voltar'));

    await memoria.repositorios.demonstracao.definirSemConexao(
      semConexao: false,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-conexao')), findsNothing);
    expect(find.byKey(const Key('pendentes-do-diario')), findsNothing);
    expect(
      find.byKey(const ValueKey('registro-$registroDeHoje')),
      findsOneWidget,
    );
    expect(
      memoria.estado.registros[registroDeHoje]!.intensidadeSintoma,
      Intensidade.moderado,
    );
  });
}
