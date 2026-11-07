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

  /// O [codigo] num texto só, para padrões que atravessam linhas (o
  /// formatador quebra `context.go(` e o argumento em linhas diferentes).
  late final String codigoUnido = codigo.join('\n');

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

/// Falhas no formato `arquivo: linha`, uma por ocorrência de [padrao] no
/// código de [fontes] (fora das linhas de comentário).
List<String> _ocorrencias(Iterable<_Fonte> fontes, RegExp padrao) => [
  for (final f in fontes)
    for (final m in padrao.allMatches(f.codigoUnido))
      '${f.caminho}: ${_linhaEm(f.codigoUnido, m.start)}',
];

String _linhaEm(String texto, int posicao) {
  final inicio = texto.lastIndexOf('\n', posicao) + 1;
  final fim = texto.indexOf('\n', posicao);
  return texto.substring(inicio, fim < 0 ? texto.length : fim).trim();
}

Iterable<_Fonte> get _foraDeRotas =>
    _fontes.where((f) => f.caminho != 'nucleo/rotas/rotas.dart');

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

  test(
    'telas não falam com SQLite, Firebase nem sincronizador (Atividade 4)',
    () {
      const camadas = [
        'dados/local/',
        'dados/remoto/',
        'dados/persistente/',
        'dados/sincronizacao/',
        'package:sqflite',
        'package:shared_preferences',
        'package:cloud_firestore',
        'package:firebase_',
        'package:connectivity_plus',
        // F2 (D28): o plugin de notificação só em dados/persistente.
        'package:flutter_local_notifications',
        'package:timezone',
      ];
      final falhas = _importacoesProibidas(
        _em('funcionalidades/'),
        (i) =>
            camadas.any(i.startsWith) &&
            i != 'dados/sincronizacao/situacao_sincronizacao.dart',
      );
      expect(falhas, isEmpty);
    },
  );

  test('só main.dart monta a persistência real', () {
    final falhas = _importacoesProibidas(
      _fontes.where(
        (f) => f.caminho != 'main.dart' && !f.caminho.startsWith('dados/'),
      ),
      (i) => i.startsWith('dados/persistente/'),
    );
    expect(falhas, isEmpty);
  });

  group('rotas só por rotas.dart (§24)', () {
    test('nenhum caminho de rota escrito à mão', () {
      // Qualquer texto que comece com "/" e um nome: '/paciente', '/x'…
      final literal = RegExp(r'''['"]/[A-Za-z_$]''');
      expect(_ocorrencias(_foraDeRotas, literal), isEmpty);
    });

    test('go/push/replace recebem constante de Rotas, nunca texto', () {
      // Primeiro argumento literal ou interpolado: go('/'), push('x'),
      // go('${Rotas.cuidadorInicio}/medicacao').
      final navegacao = RegExp(
        r'''\.(go|push|pushReplacement|replace|goNamed|pushNamed|'''
        r'''pushReplacementNamed|replaceNamed)\s*(<[^>]*>)?\(\s*r?['"]''',
      );
      expect(_ocorrencias(_foraDeRotas, navegacao), isEmpty);
    });

    test('parâmetros de rota recebem constante de Rotas, nunca texto', () {
      final parametro = RegExp(
        r'''\b(initialLocation|localInicial|location)\s*[:=]\s*r?['"]|'''
        r'''\b(GoRoute|ShellRoute)\((\s*\w+:\s*[^,()]*,)*\s*path:\s*r?['"]''',
      );
      expect(_ocorrencias(_foraDeRotas, parametro), isEmpty);
    });

    test('literal "/" só em rotas.dart (fora de montar texto)', () {
      // '/' é a TM00: em go('/'), path: '/' ou no return da guarda. Montar
      // texto com barra (a máscara da data) não é rota.
      final barra = RegExp(
        r'''(?<!\.(write|split|join|contains|startsWith|endsWith|'''
        r'''replaceAll|replaceFirst|indexOf|lastIndexOf)\()r?['"]/['"]''',
      );
      expect(_ocorrencias(_foraDeRotas, barra), isEmpty);
    });

    test('redirect: só em lib/roteador.dart (guarda num lugar só)', () {
      final redirect = RegExp(r'\bredirect\s*:');
      expect(
        _ocorrencias(
          _fontes.where((f) => f.caminho != 'roteador.dart'),
          redirect,
        ),
        isEmpty,
      );
      expect(
        _ocorrencias(_em('roteador.dart'), redirect),
        isNotEmpty,
        reason: 'a guarda continua no roteador',
      );
    });
  });

  test('áreas de funcionalidades/ não se importam (paciente ↔ cuidador; '
      'publico e autenticacao não chegam a paciente nem cuidador)', () {
    const proibidas = {
      'funcionalidades/paciente/': ['funcionalidades/cuidador/'],
      'funcionalidades/cuidador/': ['funcionalidades/paciente/'],
      'funcionalidades/publico/': [
        'funcionalidades/paciente/',
        'funcionalidades/cuidador/',
      ],
      'funcionalidades/autenticacao/': [
        'funcionalidades/paciente/',
        'funcionalidades/cuidador/',
      ],
    };
    final falhas = [
      for (final MapEntry(key: area, value: alvos) in proibidas.entries)
        ..._importacoesProibidas(_em(area), (i) => alvos.any(i.startsWith)),
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
      // Evolução de TO (D22, F1).
      'paciente/casa/em_casa_tela.dart',
      'paciente/casa/atividade_tela.dart',
      'paciente/sessoes/sessoes_tela.dart',
      'paciente/lembretes/lembretes_tela.dart',
      'paciente/metas/meta_tela.dart',
    ];
    final existentes = _em('funcionalidades/').map((f) => f.caminho).toSet();
    for (final tela in telas) {
      expect(existentes, contains('funcionalidades/$tela'));
    }
    expect(existentes, contains('funcionalidades/paciente/abas_paciente.dart'));
  });

  test('16 modelos e 17 enums em dados/ (os do §22 + evolução de TO: linha '
      'de cuidado na F0; atividade, registro, ocupação, adesão em casa e quem '
      'registrou na F1; confirmação e resposta de presença na F2; meta e '
      'situação da meta na F3)', () {
    expect(_em('dados/modelos/'), hasLength(16));
    expect(_em('dados/enums/'), hasLength(17));
  });
}
