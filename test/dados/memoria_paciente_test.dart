import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';

import 'memoria_apoio.dart';

void main() {
  final hoje = DataCivil.doInstante(agoraDaMemoria);

  test('paciente e profissional de referência (TM05)', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final ana = await repo.paciente(idAna);
    expect(ana.nome, 'Ana Lúcia Martins');
    expect(ana.cpf, cpfAna);
    expect(ana.dataNascimento, DataCivil(2010, 5, 12));
    final helena = await repo.profissional(ana.profissionalRefId);
    expect(helena.nome, 'Dra. Helena Prado');
    expect(helena.registroConselho, startsWith('CRM-MT '));
    expect(helena.especialidade, 'Psiquiatria');
  });

  test('Ana: próxima consulta em 5 dias às 14:00 da clínica (RFM02)', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final proxima = (await repo.proximaConsulta(idAna))!;
    expect(proxima.dataHora, instanteNaClinica(2026, 10, 7, 14));
    expect(formatarHora(proxima.dataHora), '14:00');
    expect(proxima.situacao, SituacaoAgendamento.agendado);
    expect(proxima.profissionalId, idHelena);
  });

  test('Ana: consultas há 49 e 21 dias e a avaliação de TO há 14 (F1), em '
      'ordem (RFM06)', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final lista = await repo.agendamentos(idAna);
    expect(lista.map((a) => DataCivil.doInstante(a.dataHora)), [
      hoje.somarDias(-49),
      hoje.somarDias(-21),
      hoje.somarDias(-14),
      hoje.somarDias(5),
    ]);
    expect(lista.map((a) => a.situacao), [
      SituacaoAgendamento.realizado,
      SituacaoAgendamento.realizado,
      SituacaoAgendamento.realizado,
      SituacaoAgendamento.agendado,
    ]);
  });

  test('Ana: sertralina 50 mg às 08:00, renovação em 6 dias', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final receita = (await repo.receitaVigente(idAna))!;
    expect(receita.id, receitaAna);
    expect(receita.dataRenovacao, hoje.somarDias(6));
    expect(receita.vigenteEm(hoje), isTrue);
    final itens = await repo.itensDaReceita(receita.id);
    expect(itens.single.medicamento, 'Sertralina');
    expect(itens.single.posologia, contains('50 mg'));
    expect(itens.single.horarios, ['08:00']);
  });

  test(
    'Miguel: TO com a Dra. Larissa em 3 dias às 09:00, sem receita',
    () async {
      final repo = memoriaDeTeste().repositorios.paciente;
      final proxima = (await repo.proximaConsulta(idMiguel))!;
      expect(proxima.dataHora, instanteNaClinica(2026, 10, 5, 9));
      final larissa = await repo.profissional(proxima.profissionalId);
      expect(larissa.nome, 'Dra. Larissa Fontes Andrade');
      expect(larissa.registroConselho, 'CREFITO-9 30125-TO');
      expect(await repo.receitaVigente(idMiguel), isNull);
    },
  );

  test('marcos da jornada em ordem de data, dos três tipos', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final marcos = await repo.marcos(idAna);
    expect(marcos.map((m) => m.tipo).toSet(), TipoMarco.values.toSet());
    for (var i = 1; i < marcos.length; i++) {
      expect(marcos[i].data.ehAntesDe(marcos[i - 1].data), isFalse);
    }
    expect(marcos.every((m) => m.textoSimples.isNotEmpty), isTrue);
  });

  test('"agora" e "hoje" vêm do relógio', () async {
    final relogio = RelogioFixo(agoraDaMemoria);
    final repo = memoriaDeTeste(relogio: relogio).repositorios.paciente;
    relogio.definir(instanteNaClinica(2026, 10, 7, 14, 1));
    expect(await repo.proximaConsulta(idAna), isNull);
    relogio.avancar(const Duration(days: 70));
    expect(await repo.receitaVigente(idAna), isNull);
  });

  test('inexistente: acessoNegado', () async {
    final repo = memoriaDeTeste().repositorios.paciente;
    final id = gerarUuidV4();
    for (final chamada in <Future<Object?> Function()>[
      () => repo.paciente(id),
      () => repo.profissional(id),
      () => repo.proximaConsulta(id),
      () => repo.agendamentos(id),
      () => repo.receitaVigente(id),
      () => repo.itensDaReceita(id),
      () => repo.marcos(id),
    ]) {
      await expectLater(chamada(), recusa(MotivoRecusa.acessoNegado));
    }
  });
}
