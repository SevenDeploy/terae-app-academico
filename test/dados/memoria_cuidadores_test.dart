import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/memoria/regras.dart';
import 'package:terae_app/dados/repositorios/cuidadores_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';
import 'package:terae_app/nucleo/validacao/cpf.dart';

import 'memoria_apoio.dart';

int _noLimite(List<CuidadorAutorizado> lista) =>
    lista.where((c) => c.contaNoLimite(agoraDaMemoria)).length;

void main() {
  test('lista da Ana: Paulo (pendente) e Regina (ativa), mais recente '
      'primeiro, com o convite de cada um', () async {
    final m = memoriaDeTeste();
    final lista = await m.repositorios.cuidadores.cuidadores(idAna);
    expect(lista.map((c) => c.vinculo.nome), [
      'Paulo Martins',
      'Regina Martins',
    ]);
    expect(lista.first.vinculo.situacao, SituacaoVinculo.pendente);
    expect(lista.first.convite.codigo, codigoPaulo);
    expect(lista.last.vinculo.situacao, SituacaoVinculo.ativo);
    expect(_noLimite(lista), limiteCuidadores);
  });

  group('limite de dois, contando pendentes e ativos (§7.4)', () {
    test('2/2 com um pendente: convidar recusa e não grava', () async {
      final m = memoriaDeTeste();
      await recusaSemGravar(
        m,
        () => m.repositorios.cuidadores.convidar(
          pacienteId: idAna,
          nome: 'Avó Martins',
          cpf: cpfsLivres.first,
        ),
        MotivoRecusa.limiteDeCuidadores,
      );
    });

    test('revogar libera a vaga; o convite novo nasce pendente', () async {
      final m = memoriaDeTeste();
      final repo = m.repositorios.cuidadores;
      await repo.revogar(vinculoPaulo);
      expect(_noLimite(await repo.cuidadores(idAna)), 1);

      final novo = await repo.convidar(
        pacienteId: idAna,
        nome: '  Avó Martins  ',
        cpf: formatarCpf(cpfsLivres.first),
      );
      expect(novo.vinculo.nome, 'Avó Martins');
      expect(novo.vinculo.situacao, SituacaoVinculo.pendente);
      expect(novo.vinculo.contaCuidadorId, isNull);
      expect(novo.vinculo.autorizadoEm, isNull);
      expect(novo.vinculo.conviteId, novo.convite.id);
      expect(uuidV4Valido(novo.vinculo.id), isTrue);
      expect(novo.convite.tipo, TipoConvite.cuidador);
      expect(novo.convite.pacienteId, idAna);
      expect(novo.convite.cpfConvidado, cpfsLivres.first);
      expect(codigoBemFormado(novo.convite.codigo), isTrue);
      expect(
        novo.convite.expiraEm,
        agoraDaMemoria.add(validadeDoConviteCuidador),
      );
      expect(novo.convite.usadoEm, isNull);

      final lista = await repo.cuidadores(idAna);
      expect(lista.first.vinculo.id, novo.vinculo.id);
      expect(_noLimite(lista), 2);
      expect(lista, hasLength(3), reason: 'o revogado continua na lista');

      await recusaSemGravar(
        m,
        () => repo.convidar(
          pacienteId: idAna,
          nome: 'Mais Alguém',
          cpf: cpfsLivres[1],
        ),
        MotivoRecusa.limiteDeCuidadores,
      );
    });

    test(
      'Miguel, sem cuidadores: dois convites passam, o terceiro não',
      () async {
        final m = memoriaDeTeste();
        final repo = m.repositorios.cuidadores;
        await repo.convidar(
          pacienteId: idMiguel,
          nome: 'Um',
          cpf: cpfsLivres[0],
        );
        await repo.convidar(
          pacienteId: idMiguel,
          nome: 'Dois',
          cpf: cpfsLivres[1],
        );
        await recusaSemGravar(
          m,
          () => repo.convidar(
            pacienteId: idMiguel,
            nome: 'Três',
            cpf: cpfsLivres[2],
          ),
          MotivoRecusa.limiteDeCuidadores,
        );
      },
    );

    test('o convite novo é aceito na TM10', () async {
      final m = memoriaDeTeste();
      final novo = await m.repositorios.cuidadores.convidar(
        pacienteId: idMiguel,
        nome: 'Rodrigo Neves',
        cpf: cpfsLivres[2],
      );
      final v = await m.repositorios.autenticacao.aceitarConviteCuidador(
        codigo: novo.convite.codigo.toLowerCase(),
        cpf: cpfsLivres[2],
        identidade: identidadeNova,
      );
      expect(v.acompanhados.single.id, idMiguel);
      expect(
        m.estado.vinculos[novo.vinculo.id]!.situacao,
        SituacaoVinculo.ativo,
      );
    });
  });

  group('pendente com convite expirado não conta no limite (§7.4, §23)', () {
    /// Ana com Regina ativa e o convite do Paulo vencido (vale 5 dias).
    MemoriaDemonstracao depoisDoPrazoDoPaulo() {
      final relogio = RelogioFixo(agoraDaMemoria);
      final m = memoriaDeTeste(relogio: relogio);
      relogio.avancar(const Duration(days: 6));
      return m;
    }

    test('1 ativo + 1 pendente expirado: pode convidar', () async {
      final m = depoisDoPrazoDoPaulo();
      final repo = m.repositorios.cuidadores;
      final novo = await repo.convidar(
        pacienteId: idAna,
        nome: 'Avó Martins',
        cpf: cpfsLivres.first,
      );
      expect(novo.vinculo.situacao, SituacaoVinculo.pendente);
      final lista = await repo.cuidadores(idAna);
      expect(lista, hasLength(3), reason: 'o expirado continua na lista');
      expect(
        m.estado.vinculos[vinculoPaulo]!.situacao,
        SituacaoVinculo.pendente,
        reason: 'nada muda sozinho no vínculo vencido',
      );
      // Com a Avó, volta a 2/2.
      await recusaSemGravar(
        m,
        () => repo.convidar(
          pacienteId: idAna,
          nome: 'Mais Alguém',
          cpf: cpfsLivres[1],
        ),
        MotivoRecusa.limiteDeCuidadores,
      );
    });

    test('o mesmo CPF do convite vencido pode ser convidado de novo; o '
        'código antigo continua recusado', () async {
      final m = depoisDoPrazoDoPaulo();
      final novo = await m.repositorios.cuidadores.convidar(
        pacienteId: idAna,
        nome: 'Paulo Martins',
        cpf: cpfPaulo,
      );
      expect(novo.convite.codigo, isNot(codigoPaulo));
      await expectLater(
        m.repositorios.autenticacao.aceitarConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
          identidade: identidadeDe(m, 'Paulo Martins'),
        ),
        recusa(MotivoRecusa.codigoExpirado),
      );
      final aceito = await m.repositorios.autenticacao.aceitarConviteCuidador(
        codigo: novo.convite.codigo,
        cpf: cpfPaulo,
        identidade: identidadeDe(m, 'Paulo Martins'),
      );
      expect(aceito.acompanhados.single.id, idAna);
    });
  });

  group('recusas do convite', () {
    test('CPF inválido', () async {
      final m = memoriaDeTeste();
      await m.repositorios.cuidadores.revogar(vinculoPaulo);
      await recusaSemGravar(
        m,
        () => m.repositorios.cuidadores.convidar(
          pacienteId: idAna,
          nome: 'Fulano',
          cpf: '111.111.111-11',
        ),
        MotivoRecusa.cpfInvalido,
      );
    });

    test('CPF com convite em aberto ou acesso ativo: cpfJaConvidado', () async {
      final m = memoriaDeTeste();
      final repo = m.repositorios.cuidadores;
      for (final cpf in [cpfPaulo, cpfRegina]) {
        await recusaSemGravar(
          m,
          () => repo.convidar(pacienteId: idAna, nome: 'De novo', cpf: cpf),
          MotivoRecusa.cpfJaConvidado,
        );
      }
    });

    test('revogado pode ser convidado de novo, com código novo', () async {
      final m = memoriaDeTeste();
      final repo = m.repositorios.cuidadores;
      await repo.revogar(vinculoPaulo);
      final novo = await repo.convidar(
        pacienteId: idAna,
        nome: 'Paulo Martins',
        cpf: cpfPaulo,
      );
      expect(novo.convite.codigo, isNot(codigoPaulo));
      await expectLater(
        m.repositorios.autenticacao.conferirConviteCuidador(
          codigo: codigoPaulo,
          cpf: cpfPaulo,
        ),
        recusa(MotivoRecusa.conviteRevogado),
      );
      final conferido = await m.repositorios.autenticacao
          .conferirConviteCuidador(codigo: novo.convite.codigo, cpf: cpfPaulo);
      expect(conferido.convite.id, novo.convite.id);
    });

    test('paciente inexistente: acessoNegado', () async {
      final m = memoriaDeTeste();
      final repo = m.repositorios.cuidadores;
      await expectLater(
        repo.cuidadores(gerarUuidV4()),
        recusa(MotivoRecusa.acessoNegado),
      );
      await recusaSemGravar(
        m,
        () => repo.convidar(
          pacienteId: gerarUuidV4(),
          nome: 'X',
          cpf: cpfsLivres.first,
        ),
        MotivoRecusa.acessoNegado,
      );
    });

    test('paciente inativo não convida', () async {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idMiguel)['ativo'] = false;
      final m = memoriaDeTeste(dados: dados);
      await recusaSemGravar(
        m,
        () => m.repositorios.cuidadores.convidar(
          pacienteId: idMiguel,
          nome: 'X',
          cpf: cpfsLivres.first,
        ),
        MotivoRecusa.pacienteInativo,
      );
    });
  });

  group('revogar (nada é apagado)', () {
    test('muda a situação e preenche a data; o resto fica', () async {
      final m = memoriaDeTeste();
      final antes = m.estado.vinculos[vinculoRegina]!;
      final revogado = await m.repositorios.cuidadores.revogar(vinculoRegina);
      expect(revogado.vinculo.situacao, SituacaoVinculo.revogado);
      expect(revogado.vinculo.revogadoEm, agoraDaMemoria);
      expect(revogado.vinculo.contaCuidadorId, antes.contaCuidadorId);
      expect(revogado.vinculo.autorizadoEm, antes.autorizadoEm);
      expect(m.estado.vinculos, hasLength(2));
      expect(m.estado.contas.containsKey(contaRegina), isTrue);
    });

    test('revogar de novo não muda a data', () async {
      final m = memoriaDeTeste();
      final repo = m.repositorios.cuidadores;
      final primeiro = await repo.revogar(vinculoPaulo);
      final antes = m.estado.paraMapa();
      final segundo = await repo.revogar(vinculoPaulo);
      expect(segundo.vinculo, primeiro.vinculo);
      expect(m.estado.paraMapa(), antes);
    });

    test('vínculo inexistente: acessoNegado', () async {
      final m = memoriaDeTeste();
      await recusaSemGravar(
        m,
        () => m.repositorios.cuidadores.revogar(gerarUuidV4()),
        MotivoRecusa.acessoNegado,
      );
    });
  });
}
