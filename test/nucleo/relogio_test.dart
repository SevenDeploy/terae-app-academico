import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

void main() {
  group('Relogio', () {
    test('RelogioSistema devolve UTC', () {
      expect(const RelogioSistema().agora().isUtc, isTrue);
    });

    test('RelogioFixo guarda em UTC, avança e é redefinido', () {
      final relogio = RelogioFixo(DateTime.parse('2026-10-02T10:00:00-04:00'));
      expect(relogio.agora(), DateTime.utc(2026, 10, 2, 14));
      relogio.avancar(const Duration(seconds: 3));
      expect(relogio.agora(), DateTime.utc(2026, 10, 2, 14, 0, 3));
      relogio.definir(DateTime.utc(2026, 1, 1));
      expect(relogio.agora(), DateTime.utc(2026, 1, 1));
    });
  });

  group('fuso da clínica (−04:00)', () {
    test('instanteNaClinica converte hora de parede em UTC', () {
      expect(instanteNaClinica(2026, 10, 7, 14), DateTime.utc(2026, 10, 7, 18));
      expect(instanteNaClinica(2026, 10, 7, 14).isUtc, isTrue);
    });

    test('formatadores exibem no horário da clínica, não no UTC', () {
      final instante = DateTime.utc(2026, 10, 2, 2, 30); // 1/10 22:30 em Cuiabá
      expect(formatarHora(instante), '22:30');
      expect(formatarData(instante), '01/10/2026');
      expect(formatarDataHora(instante), '01/10/2026 às 22:30');
      expect(formatarDiaPorExtenso(instante), 'Quinta-feira, 1 de outubro');
    });

    test('formatadores não dependem do fuso do DateTime recebido', () {
      final local = DateTime.utc(2026, 10, 7, 18).toLocal();
      expect(formatarHora(local), '14:00');
    });

    test('nomes em pt-BR', () {
      expect(nomeDiaDaSemana(DateTime.monday), 'segunda-feira');
      expect(nomeDiaDaSemana(DateTime.sunday), 'domingo');
      expect(nomeDoMes(3), 'março');
    });
  });

  group('DataCivil', () {
    test('dia civil de um instante é o da clínica', () {
      expect(
        DataCivil.doInstante(DateTime.utc(2026, 10, 2, 3, 59)),
        DataCivil(2026, 10, 1),
      );
      expect(
        DataCivil.doInstante(DateTime.utc(2026, 10, 2, 4)),
        DataCivil(2026, 10, 2),
      );
      final relogio = RelogioFixo(DateTime.utc(2026, 10, 2, 1));
      expect(DataCivil.hoje(relogio), DataCivil(2026, 10, 1));
    });

    test('lê e escreve AAAA-MM-DD', () {
      final data = DataCivil.parse('2010-03-14');
      expect(data, DataCivil(2010, 3, 14));
      expect(data.paraIso(), '2010-03-14');
      expect(formatarDataCivil(data), '14/03/2010');
      expect(formatarDataCivilPorExtenso(data), 'Domingo, 14 de março');
    });

    test('recusa formato errado e dia inexistente', () {
      expect(() => DataCivil.parse('14/03/2010'), throwsFormatException);
      expect(() => DataCivil.parse('2026-02-30'), throwsFormatException);
      expect(() => DataCivil(2026, 13, 1), throwsArgumentError);
    });

    test('aritmética de dias atravessa mês e ano', () {
      final d = DataCivil(2026, 12, 30);
      expect(d.somarDias(3), DataCivil(2027, 1, 2));
      expect(d.diasAte(DataCivil(2027, 1, 2)), 3);
      expect(DataCivil(2027, 1, 2).diasAte(d), -3);
      expect(d.ehAntesDe(DataCivil(2027, 1, 2)), isTrue);
      expect(d.ehDepoisDe(DataCivil(2027, 1, 2)), isFalse);
    });

    test('meia-noite na clínica é 04:00Z', () {
      expect(
        DataCivil(2026, 10, 7).inicioNaClinica,
        DateTime.utc(2026, 10, 7, 4),
      );
    });

    test('descricaoRelativa em linguagem simples', () {
      final hoje = DataCivil(2026, 10, 2);
      expect(descricaoRelativa(hoje, hoje: hoje), 'hoje');
      expect(descricaoRelativa(hoje.somarDias(1), hoje: hoje), 'amanhã');
      expect(descricaoRelativa(hoje.somarDias(5), hoje: hoje), 'em 5 dias');
      expect(descricaoRelativa(hoje.somarDias(-1), hoje: hoje), 'ontem');
      expect(descricaoRelativa(hoje.somarDias(-3), hoje: hoje), 'há 3 dias');
    });
  });
}
