import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/funcionalidades/autenticacao/campos_cadastro.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

void main() {
  test('código: só letras e números, maiúsculas, até 6', () {
    expect(normalizarCodigo('k7q-2m9'), 'K7Q2M9');
    expect(normalizarCodigo(' ab 12 cd ef '), 'AB12CD');
    expect(normalizarCodigo('çã!'), '');
    expect(erroDoCodigo('k7q2m9'), isNull);
    expect(erroDoCodigo('K7Q2'), isNotNull);
  });

  test('data: barras automáticas e no máximo 8 dígitos', () {
    expect(mascararData('1'), '1');
    expect(mascararData('140'), '14/0');
    expect(mascararData('14032010'), '14/03/2010');
    expect(mascararData('14/03/20109999'), '14/03/2010');
  });

  test('data: lê só o dia que existe', () {
    expect(lerDataDigitada('14/03/2010'), DataCivil(2010, 3, 14));
    expect(lerDataDigitada('29/02/2012'), DataCivil(2012, 2, 29));
    expect(lerDataDigitada('29/02/2011'), isNull);
    expect(lerDataDigitada('31/04/2010'), isNull);
    expect(lerDataDigitada('00/01/2010'), isNull);
    expect(lerDataDigitada('10/13/2010'), isNull);
    expect(lerDataDigitada('14/03/10'), isNull);
    expect(lerDataDigitada('01/01/1899'), isNull);
  });

  test('nascimento não pode ser depois de hoje', () {
    final hoje = DataCivil(2026, 10, 2);
    expect(erroDoNascimento('02/10/2026', hoje), isNull);
    expect(erroDoNascimento('03/10/2026', hoje), isNotNull);
    expect(erroDoNascimento('', hoje), isNotNull);
  });

  test('CPF: vazio, dígito errado e válido com ou sem máscara', () {
    expect(erroDoCpf(''), 'Digite o CPF.');
    expect(erroDoCpf('529.982.247-24'), MotivoRecusa.cpfInvalido.mensagem);
    expect(erroDoCpf('529.982.247-25'), isNull);
    expect(erroDoCpf('52998224725'), isNull);
  });
}
