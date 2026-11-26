/// Fumaça MANUAL do transporte do Terae local contra a API de verdade
/// (fora do portão: `flutter test` só varre `test/`).
///
/// Roda com `flutter test` e o caminho explícito — `dart run` não serve,
/// porque o `Relogio` e a `DataCivil` do núcleo importam o Flutter:
///
/// ```
/// $env:TERAE_LOCAL_EMAIL = 'conta@homologacao.terae.invalid'
/// $env:TERAE_LOCAL_SENHA = '<do cofre, nunca em arquivo>'
/// flutter test ferramentas/fumaca_terae_local_test.dart
/// ```
///
/// Opcionais: `TERAE_LOCAL_URL` (padrão `http://127.0.0.1:3000`, conferida
/// pela mesma trava do app) e `TERAE_LOCAL_MAILPIT` (padrão
/// `http://127.0.0.1:8025`, de onde sai o código de 6 dígitos). Nada de nome,
/// e-mail ou senha é impresso.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/configuracao_terae_local.dart';
import 'package:terae_app/dados/terae_local/sessao_do_portal.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

class _GuardaEmMemoria implements GuardaDoDispositivo {
  String? token;

  @override
  Future<String?> ler() async => token;

  @override
  Future<void> gravar(String token) async => this.token = token;

  @override
  Future<void> apagar() async => token = null;
}

String? _env(String nome) {
  final v = Platform.environment[nome];
  return v == null || v.isEmpty ? null : v;
}

/// O código mais recente no Mailpit para [email], chegado depois de [desde].
Future<String> _codigoDoMailpit(
  Uri mailpit,
  String email,
  DateTime desde,
) async {
  final http = HttpClient();
  try {
    Future<Object?> json(Uri uri) async {
      final r = await (await http.getUrl(uri)).close();
      return jsonDecode(await utf8.decodeStream(r));
    }

    for (var tentativa = 0; tentativa < 30; tentativa++) {
      final busca = await json(
        mailpit.replace(
          pathSegments: ['api', 'v1', 'search'],
          queryParameters: {
            'query': 'to:"$email" subject:"Seu código de acesso"',
            'limit': '1',
          },
        ),
      );
      if (busca case {
        'messages': [
          {'ID': final String id, 'Created': final String criado},
          ...,
        ],
      }) {
        if (DateTime.parse(criado).isAfter(desde)) {
          final msg = await json(
            mailpit.replace(pathSegments: ['api', 'v1', 'message', id]),
          );
          if (msg case {'Text': final String texto}) {
            final codigo = RegExp(r'\b\d{6}\b').firstMatch(texto)?.group(0);
            if (codigo != null) return codigo;
          }
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError(
      'O código não chegou ao Mailpit em 30 s (o worker roda?).',
    );
  } finally {
    http.close(force: true);
  }
}

void main() {
  final email = _env('TERAE_LOCAL_EMAIL');
  final senha = _env('TERAE_LOCAL_SENHA');

  test(
    'fumaça: entrar → código → eu → paciente → início → sair → aparelho confiável',
    () async {
      final url = exigirUrlLocal(
        _env('TERAE_LOCAL_URL') ?? 'http://127.0.0.1:3000',
      );
      final mailpit = exigirUrlLocal(
        _env('TERAE_LOCAL_MAILPIT') ?? 'http://127.0.0.1:8025',
      );
      final guarda = _GuardaEmMemoria();
      final cliente = ClienteDoPortal(
        url: url,
        dispositivo: guarda,
        relogio: const RelogioSistema(),
      );
      addTearDown(cliente.fechar);
      final sessao = SessaoDoPortal(cliente);

      final antes = const RelogioSistema().agora().subtract(
        const Duration(seconds: 5),
      );
      final etapa = await sessao.entrar(email!, senha!);
      // ignore: avoid_print
      print('1. entrar: ${etapa.runtimeType}');
      if (etapa is CodigoPedido) {
        expect(etapa.codigoEnviado, isTrue, reason: 'o teto de e-mail segurou');
        final codigo = await _codigoDoMailpit(mailpit, email, antes);
        await sessao.enviarCodigo(codigo, confiarNesteDispositivo: true);
        // ignore: avoid_print
        print(
          '2. código conferido; aparelho confiável guardado: '
          '${guarda.token != null}',
        );
        expect(guarda.token, isNotNull);
      }

      final eu = await sessao.eu();
      // ignore: avoid_print
      print(
        '3. eu: ${eu.pacientes.length} paciente(s), perfis '
        '${eu.pacientes.map((p) => p.perfil.valor).toSet()}',
      );
      expect(eu.pacientes, isNotEmpty);

      final escolhido = await sessao.escolherPaciente(
        eu.pacientes.first.idPaciente,
      );
      expect(escolhido.idPacienteAtual, eu.pacientes.first.idPaciente);
      final inicio = await cliente.get('inicio');
      // ignore: avoid_print
      print(
        '4. paciente escolhido; GET /inicio ${inicio.status}, chaves '
        '${inicio.objeto.keys.toList()}',
      );

      // Escrita sem sessão de outro jeito: o CSRF passou (X-Terae-Cliente).
      final revogadas = await sessao.sair(manterAparelhoConfiavel: true);
      // ignore: avoid_print
      print('5. sair: $revogadas sessão(ões) revogada(s)');
      expect(revogadas, 1);
      await expectLater(sessao.eu(), throwsA(isA<SessaoDoPortalAcabou>()));

      final deNovo = await sessao.entrar(email, senha);
      // ignore: avoid_print
      print('6. entrar com o aparelho confiável: ${deNovo.runtimeType}');
      expect(deNovo, isA<LoginConcluido>());
      expect((await sessao.eu()).pacientes, isNotEmpty);

      expect(await sessao.sair(), 1);
      expect(guarda.token, isNull);
      // ignore: avoid_print
      print('7. sair apagando tudo: ok');
    },
    skip: email == null || senha == null
        ? 'defina TERAE_LOCAL_EMAIL e TERAE_LOCAL_SENHA'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
