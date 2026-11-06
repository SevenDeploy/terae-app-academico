import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/situacao_conta.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';
import 'package:terae_app/nucleo/validacao/cpf.dart';

import 'memoria_apoio.dart';

Future<VinculosDaConta> _ativarJoao(
  MemoriaDemonstracao m, {
  String codigo = codigoJoao,
  String versaoTermo = '1.0',
  NovoAcesso? identidade,
}) => m.repositorios.autenticacao.ativarPaciente(
  codigo: codigo,
  cpf: formatarCpf(cpfJoao),
  dataNascimento: nascimentoJoao,
  qualidade: QualidadeConsentimento.titular,
  canalAutorizado: CanalAutorizado.aplicativo,
  versaoTermo: versaoTermo,
  acesso: identidade ?? identidadeDe(m, 'João Pedro Assis'),
);

/// Acrescenta ao cenário um código da clínica (tipo paciente) ainda não usado.
String _novoCodigoDaClinica(
  Map<String, Object?> dados, {
  required String pacienteId,
  required String cpf,
  required String codigo,
}) {
  colecao(dados, 'convites').add({
    'id': gerarUuidV4(),
    'pacienteId': pacienteId,
    'codigo': codigo,
    'tipo': 'paciente',
    'cpfConvidado': cpf,
    'expiraEm': {'emDias': 10, 'hora': '23:59'},
    'usadoEm': null,
  });
  return codigo;
}

void main() {
  group('entrar (RFM01, TM01)', () {
    test(
      'e-mail sem conta ou senha errada: credenciaisInvalidas (D14)',
      () async {
        final m = memoriaDeTeste();
        final auth = m.repositorios.autenticacao;
        final ana = identidadeDe(m, 'Ana Lúcia Martins');
        await recusaSemGravar(
          m,
          () => auth.entrar(email: ana.email, senha: '${ana.senha}-errada'),
          MotivoRecusa.credenciaisInvalidas,
        );
        await recusaSemGravar(
          m,
          () => auth.entrarCom(identidadeNova),
          MotivoRecusa.credenciaisInvalidas,
        );
        // E-mail com maiúscula e espaço entra igual.
        final v = await auth.entrar(
          email: '  ${ana.email.toUpperCase()} ',
          senha: ana.senha,
        );
        expect(v.conta.id, contaAna);
      },
    );

    test('a memória não guarda sessão entre aberturas', () async {
      final m = memoriaDeTeste();
      expect(await m.repositorios.autenticacao.sessaoGuardada(), isNull);
    });

    test('Ana: um perfil paciente/família, cópia completa', () async {
      final m = memoriaDeTeste();
      final v = await m.repositorios.autenticacao.entrarCom(
        identidadeDe(m, 'Ana Lúcia Martins'),
      );
      expect(v.conta.id, contaAna);
      expect(v.pacientes.single.id, idAna);
      expect(v.pacientes.single.cpf, cpfAna);
      expect(v.acompanhados, isEmpty);
      expect(v.conta.ultimoAcessoEm, agoraDaMemoria);
      expect(m.estado.contas[contaAna]!.ultimoAcessoEm, agoraDaMemoria);
    });

    test(
      'Patrícia: dois perfis (Miguel e Laura) → seleção de perfil',
      () async {
        final m = memoriaDeTeste();
        final v = await m.repositorios.autenticacao.entrarCom(
          identidadeDe(m, 'Patrícia Andrade Neves'),
        );
        expect(v.pacientes.map((p) => p.id), [idMiguel, idLaura]);
        final sessao = Sessao()..entrar(v);
        expect(sessao.temVariosPerfis, isTrue);
        expect(sessao.perfilAtivo, isNull);
      },
    );

    test('Regina: perfil cuidador com a cópia sem CPF e nascimento', () async {
      final m = memoriaDeTeste();
      final v = await m.repositorios.autenticacao.entrarCom(
        identidadeDe(m, 'Regina Martins'),
      );
      expect(v.pacientes, isEmpty);
      final ana = v.acompanhados.single;
      expect(ana.id, idAna);
      expect(ana.cpf, isNull);
      expect(ana.dataNascimento, isNull);
      expect(ana.contaId, isNull);
      final sessao = Sessao()..entrar(v);
      expect(sessao.perfilAtivo!.papel, Papel.cuidador);
    });

    test(
      'sem conta: credenciaisInvalidas; sem vínculo ativo: contaSemAcesso',
      () async {
        final m = memoriaDeTeste();
        final auth = m.repositorios.autenticacao;
        await recusaSemGravar(
          m,
          () => auth.entrarCom(identidadeDe(m, 'João Pedro Assis')),
          MotivoRecusa.credenciaisInvalidas,
        );
        await m.repositorios.cuidadores.revogar(vinculoRegina);
        await recusaSemGravar(
          m,
          () => auth.entrarCom(identidadeDe(m, 'Regina Martins')),
          MotivoRecusa.contaSemAcesso,
        );
      },
    );

    test('paciente inativo não dá perfil', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idAna)['ativo'] = false;
      final m = memoriaDeTeste(dados: dados);
      await recusaSemGravar(
        m,
        () => m.repositorios.autenticacao.entrarCom(
          identidadeDe(m, 'Ana Lúcia Martins'),
        ),
        MotivoRecusa.contaSemAcesso,
      );
    });

    test('conta inativa: contaInativa', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'contas', contaRegina)['situacao'] = 'inativa';
      final m = memoriaDeTeste(dados: dados);
      await recusaSemGravar(
        m,
        () => m.repositorios.autenticacao.entrarCom(
          identidadeDe(m, 'Regina Martins'),
        ),
        MotivoRecusa.contaInativa,
      );
    });
  });

  group('ativação do paciente (RFM09, TM09)', () {
    test('confere código, CPF e nascimento sem consumir o código', () async {
      final m = memoriaDeTeste();
      final auth = m.repositorios.autenticacao;
      final antes = m.estado.paraMapa();
      final conferido = await auth.conferirCodigoPaciente(
        codigo: ' k7m4qx ',
        cpf: formatarCpf(cpfJoao),
        dataNascimento: nascimentoJoao,
      );
      expect(conferido.nomePaciente, 'João Pedro Assis');
      expect(conferido.convite.codigo, codigoJoao);
      expect(conferido.convite.usadoEm, isNull);
      expect(m.estado.paraMapa(), antes);
    });

    test('recusas do passo 1, cada uma com o motivo certo', () async {
      final dados = dadosDaDemonstracao();
      final codigoInativo = _novoCodigoDaClinica(
        dados,
        pacienteId: idLaura,
        cpf: _cpfNoCenario(dados, idLaura),
        codigo: 'W7N3KD',
      );
      itemDe(dados, 'pacientes', idLaura)['ativo'] = false;
      final m = memoriaDeTeste(dados: dados);
      final auth = m.repositorios.autenticacao;
      Future<ConviteConferido> conferir(
        String codigo, {
        String cpf = cpfJoao,
        DataCivil? nascimento,
      }) => auth.conferirCodigoPaciente(
        codigo: codigo,
        cpf: cpf,
        dataNascimento: nascimento ?? nascimentoJoao,
      );

      final casos = <MotivoRecusa, Future<ConviteConferido> Function()>{
        MotivoRecusa.codigoInexistente: () => conferir('ZZZZZZ'),
        MotivoRecusa.tipoDeCodigoErrado: () => conferir(codigoPaulo),
        MotivoRecusa.codigoJaUsado: () => conferir(codigoAnaUsado, cpf: cpfAna),
        MotivoRecusa.codigoExpirado: () => conferir(codigoJoaoExpirado),
        MotivoRecusa.cpfInvalido: () =>
            conferir(codigoJoao, cpf: '583.049.216-43'),
        MotivoRecusa.cpfNaoConfere: () =>
            conferir(codigoJoao, cpf: cpfsLivres.first),
        MotivoRecusa.nascimentoNaoConfere: () =>
            conferir(codigoJoao, nascimento: DataCivil(1999, 7, 20)),
        MotivoRecusa.pacienteInativo: () => conferir(
          codigoInativo,
          cpf: m.estado.pacientes[idLaura]!.cpf!,
          nascimento: m.estado.pacientes[idLaura]!.dataNascimento,
        ),
      };
      for (final caso in casos.entries) {
        await recusaSemGravar(m, caso.value, caso.key);
      }
    });

    test('usado também quando ainda está na validade', () async {
      final m = memoriaDeTeste();
      final laura = m.estado.pacientes[idLaura]!;
      expect(
        m.estado
            .conviteDoCodigo(codigoLauraUsado)!
            .expiraEm
            .isAfter(agoraDaMemoria),
        isTrue,
      );
      await recusaSemGravar(
        m,
        () => m.repositorios.autenticacao.conferirCodigoPaciente(
          codigo: codigoLauraUsado,
          cpf: laura.cpf!,
          dataNascimento: laura.dataNascimento!,
        ),
        MotivoRecusa.codigoJaUsado,
      );
    });

    test('ativar: cria a conta, liga o paciente, grava o consentimento e '
        'encerra o código', () async {
      final m = memoriaDeTeste();
      final identidade = identidadeDe(m, 'João Pedro Assis');
      final v = await _ativarJoao(m, versaoTermo: '1.0');

      final conta = v.conta;
      expect(conta.idProvedor, conta.id, reason: 'uid do provedor');
      expect(conta.email, identidade.email);
      expect(conta.nomeExibicao, identidade.nome);
      expect(m.estado.senhas[conta.id], identidade.senha);
      expect(conta.situacao, SituacaoConta.ativa);
      expect(conta.ultimoAcessoEm, agoraDaMemoria);
      expect(uuidV4Valido(conta.id), isTrue);
      expect(m.estado.contas[conta.id], conta);

      expect(v.pacientes.single.id, idJoao);
      expect(m.estado.pacientes[idJoao]!.contaId, conta.id);

      final consentimento = m.estado.consentimentos.values.singleWhere(
        (c) => c.pacienteId == idJoao,
      );
      expect(consentimento.contaId, conta.id);
      expect(consentimento.qualidade, QualidadeConsentimento.titular);
      expect(consentimento.canalAutorizado, CanalAutorizado.aplicativo);
      expect(consentimento.versaoTermo, '1.0');
      expect(consentimento.aceitoEm, agoraDaMemoria);
      expect(consentimento.revogadoEm, isNull);

      expect(m.estado.conviteDoCodigo(codigoJoao)!.usadoEm, agoraDaMemoria);

      // Uso único: o mesmo código não serve de novo.
      await recusaSemGravar(
        m,
        () => _ativarJoao(m, identidade: identidadeNova),
        MotivoRecusa.codigoJaUsado,
      );
      // E a conta agora entra pelo TM01.
      final entrou = await m.repositorios.autenticacao.entrarCom(identidade);
      expect(entrou.pacientes.single.id, idJoao);
    });

    test('responsável legal: grava a qualidade informada', () async {
      final dados = dadosDaDemonstracao();
      final miguel = itemDe(dados, 'pacientes', idMiguel);
      final codigo = _novoCodigoDaClinica(
        dados,
        pacienteId: idMiguel,
        cpf: miguel['cpf']! as String,
        codigo: 'T5Q8MV',
      );
      final m = memoriaDeTeste(dados: dados);
      await m.repositorios.autenticacao.ativarPaciente(
        codigo: codigo,
        cpf: miguel['cpf']! as String,
        dataNascimento: DataCivil.parse(miguel['dataNascimento']! as String),
        qualidade: QualidadeConsentimento.responsavelLegal,
        canalAutorizado: CanalAutorizado.impresso,
        versaoTermo: '1.1',
        acesso: identidadeDe(m, 'Patrícia Andrade Neves'),
      );
      final ultimo = m.estado.consentimentos.values.last;
      expect(ultimo.qualidade, QualidadeConsentimento.responsavelLegal);
      expect(ultimo.canalAutorizado, CanalAutorizado.impresso);
      expect(ultimo.contaId, contaPatricia);
    });

    test('reaproveita a conta do mesmo e-mail com a mesma senha', () async {
      final dados = dadosDaDemonstracao();
      _novoCodigoDaClinica(
        dados,
        pacienteId: idJoao,
        cpf: cpfJoao,
        codigo: 'N8V2QH',
      );
      final m = memoriaDeTeste(dados: dados);
      final contas = m.estado.contas.length;
      final v = await _ativarJoao(
        m,
        codigo: 'N8V2QH',
        identidade: identidadeDe(m, 'Regina Martins'),
      );
      expect(v.conta.id, contaRegina);
      expect(m.estado.contas, hasLength(contas));
      expect(v.pacientes.single.id, idJoao);
      expect(v.acompanhados.single.id, idAna, reason: 'vínculos de antes');
      expect(Sessao.perfisDe(v), hasLength(2));
    });

    test('termo novo gera registro novo; o anterior fica como está', () async {
      final dados = dadosDaDemonstracao();
      final original = memoriaDeTeste(dados: dados);
      final anterior = original.estado.consentimentos.values.singleWhere(
        (c) => c.pacienteId == idAna,
      );
      _novoCodigoDaClinica(
        dados,
        pacienteId: idAna,
        cpf: cpfAna,
        codigo: 'Y3K7PB',
      );
      final m = memoriaDeTeste(dados: dados);
      await m.repositorios.autenticacao.ativarPaciente(
        codigo: 'Y3K7PB',
        cpf: cpfAna,
        dataNascimento: DataCivil(2010, 5, 12),
        qualidade: QualidadeConsentimento.titular,
        canalAutorizado: CanalAutorizado.email,
        versaoTermo: '2.0',
        acesso: identidadeDe(m, 'Ana Lúcia Martins'),
      );
      final daAna = m.estado.consentimentos.values
          .where((c) => c.pacienteId == idAna)
          .toList();
      expect(daAna, hasLength(2));
      expect(daAna.first, anterior);
      expect(daAna.last.versaoTermo, '2.0');
      expect(daAna.last.id, isNot(anterior.id));
      expect(m.estado.pacientes[idAna]!.contaId, contaAna);
    });

    test('paciente inativo não ativa e nada é gravado', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idJoao)['ativo'] = false;
      final m = memoriaDeTeste(dados: dados);
      await recusaSemGravar(
        m,
        () => _ativarJoao(m),
        MotivoRecusa.pacienteInativo,
      );
    });

    test(
      'ativar confere de novo: código que venceu depois do passo 1',
      () async {
        final relogio = RelogioFixo(agoraDaMemoria);
        final m = memoriaDeTeste(relogio: relogio);
        await m.repositorios.autenticacao.conferirCodigoPaciente(
          codigo: codigoJoao,
          cpf: cpfJoao,
          dataNascimento: nascimentoJoao,
        );
        relogio.avancar(const Duration(days: 13));
        await recusaSemGravar(
          m,
          () => _ativarJoao(m),
          MotivoRecusa.codigoExpirado,
        );
      },
    );

    test('e-mail já usado com outra senha: emailJaCadastrado (D14)', () async {
      final m = memoriaDeTeste();
      final regina = identidadeDe(m, 'Regina Martins');
      await recusaSemGravar(
        m,
        () => _ativarJoao(
          m,
          identidade: NovoAcesso(
            nome: 'João',
            email: regina.email,
            senha: '${regina.senha}-outra',
          ),
        ),
        MotivoRecusa.emailJaCadastrado,
      );
    });

    test('e-mail mal formado e senha curta recusam sem gravar (D14)', () async {
      final m = memoriaDeTeste();
      final joao = identidadeDe(m, 'João Pedro Assis');
      await recusaSemGravar(
        m,
        () => _ativarJoao(
          m,
          identidade: NovoAcesso(
            nome: joao.nome,
            email: 'joao.sem.arroba',
            senha: joao.senha,
          ),
        ),
        MotivoRecusa.emailInvalido,
      );
      await recusaSemGravar(
        m,
        () => _ativarJoao(
          m,
          identidade: NovoAcesso(
            nome: joao.nome,
            email: joao.email,
            senha: joao.senha.substring(0, tamanhoMinimoDaSenha - 1),
          ),
        ),
        MotivoRecusa.senhaFraca,
      );
    });

    test('conta inativa do mesmo e-mail não ativa', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'contas', contaRegina)['situacao'] = 'inativa';
      final m = memoriaDeTeste(dados: dados);
      await recusaSemGravar(
        m,
        () => _ativarJoao(m, identidade: identidadeDe(m, 'Regina Martins')),
        MotivoRecusa.contaInativa,
      );
    });
  });

  group(
    'criança só pelo responsável legal (ECA art. 2º; LGPD art. 14 § 1º)',
    () {
      /// Ativa João (código da clínica válido) com o nascimento trocado para
      /// [nascimento] no cenário e a [qualidade] pedida.
      Future<VinculosDaConta> ativarJoaoNascidoEm(
        DataCivil nascimento, {
        required QualidadeConsentimento qualidade,
        RelogioFixo? relogio,
      }) {
        final dados = dadosDaDemonstracao();
        itemDe(dados, 'pacientes', idJoao)['dataNascimento'] = nascimento
            .paraIso();
        final m = memoriaDeTeste(dados: dados, relogio: relogio);
        return m.repositorios.autenticacao.ativarPaciente(
          codigo: codigoJoao,
          cpf: cpfJoao,
          dataNascimento: nascimento,
          qualidade: qualidade,
          canalAutorizado: CanalAutorizado.aplicativo,
          versaoTermo: '1.0',
          acesso: identidadeNova,
        );
      }

      test('Miguel (7 anos) como titular recusa sem gravar; pelo responsável '
          'legal ativa com o mesmo código', () async {
        final dados = dadosDaDemonstracao();
        final miguel = itemDe(dados, 'pacientes', idMiguel);
        final codigo = _novoCodigoDaClinica(
          dados,
          pacienteId: idMiguel,
          cpf: miguel['cpf']! as String,
          codigo: 'T5Q8MV',
        );
        final m = memoriaDeTeste(dados: dados);
        Future<VinculosDaConta> ativar(QualidadeConsentimento qualidade) =>
            m.repositorios.autenticacao.ativarPaciente(
              codigo: codigo,
              cpf: miguel['cpf']! as String,
              dataNascimento: DataCivil.parse(
                miguel['dataNascimento']! as String,
              ),
              qualidade: qualidade,
              canalAutorizado: CanalAutorizado.aplicativo,
              versaoTermo: '1.0',
              acesso: identidadeNova,
            );

        await recusaSemGravar(
          m,
          () => ativar(QualidadeConsentimento.titular),
          MotivoRecusa.criancaComoTitular,
        );
        final v = await ativar(QualidadeConsentimento.responsavelLegal);
        expect(v.pacientes.single.id, idMiguel);
        expect(
          m.estado.consentimentos.values.last.qualidade,
          QualidadeConsentimento.responsavelLegal,
        );
      });

      test(
        '12 anos completos no dia do aniversário: pode ser titular',
        () async {
          final v = await ativarJoaoNascidoEm(
            DataCivil(2014, 10, 2),
            qualidade: QualidadeConsentimento.titular,
          );
          expect(v.pacientes.single.id, idJoao);
        },
      );

      test('11 anos e 364 dias: ainda é criança, não é titular', () async {
        await expectLater(
          ativarJoaoNascidoEm(
            DataCivil(2014, 10, 3),
            qualidade: QualidadeConsentimento.titular,
          ),
          recusa(MotivoRecusa.criancaComoTitular),
        );
        final v = await ativarJoaoNascidoEm(
          DataCivil(2014, 10, 3),
          qualidade: QualidadeConsentimento.responsavelLegal,
        );
        expect(v.pacientes.single.id, idJoao);
      });

      test('"hoje" é o dia da clínica: 23h de 1/10 em Cuiabá (03h de 2/10 '
          'UTC) ainda não completa 12', () async {
        await expectLater(
          ativarJoaoNascidoEm(
            DataCivil(2014, 10, 2),
            qualidade: QualidadeConsentimento.titular,
            relogio: RelogioFixo(DateTime.utc(2026, 10, 2, 3)),
          ),
          recusa(MotivoRecusa.criancaComoTitular),
        );
      });

      test(
        'adolescente (12–17) e adulto escolhem titular ou responsável',
        () async {
          for (final nascimento in [DataCivil(2010, 5, 12), nascimentoJoao]) {
            for (final qualidade in QualidadeConsentimento.values) {
              final v = await ativarJoaoNascidoEm(
                nascimento,
                qualidade: qualidade,
              );
              expect(v.pacientes.single.id, idJoao, reason: '$nascimento');
            }
          }
        },
      );
    },
  );

  group('convite do cuidador (RFM09, TM10)', () {
    test('confere código e CPF sem consumir', () async {
      final m = memoriaDeTeste();
      final antes = m.estado.paraMapa();
      final conferido = await m.repositorios.autenticacao
          .conferirConviteCuidador(
            codigo: 'p4x9rc',
            cpf: formatarCpf(cpfPaulo),
          );
      expect(conferido.nomePaciente, 'Ana Lúcia Martins');
      expect(conferido.convite.codigo, codigoPaulo);
      expect(m.estado.paraMapa(), antes);
    });

    test('recusas: inexistente, tipo, usado, expirado, CPF', () async {
      final relogio = RelogioFixo(agoraDaMemoria);
      final m = memoriaDeTeste(relogio: relogio);
      final auth = m.repositorios.autenticacao;
      Future<ConviteConferido> conferir(String codigo, String cpf) =>
          auth.conferirConviteCuidador(codigo: codigo, cpf: cpf);

      await recusaSemGravar(
        m,
        () => conferir('ZZZZZZ', cpfPaulo),
        MotivoRecusa.codigoInexistente,
      );
      await recusaSemGravar(
        m,
        () => conferir(codigoJoao, cpfJoao),
        MotivoRecusa.tipoDeCodigoErrado,
      );
      await recusaSemGravar(
        m,
        () => conferir(codigoReginaUsado, cpfRegina),
        MotivoRecusa.codigoJaUsado,
      );
      await recusaSemGravar(
        m,
        () => conferir(codigoPaulo, '847.120.563-70'),
        MotivoRecusa.cpfInvalido,
      );
      await recusaSemGravar(
        m,
        () => conferir(codigoPaulo, cpfRegina),
        MotivoRecusa.cpfNaoConfere,
      );
      relogio.avancar(const Duration(days: 6));
      await recusaSemGravar(
        m,
        () => conferir(codigoPaulo, cpfPaulo),
        MotivoRecusa.codigoExpirado,
      );
      await recusaSemGravar(
        m,
        () => auth.aceitarConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
          acesso: identidadeDe(m, 'Paulo Martins'),
        ),
        MotivoRecusa.codigoExpirado,
      );
    });

    test(
      'aceitar: vínculo ativo com conta e data; o código se encerra',
      () async {
        final m = memoriaDeTeste();
        final auth = m.repositorios.autenticacao;
        final paulo = identidadeDe(m, 'Paulo Martins');
        final v = await auth.aceitarConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
          acesso: paulo,
        );
        expect(v.conta.email, paulo.email);
        expect(v.pacientes, isEmpty);
        final ana = v.acompanhados.single;
        expect(ana.id, idAna);
        expect(ana.cpf, isNull);
        expect(ana.dataNascimento, isNull);

        final vinculo = m.estado.vinculos[vinculoPaulo]!;
        expect(vinculo.situacao, SituacaoVinculo.ativo);
        expect(vinculo.contaCuidadorId, v.conta.id);
        expect(vinculo.autorizadoEm, agoraDaMemoria);
        expect(m.estado.conviteDoCodigo(codigoPaulo)!.usadoEm, agoraDaMemoria);
        expect(m.estado.vinculosNoLimite(idAna, agora: agoraDaMemoria), 2);

        await recusaSemGravar(
          m,
          () => auth.aceitarConviteCuidador(
            codigo: codigoPaulo,
            cpf: cpfPaulo,
            acesso: paulo,
          ),
          MotivoRecusa.codigoJaUsado,
        );
        expect((await auth.entrarCom(paulo)).acompanhados.single.id, idAna);
      },
    );

    test('revogar o convite em aberto invalida o código, sem apagar', () async {
      final m = memoriaDeTeste();
      final auth = m.repositorios.autenticacao;
      final convite = m.estado.conviteDoCodigo(codigoPaulo)!;
      await m.repositorios.cuidadores.revogar(vinculoPaulo);

      await recusaSemGravar(
        m,
        () => auth.conferirConviteCuidador(codigo: codigoPaulo, cpf: cpfPaulo),
        MotivoRecusa.conviteRevogado,
      );
      await recusaSemGravar(
        m,
        () => auth.aceitarConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
          acesso: identidadeDe(m, 'Paulo Martins'),
        ),
        MotivoRecusa.conviteRevogado,
      );
      expect(m.estado.convites[convite.id], convite, reason: 'nada apagado');
      final vinculo = m.estado.vinculos[vinculoPaulo]!;
      expect(vinculo.situacao, SituacaoVinculo.revogado);
      expect(vinculo.revogadoEm, agoraDaMemoria);
    });

    test('revogado e vencido: a revogação explica melhor', () async {
      final relogio = RelogioFixo(agoraDaMemoria);
      final m = memoriaDeTeste(relogio: relogio);
      await m.repositorios.cuidadores.revogar(vinculoPaulo);
      relogio.avancar(const Duration(days: 30));
      await recusaSemGravar(
        m,
        () => m.repositorios.autenticacao.conferirConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
        ),
        MotivoRecusa.conviteRevogado,
      );
    });

    test('limite conferido de novo no aceite (§23)', () async {
      // Cenário de corrida: um terceiro convite em aberto entrou na Ana.
      final dados = dadosDaDemonstracao();
      final conviteExtra = gerarUuidV4();
      final vinculoExtra = gerarUuidV4();
      colecao(dados, 'convites').add({
        'id': conviteExtra,
        'pacienteId': idAna,
        'codigo': 'C9H4XW',
        'tipo': 'cuidador',
        'cpfConvidado': cpfsLivres[1],
        'expiraEm': {'emDias': 7, 'hora': '10:00'},
        'usadoEm': null,
      });
      colecao(dados, 'vinculos').add({
        'id': vinculoExtra,
        'pacienteId': idAna,
        'contaCuidadorId': null,
        'conviteId': conviteExtra,
        'nome': 'Terceira Pessoa',
        'situacao': 'pendente',
        'autorizadoEm': null,
        'revogadoEm': null,
      });
      final m = memoriaDeTeste(dados: dados);
      final auth = m.repositorios.autenticacao;
      expect(m.estado.vinculosNoLimite(idAna, agora: agoraDaMemoria), 3);

      await recusaSemGravar(
        m,
        () => auth.aceitarConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
          acesso: identidadeDe(m, 'Paulo Martins'),
        ),
        MotivoRecusa.limiteDeCuidadores,
      );

      await m.repositorios.cuidadores.revogar(vinculoExtra);
      final v = await auth.aceitarConviteCuidador(
        codigo: codigoPaulo,
        cpf: cpfPaulo,
        acesso: identidadeDe(m, 'Paulo Martins'),
      );
      expect(v.acompanhados.single.id, idAna);
    });
  });
}

/// CPF do paciente [id] no mapa do cenário.
String _cpfNoCenario(Map<String, Object?> dados, String id) =>
    itemDe(dados, 'pacientes', id)['cpf']! as String;
