/// Leitura e escrita dos campos nos mapas `fromMap`/`toMap` dos modelos (§22).
///
/// Formato do mapa: chaves com o nome do campo da Figura 3; enum pelo `name`;
/// instante em ISO 8601 com fuso (`toMap` escreve UTC com `Z`; `fromMap` aceita
/// `Z` ou `±hh:mm` e recusa hora sem fuso); data civil `AAAA-MM-DD`. Campo
/// obrigatório ausente ou de tipo errado lança [FormatException] com o nome do
/// campo.
library;

import '../nucleo/tempo/data_civil.dart';

/// Mapa serializável de uma entidade.
typedef Mapa = Map<String, Object?>;

final RegExp _comFuso = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

FormatException _invalido(String chave, Object? valor) =>
    FormatException('Campo "$chave" ausente ou inválido', valor);

T lerCampo<T extends Object>(Mapa mapa, String chave) {
  final valor = mapa[chave];
  if (valor is T) return valor;
  throw _invalido(chave, valor);
}

T? lerOpcional<T extends Object>(Mapa mapa, String chave) {
  final valor = mapa[chave];
  if (valor == null) return null;
  if (valor is T) return valor;
  throw _invalido(chave, valor);
}

DateTime _instante(String chave, String texto) {
  if (!_comFuso.hasMatch(texto)) throw _invalido(chave, texto);
  final instante = DateTime.tryParse(texto);
  if (instante == null) throw _invalido(chave, texto);
  return instante.toUtc();
}

/// Instante obrigatório, devolvido em UTC.
DateTime lerInstante(Mapa mapa, String chave) =>
    _instante(chave, lerCampo<String>(mapa, chave));

DateTime? lerInstanteOpcional(Mapa mapa, String chave) {
  final texto = lerOpcional<String>(mapa, chave);
  return texto == null ? null : _instante(chave, texto);
}

/// `2026-10-07T18:00:00.000Z`.
String escreverInstante(DateTime instante) =>
    instante.toUtc().toIso8601String();

String? escreverInstanteOpcional(DateTime? instante) =>
    instante == null ? null : escreverInstante(instante);

DataCivil _data(String chave, String texto) {
  try {
    return DataCivil.parse(texto);
  } on FormatException {
    throw _invalido(chave, texto);
  }
}

DataCivil lerDataCivil(Mapa mapa, String chave) =>
    _data(chave, lerCampo<String>(mapa, chave));

DataCivil? lerDataCivilOpcional(Mapa mapa, String chave) {
  final texto = lerOpcional<String>(mapa, chave);
  return texto == null ? null : _data(chave, texto);
}

/// Enum pelo `name` gravado no mapa.
T lerEnum<T extends Enum>(Mapa mapa, String chave, List<T> valores) {
  final nome = lerCampo<String>(mapa, chave);
  for (final valor in valores) {
    if (valor.name == nome) return valor;
  }
  throw _invalido(chave, nome);
}

/// Lista de enums pelos `name` gravados (ex.: `Paciente.linhasDeCuidado`),
/// na ordem do mapa e devolvida imutável.
List<T> lerEnums<T extends Enum>(Mapa mapa, String chave, List<T> valores) =>
    List.unmodifiable([
      for (final nome in lerTextos(mapa, chave))
        valores.firstWhere(
          (v) => v.name == nome,
          orElse: () => throw _invalido(chave, nome),
        ),
    ]);

/// Lista de textos (ex.: `ItemMedicacao.horarios`), devolvida imutável.
List<String> lerTextos(Mapa mapa, String chave) {
  final lista = lerCampo<List<Object?>>(mapa, chave);
  final textos = <String>[];
  for (final item in lista) {
    if (item is! String) throw _invalido(chave, lista);
    textos.add(item);
  }
  return List.unmodifiable(textos);
}
