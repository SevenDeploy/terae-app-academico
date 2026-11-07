/// O programa em casa sobre a memória de demonstração (evolução de TO, F1;
/// D26): atividades vigentes, registro do dia, correção, desfazer e a fila
/// sem conexão.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'memoria_apoio.dart';

String _atividade(int n) =>
    'ca000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// "Abotoar a camisa com a mão mais fraca" (Antônio), sem registro hoje.
final String _abotoar = _atividade(5);

/// "Segurar o copo com as duas mãos" (Antônio), já registrada hoje.
final String _copo = _atividade(6);

/// "Vestir a camiseta no espelho" (Miguel).
final String _camiseta = _atividade(1);

void main() {
  late MemoriaDemonstracao m;
  final hoje = DataCivil.doInstante(agoraDaMemoria);

  setUp(() => m = memoriaDeTeste());

  group('demonstração (D23)', () {
    test('Antônio e Miguel têm duas atividades; Laura ainda nenhuma', () async {
      final programa = m.repositorios.programaEmCasa;
      expect((await programa.atividades(idAntonio)).map((a) => a.titulo), [
        'Abotoar a camisa com a mão mais fraca',
        'Segurar o copo com as duas mãos',
      ]);
      expect(await programa.atividades(idMiguel), hasLength(2));
      expect(await programa.atividades(idLaura), isEmpty);
      expect(await programa.atividades(idJoao), isEmpty);
    });

    test('registros dos últimos 14 dias, do mais recente; Antônio já '
        'registrou o copo hoje', () async {
      final registros = await m.repositorios.programaEmCasa.registros(
        idAntonio,
      );
      expect(registros.first.dia, hoje);
      expect(registros.first.atividadeId, _copo);
      expect(registros.first.reflexao, 'Sem derramar nada hoje.');
      for (var i = 1; i < registros.length; i++) {
        expect(registros[i].dia.ehDepoisDe(registros[i - 1].dia), isFalse);
      }
      expect(
        registros.every((r) => !r.dia.ehAntesDe(hoje.somarDias(-13))),
        isTrue,
      );
      final deMiguel = await m.repositorios.programaEmCasa.registros(
        idMiguel,
        dias: 3,
      );
      expect(
        deMiguel.every((r) => !r.dia.ehAntesDe(hoje.somarDias(-2))),
        isTrue,
      );
    });

    test('dois registros da mesma atividade no mesmo dia não carregam', () {
      final dados = dadosDaDemonstracao();
      final registros = colecao(dados, 'registrosCasa');
      final copia = {...(registros.first as Map<String, Object?>)};
      copia['id'] = 'cb000000-0000-4000-8000-000000000999';
      registros.add(copia);
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });
  });

  group('registrar (D26)', () {
    test('com conexão: grava enviado, uma vez por dia, e registrar de novo '
        'corrige o mesmo', () async {
      final programa = m.repositorios.programaEmCasa;
      final primeiro = await programa.registrar(
        pacienteId: idAntonio,
        atividadeId: _abotoar,
        adesao: AdesaoEmCasa.emParte,
        reflexao: 'Dois botões.',
        quem: QuemRegistrou.paciente,
      );
      expect(primeiro.situacaoEnvio, SituacaoEnvio.enviado);
      expect(primeiro.dia, hoje);
      expect(m.estado.registrosCasa[primeiro.id], primeiro);

      final corrigido = await programa.registrar(
        pacienteId: idAntonio,
        atividadeId: _abotoar,
        adesao: AdesaoEmCasa.feito,
        quem: QuemRegistrou.paciente,
      );
      expect(corrigido.id, primeiro.id);
      expect(corrigido.adesao, AdesaoEmCasa.feito);
      expect(corrigido.reflexao, isNull);
      expect(corrigido.atualizadoEm, agoraDaMemoria);
      final doDia = (await programa.registros(idAntonio))
          .where((r) => r.atividadeId == _abotoar && r.dia == hoje);
      expect(doDia, hasLength(1));
    });

    test('sem conexão: fica na fila, conta no aviso e sai quando a conexão '
        'volta', () async {
      await m.repositorios.demonstracao.definirSemConexao(semConexao: true);
      final r = await m.repositorios.programaEmCasa.registrar(
        pacienteId: idMiguel,
        atividadeId: _camiseta,
        adesao: AdesaoEmCasa.naoFeito,
        quem: QuemRegistrou.responsavel,
      );
      expect(r.situacaoEnvio, SituacaoEnvio.naFila);
      expect(m.estado.filaCasa.keys, [r.id]);
      expect(m.conexao.value.pendentes, 1);
      expect(
        (await m.repositorios.programaEmCasa.registros(idMiguel)).first.id,
        r.id,
        reason: 'a lista mostra o que está na fila',
      );

      await m.repositorios.demonstracao.definirSemConexao(semConexao: false);
      expect(m.estado.filaCasa, isEmpty);
      expect(
        m.estado.registrosCasa[r.id]!.situacaoEnvio,
        SituacaoEnvio.enviado,
      );
      expect(m.conexao.value.pendentes, 0);
    });

    test(
      'atividade de outro paciente ou inexistente é recusada sem gravar',
      () async {
        final programa = m.repositorios.programaEmCasa;
        await recusaSemGravar(
          m,
          () => programa.registrar(
            pacienteId: idMiguel,
            atividadeId: _abotoar,
            adesao: AdesaoEmCasa.feito,
            quem: QuemRegistrou.responsavel,
          ),
          MotivoRecusa.atividadeInexistente,
        );
        await recusaSemGravar(
          m,
          () => programa.atividade(idAntonio, 'nao-existe'),
          MotivoRecusa.atividadeInexistente,
        );
      },
    );
  });

  group('desfazer (D26)', () {
    test('o de hoje sai das listas (lógico) e pode ser registrado de novo '
        'com o mesmo id', () async {
      final programa = m.repositorios.programaEmCasa;
      final deHoje = (await programa.registros(idAntonio)).first;
      final desfeito = await programa.desfazer(idAntonio, deHoje.id);
      expect(desfeito.excluido, isTrue);
      expect(m.estado.registrosCasa[deHoje.id]!.excluido, isTrue);
      expect(
        (await programa.registros(idAntonio)).map((r) => r.id),
        isNot(contains(deHoje.id)),
      );
      final denovo = await programa.registrar(
        pacienteId: idAntonio,
        atividadeId: _copo,
        adesao: AdesaoEmCasa.emParte,
        quem: QuemRegistrou.paciente,
      );
      expect(denovo.id, deHoje.id);
      expect(denovo.excluido, isFalse);
    });

    test('de outro dia é recusado; de outro paciente ou inexistente, '
        'também', () async {
      final programa = m.repositorios.programaEmCasa;
      final ontem = (await programa.registros(idAntonio))
          .firstWhere((r) => r.dia == hoje.somarDias(-1));
      await recusaSemGravar(
        m,
        () => programa.desfazer(idAntonio, ontem.id),
        MotivoRecusa.edicaoEncerrada,
      );
      await recusaSemGravar(
        m,
        () => programa.desfazer(idMiguel, ontem.id),
        MotivoRecusa.registroInexistente,
      );
      await recusaSemGravar(
        m,
        () => programa.desfazer(idAntonio, 'nao-existe'),
        MotivoRecusa.registroInexistente,
      );
    });
  });

  test('reiniciar volta ao início, com a fila vazia', () async {
    await m.repositorios.demonstracao.definirSemConexao(semConexao: true);
    await m.repositorios.programaEmCasa.registrar(
      pacienteId: idAntonio,
      atividadeId: _abotoar,
      adesao: AdesaoEmCasa.feito,
      quem: QuemRegistrou.paciente,
    );
    await m.repositorios.demonstracao.reiniciarDados();
    expect(m.estado.paraMapa(), memoriaDeTeste().estado.paraMapa());
  });

  test('outro dia: a atividade vira histórico e não se corrige mais', () async {
    final programa = m.repositorios.programaEmCasa;
    final r = await programa.registrar(
      pacienteId: idAntonio,
      atividadeId: _abotoar,
      adesao: AdesaoEmCasa.feito,
      quem: QuemRegistrou.paciente,
    );
    // O registro de hoje não se desfaz amanhã.
    final mAmanha = memoriaDeTeste(
      relogio: RelogioFixo(agoraDaMemoria.add(const Duration(days: 1))),
    );
    mAmanha.estado.registrosCasa[r.id] = r;
    await recusaSemGravar(
      mAmanha,
      () => mAmanha.repositorios.programaEmCasa.desfazer(idAntonio, r.id),
      MotivoRecusa.edicaoEncerrada,
    );
  });
}
