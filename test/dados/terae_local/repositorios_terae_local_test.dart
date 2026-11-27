import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/terae_local/autenticacao_terae_local.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/contexto_do_portal.dart';
import 'package:terae_app/dados/terae_local/indisponiveis_terae_local.dart';
import 'package:terae_app/dados/terae_local/repositorios_terae_local.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'portal_falso.dart';
import 'servidor_falso.dart';

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

void main() {
  late ServidorFalso servidor;
  late PortalFalso portal;
  late GuardaEmMemoria guarda;
  late ClienteDoPortal cliente;
  late ContextoDoPortal contexto;
  late AutenticacaoTeraeLocal autenticacao;
  final relogio = RelogioFixo(DateTime.utc(2026, 11, 26, 18));

  setUp(() async {
    servidor = await ServidorFalso.iniciar();
    portal = PortalFalso(servidor);
    guarda = GuardaEmMemoria();
    cliente = ClienteDoPortal(
      url: servidor.url,
      dispositivo: guarda,
      relogio: relogio,
      tempoLimite: const Duration(seconds: 5),
    );
    contexto = ContextoDoPortal(cliente: cliente);
    autenticacao = AutenticacaoTeraeLocal(contexto);
  });

  tearDown(() async {
    cliente.fechar();
    await servidor.parar();
  });

  /// Senha → código → sessão completa, como a Mariana na TM01.
  Future<VinculosDaConta> entrar() async {
    final passo = await autenticacao.iniciarEntrada(
      email: 'mariana@exemplo.test',
      senha: portal.senha,
    );
    expect(passo, isA<CodigoDeAcessoPedido>());
    return autenticacao.confirmarCodigo(
      portal.codigo,
      confiarNesteAparelho: false,
    );
  }

  List<String> rotas() => [
    for (final p in servidor.pedidos)
      '${p.metodo} ${Uri.parse(p.caminho).path.replaceFirst('/api/portal/', '')}',
  ];

  group('autenticação', () {
    test('senha → código (e-mail mascarado) → conta e perfis do /eu', () async {
      final passo = await autenticacao.iniciarEntrada(
        email: ' Mariana@Exemplo.test ',
        senha: portal.senha,
      );
      final codigo = passo as CodigoDeAcessoPedido;
      expect(codigo.emailMascarado, 'ma***@exemplo.test');
      expect(codigo.codigoEnviado, isTrue);
      expect(codigo.reenviarAPartirDe, DateTime.utc(2026, 11, 26, 18, 1));
      expect(
        (servidor.pedidos.first.json! as Map)['email'],
        'mariana@exemplo.test',
        reason: 'e-mail normalizado',
      );

      final vinculos = await autenticacao.confirmarCodigo(
        portal.codigo,
        confiarNesteAparelho: false,
      );
      expect(vinculos.conta.nomeExibicao, 'Mariana Souza');
      expect(vinculos.conta.email, 'mariana@exemplo.test');
      expect(vinculos.pacientes.map((p) => p.nome), [
        'Alice Souza',
        'Bento Souza',
      ]);
      expect(vinculos.acompanhados.single.id, idCaio);
      expect(vinculos.acompanhados.single.cpf, isNull);
      expect(vinculos.qualidades, {
        idAlice: QualidadeConsentimento.responsavelLegal,
        idBento: QualidadeConsentimento.titular,
      });
      expect(vinculos.pacientes.every((p) => p.temTerapiaOcupacional), isTrue);
      expect(
        vinculos.pacientes.any((p) => p.temAcompanhamentoClinico),
        isFalse,
        reason: 'D21: sem receita no Terae local',
      );
      expect(guarda.token, isNull, reason: 'confiar desmarcado');
    });

    test('senha errada: credenciaisInvalidas', () async {
      await expectLater(
        autenticacao.iniciarEntrada(email: 'm@exemplo.test', senha: 'errada'),
        _recusa(MotivoRecusa.credenciaisInvalidas),
      );
    });

    test('código errado conta as tentativas; a última volta à senha', () async {
      await autenticacao.iniciarEntrada(
        email: 'm@exemplo.test',
        senha: portal.senha,
      );
      await expectLater(
        autenticacao.confirmarCodigo('000000', confiarNesteAparelho: false),
        throwsA(
          isA<CodigoNaoConfere>().having(
            (e) => e.tentativasRestantes,
            'tentativas',
            4,
          ),
        ),
      );
      portal.tentativas = 1;
      await expectLater(
        autenticacao.confirmarCodigo('000000', confiarNesteAparelho: false),
        throwsA(
          isA<VoltarParaASenha>().having(
            (e) => e.recado,
            'recado',
            recadoDasTentativas,
          ),
        ),
      );
      expect(cliente.temSessao, isFalse);
    });

    test('confiar no aparelho guarda o cookie e a próxima senha dispensa o '
        'código', () async {
      portal.tokenDoAparelho = 'aparelho-1';
      await autenticacao.iniciarEntrada(
        email: 'm@exemplo.test',
        senha: portal.senha,
      );
      await autenticacao.confirmarCodigo(
        portal.codigo,
        confiarNesteAparelho: true,
      );
      expect(guarda.token, 'aparelho-1');
      cliente.esquecerSessao();
      final passo = await autenticacao.iniciarEntrada(
        email: 'm@exemplo.test',
        senha: portal.senha,
      );
      expect(passo, isA<EntradaConcluida>());
    });

    test('reenviar com a sessão provisória vencida volta à senha', () async {
      await expectLater(
        autenticacao.reenviarCodigo(),
        throwsA(isA<VoltarParaASenha>()),
      );
      await autenticacao.iniciarEntrada(
        email: 'm@exemplo.test',
        senha: portal.senha,
      );
      final novo = await autenticacao.reenviarCodigo();
      expect(novo.reenviarAPartirDe, DateTime.utc(2026, 11, 26, 18, 2));
    });

    test('conta sem paciente: contaSemAcesso e a sessão é encerrada', () async {
      portal.pacientes = [];
      await autenticacao.iniciarEntrada(
        email: 'm@exemplo.test',
        senha: portal.senha,
      );
      await expectLater(
        autenticacao.confirmarCodigo(
          portal.codigo,
          confiarNesteAparelho: false,
        ),
        _recusa(MotivoRecusa.contaSemAcesso),
      );
      expect(rotas().last, 'DELETE sessoes');
    });

    test('sair chama DELETE /portal/sessoes e esquece a conta', () async {
      await entrar();
      expect(contexto.eu, isNotNull);
      await autenticacao.sair();
      expect(rotas().last, 'DELETE sessoes');
      expect(cliente.temSessao, isFalse);
      expect(contexto.eu, isNull);
      expect(await autenticacao.sessaoGuardada(), isNull);
    });

    test('primeiro acesso por código do app não existe no portal', () async {
      await expectLater(
        autenticacao.conferirConviteCuidador(codigo: 'X', cpf: '1'),
        _recusa(MotivoRecusa.indisponivelNestaFonte),
      );
    });

    test('servidor fora do ar: semConexao', () async {
      await servidor.parar();
      await expectLater(
        autenticacao.iniciarEntrada(email: 'm@exemplo.test', senha: 'x'),
        _recusa(MotivoRecusa.semConexao),
      );
    });
  });

  group('paciente e agenda', () {
    test(
      'a próxima sessão vem do /inicio, com o paciente escolhido antes',
      () async {
        await entrar();
        final repo = PacienteTeraeLocal(contexto);
        final proxima = await repo.proximaConsulta(idAlice);
        expect(proxima!.id, idSessao1);
        expect(proxima.dataHora, DateTime.utc(2026, 11, 27, 18));
        expect(proxima.situacao, SituacaoAgendamento.agendado);
        expect(rotas().sublist(rotas().length - 2), [
          'PUT sessoes/paciente',
          'GET inicio',
        ]);
        final profissional = await repo.profissional(proxima.profissionalId);
        expect(profissional.nome, 'Ana');
        expect(profissional.especialidade, 'Terapia ocupacional');
      },
    );

    test('a clínica, o telefone e a duração chegam ao app (paridade com o '
        'portal)', () async {
      await entrar();
      final repo = PacienteTeraeLocal(contexto);
      final paciente = await repo.paciente(idAlice);
      expect(paciente.nomeDaClinica, 'Clínica Exemplo');
      expect(paciente.telefoneDaClinica, '+55 65 3000-0000');
      // Sem telefone no /eu, fica nulo (o app não inventa um).
      expect((await repo.paciente(idBento)).telefoneDaClinica, isNull);
      final proxima = await repo.proximaConsulta(idAlice);
      expect(proxima!.duracaoMinutos, 50);
      final agenda = await repo.agendamentos(idAlice);
      expect(agenda.map((a) => a.duracaoMinutos), [50, 50]);
    });

    test('agenda em ordem, desmarcada pela clínica vira cancelada', () async {
      await entrar();
      final repo = PacienteTeraeLocal(contexto);
      final agenda = await repo.agendamentos(idAlice);
      expect(agenda.map((a) => a.id), [idSessao1, idSessao2]);
      expect(agenda.last.situacao, SituacaoAgendamento.cancelado);
      expect(agenda.first.pacienteId, idAlice);
    });

    test('agenda não liberada: sem sessões e sem próxima', () async {
      await entrar();
      final repo = PacienteTeraeLocal(contexto);
      expect(await repo.agendamentos(idBento), isEmpty);
      expect(await repo.proximaConsulta(idBento), isNull);
    });

    test('receita, itens e marcos não existem no portal: vazios', () async {
      await entrar();
      final repo = PacienteTeraeLocal(contexto);
      expect(await repo.receitaVigente(idAlice), isNull);
      expect(await repo.itensDaReceita('x'), isEmpty);
      expect(await repo.marcos(idAlice), isEmpty);
      expect((await repo.paciente(idAlice)).nome, 'Alice Souza');
      await expectLater(
        repo.paciente('outro'),
        _recusa(MotivoRecusa.acessoNegado),
      );
    });

    test('trocar de paciente escolhe de novo só quando muda; chamadas ao '
        'mesmo tempo saem uma de cada vez', () async {
      await entrar();
      final repo = PacienteTeraeLocal(contexto);
      servidor.pedidos.clear();
      await Future.wait([
        repo.agendamentos(idAlice),
        repo.agendamentos(idBento),
        repo.agendamentos(idAlice),
      ]);
      expect(rotas(), [
        'PUT sessoes/paciente',
        'GET agenda',
        'PUT sessoes/paciente',
        'GET agenda',
        'PUT sessoes/paciente',
        'GET agenda',
      ]);
      servidor.pedidos.clear();
      await repo.agendamentos(idAlice);
      expect(rotas(), ['GET agenda']);
    });

    test(
      '409 "Escolha o paciente primeiro" escolhe de novo e repete',
      () async {
        await entrar();
        final repo = PacienteTeraeLocal(contexto);
        await repo.agendamentos(idAlice);
        portal.pacienteAtual = null;
        servidor.pedidos.clear();
        expect(await repo.agendamentos(idAlice), hasLength(2));
        expect(rotas(), ['GET agenda', 'PUT sessoes/paciente', 'GET agenda']);
      },
    );

    test('401 numa leitura: sessaoTerminou e o app volta ao Entrar', () async {
      await entrar();
      var acabou = 0;
      contexto.aoSessaoAcabar = () => acabou++;
      portal.completa = false;
      await expectLater(
        PacienteTeraeLocal(contexto).agendamentos(idAlice),
        _recusa(MotivoRecusa.sessaoTerminou),
      );
      expect(acabou, 1);
      expect(cliente.temSessao, isFalse);
    });

    test('corpo fora do contrato: RespostaInesperadaDoPortal', () async {
      await entrar();
      portal.forcar['GET agenda'] = const RespostaFalsa(
        200,
        json: {'liberada': 'sim', 'sessoes': <Object?>[]},
      );
      await expectLater(
        PacienteTeraeLocal(contexto).agendamentos(idAlice),
        throwsA(isA<RespostaInesperadaDoPortal>()),
      );
    });
  });

  group('presença', () {
    test('as respostas vêm da confirmação de cada sessão', () async {
      await entrar();
      portal.confirmacoes[idSessao1] = 'confirmada';
      final respostas = await PresencaTeraeLocal(contexto).respostas(idAlice);
      expect(respostas.keys, [idSessao1]);
      expect(respostas[idSessao1]!.resposta, RespostaPresenca.vamos);
      expect(respostas[idSessao1]!.situacaoEnvio, SituacaoEnvio.enviado);
    });

    test('"Sim, vamos" confirma; "Não vamos" depois ainda avisa; voltar a '
        'confirmar recusa sessaoEncerrada', () async {
      await entrar();
      final repo = PresencaTeraeLocal(contexto);
      final sim = await repo.responder(
        pacienteId: idAlice,
        agendamentoId: idSessao1,
        resposta: RespostaPresenca.vamos,
      );
      expect(sim.respondidaEm, DateTime.utc(2026, 11, 26, 18, 0, 5));
      final pedido = servidor.pedidos.last;
      expect(pedido.caminho, '/api/portal/agenda/$idSessao1/confirmacao');
      expect(pedido.cabecalho('x-terae-cliente'), rotuloDoCliente);
      expect(portal.confirmacoes[idSessao1], 'confirmada');

      final nao = await repo.responder(
        pacienteId: idAlice,
        agendamentoId: idSessao1,
        resposta: RespostaPresenca.naoVamos,
      );
      expect(nao.resposta, RespostaPresenca.naoVamos);
      expect(portal.confirmacoes[idSessao1], 'ausencia_avisada');

      await expectLater(
        repo.responder(
          pacienteId: idAlice,
          agendamentoId: idSessao1,
          resposta: RespostaPresenca.vamos,
        ),
        _recusa(MotivoRecusa.sessaoEncerrada),
      );
      final respostas = await repo.respostas(idAlice);
      expect(
        respostas[idSessao1]!.respondidaEm,
        DateTime.utc(2026, 11, 26, 18, 0, 6),
        reason: 'o instante do recibo deste aparelho',
      );
    });

    test('sessão que não existe: agendamentoInexistente', () async {
      await entrar();
      await expectLater(
        PresencaTeraeLocal(contexto).responder(
          pacienteId: idAlice,
          agendamentoId: 'nenhuma',
          resposta: RespostaPresenca.vamos,
        ),
        _recusa(MotivoRecusa.agendamentoInexistente),
      );
    });

    test('cuidador recebe 403: acessoNegado', () async {
      await entrar();
      portal.forcar['POST agenda/$idSessao1/confirmacao'] = RespostaFalsa(
        403,
        json: problema(403, 'perfil_sem_recurso'),
      );
      await expectLater(
        PresencaTeraeLocal(contexto).responder(
          pacienteId: idAlice,
          agendamentoId: idSessao1,
          resposta: RespostaPresenca.vamos,
        ),
        _recusa(MotivoRecusa.acessoNegado),
      );
    });
  });

  group('programa em casa', () {
    test('orientações viram atividades, campo a campo', () async {
      await entrar();
      final repo = ProgramaTeraeLocal(contexto);
      final atividades = await repo.atividades(idAlice);
      expect(atividades.map((a) => a.titulo), [
        'Escovar os dentes sozinha',
        'Guardar os brinquedos',
      ]);
      final a = atividades.first;
      expect(a.id, idOrientacao1);
      expect(a.pacienteId, idAlice);
      expect(a.texto, 'Com o espelho na altura dela.');
      expect(a.vezesPorSemana, 5);
      expect(a.publicadaEm, DateTime.utc(2026, 11, 20, 13));
      expect(atividades.last.vezesPorSemana, 7, reason: 'o app vai até 7');
      expect((await repo.atividade(idAlice, idOrientacao2)).id, idOrientacao2);
      await expectLater(
        repo.atividade(idAlice, 'outra'),
        _recusa(MotivoRecusa.atividadeInexistente),
      );
      expect(await repo.atividades(idBento), isEmpty);
    });

    test('registrar manda a adesão e a reflexão; o registro de hoje volta '
        'na leitura', () async {
      await entrar();
      final repo = ProgramaTeraeLocal(contexto);
      final r = await repo.registrar(
        pacienteId: idAlice,
        atividadeId: idOrientacao1,
        adesao: AdesaoEmCasa.emParte,
        reflexao: '  Foi com ajuda.  ',
        quem: QuemRegistrou.responsavel,
      );
      expect(servidor.pedidos.last.json, {
        'registros': [
          {
            'idOrientacao': idOrientacao1,
            'adesao': 'em_parte',
            'reflexao': 'Foi com ajuda.',
          },
        ],
      });
      expect(r.dia, DataCivil(2026, 11, 26));
      expect(r.registradoEm, DateTime.utc(2026, 11, 26, 18, 0, 7));
      expect(r.situacaoEnvio, SituacaoEnvio.enviado);

      final registros = await repo.registros(idAlice, dias: 14);
      expect(registros, hasLength(2));
      final meu = registros.firstWhere((x) => x.atividadeId == idOrientacao1);
      expect(meu.id, r.id);
      expect(meu.adesao, AdesaoEmCasa.emParte);
      expect(meu.reflexao, 'Foi com ajuda.');
      expect(meu.quem, QuemRegistrou.responsavel);
      final daRosa = registros.firstWhere(
        (x) => x.atividadeId == idOrientacao2,
      );
      expect(daRosa.adesao, AdesaoEmCasa.feito);
      expect(daRosa.reflexao, isNull);
      expect(await repo.registros(idAlice, dias: 0), isEmpty);
    });

    test('sem reflexão, o campo não vai', () async {
      await entrar();
      await ProgramaTeraeLocal(contexto).registrar(
        pacienteId: idAlice,
        atividadeId: idOrientacao1,
        adesao: AdesaoEmCasa.naoFeito,
        reflexao: '   ',
        quem: QuemRegistrou.responsavel,
      );
      expect(servidor.pedidos.last.json, {
        'registros': [
          {'idOrientacao': idOrientacao1, 'adesao': 'nao_feito'},
        ],
      });
    });

    test('registro de outra conta hoje (409): registroDeOutraConta', () async {
      await entrar();
      portal.forcar['POST programa'] = RespostaFalsa(
        409,
        json: problema(409, 'conflito'),
      );
      await expectLater(
        ProgramaTeraeLocal(contexto).registrar(
          pacienteId: idAlice,
          atividadeId: idOrientacao2,
          adesao: AdesaoEmCasa.feito,
          quem: QuemRegistrou.responsavel,
        ),
        _recusa(MotivoRecusa.registroDeOutraConta),
      );
    });

    test('desfazer não existe na API', () async {
      await entrar();
      await expectLater(
        ProgramaTeraeLocal(contexto).desfazer(idAlice, 'x'),
        _recusa(MotivoRecusa.indisponivelNestaFonte),
      );
    });
  });

  group('visão do cuidador', () {
    test('o cuidador vê o paciente sem dados pessoais e a agenda só se '
        'liberada', () async {
      await entrar();
      final repo = VisaoCuidadorTeraeLocal(contexto);
      final caio = await repo.pacienteAcompanhado(
        contaCuidadorId: 'c',
        pacienteId: idCaio,
      );
      expect(caio.nome, 'Caio Lima');
      expect(caio.cpf, isNull);
      expect(
        await repo.consultas(contaCuidadorId: 'c', pacienteId: idCaio),
        isEmpty,
      );
      expect(
        await repo.respostasDePresenca(
          contaCuidadorId: 'c',
          pacienteId: idCaio,
        ),
        isEmpty,
      );
      expect(
        await repo.alertas(contaCuidadorId: 'c', pacienteId: idCaio),
        isEmpty,
      );
      expect(
        await repo.receitaVigente(contaCuidadorId: 'c', pacienteId: idCaio),
        isNull,
      );
    });

    test('paciente que não é do cuidador: acessoNegado', () async {
      await entrar();
      await expectLater(
        VisaoCuidadorTeraeLocal(contexto)
            .consultas(contaCuidadorId: 'c', pacienteId: idAlice),
        _recusa(MotivoRecusa.acessoNegado),
      );
    });
  });

  group('o que o portal não tem', () {
    test('cuidadores e metas: vazios', () async {
      const cuidadores = CuidadoresIndisponiveisNoTeraeLocal();
      expect(await cuidadores.cuidadores(idAlice), isEmpty);
      await expectLater(
        cuidadores.convidar(pacienteId: idAlice, nome: 'X', cpf: '1'),
        _recusa(MotivoRecusa.indisponivelNestaFonte),
      );
      const metas = MetasIndisponiveisNoTeraeLocal();
      expect(await metas.metas(idAlice), isEmpty);
      await expectLater(
        metas.meta(idAlice, 'm'),
        _recusa(MotivoRecusa.metaInexistente),
      );
    });
  });
}
