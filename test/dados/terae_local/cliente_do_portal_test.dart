import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/guarda_do_dispositivo_em_preferencias.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'servidor_falso.dart';

void main() {
  late ServidorFalso servidor;
  late GuardaEmMemoria guarda;
  late ClienteDoPortal cliente;
  final relogio = RelogioFixo(DateTime.utc(2026, 11, 26, 18));

  setUp(() async {
    servidor = await ServidorFalso.iniciar();
    guarda = GuardaEmMemoria();
    cliente = ClienteDoPortal(
      url: servidor.url,
      dispositivo: guarda,
      relogio: relogio,
      tempoLimite: const Duration(seconds: 5),
    );
  });

  tearDown(() async {
    cliente.fechar();
    await servidor.parar();
  });

  group('cabeçalhos', () {
    test('toda chamada vai a /api/portal com Host: portal.localhost', () async {
      await cliente.get('eu');
      await cliente.post('sessoes', corpo: {'a': 1});
      for (final p in servidor.pedidos) {
        expect(p.cabecalho('host'), startsWith(hostDoPortal));
        expect(p.cabecalho('host'), isNot(contains('127.0.0.1')));
        expect(p.cabecalho('accept'), 'application/json');
      }
      expect(servidor.pedidos.map((p) => p.caminho), [
        '/api/portal/eu',
        '/api/portal/sessoes',
      ]);
    });

    test('X-Terae-Cliente só em escrita', () async {
      await cliente.get('eu');
      await cliente.post('sessoes');
      await cliente.put('sessoes/paciente', corpo: {'idPaciente': 'x'});
      await cliente.patch('diario/1', corpo: {});
      await cliente.delete('sessoes');
      final vistos = {
        for (final p in servidor.pedidos)
          p.metodo: p.cabecalho('x-terae-cliente'),
      };
      expect(vistos, {
        'GET': null,
        'POST': rotuloDoCliente,
        'PUT': rotuloDoCliente,
        'PATCH': rotuloDoCliente,
        'DELETE': rotuloDoCliente,
      });
    });

    test('corpo em JSON e consulta na URL', () async {
      await cliente.post('sessoes', corpo: {'email': 'á@b.c'});
      await cliente.get('diario', consulta: {'antes': '2026-11-26T00:00:00Z'});
      expect(servidor.pedidos[0].json, {'email': 'á@b.c'});
      expect(
        servidor.pedidos[0].cabecalho('content-type'),
        startsWith('application/json'),
      );
      expect(
        servidor.pedidos[1].caminho,
        '/api/portal/diario?antes=2026-11-26T00%3A00%3A00Z',
      );
    });

    test('Idempotency-Key só quando pedida', () async {
      await cliente.post('diario', corpo: {}, chaveDeIdempotencia: 'k-1');
      await cliente.post('diario', corpo: {});
      expect(servidor.pedidos[0].cabecalho('idempotency-key'), 'k-1');
      expect(servidor.pedidos[1].cabecalho('idempotency-key'), isNull);
    });

    test('não segue redirecionamento', () async {
      servidor.roteiro = (_) => const RespostaFalsa(
        302,
        cabecalhos: {'location': 'https://terae.com.br/api/portal/eu'},
      );
      await expectLater(
        cliente.get('eu'),
        throwsA(isA<RespostaInesperadaDoPortal>()),
      );
      expect(servidor.pedidos, hasLength(1));
    });
  });

  group('cookies', () {
    test('a sessão gira e só a última volta no Cookie', () async {
      servidor.roteiro = (p) => switch (p.caminho) {
        '/api/portal/sessoes' => const RespostaFalsa(
          201,
          json: {'etapa': 'concluida'},
          setCookies: [
            '__Host-terae_familia=s1; Path=/; HttpOnly; Secure; SameSite=Strict',
          ],
        ),
        '/api/portal/sessoes/paciente' => const RespostaFalsa(
          200,
          json: {},
          setCookies: [
            '__Host-terae_familia=s2; Path=/; HttpOnly; Secure; SameSite=Strict',
          ],
        ),
        _ => const RespostaFalsa(200, json: {}),
      };
      expect(cliente.temSessao, isFalse);
      await cliente.post('sessoes');
      expect(cliente.temSessao, isTrue);
      await cliente.get('eu');
      await cliente.put('sessoes/paciente');
      await cliente.get('eu');
      expect(servidor.pedidos[0].cookies, isEmpty);
      expect(servidor.pedidos[1].cookies, {cookieDaFamilia: 's1'});
      expect(servidor.pedidos[3].cookies, {cookieDaFamilia: 's2'});
      expect(guarda.token, isNull, reason: 'a sessão não vai para o disco');
    });

    test('vários Set-Cookie numa resposta, com Expires de vírgula', () async {
      servidor.roteiro = (_) => const RespostaFalsa(
        200,
        json: {'etapa': 'concluida'},
        setCookies: [
          '__Host-terae_familia=s9; Path=/; HttpOnly; Secure; SameSite=Strict',
          '__Host-terae_dispositivo=d1; Path=/; Expires=Sat, 26 Dec 2026 '
              '18:00:00 GMT; HttpOnly; Secure; SameSite=Strict',
        ],
      );
      await cliente.post('sessoes/codigo');
      expect(guarda.token, 'd1');
      await cliente.get('eu');
      expect(servidor.pedidos.last.cookies, {
        cookieDaFamilia: 's9',
        cookieDoDispositivo: 'd1',
      });
    });

    test(
      'o aparelho confiável guardado vai desde a primeira chamada',
      () async {
        guarda.token = 'd-antigo';
        final outro = ClienteDoPortal(
          url: servidor.url,
          dispositivo: guarda,
          relogio: relogio,
        );
        addTearDown(outro.fechar);
        await outro.post('sessoes');
        expect(servidor.pedidos.single.cookies, {
          cookieDoDispositivo: 'd-antigo',
        });
        expect(await outro.temAparelhoConfiavel, isTrue);
      },
    );

    test('cookie apagado pelo servidor sai da memória e do disco', () async {
      guarda.token = 'd1';
      servidor.roteiro = (_) => const RespostaFalsa(
        200,
        json: {'sessoesRevogadas': 1},
        setCookies: [
          '__Host-terae_familia=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT',
          '__Host-terae_dispositivo=x; Path=/; Max-Age=0',
        ],
      );
      await cliente.delete('sessoes');
      expect(cliente.temSessao, isFalse);
      expect(guarda.token, isNull);
    });

    test(
      'esquecerSessao mantém o aparelho; esquecerAparelho o apaga',
      () async {
        servidor.roteiro = (_) => const RespostaFalsa(
          200,
          json: {},
          setCookies: [
            '__Host-terae_familia=s1; Path=/',
            '__Host-terae_dispositivo=d1; Path=/; Max-Age=2592000',
          ],
        );
        await cliente.post('sessoes/codigo');
        cliente.esquecerSessao();
        expect(cliente.temSessao, isFalse);
        expect(guarda.token, 'd1');
        await cliente.esquecerAparelho();
        expect(guarda.token, isNull);
        servidor.roteiro = (_) => const RespostaFalsa(200, json: {});
        await cliente.get('eu');
        expect(servidor.pedidos.last.cookies, isEmpty);
      },
    );

    test('dispositivo persistido em SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final emPrefs = GuardaDoDispositivoEmPreferencias(prefs);
      final c = ClienteDoPortal(
        url: servidor.url,
        dispositivo: emPrefs,
        relogio: relogio,
      );
      addTearDown(c.fechar);
      servidor.roteiro = (_) => const RespostaFalsa(
        200,
        json: {},
        setCookies: ['__Host-terae_dispositivo=d7; Path=/; Max-Age=2592000'],
      );
      await c.post('sessoes/codigo');
      expect(prefs.getString(GuardaDoDispositivoEmPreferencias.chave), 'd7');

      // Outro "processo": o cliente novo lê o aparelho do disco.
      final depois = ClienteDoPortal(
        url: servidor.url,
        dispositivo: GuardaDoDispositivoEmPreferencias(prefs),
        relogio: relogio,
      );
      addTearDown(depois.fechar);
      await depois.get('eu');
      expect(servidor.pedidos.last.cookies, {cookieDoDispositivo: 'd7'});
    });
  });

  group('erros tipados', () {
    test('401 com tentativas restantes', () async {
      servidor.roteiro = (_) => RespostaFalsa(
        401,
        json: problema(
          401,
          'nao_autenticado',
          extra: {'tentativasRestantes': 2},
        ),
      );
      await expectLater(
        cliente.post('sessoes/codigo'),
        throwsA(
          isA<SessaoDoPortalAcabou>()
              .having((e) => e.codigo, 'codigo', 'nao_autenticado')
              .having((e) => e.tentativasRestantes, 'restantes', 2),
        ),
      );
    });

    test('403 sem o cabeçalho do cliente', () async {
      servidor.roteiro = (_) =>
          RespostaFalsa(403, json: problema(403, 'origem_nao_confirmada'));
      await expectLater(
        cliente.get('eu'),
        throwsA(
          isA<AcessoRecusadoNoPortal>().having(
            (e) => e.codigo,
            'codigo',
            'origem_nao_confirmada',
          ),
        ),
      );
    });

    test('404 do host errado', () async {
      servidor.roteiro = (_) =>
          RespostaFalsa(404, json: problema(404, 'recurso_nao_encontrado'));
      await expectLater(
        cliente.get('eu'),
        throwsA(isA<NaoEncontradoNoPortal>()),
      );
    });

    test('409 com o codigo do corpo', () async {
      servidor.roteiro = (_) => RespostaFalsa(
        409,
        json: problema(
          409,
          'chave_de_idempotencia_em_uso',
          extra: {'detail': 'Esta Idempotency-Key já foi usada'},
        ),
      );
      await expectLater(
        cliente.post('diario', corpo: {}, chaveDeIdempotencia: 'k'),
        throwsA(
          isA<ConflitoNoPortal>()
              .having((e) => e.codigo, 'codigo', 'chave_de_idempotencia_em_uso')
              .having((e) => e.detalhe, 'detalhe', contains('Idempotency')),
        ),
      );
    });

    test('429 com a espera do Retry-After', () async {
      servidor.roteiro = (_) => RespostaFalsa(
        429,
        json: problema(429, 'limite_de_taxa_excedido'),
        cabecalhos: const {'retry-after': '42'},
      );
      await expectLater(
        cliente.post('sessoes'),
        throwsA(
          isA<LimiteDoPortalExcedido>().having(
            (e) => e.espera,
            'espera',
            const Duration(seconds: 42),
          ),
        ),
      );
    });

    test('400 é pedido recusado; 500 é resposta inesperada', () async {
      servidor.roteiro = (_) =>
          RespostaFalsa(400, json: problema(400, 'requisicao_invalida'));
      await expectLater(
        cliente.post('sessoes'),
        throwsA(isA<PedidoRecusadoPeloPortal>()),
      );
      servidor.roteiro = (_) =>
          RespostaFalsa(500, json: problema(500, 'erro_interno'));
      await expectLater(
        cliente.get('eu'),
        throwsA(
          isA<RespostaInesperadaDoPortal>().having((e) => e.status, 's', 500),
        ),
      );
    });

    test('servidor fora do ar é falha de rede', () async {
      final porta = servidor.url.port;
      await servidor.parar();
      final c = ClienteDoPortal(
        url: Uri.parse('http://127.0.0.1:$porta'),
        dispositivo: guarda,
        relogio: relogio,
        tempoLimite: const Duration(seconds: 2),
      );
      addTearDown(c.fechar);
      await expectLater(c.get('eu'), throwsA(isA<FalhaDeRedeNoPortal>()));
    });

    test('servidor que não responde estoura o tempo', () async {
      final mudo = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(mudo.close);
      final aceitas = <Socket>[];
      mudo.listen(aceitas.add);
      addTearDown(() {
        for (final s in aceitas) {
          s.destroy();
        }
      });
      final c = ClienteDoPortal(
        url: Uri.parse('http://127.0.0.1:${mudo.port}'),
        dispositivo: guarda,
        relogio: relogio,
        tempoLimite: const Duration(milliseconds: 300),
      );
      addTearDown(c.fechar);
      await expectLater(c.get('eu'), throwsA(isA<FalhaDeRedeNoPortal>()));
    });
  });
}
