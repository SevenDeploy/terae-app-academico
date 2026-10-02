import 'dart:math';

/// Identificadores UUID versão 4 (RFC 9562), gerados no próprio aparelho.
///
/// §23 "Identidade e tempo": os identificadores são UUID, e o do RegistroDiario
/// nasce no aparelho — é o que permite criá-lo sem rede e reenviá-lo sem
/// duplicar. A fonte de aleatoriedade é `Random.secure()`; teste que precise
/// de sequência previsível injeta outro [Random].
final Random _aleatorioSeguro = Random.secure();

final RegExp _formatoUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Gera um UUID v4 em minúsculas (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`).
String gerarUuidV4({Random? aleatorio}) {
  final fonte = aleatorio ?? _aleatorioSeguro;
  final bytes = List<int>.generate(16, (_) => fonte.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// O texto é um UUID v4 em minúsculas?
bool uuidV4Valido(String texto) => _formatoUuidV4.hasMatch(texto);
