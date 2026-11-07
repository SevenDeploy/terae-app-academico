import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/linha_de_cuidado.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/memoria/estado_memoria.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/memoria/regras.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/cuidadores_repositorio.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';
import 'package:terae_app/nucleo/validacao/cpf.dart';

import 'memoria_apoio.dart';

int _idade(DataCivil nascimento, DataCivil hoje) {
  final fezAniversario =
      hoje.mes > nascimento.mes ||
      (hoje.mes == nascimento.mes && hoje.dia >= nascimento.dia);
  return hoje.ano - nascimento.ano - (fezAniversario ? 0 : 1);
}

void main() {
  group('datas relativas a hoje (D9)', () {
    final hoje = DataCivil(2026, 10, 2);

    test('instante: hora de parede da clínica, gravado em UTC', () {
      expect(
        resolverDatasRelativas({'emDias': 5, 'hora': '14:00'}, hoje),
        '2026-10-07T18:00:00.000Z',
      );
      expect(
        resolverDatasRelativas({'emDias': -1, 'hora': '21:30'}, hoje),
        '2026-10-02T01:30:00.000Z',
      );
    });

    test('data civil, sem hora', () {
      expect(resolverDatasRelativas({'emDias': 6}, hoje), '2026-10-08');
      expect(resolverDatasRelativas({'emDias': -30}, hoje), '2026-09-02');
    });

    test('resolve em qualquer profundidade e não muda a entrada', () {
      final entrada = {
        'lista': [
          {
            'x': {'emDias': 1},
          },
        ],
        'texto': 'igual',
      };
      expect(resolverDatasRelativas(entrada, hoje), {
        'lista': [
          {'x': '2026-10-03'},
        ],
        'texto': 'igual',
      });
      expect(entrada['texto'], 'igual');
      expect(((entrada['lista']! as List).first as Map)['x'], {'emDias': 1});
    });

    test('formato errado lança FormatException', () {
      expect(
        () => resolverDatasRelativas({'emDias': 1, 'minuto': 3}, hoje),
        throwsFormatException,
      );
      expect(
        () => resolverDatasRelativas({'emDias': 1, 'hora': '25:00'}, hoje),
        throwsFormatException,
      );
      expect(
        () => resolverDatasRelativas({'emDias': '1'}, hoje),
        throwsFormatException,
      );
    });

    test('"hoje" é o dia civil da clínica, não o de UTC', () async {
      // 3/10 02:00Z ainda é 2/10 22:00 em Cuiabá.
      final m = memoriaDeTeste(
        relogio: RelogioFixo(DateTime.utc(2026, 10, 3, 2)),
      );
      final proxima = await m.repositorios.paciente.proximaConsulta(idAna);
      expect(proxima!.dataHora, DateTime.utc(2026, 10, 7, 18));
    });
  });

  group('demonstracao.json (personas fictícias)', () {
    final m = memoriaDeTeste();
    final e = m.estado;
    final hoje = DataCivil.doInstante(agoraDaMemoria);

    test('todo identificador é UUID v4 (§23)', () {
      final mapa = e.paraMapa();
      for (final chave in mapa.keys) {
        final itens = mapa[chave];
        if (itens is! List) continue;
        for (final item in itens.cast<Map<String, Object?>>()) {
          if (!item.containsKey('id')) continue;
          expect(uuidV4Valido(item['id']! as String), isTrue, reason: '$item');
        }
      }
    });

    test('CPFs com dígito verificador válido e códigos de 6 caracteres', () {
      for (final p in e.pacientes.values) {
        expect(cpfValido(p.cpf!), isTrue, reason: p.nome);
      }
      for (final c in e.convites.values) {
        expect(cpfValido(c.cpfConvidado), isTrue, reason: c.codigo);
        expect(codigoBemFormado(c.codigo), isTrue, reason: c.codigo);
      }
      expect(e.codigos, hasLength(e.convites.length));
    });

    test('idades das personas', () {
      int idade(String id) => _idade(e.pacientes[id]!.dataNascimento!, hoje);
      expect(idade(idAna), 16);
      expect(idade(idMiguel), 7);
      expect(idade(idLaura), 4);
      expect(idade(idJoao), greaterThanOrEqualTo(18));
      expect(idade(idAntonio), 71);
    });

    test('linhas de cuidado das personas (D21, D23)', () {
      Set<LinhaDeCuidado> linhas(String id) => e.pacientes[id]!.linhasDeCuidado;
      expect(linhas(idAna), {
        LinhaDeCuidado.acompanhamentoClinico,
        LinhaDeCuidado.terapiaOcupacional,
      });
      expect(linhas(idMiguel), {LinhaDeCuidado.terapiaOcupacional});
      expect(linhas(idLaura), {LinhaDeCuidado.terapiaOcupacional});
      expect(linhas(idJoao), {LinhaDeCuidado.acompanhamentoClinico});
      expect(linhas(idAntonio), {LinhaDeCuidado.terapiaOcupacional});
    });

    test('Antônio: titular, com o Tiago, sem receita, com sessões, marcos e '
        'metas', () {
      final antonio = e.pacientes[idAntonio]!;
      expect(antonio.contaId, contaAntonio);
      expect(antonio.profissionalRefId, idTiago);
      expect(e.profissionais[idTiago]!.especialidade, 'Terapia ocupacional');
      expect(
        e.receitas.values.where((r) => r.pacienteId == idAntonio),
        isEmpty,
      );
      expect(
        e.agendamentos.values.where((a) => a.pacienteId == idAntonio),
        hasLength(3),
      );
      // F3: + "Meta alcançada" (escovar os dentes).
      expect(
        e.marcos.values.where((m) => m.pacienteId == idAntonio),
        hasLength(3),
      );
      expect(
        e.metas.values.where((m) => m.pacienteId == idAntonio),
        hasLength(3),
      );
      final v = e.vinculosDaConta(e.contas[contaAntonio]!);
      expect(v.pacientes.single.id, idAntonio);
      expect(v.qualidades, {idAntonio: QualidadeConsentimento.titular});
    });

    test('a qualidade do termo vem do consentimento vigente (D24)', () {
      final patricia = e.vinculosDaConta(e.contas[contaPatricia]!);
      expect(patricia.qualidades, {
        idMiguel: QualidadeConsentimento.responsavelLegal,
        idLaura: QualidadeConsentimento.responsavelLegal,
      });
      final ana = e.vinculosDaConta(e.contas[contaAna]!);
      expect(ana.qualidades, {idAna: QualidadeConsentimento.titular});
      final regina = e.vinculosDaConta(e.contas[contaRegina]!);
      expect(regina.qualidades, isEmpty);
    });

    test('Ana: 2/2 cuidadores, Regina ativa e Paulo pendente', () {
      final daAna = e.vinculos.values.where((v) => v.pacienteId == idAna);
      expect(
        e.vinculosNoLimite(idAna, agora: agoraDaMemoria),
        limiteCuidadores,
      );
      expect(
        {for (final v in daAna) v.nome: v.situacao},
        {
          'Regina Martins': SituacaoVinculo.ativo,
          'Paulo Martins': SituacaoVinculo.pendente,
        },
      );
      for (final p in e.pacientes.values) {
        expect(
          e.vinculosNoLimite(p.id, agora: agoraDaMemoria),
          lessThanOrEqualTo(2),
        );
      }
    });

    test('Ana: ~14 dias de diário, nenhum crítico, último ontem', () {
      final daAna = e.registros.values.where((r) => r.pacienteId == idAna);
      expect(daAna.length, inInclusiveRange(12, 14));
      expect(daAna.any((r) => r.intensidade == Intensidade.critica), isFalse);
      final ultimo = ordenar<RegistroDiario>(
        daAna,
        (a, b) => b.registradoEm.compareTo(a.registradoEm),
      ).first;
      expect(DataCivil.doInstante(ultimo.registradoEm), hoje.somarDias(-1));
      expect(ultimo.intensidade, Intensidade.leve);
    });

    test('João Pedro: sem conta, código válido e último registro grave '
        'ontem', () {
      final joao = e.pacientes[idJoao]!;
      expect(joao.contaId, isNull);
      final codigo = e.conviteDoCodigo(codigoJoao)!;
      expect(codigo.tipo, TipoConvite.paciente);
      expect(codigo.usadoEm, isNull);
      expect(codigo.expiraEm.isAfter(agoraDaMemoria), isTrue);
      final ultimo = ordenar<RegistroDiario>(
        e.registros.values.where((r) => r.pacienteId == idJoao),
        (a, b) => b.registradoEm.compareTo(a.registradoEm),
      ).first;
      expect(ultimo.intensidade, Intensidade.grave);
      expect(DataCivil.doInstante(ultimo.registradoEm), hoje.somarDias(-1));
    });

    test('Patrícia: conta de Miguel e Laura; Regina: cuidadora de Ana', () {
      final patricia = e.contas[contaPatricia]!;
      expect(
        e.vinculosDaConta(patricia).pacientes.map((p) => p.nome),
        unorderedEquals(['Miguel Andrade Neves', 'Laura Andrade Neves']),
      );
      final regina = e.vinculosDaConta(e.contas[contaRegina]!);
      expect(regina.pacientes, isEmpty);
      expect(regina.acompanhados.single.nome, 'Ana Lúcia Martins');
    });

    test('convites para a demonstração de recusa: expirado e usado', () {
      final convites = e.convites.values;
      expect(
        convites.any(
          (c) => c.usadoEm == null && !c.expiraEm.isAfter(agoraDaMemoria),
        ),
        isTrue,
      );
      expect(convites.where((c) => c.usadoEm != null), isNotEmpty);
    });

    test('toda conta da demonstração entra com a senha de demonstração', () {
      expect(e.senhas.keys, unorderedEquals(e.contas.keys));
      expect(e.senhas.values.toSet(), {senhaDeDemonstracao});
      for (final c in e.contas.values) {
        expect(e.contaDoEmail(c.email), c, reason: c.email);
        expect(c.idProvedor, c.id, reason: 'uid do provedor = id da conta');
      }
    });

    test('alertas da demonstração batem com as regras do §7.1', () {
      final esperados = <String>{};
      for (final p in e.pacientes.values) {
        final seq = ordenar<RegistroDiario>(
          e.registros.values.where((r) => r.pacienteId == p.id),
          (a, b) => a.registradoEm.compareTo(b.registradoEm),
        );
        for (var i = 0; i < seq.length; i++) {
          final regra = regraDoAlerta(
            nova: seq[i].intensidade,
            anterior: i == 0 ? null : seq[i - 1].intensidade,
          );
          if (regra != null) esperados.add(seq[i].id);
        }
      }
      expect(e.alertas.values.map((a) => a.registroId).toSet(), esperados);
      for (final a in e.alertas.values) {
        expect(e.destinatarios[a.id], idHelena);
      }
    });
  });

  group('carga rejeita demonstração inconsistente', () {
    test('coleção desconhecida', () {
      final dados = dadosDaDemonstracao()..['pacientez'] = <Object?>[];
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('referência quebrada', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idAna)['profissionalRefId'] = gerarUuidV4();
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('código repetido', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'convites', conviteJoao)['codigo'] = codigoPaulo;
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('vínculo ativo sem aceite do convite', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'vinculos', vinculoPaulo)['situacao'] = 'ativo';
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });

    test('CPF inválido no paciente', () {
      final dados = dadosDaDemonstracao();
      itemDe(dados, 'pacientes', idJoao)['cpf'] = '58304921643';
      expect(() => memoriaDeTeste(dados: dados), throwsFormatException);
    });
  });

  test('guarda cópia do mapa: mudar o original não muda o reinício', () async {
    final dados = dadosDaDemonstracao();
    final m = memoriaDeTeste(dados: dados);
    final inicial = m.estado.paraMapa();
    colecao(dados, 'pacientes').clear();
    await m.repositorios.demonstracao.reiniciarDados();
    expect(m.estado.paraMapa(), inicial);
  });

  testWidgets('carrega o asset pelo rootBundle', (tester) async {
    final m = await tester.runAsync(
      () => MemoriaDemonstracao.carregar(
        relogio: RelogioFixo(agoraDaMemoria),
        latencia: Duration.zero,
      ),
    );
    expect(m!.estado.pacientes, hasLength(5));
    expect(m.latencia, Duration.zero);
    expect(
      MemoriaDemonstracao.latenciaDoApp,
      lessThanOrEqualTo(const Duration(milliseconds: 300)),
    );
  });
}
