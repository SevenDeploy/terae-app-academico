import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/uuid.dart';

import 'memoria_apoio.dart';

/// Tudo o que a visão do cuidador devolve para [conta] sobre [paciente],
/// como mapas, com o tipo de cada objeto.
Future<List<(String, Mapa)>> _tudoQueVolta(
  MemoriaDemonstracao m,
  String conta,
  String paciente,
) async {
  final visao = m.repositorios.visaoCuidador;
  final saida = <(String, Mapa)>[];
  final p = await visao.pacienteAcompanhado(
    contaCuidadorId: conta,
    pacienteId: paciente,
  );
  saida.add(('Paciente', p.toMap()));
  final consultas = await visao.consultas(
    contaCuidadorId: conta,
    pacienteId: paciente,
  );
  for (final c in consultas) {
    saida.add(('Agendamento', c.toMap()));
    final profissional = await visao.profissional(c.profissionalId);
    saida.add(('ProfissionalSaude', profissional.toMap()));
  }
  final receita = await visao.receitaVigente(
    contaCuidadorId: conta,
    pacienteId: paciente,
  );
  if (receita != null) {
    saida.add(('ReceitaUsoContinuo', receita.toMap()));
    final itens = await visao.itensDaReceita(
      contaCuidadorId: conta,
      pacienteId: paciente,
      receitaId: receita.id,
    );
    saida.addAll(itens.map((i) => ('ItemMedicacao', i.toMap())));
  }
  final alertas = await visao.alertas(
    contaCuidadorId: conta,
    pacienteId: paciente,
  );
  saida.addAll(alertas.map((a) => ('AvisoDeAlerta', a.toMap())));
  return saida;
}

/// RNFM05 — lista branca: as únicas chaves que podem chegar preenchidas ao
/// aparelho do cuidador, por tipo. É o que a TM08, a TM11 e a TM12 mostram
/// ou usam (vigência para os próximos dias, ids para buscar o resto); o
/// profissional da consulta vai com o mínimo público do §23. Campo novo num
/// modelo fica fora da cópia até entrar aqui de propósito.
const Map<String, Set<String>> _permitidasAoCuidador = {
  'Paciente': {'id', 'profissionalRefId', 'nome', 'ativo'},
  'Agendamento': {'id', 'pacienteId', 'profissionalId', 'dataHora', 'situacao'},
  'ProfissionalSaude': {'id', 'nome', 'registroConselho', 'especialidade'},
  'ReceitaUsoContinuo': {
    'id',
    'pacienteId',
    'vigenciaInicio',
    'vigenciaFim',
    'dataRenovacao',
  },
  'ItemMedicacao': {'id', 'receitaId', 'medicamento', 'posologia', 'horarios'},
  'AvisoDeAlerta': {'emitidoEm', 'cienteEm'},
};

/// Todas as chamadas da visão que conferem o vínculo.
List<Future<Object?> Function()> _chamadasComVinculo(
  MemoriaDemonstracao m,
  String conta,
  String paciente,
) {
  final v = m.repositorios.visaoCuidador;
  return [
    () => v.pacienteAcompanhado(contaCuidadorId: conta, pacienteId: paciente),
    () => v.consultas(contaCuidadorId: conta, pacienteId: paciente),
    () => v.receitaVigente(contaCuidadorId: conta, pacienteId: paciente),
    () => v.itensDaReceita(
      contaCuidadorId: conta,
      pacienteId: paciente,
      receitaId: receitaAna,
    ),
    () => v.alertas(contaCuidadorId: conta, pacienteId: paciente),
  ];
}

Future<void> _semAcesso(
  MemoriaDemonstracao m,
  String conta,
  String paciente,
) async {
  for (final chamada in _chamadasComVinculo(m, conta, paciente)) {
    await expectLater(chamada(), recusa(MotivoRecusa.acessoNegado));
  }
}

void main() {
  test('Regina vê agenda, medicação e avisos da Ana (RFM08)', () async {
    final m = memoriaDeTeste();
    final v = m.repositorios.visaoCuidador;
    final ana = await v.pacienteAcompanhado(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    expect(ana.nome, 'Ana Lúcia Martins');

    final consultas = await v.consultas(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    expect(consultas.single.dataHora, isNotNull);
    expect(consultas.single.situacao, SituacaoAgendamento.agendado);
    final profissional = await v.profissional(consultas.single.profissionalId);
    expect(profissional.nome, 'Dra. Helena Prado');

    final receita = await v.receitaVigente(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    final itens = await v.itensDaReceita(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
      receitaId: receita!.id,
    );
    expect(itens.single.horarios, ['08:00']);

    final alertas = await v.alertas(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    expect(alertas.single.cienteEm, isNotNull, reason: 'alerta antigo, ciente');
  });

  test('RNFM05: cada objeto que volta só tem chaves da lista branca, sem '
      'conteúdo do registro', () async {
    final m = memoriaDeTeste();
    // Um alerta novo, com observação, para haver o que vazar.
    final enviado = await m.repositorios.diario.enviar(
      RegistroDiario(
        id: gerarUuidV4(),
        pacienteId: idAna,
        registradoEm: agoraDaMemoria,
        adesao: Adesao.nenhuma,
        intensidade: Intensidade.critica,
        sintomaPredominante: 'Pensamentos difíceis',
        observacao: 'Texto que só a equipe lê',
        situacaoEnvio: SituacaoEnvio.naFila,
      ),
    );
    expect(enviado.equipeAvisada, isTrue);

    final objetos = await _tudoQueVolta(m, contaRegina, idAna);
    expect(
      objetos.map((o) => o.$1).toSet(),
      _permitidasAoCuidador.keys.toSet(),
      reason: 'todo tipo da lista branca foi conferido',
    );
    for (final (tipo, mapa) in objetos) {
      final preenchidas = {
        for (final e in mapa.entries)
          if (e.value != null) e.key,
      };
      expect(
        preenchidas.difference(_permitidasAoCuidador[tipo]!),
        isEmpty,
        reason: '$tipo fora da lista branca: $mapa',
      );
      for (final valor in mapa.values) {
        expect(
          '$valor',
          isNot(anyOf(contains('Texto que só'), contains('Pensamentos'))),
        );
      }
    }
    final avisos = await m.repositorios.visaoCuidador.alertas(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    expect(avisos, hasLength(2));
    expect(avisos.first.emitidoEm, enviado.alerta!.emitidoEm);
    expect(avisos.first.cienteEm, isNull);
    for (final aviso in avisos) {
      expect(aviso.toMap().keys, unorderedEquals(['emitidoEm', 'cienteEm']));
    }
  });

  test('consultas de hoje em diante, agendadas e canceladas', () async {
    final dados = dadosDaDemonstracao();
    Mapa consulta(int emDias, String hora, String situacao) => {
      'id': gerarUuidV4(),
      'pacienteId': idAna,
      'profissionalId': idHelena,
      'dataHora': {'emDias': emDias, 'hora': hora},
      'motivoRetorno': 'Motivo que o cuidador não vê',
      'situacao': situacao,
    };
    colecao(dados, 'agendamentos').addAll([
      consulta(9, '15:00', 'cancelado'),
      consulta(0, '08:00', 'agendado'),
      consulta(-1, '16:00', 'agendado'),
    ]);
    final m = memoriaDeTeste(dados: dados);
    final consultas = await m.repositorios.visaoCuidador.consultas(
      contaCuidadorId: contaRegina,
      pacienteId: idAna,
    );
    expect(consultas.map((c) => c.situacao), [
      SituacaoAgendamento.agendado,
      SituacaoAgendamento.agendado,
      SituacaoAgendamento.cancelado,
    ]);
    expect(consultas.first.dataHora.isBefore(agoraDaMemoria), isTrue);
    expect(consultas.every((c) => c.motivoRetorno == null), isTrue);
  });

  group('sem vínculo ativo: acessoNegado (RNFM05)', () {
    test('conta sem vínculo com o paciente', () async {
      final m = memoriaDeTeste();
      await _semAcesso(m, contaPatricia, idAna);
      await _semAcesso(m, contaAna, idAna);
      await _semAcesso(m, contaRegina, idMiguel);
      await _semAcesso(m, gerarUuidV4(), idAna);
    });

    test('convite pendente ainda não dá acesso; o aceito dá', () async {
      final m = memoriaDeTeste();
      final paulo = identidadeDe(m, 'Paulo Martins');
      final v = await m.repositorios.autenticacao.aceitarConviteCuidador(
        codigo: codigoPaulo,
        cpf: cpfPaulo,
        acesso: paulo,
      );
      final ana = await m.repositorios.visaoCuidador.pacienteAcompanhado(
        contaCuidadorId: v.conta.id,
        pacienteId: idAna,
      );
      expect(ana.cpf, isNull);
    });

    test('revogado perde o acesso na hora', () async {
      final m = memoriaDeTeste();
      await m.repositorios.cuidadores.revogar(vinculoRegina);
      await _semAcesso(m, contaRegina, idAna);
    });

    test('paciente inativo ou conta inativa', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idAna)['ativo'] = false;
      await _semAcesso(memoriaDeTeste(dados: dados), contaRegina, idAna);

      final outros = dadosDaDemonstracao();
      itemDe(outros, 'contas', contaRegina)['situacao'] = 'inativa';
      await _semAcesso(memoriaDeTeste(dados: outros), contaRegina, idAna);
    });

    test('receita de outro paciente não sai pela Ana', () async {
      final m = memoriaDeTeste();
      await expectLater(
        m.repositorios.visaoCuidador.itensDaReceita(
          contaCuidadorId: contaRegina,
          pacienteId: idAna,
          receitaId: receitaJoao,
        ),
        recusa(MotivoRecusa.acessoNegado),
      );
    });

    test('profissional inexistente', () async {
      final m = memoriaDeTeste();
      await expectLater(
        m.repositorios.visaoCuidador.profissional(gerarUuidV4()),
        recusa(MotivoRecusa.acessoNegado),
      );
    });
  });
}
