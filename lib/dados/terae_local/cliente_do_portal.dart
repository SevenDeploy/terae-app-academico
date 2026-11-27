/// Transporte HTTP para a API do portal da família do Terae LOCAL
/// (`/api/portal/*`; ADR-0023 do Terae web).
///
/// O que a API exige e este cliente cumpre:
/// - **Host do portal.** A API só serve `/api/portal/*` ao host com prefixo
///   `portal.` (senão 404). O app fala com `10.0.2.2`/`127.0.0.1`, então manda
///   `Host: portal.localhost` em toda chamada.
/// - **Cabeçalho contra CSRF.** Toda escrita (`POST`, `PUT`, `PATCH`,
///   `DELETE`) leva `X-Terae-Cliente: terae-app-flutter` (senão 403
///   `origem_nao_confirmada`). Leitura não leva: não precisa.
/// - **Cookies à mão.** A sessão vem em `__Host-terae_familia` e o aparelho
///   confiável em `__Host-terae_dispositivo`, os dois `Secure`. Um cookie jar
///   comum descarta cookie `Secure` recebido por `http`, e o Terae local roda
///   em `http`; por isso cada `Set-Cookie` é lido aqui. A sessão (e a prova do
///   convite) fica **só em memória** — fechar o app encerra a sessão, como
///   fechar o navegador. O aparelho confiável fica no [GuardaDoDispositivo]
///   (SharedPreferences), porque vale 30 dias.
/// - **Erros tipados** ([FalhaDoPortal]) a partir do corpo RFC 9457, com o
///   `codigo` estável do Terae.
/// - **`Idempotency-Key`** opcional nas escritas: reenviar o mesmo pedido com
///   a mesma chave não duplica; a mesma chave com outro corpo dá 409
///   `chave_de_idempotencia_em_uso`.
///
/// Redirecionamento não é seguido: um 3xx para fora da máquina furaria a trava
/// de [exigirUrlLocal].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../nucleo/tempo/relogio.dart';
import 'configuracao_terae_local.dart';

/// O host que a API reconhece como o do portal (prefixo `portal.`).
const String hostDoPortal = 'portal.localhost';

/// Valor do `X-Terae-Cliente`. A API confere só a presença, não o texto.
const String rotuloDoCliente = 'terae-app-flutter';

/// Cookie da sessão do portal (só em memória).
const String cookieDaFamilia = '__Host-terae_familia';

/// Cookie do aparelho confiável (persistido por 30 dias).
const String cookieDoDispositivo = '__Host-terae_dispositivo';

/// Onde o token do aparelho confiável sobrevive ao fechar o app. No app, é
/// `GuardaDoDispositivoEmPreferencias`; este arquivo fica sem Flutter para
/// rodar também em `dart run` (ferramentas/fumaca_terae_local.dart).
abstract interface class GuardaDoDispositivo {
  Future<String?> ler();
  Future<void> gravar(String token);
  Future<void> apagar();
}

// ---------------------------------------------------------------------------
// Falhas
// ---------------------------------------------------------------------------

/// Uma chamada ao portal que não deu certo. [codigo] é o `codigo` estável do
/// corpo de erro do Terae (`nao_autenticado`, `chave_de_idempotencia_em_uso`…),
/// quando veio.
sealed class FalhaDoPortal implements Exception {
  const FalhaDoPortal({this.status, this.codigo, this.detalhe});

  /// Status HTTP; `null` em [FalhaDeRedeNoPortal].
  final int? status;
  final String? codigo;

  /// O `detail` do problema, texto para gente (pode mudar de redação).
  final String? detalhe;

  @override
  String toString() =>
      '$runtimeType(status: $status, codigo: $codigo, detalhe: $detalhe)';
}

/// 401: sem sessão, sessão acabada, ou código de acesso que não conferiu.
final class SessaoDoPortalAcabou extends FalhaDoPortal {
  const SessaoDoPortalAcabou({
    super.codigo,
    super.detalhe,
    this.tentativasRestantes,
  }) : super(status: 401);

  /// Só no código de acesso errado: quantas tentativas restam. Zero é o fim
  /// da sessão provisória — a pessoa volta à senha.
  final int? tentativasRestantes;
}

/// 403: perfil sem o recurso, operação não permitida ou CSRF recusado.
final class AcessoRecusadoNoPortal extends FalhaDoPortal {
  const AcessoRecusadoNoPortal({super.codigo, super.detalhe})
    : super(status: 403);
}

/// 404: a rota ou o recurso não existe para esta conta (ou o host não é o do
/// portal).
final class NaoEncontradoNoPortal extends FalhaDoPortal {
  const NaoEncontradoNoPortal({super.codigo, super.detalhe})
    : super(status: 404);
}

/// 409: conflito, como `chave_de_idempotencia_em_uso`.
final class ConflitoNoPortal extends FalhaDoPortal {
  const ConflitoNoPortal({super.codigo, super.detalhe}) : super(status: 409);
}

/// 429: limite de taxa. [espera] vem do `Retry-After`, quando veio.
final class LimiteDoPortalExcedido extends FalhaDoPortal {
  const LimiteDoPortalExcedido({super.codigo, super.detalhe, this.espera})
    : super(status: 429);

  final Duration? espera;
}

/// 400/422: o servidor recusou o pedido como inválido.
final class PedidoRecusadoPeloPortal extends FalhaDoPortal {
  const PedidoRecusadoPeloPortal({
    required int super.status,
    super.codigo,
    super.detalhe,
  });
}

/// Sem resposta: servidor fora do ar, conexão recusada ou tempo esgotado.
final class FalhaDeRedeNoPortal extends FalhaDoPortal {
  const FalhaDeRedeNoPortal(this.causa) : super(detalhe: null);

  final Object causa;

  @override
  String toString() => 'FalhaDeRedeNoPortal($causa)';
}

/// Qualquer outra resposta: 5xx, status não previsto ou corpo fora do
/// contrato.
final class RespostaInesperadaDoPortal extends FalhaDoPortal {
  const RespostaInesperadaDoPortal({super.status, super.codigo, super.detalhe});
}

// ---------------------------------------------------------------------------
// Resposta e cliente
// ---------------------------------------------------------------------------

/// Resposta 2xx do portal, com o corpo JSON já decodificado (`null` se vazio).
class RespostaDoPortal {
  const RespostaDoPortal(this.status, this.corpo);

  final int status;
  final Object? corpo;

  /// O corpo como objeto JSON; outro formato é [RespostaInesperadaDoPortal].
  Map<String, Object?> get objeto {
    final c = corpo;
    if (c is Map<String, Object?>) return c;
    throw RespostaInesperadaDoPortal(
      status: status,
      detalhe: 'O corpo não é um objeto JSON.',
    );
  }
}

/// Cliente HTTP do portal da família do Terae local.
class ClienteDoPortal {
  /// [url] é a raiz do Terae local (de [ConfiguracaoTeraeLocal.url]); é
  /// conferida de novo por [exigirUrlLocal] e lança [ConfiguracaoInvalida] se
  /// não for local.
  ClienteDoPortal({
    required Uri url,
    required GuardaDoDispositivo dispositivo,
    required this.relogio,
    HttpClient? http,
    this.tempoLimite = const Duration(seconds: 20),
  }) : _url = exigirUrlLocal(url.toString()),
       _guarda = dispositivo,
       _http = http ?? HttpClient() {
    _http
      ..connectionTimeout = tempoLimite
      ..userAgent = 'Terae app academico (Flutter)';
  }

  final Uri _url;
  final GuardaDoDispositivo _guarda;

  /// Fonte do "agora" para conferir o `Expires` dos cookies.
  final Relogio relogio;
  final HttpClient _http;

  /// Tempo máximo de cada etapa da chamada (conectar, enviar, ler).
  final Duration tempoLimite;

  /// Cookies só de memória: a sessão e a prova do convite.
  final Map<String, String> _cookies = {};

  String? _dispositivo;
  Future<void>? _carregando;

  /// Muda a cada sessão nova ou esquecida. A resposta de uma chamada que
  /// começou noutra geração não mexe nos cookies (o `DELETE /sessoes` lento
  /// do "Sair" não apaga o login feito em seguida).
  int _geracao = 0;

  /// A geração atual da sessão (ver [esquecerSessao] com `daGeracao`).
  int get geracaoDaSessao => _geracao;

  /// Há cookie de sessão (completa ou provisória) em memória.
  bool get temSessao => _cookies.containsKey(cookieDaFamilia);

  /// Há aparelho confiável guardado.
  Future<bool> get temAparelhoConfiavel async {
    await _carregarDispositivo();
    return _dispositivo != null;
  }

  Future<RespostaDoPortal> get(
    String caminho, {
    Map<String, String>? consulta,
  }) => _requisitar('GET', caminho, consulta: consulta);

  Future<RespostaDoPortal> post(
    String caminho, {
    Object? corpo,
    String? chaveDeIdempotencia,
  }) => _requisitar(
    'POST',
    caminho,
    corpo: corpo,
    chaveDeIdempotencia: chaveDeIdempotencia,
  );

  Future<RespostaDoPortal> put(
    String caminho, {
    Object? corpo,
    String? chaveDeIdempotencia,
  }) => _requisitar(
    'PUT',
    caminho,
    corpo: corpo,
    chaveDeIdempotencia: chaveDeIdempotencia,
  );

  Future<RespostaDoPortal> patch(
    String caminho, {
    Object? corpo,
    String? chaveDeIdempotencia,
  }) => _requisitar(
    'PATCH',
    caminho,
    corpo: corpo,
    chaveDeIdempotencia: chaveDeIdempotencia,
  );

  Future<RespostaDoPortal> delete(
    String caminho, {
    Object? corpo,
    String? chaveDeIdempotencia,
  }) => _requisitar(
    'DELETE',
    caminho,
    corpo: corpo,
    chaveDeIdempotencia: chaveDeIdempotencia,
  );

  /// Esquece a sessão (e a prova) em memória; o aparelho confiável fica.
  /// Com [daGeracao], só esquece se nenhuma sessão nova nasceu desde então.
  void esquecerSessao({int? daGeracao}) {
    if (daGeracao != null && daGeracao != _geracao) return;
    _cookies.clear();
    _geracao++;
  }

  /// Esquece o aparelho confiável: o próximo login volta a pedir o código.
  /// Com [daGeracao], só esquece se nenhuma sessão nova nasceu desde então.
  Future<void> esquecerAparelho({int? daGeracao}) async {
    if (daGeracao != null && daGeracao != _geracao) return;
    await _carregarDispositivo();
    _dispositivo = null;
    await _guarda.apagar();
  }

  /// Fecha as conexões. O cliente não deve ser usado depois.
  void fechar() => _http.close(force: true);

  /// O endereço de `/api/portal/<caminho>` (ex.: `sessoes/codigo`).
  Uri enderecoDe(String caminho, [Map<String, String>? consulta]) =>
      _url.replace(
        pathSegments: [
          'api',
          'portal',
          ...caminho.split('/').where((s) => s.isNotEmpty),
        ],
        queryParameters: consulta == null || consulta.isEmpty ? null : consulta,
      );

  Future<void> _carregarDispositivo() =>
      _carregando ??= _guarda.ler().then((t) => _dispositivo ??= t);

  Future<RespostaDoPortal> _requisitar(
    String metodo,
    String caminho, {
    Map<String, String>? consulta,
    Object? corpo,
    String? chaveDeIdempotencia,
  }) async {
    await _carregarDispositivo();
    final geracao = _geracao;
    final endereco = enderecoDe(caminho, consulta);
    final escrita = metodo != 'GET' && metodo != 'HEAD';

    final int status;
    final HttpHeaders cabecalhos;
    final String texto;
    try {
      final pedido = await _http.openUrl(metodo, endereco).timeout(tempoLimite);
      pedido
        ..followRedirects = false
        ..persistentConnection = true;
      final h = pedido.headers
        ..host = hostDoPortal
        ..port = endereco.port
        ..set(HttpHeaders.acceptHeader, 'application/json');
      if (escrita) h.set('X-Terae-Cliente', rotuloDoCliente);
      if (chaveDeIdempotencia != null) {
        h.set('Idempotency-Key', chaveDeIdempotencia);
      }
      final cookie = _cabecalhoCookie();
      if (cookie != null) h.set(HttpHeaders.cookieHeader, cookie);
      if (corpo != null) {
        final bytes = utf8.encode(jsonEncode(corpo));
        h.contentType = ContentType.json;
        pedido
          ..contentLength = bytes.length
          ..add(bytes);
      } else if (escrita) {
        pedido.contentLength = 0;
      }
      final resposta = await pedido.close().timeout(tempoLimite);
      status = resposta.statusCode;
      cabecalhos = resposta.headers;
      texto = await utf8.decodeStream(resposta).timeout(tempoLimite);
    } on SocketException catch (e) {
      throw FalhaDeRedeNoPortal(e);
    } on HttpException catch (e) {
      throw FalhaDeRedeNoPortal(e);
    } on TlsException catch (e) {
      throw FalhaDeRedeNoPortal(e);
    } on TimeoutException catch (e) {
      throw FalhaDeRedeNoPortal(e);
    }

    // Cookies primeiro: até a resposta de erro pode girar ou apagar a sessão.
    if (geracao == _geracao) {
      await _absorverCookies(cabecalhos[HttpHeaders.setCookieHeader]);
    }

    final Object? json = _decodificar(texto);
    if (status >= 200 && status < 300) {
      if (json is _CorpoInvalido) {
        throw RespostaInesperadaDoPortal(
          status: status,
          detalhe: 'Corpo que não é JSON.',
        );
      }
      return RespostaDoPortal(status, json);
    }
    throw _falha(
      status,
      json is Map<String, Object?> ? json : null,
      cabecalhos,
    );
  }

  String? _cabecalhoCookie() {
    final pares = [
      for (final MapEntry(:key, :value) in _cookies.entries) '$key=$value',
      if (_dispositivo != null) '$cookieDoDispositivo=$_dispositivo',
    ];
    return pares.isEmpty ? null : pares.join('; ');
  }

  Future<void> _absorverCookies(List<String>? brutos) async {
    if (brutos == null) return;
    for (final bruto in brutos) {
      final cookie = _CookieRecebido.ler(bruto, relogio.agora());
      if (cookie == null) continue;
      if (cookie.nome == cookieDoDispositivo) {
        if (cookie.apagado) {
          _dispositivo = null;
          await _guarda.apagar();
        } else {
          _dispositivo = cookie.valor;
          await _guarda.gravar(cookie.valor);
        }
      } else if (cookie.apagado) {
        _cookies.remove(cookie.nome);
      } else {
        if (cookie.nome == cookieDaFamilia &&
            _cookies[cookieDaFamilia] != cookie.valor) {
          _geracao++; // sessão nova ou girada
        }
        _cookies[cookie.nome] = cookie.valor;
      }
    }
  }

  static Object? _decodificar(String texto) {
    if (texto.trim().isEmpty) return null;
    try {
      return jsonDecode(texto);
    } on FormatException {
      return const _CorpoInvalido();
    }
  }

  static FalhaDoPortal _falha(
    int status,
    Map<String, Object?>? problema,
    HttpHeaders cabecalhos,
  ) {
    final codigo = problema?['codigo'];
    final detalhe = problema?['detail'];
    final c = codigo is String ? codigo : null;
    final d = detalhe is String ? detalhe : null;
    switch (status) {
      case 401:
        final restantes = problema?['tentativasRestantes'];
        return SessaoDoPortalAcabou(
          codigo: c,
          detalhe: d,
          tentativasRestantes: restantes is int ? restantes : null,
        );
      case 403:
        return AcessoRecusadoNoPortal(codigo: c, detalhe: d);
      case 404:
        return NaoEncontradoNoPortal(codigo: c, detalhe: d);
      case 409:
        return ConflitoNoPortal(codigo: c, detalhe: d);
      case 429:
        final segundos = int.tryParse(
          cabecalhos.value(HttpHeaders.retryAfterHeader)?.trim() ?? '',
        );
        return LimiteDoPortalExcedido(
          codigo: c,
          detalhe: d,
          espera: segundos == null || segundos < 0
              ? null
              : Duration(seconds: segundos),
        );
      case 400 || 422:
        return PedidoRecusadoPeloPortal(status: status, codigo: c, detalhe: d);
      default:
        return RespostaInesperadaDoPortal(
          status: status,
          codigo: c,
          detalhe: d,
        );
    }
  }
}

/// Marca de corpo que não é JSON.
class _CorpoInvalido {
  const _CorpoInvalido();
}

/// Um `Set-Cookie` lido à mão: nome, valor e se ele apaga o cookie
/// (valor vazio, `Max-Age` ≤ 0 ou `Expires` no passado).
class _CookieRecebido {
  const _CookieRecebido(this.nome, this.valor, {required this.apagado});

  final String nome;
  final String valor;
  final bool apagado;

  static _CookieRecebido? ler(String bruto, DateTime agora) {
    final partes = bruto.split(';');
    final par = partes.first;
    final igual = par.indexOf('=');
    if (igual <= 0) return null;
    final nome = par.substring(0, igual).trim();
    var valor = par.substring(igual + 1).trim();
    if (valor.length >= 2 && valor.startsWith('"') && valor.endsWith('"')) {
      valor = valor.substring(1, valor.length - 1);
    }
    var apagado = valor.isEmpty;
    for (final atributo in partes.skip(1)) {
      final i = atributo.indexOf('=');
      if (i < 0) continue;
      final chave = atributo.substring(0, i).trim().toLowerCase();
      final v = atributo.substring(i + 1).trim();
      if (chave == 'max-age') {
        final segundos = int.tryParse(v);
        if (segundos != null && segundos <= 0) apagado = true;
      } else if (chave == 'expires') {
        try {
          if (!HttpDate.parse(v).isAfter(agora)) apagado = true;
        } on HttpException {
          // Data ilegível: fica a decisão do valor.
        } on FormatException {
          // Idem.
        }
      }
    }
    return _CookieRecebido(nome, valor, apagado: apagado);
  }
}
