import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/regras/consentimento.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

void main() {
  final hoje = DataCivil(2026, 10, 2);

  group('idadeEmAnos', () {
    test('o ano só se completa no dia do aniversário', () {
      expect(idadeEmAnos(nascimento: DataCivil(2014, 10, 2), hoje: hoje), 12);
      expect(idadeEmAnos(nascimento: DataCivil(2014, 10, 3), hoje: hoje), 11);
      expect(idadeEmAnos(nascimento: DataCivil(2014, 9, 30), hoje: hoje), 12);
      expect(idadeEmAnos(nascimento: DataCivil(2019, 3, 8), hoje: hoje), 7);
      expect(idadeEmAnos(nascimento: hoje, hoje: hoje), 0);
    });

    test('29/02 completa em 01/03 nos anos sem esse dia', () {
      final nascimento = DataCivil(2016, 2, 29);
      expect(
        idadeEmAnos(nascimento: nascimento, hoje: DataCivil(2028, 2, 28)),
        11,
      );
      expect(
        idadeEmAnos(nascimento: nascimento, hoje: DataCivil(2028, 2, 29)),
        12,
      );
      expect(
        idadeEmAnos(nascimento: nascimento, hoje: DataCivil(2027, 2, 28)),
        10,
      );
      expect(
        idadeEmAnos(nascimento: nascimento, hoje: DataCivil(2027, 3, 1)),
        11,
      );
    });
  });

  group('criança só pelo responsável legal (ECA art. 2º; LGPD art. 14)', () {
    test('menos de 12 anos completos é criança', () {
      expect(ehCrianca(nascimento: DataCivil(2019, 3, 8), hoje: hoje), isTrue);
      expect(ehCrianca(nascimento: DataCivil(2014, 10, 3), hoje: hoje), isTrue);
      expect(
        ehCrianca(nascimento: DataCivil(2014, 10, 2), hoje: hoje),
        isFalse,
      );
      expect(
        ehCrianca(nascimento: DataCivil(2010, 5, 12), hoje: hoje),
        isFalse,
      );
    });

    test('criança: só responsável legal; 12 anos ou mais: os dois', () {
      expect(
        qualidadesPermitidas(nascimento: DataCivil(2014, 10, 3), hoje: hoje),
        [QualidadeConsentimento.responsavelLegal],
      );
      expect(
        qualidadesPermitidas(nascimento: DataCivil(2014, 10, 2), hoje: hoje),
        QualidadeConsentimento.values,
      );
      expect(
        qualidadePermitida(
          QualidadeConsentimento.titular,
          nascimento: DataCivil(2019, 3, 8),
          hoje: hoje,
        ),
        isFalse,
      );
      expect(
        qualidadePermitida(
          QualidadeConsentimento.titular,
          nascimento: DataCivil(1999, 7, 19),
          hoje: hoje,
        ),
        isTrue,
      );
    });
  });
}
