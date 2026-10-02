import 'package:flutter/services.dart';

import 'cpf.dart';

/// Aplica a máscara de CPF enquanto a pessoa digita (TM07, TM09, TM10), sem
/// exigir pontuação (RNFM01: mínimo de digitação). Use com
/// `keyboardType: TextInputType.number`.
class FormatadorCpf extends TextInputFormatter {
  const FormatadorCpf();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = mascararCpf(newValue.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
