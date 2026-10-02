/// Regras de organização do §24 e do CLAUDE.md, conferidas sobre o código de
/// `lib/` (o teste roda na raiz do projeto).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arquivo de `lib/` com o caminho relativo a `lib/` e o conteúdo.
class _Fonte {
  _Fonte(this.caminho, this.conteudo);

  final String caminho;
  final String conteudo;

  late final List<String> importacoes = [
    for (final m in _diretiva.allMatches(conteudo)) _resolver(m.group(2)!),
  ];

  /// Linhas de código, sem as de comentário.
  late final Iterable<String> codigo = conteudo
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'));

  String _resolver(String alvo) {
    const pacote = 'package:terae_app/';
    if (alvo.startsWith(pacote)) return alvo.substring(pacote.length);
    if (alvo.contains(':')) return alvo;
    return Uri.parse('/$caminho').resolve(alvo).path.substring(1);
  }
}

final RegExp _diretiva = RegExp(
  r'''^\s*(import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

final List<_Fonte> _fontes = [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      _Fonte(
        f.path.replaceAll(r'\', '/').substring('lib/'.length),
        f.readAsStringSync(),
      ),
];

Iterable<_Fonte> _em(String pasta) =>
    _fontes.where((f) => f.caminho.startsWith(pasta));

/// Falhas no formato `arquivo → importação` para a mensagem do teste.
List<String> _importacoesProibidas(
  Iterable<_Fonte> fontes,
  bool Function(String importacao) proibida,
) => [
  for (final f in fontes)
    for (final i in f.importacoes)
      if (proibida(i)) '${f.caminho} → $i',
];

void main() {
  test('encontrou o código de lib/', () {
    expect(_fontes.length, greaterThan(40));
    expect(_fontes.map((f) => f.caminho), contains('roteador.dart'));
  });

  test('dados/ e nucleo/ não importam funcionalidades/', () {
    final falhas = _importacoesProibidas([
      ..._em('dados/'),
      ..._em('nucleo/'),
    ], (i) => i.startsWith('funcionalidades/'));
    expect(falhas, isEmpty);
  });

  test('dados/ não importa widgets, material, roteamento nem provider', () {
    const proibidas = [
      'package:flutter/widgets.dart',
      'package:flutter/material.dart',
      'package:flutter/cupertino.dart',
      'package:go_router/',
      'package:provider/',
      'nucleo/widgets/',
      'nucleo/tema/',
      'nucleo/sessao/',
      'nucleo/rotas/',
    ];
    final falhas = _importacoesProibidas(
      _em('dados/'),
      (i) => proibidas.any(i.startsWith),
    );
    expect(falhas, isEmpty);
  });

  test(
    'utilitários do núcleo (tempo, validação, uuid) não dependem de dados/',
    () {
      final falhas = _importacoesProibidas([
        ..._em('nucleo/tempo/'),
        ..._em('nucleo/validacao/'),
        ..._em('nucleo/uuid'),
      ], (i) => i.startsWith('dados/'));
      expect(falhas, isEmpty);
    },
  );

  test('só roteador.dart e app.dart conhecem as telas', () {
    final falhas = _importacoesProibidas(
      _fontes.where(
        (f) =>
            !f.caminho.startsWith('funcionalidades/') &&
            f.caminho != 'roteador.dart' &&
            f.caminho != 'app.dart',
      ),
      (i) => i.startsWith('funcionalidades/'),
    );
    expect(falhas, isEmpty);
  });

  test('tela nenhuma lê a fonte de dados direto, só por repositório', () {
    final falhas = _importacoesProibidas(
      _em('funcionalidades/'),
      (i) => i.startsWith('dados/memoria/'),
    );
    expect(falhas, isEmpty);
  });

  test('nenhum caminho de rota escrito à mão fora de rotas.dart', () {
    final literal = RegExp(r'''['"]/(paciente|cuidador|entrar|cadastro)''');
    final falhas = [
      for (final f in _fontes)
        if (f.caminho != 'nucleo/rotas/rotas.dart')
          for (final linha in f.codigo)
            if (literal.hasMatch(linha)) '${f.caminho}: ${linha.trim()}',
    ];
    expect(falhas, isEmpty);
  });

  test('"agora" só pelo Relogio: DateTime.now() só em relogio.dart', () {
    final falhas = [
      for (final f in _fontes)
        if (f.caminho != 'nucleo/tempo/relogio.dart')
          for (final linha in f.codigo)
            if (linha.contains('DateTime.now('))
              '${f.caminho}: ${linha.trim()}',
    ];
    expect(falhas, isEmpty);
  });

  test('uma tela por arquivo, no caminho do §21', () {
    const telas = [
      'publico/boas_vindas_tela.dart',
      'autenticacao/entrar_tela.dart',
      'autenticacao/cadastro_paciente_tela.dart',
      'autenticacao/cadastro_cuidador_tela.dart',
      'paciente/inicio/inicio_tela.dart',
      'paciente/diario/diario_tela.dart',
      'paciente/diario/diario_enviado_tela.dart',
      'paciente/diario/ajuda_imediata_tela.dart',
      'paciente/jornada/jornada_tela.dart',
      'paciente/cuidadores/cuidadores_tela.dart',
      'cuidador/inicio_cuidador_tela.dart',
      'cuidador/medicacao_tela.dart',
      'cuidador/agenda_avisos_tela.dart',
    ];
    final existentes = _em('funcionalidades/').map((f) => f.caminho).toSet();
    for (final tela in telas) {
      expect(existentes, contains('funcionalidades/$tela'));
    }
    expect(existentes, contains('funcionalidades/paciente/abas_paciente.dart'));
  });

  test('12 modelos e 11 enums em dados/', () {
    expect(_em('dados/modelos/'), hasLength(12));
    expect(_em('dados/enums/'), hasLength(11));
  });
}
