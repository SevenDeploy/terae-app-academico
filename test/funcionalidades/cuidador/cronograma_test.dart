import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/funcionalidades/cuidador/cronograma.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import '../../apoio/dubles.dart';
import 'apoio_cuidador.dart';

void main() {
  test('agrupa por horário, em ordem do dia, e separa o "quando precisar"', () {
    final grupos = agruparPorHorario(itensDeTeste);
    expect(grupos.map((g) => g.horario), ['08:00', '21:00']);
    expect(grupos.first.itens.map((i) => i.medicamento), [
      'Sertralina',
      'Vitamina D',
    ]);
    expect(itensQuandoPrecisar(itensDeTeste).single.medicamento, 'Dipirona');
  });

  test('o horário HH:mm é da clínica: 08:00 em Cuiabá = 12:00Z', () {
    expect(
      instanteDoHorario(DataCivil(2026, 10, 2), '08:00'),
      DateTime.utc(2026, 10, 2, 12),
    );
  });

  group('proximaDose', () {
    ProximaDose? as(int hora, [int minuto = 0, DataCivil? fim]) => proximaDose(
      receita: receitaDe(vigenciaFim: fim),
      itens: itensDeTeste,
      agora: instanteNaClinica(2026, 10, 2, hora, minuto),
    );

    test('antes das 08:00, é às 08:00 de hoje', () {
      expect(as(7, 59)?.instante, instanteNaClinica(2026, 10, 2, 8));
    });

    test('exatamente às 08:00 ainda conta', () {
      expect(as(8)?.instante, instanteNaClinica(2026, 10, 2, 8));
    });

    test('depois das 21:00, é às 08:00 de amanhã', () {
      expect(as(21, 1)?.instante, instanteNaClinica(2026, 10, 3, 8));
    });

    test('se a receita acaba hoje, não há amanhã', () {
      expect(as(22, 0, DataCivil(2026, 10, 2)), isNull);
    });

    test('sem receita, nada', () {
      expect(
        proximaDose(receita: null, itens: itensDeTeste, agora: agoraDeTeste),
        isNull,
      );
    });
  });

  test('próximos dias param no fim da vigência', () {
    final hoje = DataCivil(2026, 10, 2);
    expect(proximosDias(receitaDe(), hoje), [
      DataCivil(2026, 10, 3),
      DataCivil(2026, 10, 4),
      DataCivil(2026, 10, 5),
    ]);
    expect(proximosDias(receitaDe(vigenciaFim: DataCivil(2026, 10, 3)), hoje), [
      DataCivil(2026, 10, 3),
    ]);
  });

  test('consultas marcadas: só agendadas e futuras, em ordem', () {
    final agora = instanteNaClinica(2026, 10, 2, 10);
    expect(consultasMarcadas(consultasDeTeste, agora).map((a) => a.id), [
      'ag-1',
      'ag-3',
    ]);
    expect(proximaConsulta(consultasDeTeste, agora)?.id, 'ag-1');
    expect(
      consultasCanceladas(consultasDeTeste, DataCivil(2026, 10, 2)).single.id,
      'ag-2',
    );
  });

  test('renovação vira aviso a 7 dias ou menos, e também se já passou', () {
    final hoje = DataCivil(2026, 10, 2);
    expect(
      renovacaoProxima(receitaDe(dataRenovacao: DataCivil(2026, 10, 9)), hoje),
      isTrue,
    );
    expect(
      renovacaoProxima(receitaDe(dataRenovacao: DataCivil(2026, 10, 10)), hoje),
      isFalse,
    );
    expect(
      renovacaoProxima(receitaDe(dataRenovacao: DataCivil(2026, 9, 1)), hoje),
      isTrue,
    );
  });
}
