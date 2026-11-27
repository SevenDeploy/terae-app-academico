import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/terae_local/autenticacao_terae_local.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/contexto_do_portal.dart';
import 'package:terae_app/dados/terae_local/diario_terae_local.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'portal_falso.dart';
import 'servidor_falso.dart';

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

const String _idLocal1 = '11111111-1111-4111-8111-111111111111';
const String _idLocal2 = '22222222-2222-4222-8222-222222222222';
const String _idLocal3 = '33333333-3333-4333-8333-333333333333';

RegistroDiario _novo(
  String id, {
  Intensidade? intensidade,
  String? sintomas,
  DateTime? em,
}) => RegistroDiario(
  id: id,
  pacienteId: idAlice,
  registradoEm: em ?? DateTime.utc(2026, 11, 26, 17),
  adesao: Adesao.parcial,
  sintomas: sintomas,
  intensidadeSintoma: intensidade,
  situacaoEnvio: SituacaoEnvio.naFila,
);

String _jsonDe(RegistroDiario r) => jsonEncode(r.toMap());

void main() {
  late ServidorFalso servidor;
  late PortalFalso portal;
  late ClienteDoPortal cliente;
  late ContextoDoPortal contexto;
  late GuardaDaFilaEmMemoria fila;
  late DiarioTeraeLocal diario;
  final relogio = RelogioFixo(DateTime.utc(2026, 11, 26, 18));

  setUp(() async {
    servidor = await ServidorFalso.iniciar();
    portal = PortalFalso(servidor);
    cliente = ClienteDoPortal(
      url: servidor.url,
      dispositivo: GuardaEmMemoria(),
      relogio: relogio,
      tempoLimite: const Duration(seconds: 5),
    );
    contexto = ContextoDoPortal(cliente: cliente);
    fila = GuardaDaFilaEmMemoria();
    diario = DiarioTeraeLocal(contexto, fila: fila);
    final autenticacao = AutenticacaoTeraeLocal(contexto);
    await autenticacao.iniciarEntrada(
      email: 'mariana@exemplo.test',
      senha: portal.senha,
    );
    await autenticacao.confirmarCodigo(
      portal.codigo,
      confiarNesteAparelho: false,
    );
  });

  tearDown(() async {
    cliente.fechar();
    await servidor.parar();
  });

  test('enviar manda a chave de idempotência e devolve o registro do '
      'servidor; reenviar não duplica', () async {
    final r = await diario.enviar(_novo(_idLocal1, sintomas: '  Chorou  '));
    expect(r.enviado, isTrue);
    expect(r.equipeAvisada, isFalse);
    expect(r.registro.id, isNot(_idLocal1), reason: 'o id é o do servidor');
    expect(r.registro.versao, 1);
    expect(r.registro.enviadoEm, DateTime.utc(2026, 11, 26, 18, 1));
    final post = servidor.pedidos.lastWhere((p) => p.metodo == 'POST');
    expect(post.cabecalho('idempotency-key'), _idLocal1);
    expect(portal.enviosDoDiario.single, {
      'idPaciente': idAlice,
      'adesao': 'parcial',
      'sintomas': 'Chorou',
      // B2: o mesmo corpo em toda tentativa, com a hora em que foi escrito
      // (a API só a mostra se passar de 5 min da chegada).
      'guardadoEm': '2026-11-26T17:00:00.000Z',
    });

    final deNovo = await diario.enviar(_novo(_idLocal1));
    expect(deNovo.registro.id, r.registro.id);
    expect(portal.diario, hasLength(1));
  });

  test('registro crítico: a equipe foi avisada (ajudaImediata)', () async {
    final r = await diario.enviar(
      _novo(_idLocal1, intensidade: Intensidade.critico),
    );
    expect(r.equipeAvisada, isTrue);
    expect(r.alerta?.regraDisparada, RegraAlerta.intensidadeCritica);
    expect(await diario.alertaDoRegistro(r.registro.id), isNotNull);
  });

  test('lista paginada do mais novo ao mais antigo, com "haMais"', () async {
    for (final id in [_idLocal1, _idLocal2, _idLocal3]) {
      await diario.enviar(_novo(id));
    }
    final primeira = await diario.pagina(idAlice);
    expect(primeira.registros, hasLength(2));
    expect(primeira.haMais, isTrue);
    expect(
      primeira.registros.first.enviadoEm,
      DateTime.utc(2026, 11, 26, 18, 3),
    );
    final segunda = await diario.pagina(
      idAlice,
      antes: primeira.registros.last.enviadoEm,
    );
    expect(segunda.registros, hasLength(1));
    expect(segunda.haMais, isFalse);
    expect(
      servidor.pedidos.last.caminho,
      contains('antes=2026-11-26T18%3A02%3A00.000Z'),
    );
  });

  test('corrigir cria a versão 2 e "Ver a versão 1" vem das versões', () async {
    final enviado = await diario.enviar(_novo(_idLocal1, sintomas: 'Antes'));
    final id = enviado.registro.id;
    final corrigido = await diario.corrigir(
      id,
      EntradaDoDiario(adesao: Adesao.total, sintomas: 'Depois'),
    );
    expect(corrigido.registro.versao, 2);
    expect(
      corrigido.registro.id,
      isNot(id),
      reason: 'a versão vigente é uma linha nova na API',
    );
    expect(
      (await diario.registro(id)).versao,
      2,
      reason: 'o id antigo leva à vigente',
    );
    expect(corrigido.registro.sintomas, 'Depois');
    expect(corrigido.registro.versoesAnteriores.single.sintomas, 'Antes');
    final put = servidor.pedidos.lastWhere((p) => p.metodo == 'PUT');
    expect(put.json, {
      'idPaciente': idAlice,
      'adesao': 'total',
      'sintomas': 'Depois',
    });

    // Outro aparelho: só a lista, sem o que este viu.
    final outro = DiarioTeraeLocal(contexto, fila: GuardaDaFilaEmMemoria());
    final lido = (await outro.pagina(idAlice)).registros.single;
    expect(lido.versao, 2);
    expect(lido.versoesAnteriores.single.versao, 1);
    expect(lido.versoesAnteriores.single.sintomas, 'Antes');
    expect(lido.atualizadoEm, DateTime.utc(2026, 11, 26, 19, 2));
    expect(
      servidor.pedidos.map((p) => p.caminho),
      contains('/api/portal/diario/${corrigido.registro.id}/versoes'),
    );

    // Retirar pelo id antigo vai à versão vigente.
    final retirado = await diario.retirar(
      id,
      RetiradaDoRegistro(categoria: MotivoDaRetirada.enviadoSemQuerer),
    );
    expect(retirado.id, corrigido.registro.id);
    expect(retirado.versoesAnteriores, hasLength(1));
  });

  test(
    'revisado (ou crítico) não muda mais: 409 → registroNaoMudaMais',
    () async {
      final enviado = await diario.enviar(_novo(_idLocal1));
      portal.diario.single['podeAlterar'] = false;
      await expectLater(
        diario.corrigir(
          enviado.registro.id,
          EntradaDoDiario(adesao: Adesao.total),
        ),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
      await expectLater(
        diario.retirar(
          enviado.registro.id,
          RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado),
        ),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
    },
  );

  test('retirar manda o motivo e devolve o registro retirado', () async {
    final enviado = await diario.enviar(_novo(_idLocal1));
    final retirado = await diario.retirar(
      enviado.registro.id,
      RetiradaDoRegistro(categoria: MotivoDaRetirada.outro, detalhe: ' Teste '),
    );
    expect(retirado.retirado, isTrue);
    expect(retirado.motivoDaRetirada?.categoria, MotivoDaRetirada.outro);
    expect(retirado.motivoDaRetirada?.detalhe, 'Teste');
    final post = servidor.pedidos.last;
    expect(post.json, {
      'idPaciente': idAlice,
      'motivo': {'categoria': 'outro', 'detalhe': 'Teste'},
    });
  });

  test('registro inexistente: 404 → registroInexistente', () async {
    await expectLater(
      diario.registro('d0000000-0000-4000-8000-000000000999'),
      _recusa(MotivoRecusa.registroInexistente),
    );
  });

  test('sem internet: guarda neste aparelho e reenvia com a mesma chave e o '
      '"guardadoEm"', () async {
    final desligado = await ServidorFalso.iniciar();
    final url = desligado.url;
    await desligado.parar();
    final semRede = ClienteDoPortal(
      url: url,
      dispositivo: GuardaEmMemoria(),
      relogio: relogio,
      tempoLimite: const Duration(seconds: 2),
    );
    addTearDown(semRede.fechar);
    final offline = DiarioTeraeLocal(
      ContextoDoPortal(cliente: semRede),
      fila: fila,
    );
    final guardado = await offline.enviar(_novo(_idLocal1));
    expect(guardado.registro.situacaoEnvio, SituacaoEnvio.naFila);
    expect(guardado.equipeAvisada, isFalse);
    expect((await diario.pendentes(idAlice)).single.id, _idLocal1);

    final saidos = await diario.reenviarFila();
    expect(saidos, hasLength(1));
    expect(await diario.pendentes(idAlice), isEmpty);
    final post = servidor.pedidos.lastWhere((p) => p.metodo == 'POST');
    expect(post.cabecalho('idempotency-key'), _idLocal1);
    expect(
      (post.json! as Map<String, Object?>)['guardadoEm'],
      '2026-11-26T17:00:00.000Z',
    );
  });

  test('abrir a lista tenta a fila antes (como o portal)', () async {
    await fila.gravar(null);
    final desligado = await ServidorFalso.iniciar();
    final url = desligado.url;
    await desligado.parar();
    final semRede = ClienteDoPortal(
      url: url,
      dispositivo: GuardaEmMemoria(),
      relogio: relogio,
      tempoLimite: const Duration(seconds: 2),
    );
    addTearDown(semRede.fechar);
    await DiarioTeraeLocal(
      ContextoDoPortal(cliente: semRede),
      fila: fila,
    ).enviar(_novo(_idLocal2));
    final pagina = await diario.pagina(idAlice);
    expect(pagina.registros, hasLength(1));
    expect(await diario.pendentes(idAlice), isEmpty);
  });

  test('"Sair" esquece a fila deste aparelho', () async {
    await fila.gravar('[]');
    await diario.esquecer();
    expect(fila.texto, isNull);
  });

  test('sessão acabada (401) vira sessaoTerminou', () async {
    portal.completa = false;
    await expectLater(
      diario.pagina(idAlice),
      _recusa(MotivoRecusa.sessaoTerminou),
    );
  });

  group('revisão da P4', () {
    Future<DiarioTeraeLocal> semRede() async {
      final desligado = await ServidorFalso.iniciar();
      final url = desligado.url;
      await desligado.parar();
      final semRede = ClienteDoPortal(
        url: url,
        dispositivo: GuardaEmMemoria(),
        relogio: relogio,
        tempoLimite: const Duration(seconds: 2),
      );
      addTearDown(semRede.fechar);
      return DiarioTeraeLocal(ContextoDoPortal(cliente: semRede), fila: fila);
    }

    test('B1: a sessão acabada (401) não apaga a fila; ao entrar de novo, os '
        'dois guardados saem', () async {
      final offline = await semRede();
      await offline.enviar(_novo(_idLocal1));
      await offline.enviar(_novo(_idLocal2));
      expect(await diario.pendentes(idAlice), hasLength(2));

      portal.completa = false;
      expect(await diario.reenviarFila(), isEmpty);
      // O que se escreve com a sessão acabada também fica guardado.
      final noFim = await diario.enviar(_novo(_idLocal3));
      expect(noFim.registro.situacaoEnvio, SituacaoEnvio.naFila);
      expect(await diario.pendentes(idAlice), hasLength(3));

      final autenticacao = AutenticacaoTeraeLocal(contexto);
      await autenticacao.iniciarEntrada(
        email: 'mariana@exemplo.test',
        senha: portal.senha,
      );
      await autenticacao.confirmarCodigo(
        portal.codigo,
        confiarNesteAparelho: false,
      );
      expect(await diario.reenviarFila(), hasLength(3));
      expect(await diario.pendentes(idAlice), isEmpty);
      expect(portal.diario, hasLength(3));
    });

    test('B2: o POST grava mas a resposta estoura o tempo; o reenvio leva o '
        'mesmo corpo, não duplica e a fila esvazia', () async {
      final apressado = ClienteDoPortal(
        url: servidor.url,
        dispositivo: GuardaEmMemoria(),
        relogio: relogio,
        tempoLimite: const Duration(milliseconds: 300),
      );
      addTearDown(apressado.fechar);
      final contextoApressado = ContextoDoPortal(cliente: apressado);
      final autenticacao = AutenticacaoTeraeLocal(contextoApressado);
      await autenticacao.iniciarEntrada(
        email: 'mariana@exemplo.test',
        senha: portal.senha,
      );
      await autenticacao.confirmarCodigo(
        portal.codigo,
        confiarNesteAparelho: false,
      );
      final apressadoDiario = DiarioTeraeLocal(contextoApressado, fila: fila);

      portal.demorarProximoEnvio = const Duration(seconds: 1);
      final primeiro = await apressadoDiario.enviar(_novo(_idLocal1));
      expect(primeiro.registro.situacaoEnvio, SituacaoEnvio.naFila);
      expect(portal.diario, hasLength(1), reason: 'o servidor gravou');

      expect(await diario.reenviarFila(), hasLength(1));
      expect(await diario.pendentes(idAlice), isEmpty);
      expect(portal.diario, hasLength(1), reason: 'não duplicou');
      final corpos = [
        for (final p in servidor.pedidos)
          if (p.metodo == 'POST' && p.caminho.endsWith('/diario')) p.corpo,
      ];
      expect(corpos, hasLength(2));
      expect(corpos.toSet(), hasLength(1), reason: 'o mesmo corpo');
    });

    test('B2: a chave já usada com outro corpo tira o registro da fila em vez '
        'de prendê-lo', () async {
      final offline = await semRede();
      await offline.enviar(_novo(_idLocal1));
      // Outro corpo com a mesma chave já chegou ao servidor.
      portal.impressaoPorChave[_idLocal1] = '{"outro":"corpo"}';
      portal.recibosPorChave[_idLocal1] = const {};
      final saidos = await diario.reenviarFila();
      expect(saidos, isEmpty);
      expect(await diario.pendentes(idAlice), isEmpty);
    });

    test('"Sair" de uma conta não apaga o que outra conta guardou', () async {
      await fila.gravar(
        '[{"registro":${_jsonDe(_novo(_idLocal1))},"dono":"outra-conta"}]',
      );
      await diario.esquecer();
      expect(fila.texto, contains('outra-conta'));
      expect(await diario.pendentes(idAlice), isEmpty);
    });
  });
}
