/// A confirmação de presença sobre a memória (evolução de TO, F2; D27, D29).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';

import 'memoria_apoio.dart';

String _ag(int n) => 'ad000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// A consulta da Ana daqui a 5 dias (já confirmada na demonstração).
final String _consultaAna = _ag(3);

/// A sessão do Miguel daqui a 3 dias (ainda sem resposta).
final String _sessaoMiguel = _ag(6);

/// Sessão do Miguel que já passou.
final String _passadaMiguel = _ag(5);

void main() {
  late MemoriaDemonstracao m;

  setUp(() => m = memoriaDeTeste());

  test(
    'a demonstração traz a Ana já confirmada; Miguel sem resposta',
    () async {
      final presenca = m.repositorios.presenca;
      expect(
        (await presenca.respostas(idAna))[_consultaAna]!.resposta,
        RespostaPresenca.vamos,
      );
      expect(await presenca.respostas(idMiguel), isEmpty);
    },
  );

  test('responder com conexão grava enviado; responder de novo troca a '
      'resposta da mesma sessão', () async {
    final presenca = m.repositorios.presenca;
    final sim = await presenca.responder(
      pacienteId: idMiguel,
      agendamentoId: _sessaoMiguel,
      resposta: RespostaPresenca.vamos,
    );
    expect(sim.situacaoEnvio, SituacaoEnvio.enviado);
    expect(sim.respondidaEm, agoraDaMemoria);
    final nao = await presenca.responder(
      pacienteId: idMiguel,
      agendamentoId: _sessaoMiguel,
      resposta: RespostaPresenca.naoVamos,
    );
    expect(nao.resposta, RespostaPresenca.naoVamos);
    expect(await presenca.respostas(idMiguel), {_sessaoMiguel: nao});
    // Nunca cancela: a sessão continua marcada.
    expect(m.estado.agendamentos[_sessaoMiguel]!.situacao.name, 'agendado');
  });

  test('sem conexão vai para a fila, conta no aviso e sai quando a conexão '
      'volta', () async {
    await m.repositorios.demonstracao.definirSemConexao(semConexao: true);
    final r = await m.repositorios.presenca.responder(
      pacienteId: idMiguel,
      agendamentoId: _sessaoMiguel,
      resposta: RespostaPresenca.vamos,
    );
    expect(r.situacaoEnvio, SituacaoEnvio.naFila);
    expect(m.conexao.value.pendentes, 1);
    await m.repositorios.demonstracao.definirSemConexao(semConexao: false);
    expect(m.estado.filaPresenca, isEmpty);
    expect(
      m.estado.confirmacoes[_sessaoMiguel]!.situacaoEnvio,
      SituacaoEnvio.enviado,
    );
  });

  test('sessão que já passou, de outro paciente ou inexistente: recusa sem '
      'gravar', () async {
    final presenca = m.repositorios.presenca;
    await recusaSemGravar(
      m,
      () => presenca.responder(
        pacienteId: idMiguel,
        agendamentoId: _passadaMiguel,
        resposta: RespostaPresenca.vamos,
      ),
      MotivoRecusa.sessaoEncerrada,
    );
    await recusaSemGravar(
      m,
      () => presenca.responder(
        pacienteId: idMiguel,
        agendamentoId: _consultaAna,
        resposta: RespostaPresenca.vamos,
      ),
      MotivoRecusa.agendamentoInexistente,
    );
    await recusaSemGravar(
      m,
      () => presenca.responder(
        pacienteId: idMiguel,
        agendamentoId: 'nao-existe',
        resposta: RespostaPresenca.vamos,
      ),
      MotivoRecusa.agendamentoInexistente,
    );
  });

  test(
    'a cuidadora vê a resposta confirmada, sem quem nem quando (D29)',
    () async {
      final respostas = await m.repositorios.visaoCuidador.respostasDePresenca(
        contaCuidadorId: contaRegina,
        pacienteId: idAna,
      );
      expect(respostas, {_consultaAna: RespostaPresenca.vamos});
      await expectLater(
        m.repositorios.visaoCuidador.respostasDePresenca(
          contaCuidadorId: contaRegina,
          pacienteId: idMiguel,
        ),
        recusa(MotivoRecusa.acessoNegado),
      );
    },
  );

  test('resposta dada depois da sessão não carrega', () {
    final dados = dadosDaDemonstracao();
    final c = colecao(dados, 'confirmacoes').single as Map<String, Object?>;
    c['respondidaEm'] = {'emDias': 6, 'hora': '10:00'};
    expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
  });
}
