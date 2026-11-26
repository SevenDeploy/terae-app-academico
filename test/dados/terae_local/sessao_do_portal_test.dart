import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/sessao_do_portal.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'servidor_falso.dart';

const _familia = '__Host-terae_familia';

const Map<String, Object?> _theo = {
  'idPaciente': '22222222-2222-4222-8222-222222222222',
  'nome': 'Theo',
  'nomeDaClinica': 'Clínica Exemplo',
  'fusoHorario': 'America/Cuiaba',
  'perfil': 'responsavel_legal',
  'agendaLiberada': true,
  'acessoTerminaEm': '2038-05-01',
};

Map<String, Object?> _eu({String? atual}) => {
  'idUsuario': '11111111-1111-4111-8111-111111111111',
  'nome': 'Marina Souza',
  'email': 'marina@exemplo.test',
  'superficie': 'portal',
  'idPacienteAtual': ?atual,
  'pacientes': [
    _theo,
    {
      'idPaciente': '33333333-3333-4333-8333-333333333333',
      'nome': 'Lia',
      'nomeDaClinica': 'Outra Clínica',
      'fusoHorario': 'America/Sao_Paulo',
      'telefoneDaClinica': '+55 65 3000-0000',
      'perfil': 'cuidador',
      'agendaLiberada': false,
    },
  ],
  'idRequisicao': '44444444-4444-4444-8444-444444444444',
};

void main() {
  late ServidorFalso servidor;
  late GuardaEmMemoria guarda;
  late ClienteDoPortal cliente;
  late SessaoDoPortal sessao;

  setUp(() async {
    servidor = await ServidorFalso.iniciar();
    guarda = GuardaEmMemoria();
    cliente = ClienteDoPortal(
      url: servidor.url,
      dispositivo: guarda,
      relogio: RelogioFixo(DateTime.utc(2026, 11, 26, 18)),
      tempoLimite: const Duration(seconds: 5),
    );
    sessao = SessaoDoPortal(cliente);
  });

  tearDown(() async {
    cliente.fechar();
    await servidor.parar();
  });

  test('entrar → código → eu → escolher paciente → sair', () async {
    servidor.roteiro = (p) => switch ((p.metodo, p.caminho)) {
      ('POST', '/api/portal/sessoes') => const RespostaFalsa(
        201,
        json: {
          'etapa': 'codigo',
          'emailMascarado': 'ma***@exemplo.test',
          'codigoEnviado': true,
          'reenviarAPartirDe': '2026-11-26T18:01:00.000Z',
        },
        setCookies: ['$_familia=provisoria; Path=/; Secure'],
      ),
      ('POST', '/api/portal/sessoes/codigo') => const RespostaFalsa(
        200,
        json: {'etapa': 'concluida'},
        setCookies: [
          '$_familia=completa; Path=/; Secure',
          '__Host-terae_dispositivo=disp; Path=/; Max-Age=2592000',
        ],
      ),
      ('GET', '/api/portal/eu') => RespostaFalsa(200, json: _eu()),
      ('PUT', '/api/portal/sessoes/paciente') => RespostaFalsa(
        200,
        json: _eu(atual: '33333333-3333-4333-8333-333333333333'),
        setCookies: const ['$_familia=girada; Path=/; Secure'],
      ),
      ('DELETE', '/api/portal/sessoes') => const RespostaFalsa(
        200,
        json: {'sessoesRevogadas': 1},
        setCookies: [
          '$_familia=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT',
        ],
      ),
      _ => const RespostaFalsa(404),
    };

    final etapa = await sessao.entrar('marina@exemplo.test', 'senha-de-teste');
    expect(etapa, isA<CodigoPedido>());
    final pedido = etapa as CodigoPedido;
    expect(pedido.emailMascarado, 'ma***@exemplo.test');
    expect(pedido.codigoEnviado, isTrue);
    expect(pedido.reenviarAPartirDe, DateTime.utc(2026, 11, 26, 18, 1));
    expect(servidor.pedidos.last.json, {
      'email': 'marina@exemplo.test',
      'senha': 'senha-de-teste',
    });

    await sessao.enviarCodigo('123456', confiarNesteDispositivo: true);
    expect(servidor.pedidos.last.cookies[_familia], 'provisoria');
    expect(servidor.pedidos.last.json, {
      'codigo': '123456',
      'confiarNesteDispositivo': true,
    });
    expect(guarda.token, 'disp');

    final eu = await sessao.eu();
    expect(servidor.pedidos.last.cookies[_familia], 'completa');
    expect(eu.nome, 'Marina Souza');
    expect(eu.idPacienteAtual, isNull);
    expect(eu.pacientes, hasLength(2));
    expect(eu.pacientes[0].perfil, PerfilDoPortal.responsavelLegal);
    expect(eu.pacientes[0].acessoTerminaEm, DataCivil(2038, 5, 1));
    expect(eu.pacientes[0].telefoneDaClinica, isNull);
    expect(eu.pacientes[1].perfil, PerfilDoPortal.cuidador);
    expect(eu.pacientes[1].telefoneDaClinica, '+55 65 3000-0000');
    expect(eu.pacientes[1].acessoTerminaEm, isNull);

    final escolhido = await sessao.escolherPaciente(
      '33333333-3333-4333-8333-333333333333',
    );
    expect(escolhido.idPacienteAtual, '33333333-3333-4333-8333-333333333333');
    expect(servidor.pedidos.last.json, {
      'idPaciente': '33333333-3333-4333-8333-333333333333',
    });

    expect(await sessao.sair(), 1);
    expect(servidor.pedidos.last.cookies[_familia], 'girada');
    expect(sessao.temSessao, isFalse);
    expect(guarda.token, isNull, reason: 'Sair apaga tudo (D20)');
  });

  test('aparelho confiável: entrar conclui sem código', () async {
    guarda.token = 'disp';
    servidor.roteiro = (_) => const RespostaFalsa(
      201,
      json: {'etapa': 'concluida'},
      setCookies: ['$_familia=completa; Path=/'],
    );
    expect(await sessao.entrar('a@b.test', 'x'), isA<LoginConcluido>());
    expect(servidor.pedidos.single.cookies['__Host-terae_dispositivo'], 'disp');
  });

  test('sair mantendo o aparelho confiável', () async {
    guarda.token = 'disp';
    servidor.roteiro = (p) => p.metodo == 'DELETE'
        ? const RespostaFalsa(200, json: {'sessoesRevogadas': 1})
        : const RespostaFalsa(
            201,
            json: {'etapa': 'concluida'},
            setCookies: ['$_familia=s; Path=/'],
          );
    await sessao.entrar('a@b.test', 'x');
    await sessao.sair(manterAparelhoConfiavel: true);
    expect(guarda.token, 'disp');
    expect(sessao.temSessao, isFalse);
  });

  test('sair sem rede ainda esquece a sessão', () async {
    servidor.roteiro = (_) => const RespostaFalsa(
      201,
      json: {'etapa': 'concluida'},
      setCookies: ['$_familia=s; Path=/'],
    );
    await sessao.entrar('a@b.test', 'x');
    await servidor.parar();
    expect(await sessao.sair(), 0);
    expect(sessao.temSessao, isFalse);
  });

  test(
    'código errado mantém a sessão provisória; o último a esquece',
    () async {
      var restantes = 2;
      servidor.roteiro = (p) => p.caminho.endsWith('codigo')
          ? RespostaFalsa(
              401,
              json: problema(
                401,
                'nao_autenticado',
                extra: {'tentativasRestantes': restantes--},
              ),
            )
          : const RespostaFalsa(
              201,
              json: {
                'etapa': 'codigo',
                'emailMascarado': 'a***@b.test',
                'codigoEnviado': true,
                'reenviarAPartirDe': '2026-11-26T18:01:00Z',
              },
              setCookies: ['$_familia=prov; Path=/'],
            );
      await sessao.entrar('a@b.test', 'x');
      for (final esperado in [2, 1]) {
        await expectLater(
          sessao.enviarCodigo('000000'),
          throwsA(
            isA<SessaoDoPortalAcabou>().having(
              (e) => e.tentativasRestantes,
              'restantes',
              esperado,
            ),
          ),
        );
        expect(sessao.temSessao, isTrue);
      }
      await expectLater(
        sessao.enviarCodigo('000000'),
        throwsA(isA<SessaoDoPortalAcabou>()),
      );
      expect(sessao.temSessao, isFalse);
    },
  );

  test('reenviar código devolve a nova etapa', () async {
    servidor.roteiro = (_) => const RespostaFalsa(
      200,
      json: {
        'etapa': 'codigo',
        'emailMascarado': 'a***@b.test',
        'codigoEnviado': false,
        'reenviarAPartirDe': '2026-11-26T18:02:00-04:00',
      },
    );
    final etapa = await sessao.reenviarCodigo() as CodigoPedido;
    expect(etapa.codigoEnviado, isFalse);
    expect(etapa.reenviarAPartirDe, DateTime.utc(2026, 11, 26, 22, 2));
    expect(servidor.pedidos.single.metodo, 'POST');
    expect(
      servidor.pedidos.single.caminho,
      '/api/portal/sessoes/codigo/reenvio',
    );
  });

  test('401 no eu() esquece a sessão', () async {
    servidor.roteiro = (p) => p.metodo == 'POST'
        ? const RespostaFalsa(
            201,
            json: {'etapa': 'concluida'},
            setCookies: ['$_familia=s; Path=/'],
          )
        : RespostaFalsa(401, json: problema(401, 'nao_autenticado'));
    await sessao.entrar('a@b.test', 'x');
    await expectLater(sessao.eu(), throwsA(isA<SessaoDoPortalAcabou>()));
    expect(sessao.temSessao, isFalse);
  });

  test('Eu fora do contrato é resposta inesperada', () async {
    servidor.roteiro = (_) =>
        RespostaFalsa(200, json: {..._eu(), 'pacientes': 'não é lista'});
    await expectLater(sessao.eu(), throwsA(isA<RespostaInesperadaDoPortal>()));
    servidor.roteiro = (_) => RespostaFalsa(
      200,
      json: {
        ..._eu(),
        'pacientes': [
          {..._theo, 'perfil': 'admin'},
        ],
      },
    );
    await expectLater(sessao.eu(), throwsA(isA<RespostaInesperadaDoPortal>()));
  });
}
