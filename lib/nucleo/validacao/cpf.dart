/// CPF: limpeza, dígito verificador e máscara (TM07, TM09, TM10; §23 convite
/// preso a um CPF). Dart puro — `dados/` também usa para conferir o convite.
library;

/// Só os dígitos do texto (`'529.982.247-25'` → `'52998224725'`).
String somenteDigitos(String texto) => texto.replaceAll(RegExp(r'\D'), '');

/// CPF com 11 dígitos, não repetidos, e os dois dígitos verificadores certos.
/// Aceita o texto com ou sem máscara.
bool cpfValido(String texto) {
  final d = somenteDigitos(texto);
  if (d.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
  final numeros = d.split('').map(int.parse).toList();
  return _digitoVerificador(numeros, 9) == numeros[9] &&
      _digitoVerificador(numeros, 10) == numeros[10];
}

/// Dígito verificador calculado sobre os [quantidade] primeiros dígitos.
int _digitoVerificador(List<int> numeros, int quantidade) {
  var soma = 0;
  for (var i = 0; i < quantidade; i++) {
    soma += numeros[i] * (quantidade + 1 - i);
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

/// Máscara progressiva, para usar enquanto a pessoa digita: `'5299822'` →
/// `'529.982.2'`. Ignora o que passar de 11 dígitos.
String mascararCpf(String texto) {
  var d = somenteDigitos(texto);
  if (d.length > 11) d = d.substring(0, 11);
  final saida = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 3 || i == 6) saida.write('.');
    if (i == 9) saida.write('-');
    saida.write(d[i]);
  }
  return saida.toString();
}

/// CPF completo no formato `000.000.000-00`. Lança [FormatException] se o texto
/// não tiver exatamente 11 dígitos.
String formatarCpf(String texto) {
  final d = somenteDigitos(texto);
  if (d.length != 11) {
    throw FormatException('CPF precisa de 11 dígitos', texto);
  }
  return mascararCpf(d);
}
