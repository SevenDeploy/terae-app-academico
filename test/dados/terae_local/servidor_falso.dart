/// Servidor HTTP falso em loopback para os testes do transporte do Terae
/// local. Nada de rede real: só `127.0.0.1` numa porta livre.
library;

import 'dart:convert';
import 'dart:io';

import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';

/// O que o servidor viu de uma requisição.
class PedidoVisto {
  PedidoVisto({
    required this.metodo,
    required this.caminho,
    required this.cabecalhos,
    required this.corpo,
  });

  final String metodo;
  final String caminho;
  final Map<String, String> cabecalhos;
  final String corpo;

  String? cabecalho(String nome) => cabecalhos[nome.toLowerCase()];

  Object? get json => corpo.isEmpty ? null : jsonDecode(corpo);

  /// Os cookies do cabeçalho `Cookie`, nome → valor.
  Map<String, String> get cookies {
    final bruto = cabecalho('cookie');
    if (bruto == null) return const {};
    return {
      for (final par in bruto.split(';'))
        if (par.contains('='))
          par.substring(0, par.indexOf('=')).trim(): par
              .substring(par.indexOf('=') + 1)
              .trim(),
    };
  }
}

/// A resposta que o roteiro manda devolver.
class RespostaFalsa {
  const RespostaFalsa(
    this.status, {
    this.json,
    this.setCookies = const [],
    this.cabecalhos = const {},
    this.demora = Duration.zero,
  });

  final int status;

  /// Espera antes de responder (a resposta que estoura o tempo do cliente).
  final Duration demora;
  final Object? json;
  final List<String> setCookies;
  final Map<String, String> cabecalhos;
}

typedef Roteiro = RespostaFalsa Function(PedidoVisto pedido);

class ServidorFalso {
  ServidorFalso._(this._servidor);

  final HttpServer _servidor;
  final List<PedidoVisto> pedidos = [];
  Roteiro roteiro = (_) => const RespostaFalsa(200, json: {});

  static Future<ServidorFalso> iniciar() async {
    final servidor = ServidorFalso._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    servidor._servidor.listen(servidor._atender);
    return servidor;
  }

  Uri get url => Uri.parse('http://127.0.0.1:${_servidor.port}');

  Future<void> _atender(HttpRequest req) async {
    final corpo = await utf8.decodeStream(req);
    final cabecalhos = <String, String>{};
    req.headers.forEach(
      (nome, valores) => cabecalhos[nome] = valores.join(', '),
    );
    final pedido = PedidoVisto(
      metodo: req.method,
      caminho: req.uri.toString(),
      cabecalhos: cabecalhos,
      corpo: corpo,
    );
    pedidos.add(pedido);
    final r = roteiro(pedido);
    if (r.demora > Duration.zero) await Future<void>.delayed(r.demora);
    final resp = req.response..statusCode = r.status;
    for (final c in r.setCookies) {
      resp.headers.add(HttpHeaders.setCookieHeader, c);
    }
    r.cabecalhos.forEach(resp.headers.set);
    if (r.json != null) {
      resp.headers.contentType = ContentType.json;
      resp.write(jsonEncode(r.json));
    }
    await resp.close();
  }

  Future<void> parar() => _servidor.close(force: true);
}

/// [GuardaDoDispositivo] em memória, para os testes.
class GuardaEmMemoria implements GuardaDoDispositivo {
  GuardaEmMemoria([this.token]);

  String? token;

  @override
  Future<String?> ler() async => token;

  @override
  Future<void> gravar(String token) async => this.token = token;

  @override
  Future<void> apagar() async => token = null;
}

/// Corpo de erro RFC 9457 do Terae.
Map<String, Object?> problema(
  int status,
  String codigo, {
  Map<String, Object?> extra = const {},
}) => {
  'type': 'https://terae.example/problemas/$codigo',
  'title': codigo,
  'status': status,
  'codigo': codigo,
  'idRequisicao': '00000000-0000-4000-8000-000000000000',
  ...extra,
};
