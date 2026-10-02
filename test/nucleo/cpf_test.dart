import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/validacao/cpf.dart';
import 'package:terae_app/nucleo/validacao/formatador_cpf.dart';

void main() {
  group('cpfValido', () {
    test('aceita CPF com dígitos verificadores certos, com ou sem máscara', () {
      expect(cpfValido('529.982.247-25'), isTrue);
      expect(cpfValido('52998224725'), isTrue);
      expect(cpfValido('111.444.777-35'), isTrue);
    });

    test('recusa dígito verificador errado', () {
      expect(cpfValido('529.982.247-24'), isFalse);
      expect(cpfValido('529.982.247-15'), isFalse);
    });

    test('recusa sequência repetida e tamanho errado', () {
      expect(cpfValido('111.111.111-11'), isFalse);
      expect(cpfValido('000.000.000-00'), isFalse);
      expect(cpfValido('5299822472'), isFalse);
      expect(cpfValido('529982247255'), isFalse);
      expect(cpfValido(''), isFalse);
    });

    test('resto menor que 2 vira dígito 0', () {
      // 123.456.789-09: no primeiro dígito o resto é 1 → 0.
      expect(cpfValido('123.456.789-09'), isTrue);
    });
  });

  group('máscara', () {
    test('somenteDigitos tira a pontuação', () {
      expect(somenteDigitos('529.982.247-25'), '52998224725');
    });

    test('mascararCpf é progressiva e corta em 11 dígitos', () {
      expect(mascararCpf(''), '');
      expect(mascararCpf('529'), '529');
      expect(mascararCpf('5299'), '529.9');
      expect(mascararCpf('5299822'), '529.982.2');
      expect(mascararCpf('5299822472'), '529.982.247-2');
      expect(mascararCpf('529982247259999'), '529.982.247-25');
    });

    test('formatarCpf exige 11 dígitos', () {
      expect(formatarCpf('52998224725'), '529.982.247-25');
      expect(() => formatarCpf('5299'), throwsFormatException);
    });

    test('FormatadorCpf aplica a máscara ao digitar', () {
      const formatador = FormatadorCpf();
      final saida = formatador.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '52998a224'),
      );
      expect(saida.text, '529.982.24');
      expect(saida.selection.baseOffset, saida.text.length);
    });
  });
}
