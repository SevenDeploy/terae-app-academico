/// Fumaça MANUAL dos repositórios do Terae local contra a API de verdade
/// (fora do portão: `flutter test` só varre `test/`). Só lê: entra, lê o
/// início, a agenda, as respostas de presença e o programa, e sai.
///
/// ```
/// $env:TERAE_LOCAL_EMAIL = 'responsavel-alice@homologacao.terae.invalid'
/// $env:TERAE_LOCAL_SENHA = '<do cofre, nunca em arquivo>'
/// flutter test ferramentas/fumaca_repositorios_terae_local_test.dart
/// ```
///
/// O código de 6 dígitos sai do Mailpit (`TERAE_LOCAL_MAILPIT`, padrão
/// `http://127.0.0.1:8025`). Nada de e-mail ou senha é impresso.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/terae_local/autenticacao_terae_local.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/configuracao_terae_local.dart';
import 'package:terae_app/dados/terae_local/contexto_do_portal.dart';
import 'package:terae_app/dados/terae_local/repositorios_terae_local.dart';
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

Future<String> _codigoDoMailpit(Uri mailpit, String email, DateTime desde) async {
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
      } when DateTime.parse(criado).isAfter(desde)) {
        final msg = await json(
          mailpit.replace(pathSegments: ['api', 'v1', 'message', id]),
        );
        if (msg case {'Text': final String texto}) {
          final codigo = RegExp(r'\b\d{6}\b').firstMatch(texto)?.group(0);
          if (codigo != null) return codigo;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('O código não chegou ao Mailpit em 30 s (o worker roda?).');
  } finally {
    http.close(force: true);
  }
}

void main() {
  final email = _env('TERAE_LOCAL_EMAIL');
  final senha = _env('TERAE_LOCAL_SENHA');

  test(
    'fumaça dos repositórios: entrar → início → agenda → presença → programa',
    () async {
      final url = exigirUrlLocal(
        _env('TERAE_LOCAL_URL') ?? 'http://127.0.0.1:3000',
      );
      final mailpit = exigirUrlLocal(
        _env('TERAE_LOCAL_MAILPIT') ?? 'http://127.0.0.1:8025',
      );
      final cliente = ClienteDoPortal(
        url: url,
        dispositivo: _GuardaEmMemoria(),
        relogio: const RelogioSistema(),
      );
      addTearDown(cliente.fechar);
      final contexto = ContextoDoPortal(cliente: cliente);
      final auth = AutenticacaoTeraeLocal(contexto);

      final antes = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
      final passo = await auth.iniciarEntrada(email: email!, senha: senha!);
      final VinculosDaConta vinculos;
      if (passo case CodigoDeAcessoPedido()) {
        final codigo = await _codigoDoMailpit(mailpit, email, antes);
        vinculos = await auth.confirmarCodigo(
          codigo,
          confiarNesteAparelho: false,
        );
      } else {
        vinculos = (passo as EntradaConcluida).vinculos;
      }
      // ignore: avoid_print
      print(
        '1. entrou: ${vinculos.pacientes.length} perfil(is) da família, '
        '${vinculos.acompanhados.length} como cuidador',
      );
      expect(vinculos.pacientes, isNotEmpty);
      final id = vinculos.pacientes.first.id;

      final paciente = PacienteTeraeLocal(contexto);
      final proxima = await paciente.proximaConsulta(id);
      final agenda = await paciente.agendamentos(id);
      // ignore: avoid_print
      print(
        '2. próxima sessão: ${proxima?.dataHora.toIso8601String()}; '
        'agenda com ${agenda.length} sessão(ões)',
      );
      if (proxima != null) {
        final quem = await paciente.profissional(proxima.profissionalId);
        // ignore: avoid_print
        print('   com ${quem.nome} (${quem.especialidade})');
      }
      final respostas = await PresencaTeraeLocal(contexto).respostas(id);
      // ignore: avoid_print
      print('3. respostas de presença: ${respostas.length}');
      final programa = ProgramaTeraeLocal(contexto);
      final atividades = await programa.atividades(id);
      final registros = await programa.registros(id, dias: 1);
      // ignore: avoid_print
      print(
        '4. programa: ${atividades.map((a) => a.titulo).toList()}; '
        '${registros.length} registro(s) hoje',
      );
      await auth.sair();
      // ignore: avoid_print
      print('5. saiu: sessão revogada');
    },
    skip: email == null || senha == null
        ? 'defina TERAE_LOCAL_EMAIL e TERAE_LOCAL_SENHA'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
