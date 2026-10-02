/// Máscaras e conferências locais dos campos da TM09 e da TM10 (RNFM01:
/// mínimo de digitação, mensagem simples). A conferência de verdade do código,
/// do CPF e do nascimento é do repositório; aqui só se evita mandar o que
/// claramente está incompleto.
library;

import 'package:flutter/services.dart';

import '../../dados/repositorios/falhas.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/validacao/cpf.dart';

/// Tamanho do código de convite (§22: seis caracteres).
const int tamanhoDoCodigo = 6;

/// Só letras e números, em maiúsculas, até [tamanhoDoCodigo]: `'k7q-2m9'` →
/// `'K7Q2M9'`.
String normalizarCodigo(String texto) {
  final limpo = texto.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return limpo.length > tamanhoDoCodigo
      ? limpo.substring(0, tamanhoDoCodigo)
      : limpo;
}

/// Data digitada só com números; as barras entram sozinhas: `'14032010'` →
/// `'14/03/2010'`.
String mascararData(String texto) {
  var d = somenteDigitos(texto);
  if (d.length > 8) d = d.substring(0, 8);
  final saida = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 4) saida.write('/');
    saida.write(d[i]);
  }
  return saida.toString();
}

/// Lê `dd/mm/aaaa`; `null` se faltar número ou o dia não existir (30/02).
DataCivil? lerDataDigitada(String texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final ano = int.parse(m.group(3)!);
  if (ano < 1900 || mes < 1 || mes > 12 || dia < 1) return null;
  final utc = DateTime.utc(ano, mes, dia);
  if (utc.month != mes || utc.day != dia) return null;
  return DataCivil(ano, mes, dia);
}

/// Conferência local do código; `null` quando está no formato.
String? erroDoCodigo(String texto) =>
    normalizarCodigo(texto).length == tamanhoDoCodigo
    ? null
    : 'O código tem $tamanhoDoCodigo letras ou números. '
          'Confira e digite de novo.';

/// Conferência local do CPF (dígitos verificadores); `null` quando válido.
String? erroDoCpf(String texto) {
  if (somenteDigitos(texto).isEmpty) return 'Digite o CPF.';
  return cpfValido(texto) ? null : MotivoRecusa.cpfInvalido.mensagem;
}

/// Conferência local do nascimento: data que existe e não é depois de [hoje].
String? erroDoNascimento(String texto, DataCivil hoje) {
  final data = lerDataDigitada(texto);
  if (data == null) {
    return 'Digite dia, mês e ano, por exemplo 14/03/2010.';
  }
  if (data.ehDepoisDe(hoje)) {
    return 'A data de nascimento não pode ser depois de hoje.';
  }
  return null;
}

/// Aplica [normalizarCodigo] enquanto a pessoa digita.
class FormatadorCodigo extends TextInputFormatter {
  const FormatadorCodigo();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = normalizarCodigo(newValue.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Aplica [mascararData] enquanto a pessoa digita. Use com
/// `keyboardType: TextInputType.number`.
class FormatadorData extends TextInputFormatter {
  const FormatadorData();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = mascararData(newValue.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
