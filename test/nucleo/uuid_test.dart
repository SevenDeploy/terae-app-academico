import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/nucleo/uuid.dart';

void main() {
  test('gera UUID v4 no formato da RFC (versão 4, variante 10xx)', () {
    for (var i = 0; i < 200; i++) {
      final id = gerarUuidV4();
      expect(uuidV4Valido(id), isTrue, reason: id);
      expect(id[14], '4');
      expect('89ab'.contains(id[19]), isTrue);
    }
  });

  test('não repete em 5 000 gerações', () {
    final ids = {for (var i = 0; i < 5000; i++) gerarUuidV4()};
    expect(ids, hasLength(5000));
  });

  test('aceita Random injetado e fica determinístico', () {
    expect(
      gerarUuidV4(aleatorio: Random(7)),
      gerarUuidV4(aleatorio: Random(7)),
    );
  });

  test('uuidV4Valido recusa outros formatos', () {
    expect(uuidV4Valido('nao-e-uuid'), isFalse);
    expect(uuidV4Valido('123e4567-e89b-12d3-a456-426614174000'), isFalse);
    expect(uuidV4Valido('123E4567-E89B-42D3-A456-426614174000'), isFalse);
  });
}
