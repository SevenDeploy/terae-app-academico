/// Cadastro e entrada com Firebase Authentication + Firestore, sessão
/// guardada e "Sair" (Atividade 4: D14, D16, D20), e a leitura com cópia
/// local quando não há conexão.
library;

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/remoto/fonte_firestore.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

import 'apoio_persistencia.dart';

const String _uidAna = 'c0000000-0000-4000-8000-000000000001';
const String _pidAna = 'a0000000-0000-4000-8000-000000000001';
const String _pidJoao = 'a0000000-0000-4000-8000-000000000004';
const String _codigoJoao = 'K7M4QX';
const String _cpfJoao = '58304921642';
final DataCivil _nascimentoJoao = DataCivil(1999, 7, 19);

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

/// O mínimo da semente: a conta e o paciente de Ana, o João sem conta, o
/// código da clínica dele e a agenda de Ana.
Future<void> _semear(Montagem m) async {
  final db = m.firestore;
  await db.collection('contas').doc(_uidAna).set({
    'id': _uidAna,
    'nomeExibicao': 'Ana Lúcia Martins',
    'email': 'ana.lucia.martins@exemplo.test',
    'idProvedor': _uidAna,
    'situacao': 'ativa',
    'ultimoAcessoEm': null,
  });
  await db.collection('pacientes').doc(_pidAna).set({
    'id': _pidAna,
    'contaId': _uidAna,
    'profissionalRefId': 'd0000000-0000-4000-8000-000000000001',
    'nome': 'Ana Lúcia Martins',
    'ativo': true,
    'cuidadoresAtivos': <String>[],
  });
  await db
      .collection('pacientes')
      .doc(_pidAna)
      .collection('privado')
      .doc('identificacao')
      .set({'cpf': '41850372608', 'dataNascimento': '2010-05-12'});
  await db
      .collection('pacientes')
      .doc(_pidAna)
      .collection('agendamentos')
      .doc('ad1')
      .set({
        'id': 'ad1',
        'pacienteId': _pidAna,
        'profissionalId': 'd0000000-0000-4000-8000-000000000001',
        'dataHora': '2026-10-07T18:00:00.000Z',
        'motivoRetorno': 'Retorno',
        'situacao': 'agendado',
      });
  await db
      .collection('pacientes')
      .doc(_pidAna)
      .collection('registros')
      .doc('dd1')
      .set({
        'id': 'dd1',
        'pacienteId': _pidAna,
        'registradoEm': '2026-10-01T00:40:00.000Z',
        'adesao': 'total',
        'intensidade': 'leve',
        'sintomaPredominante': 'Cansaço',
        'observacao': null,
        'situacaoEnvio': 'enviado',
        'atualizadoEm': null,
        'excluidoEm': null,
      });
  await db.collection('pacientes').doc(_pidJoao).set({
    'id': _pidJoao,
    'contaId': null,
    'profissionalRefId': 'd0000000-0000-4000-8000-000000000001',
    'nome': 'João Pedro Assis',
    'ativo': true,
    'cuidadoresAtivos': <String>[],
  });
  await db.collection('convites').doc(_codigoJoao).set({
    'id': 'e0000000-0000-4000-8000-000000000007',
    'codigo': _codigoJoao,
    'pacienteId': _pidJoao,
    'tipo': 'paciente',
    'cpfHash': hashDoConvite(_codigoJoao, _cpfJoao),
    'nascimentoHash': hashDoConvite(_codigoJoao, _nascimentoJoao.paraIso()),
    'expiraEm': '2026-10-14T03:59:00.000Z',
    'usadoEm': null,
    'revogado': false,
    'nomePaciente': 'João Pedro Assis',
    'pacienteAtivo': true,
  });
}

void main() {
  test('o hash do convite é o mesmo da semente em Node', () {
    // node -e "crypto.createHash('sha256').update('K7M4QX:58304921642')…"
    expect(
      hashDoConvite(_codigoJoao, _cpfJoao),
      'c4c7acf636cdcedb23b0237966509e560e66303fd68389887d2b79c15c02b2d3',
    );
  });

  group('entrar, sessão guardada e sair (D14, D16, D20)', () {
    late Montagem m;
    late RepositorioAutenticacao auth;

    setUp(() async {
      m = await montar(
        auth: MockFirebaseAuth(
          mockUser: MockUser(
            uid: _uidAna,
            email: 'ana.lucia.martins@exemplo.test',
          ),
        ),
      );
      await _semear(m);
      auth = m.persistencia.repositorios.autenticacao;
    });

    test(
      'entrar devolve os vínculos com a cópia completa do titular',
      () async {
        final v = await auth.entrar(
          email: 'Ana.Lucia.Martins@exemplo.test',
          senha: 'senha-de-teste',
        );
        expect(v.conta.id, _uidAna);
        expect(v.pacientes.single.cpf, '41850372608');
        expect(v.acompanhados, isEmpty);
        final conta = await m.firestore.collection('contas').doc(_uidAna).get();
        expect(conta.data()!['ultimoAcessoEm'], isNotNull);
      },
    );

    test('entrar já traz o histórico do servidor para o SQLite', () async {
      await auth.entrar(
        email: 'ana.lucia.martins@exemplo.test',
        senha: 'senha-de-teste',
      );
      // Só espera a sincronização que a própria entrada dispara (sem chamar
      // sincronizar aqui, que buscaria o servidor por conta própria).
      final diario = m.persistencia.repositorios.diario;
      var ids = <String>[];
      for (var i = 0; i < 100 && !ids.contains('dd1'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        ids = [for (final r in await diario.registros(_pidAna)) r.id];
      }
      expect(ids, contains('dd1'));
    });

    test('sem conexão, entrar recusa semConexao', () async {
      await m.conexao.desligar();
      await expectLater(
        auth.entrar(email: 'ana.lucia.martins@exemplo.test', senha: 'x'),
        _recusa(MotivoRecusa.semConexao),
      );
    });

    test('a sessão guardada reabre sem conexão pela cópia local', () async {
      await auth.entrar(
        email: 'ana.lucia.martins@exemplo.test',
        senha: 'senha-de-teste',
      );
      await m.conexao.desligar();
      final guardada = await auth.sessaoGuardada();
      expect(guardada!.pacientes.single.id, _pidAna);
    });

    test(
      'sair encerra o Firebase e apaga o SQLite e as preferências',
      () async {
        await auth.entrar(
          email: 'ana.lucia.martins@exemplo.test',
          senha: 'senha-de-teste',
        );
        m.persistencia.preferencias.guardarPerfil('pacienteFamilia:$_pidAna');
        await auth.sair();
        expect(m.auth.currentUser, isNull);
        expect(m.persistencia.preferencias.perfilAtivo, isNull);
        final linhas = await m.persistencia.banco.db.query('cache_documentos');
        expect(linhas, isEmpty);
        expect(await auth.sessaoGuardada(), isNull);
      },
    );

    test('leitura com cópia: online guarda, offline lê do SQLite', () async {
      final paciente = m.persistencia.repositorios.paciente;
      await m.conexao.desligar();
      await expectLater(
        paciente.agendamentos(_pidAna),
        _recusa(MotivoRecusa.semConexao),
        reason: 'sem cópia e sem conexão',
      );
      await m.conexao.ligar();
      expect(await paciente.agendamentos(_pidAna), hasLength(1));
      await m.conexao.desligar();
      final offline = await paciente.agendamentos(_pidAna);
      expect(offline.single.motivoRetorno, 'Retorno');
    });
  });

  group('primeiro acesso com o código da clínica (TM09, D14)', () {
    late Montagem m;
    late RepositorioAutenticacao auth;

    setUp(() async {
      m = await montar(auth: MockFirebaseAuth());
      await _semear(m);
      auth = m.persistencia.repositorios.autenticacao;
    });

    test('confere CPF e nascimento pelo hash do convite', () async {
      final ok = await auth.conferirCodigoPaciente(
        codigo: 'k7m-4qx',
        cpf: '583.049.216-42',
        dataNascimento: _nascimentoJoao,
      );
      expect(ok.nomePaciente, 'João Pedro Assis');
      await expectLater(
        auth.conferirCodigoPaciente(
          codigo: _codigoJoao,
          cpf: '41850372608',
          dataNascimento: _nascimentoJoao,
        ),
        _recusa(MotivoRecusa.cpfNaoConfere),
      );
      await expectLater(
        auth.conferirCodigoPaciente(
          codigo: _codigoJoao,
          cpf: _cpfJoao,
          dataNascimento: DataCivil(1999, 7, 20),
        ),
        _recusa(MotivoRecusa.nascimentoNaoConfere),
      );
      await expectLater(
        auth.conferirCodigoPaciente(
          codigo: 'ZZZZZZ',
          cpf: _cpfJoao,
          dataNascimento: _nascimentoJoao,
        ),
        _recusa(MotivoRecusa.codigoInexistente),
      );
    });

    test('ativar cria a conta, liga o paciente, grava o consentimento e '
        'encerra o código', () async {
      final v = await auth.ativarPaciente(
        codigo: _codigoJoao,
        cpf: _cpfJoao,
        dataNascimento: _nascimentoJoao,
        qualidade: QualidadeConsentimento.titular,
        canalAutorizado: CanalAutorizado.aplicativo,
        versaoTermo: '1.0',
        acesso: const NovoAcesso(
          nome: 'João Pedro Assis',
          email: 'Joao.Pedro.Assis@exemplo.test',
          senha: 'senha-de-teste',
        ),
      );
      final uid = m.auth.currentUser!.uid;
      expect(v.conta.id, uid);
      expect(v.conta.email, 'joao.pedro.assis@exemplo.test');
      expect(v.pacientes.single.id, _pidJoao);
      final paciente = await m.firestore
          .collection('pacientes')
          .doc(_pidJoao)
          .get();
      expect(paciente.data()!['contaId'], uid);
      final convite = await m.firestore
          .collection('convites')
          .doc(_codigoJoao)
          .get();
      expect(convite.data()!['usadoEm'], isNotNull);
      final consentimentos = await m.firestore
          .collection('consentimentos')
          .get();
      expect(consentimentos.docs.single.data()['contaId'], uid);

      await expectLater(
        auth.conferirCodigoPaciente(
          codigo: _codigoJoao,
          cpf: _cpfJoao,
          dataNascimento: _nascimentoJoao,
        ),
        _recusa(MotivoRecusa.codigoJaUsado),
      );
    });

    test(
      'senha curta e e-mail mal formado recusam antes do Firebase',
      () async {
        Future<void> ativar(NovoAcesso acesso) => auth.ativarPaciente(
          codigo: _codigoJoao,
          cpf: _cpfJoao,
          dataNascimento: _nascimentoJoao,
          qualidade: QualidadeConsentimento.titular,
          canalAutorizado: CanalAutorizado.aplicativo,
          versaoTermo: '1.0',
          acesso: acesso,
        );
        await expectLater(
          ativar(
            const NovoAcesso(nome: 'J', email: 'joao', senha: 'teste-ok-1'),
          ),
          _recusa(MotivoRecusa.emailInvalido),
        );
        await expectLater(
          ativar(
            const NovoAcesso(
              nome: 'J',
              email: 'j@exemplo.test',
              senha: 'curta',
            ),
          ),
          _recusa(MotivoRecusa.senhaFraca),
        );
        expect(m.auth.currentUser, isNull);
      },
    );
  });
}
