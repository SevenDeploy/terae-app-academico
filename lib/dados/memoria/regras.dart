/// Regras do "servidor simulado" escritas como funções puras (§7.4, §23),
/// para serem testadas sem estado. A do alerta (§7.1) mora em
/// `dados/regras/alerta.dart` desde a Atividade 4 e é reexportada aqui.
library;

import 'dart:math';

export '../regras/alerta.dart' show regraDoAlerta;

/// Seis caracteres por convite (RFM09; TM09 e TM10, passo 1).
const int tamanhoDoCodigo = 6;

/// Letras e números sem os que se confundem (0/O, 1/I/L): o código é lido em
/// voz alta e digitado à mão (RNFM01).
const String alfabetoDoCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Validade do convite que o paciente gera na TM07.
const Duration validadeDoConviteCuidador = Duration(days: 7);

final RegExp _separadores = RegExp(r'[\s.-]');

/// O código como a pessoa digitou → como está gravado: sem espaço, ponto ou
/// hífen, em maiúsculas (`'p4x 9rc'` → `'P4X9RC'`).
String normalizarCodigo(String texto) =>
    texto.replaceAll(_separadores, '').toUpperCase();

/// O texto tem a forma de um código de convite?
bool codigoBemFormado(String codigo) =>
    codigo.length == tamanhoDoCodigo &&
    codigo.split('').every(alfabetoDoCodigo.contains);

/// Código novo de [tamanhoDoCodigo] caracteres de [alfabetoDoCodigo], fora
/// de [existentes] (o código é único entre todos os convites).
String gerarCodigoConvite(
  Random aleatorio, {
  Set<String> existentes = const {},
}) {
  while (true) {
    final codigo = String.fromCharCodes([
      for (var i = 0; i < tamanhoDoCodigo; i++)
        alfabetoDoCodigo.codeUnitAt(aleatorio.nextInt(alfabetoDoCodigo.length)),
    ]);
    if (!existentes.contains(codigo)) return codigo;
  }
}

/// Cópia ordenada e estável de [itens] (`List.sort` não garante a ordem dos
/// empates; aqui o empate fica na ordem de criação).
List<T> ordenar<T>(Iterable<T> itens, int Function(T a, T b) comparar) {
  final indexados = [...itens.indexed];
  indexados.sort((a, b) {
    final c = comparar(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexados) item];
}
