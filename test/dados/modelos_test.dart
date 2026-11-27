import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/adesao_em_casa.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/linha_de_cuidado.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/ocupacao.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/quem_registrou.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/resposta_presenca.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/enums/situacao_conta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/enums/situacao_meta.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/enums/tipo_marco.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/modelos/alerta.dart';
import 'package:terae_app/dados/modelos/atividade_de_casa.dart';
import 'package:terae_app/dados/modelos/confirmacao_de_presenca.dart';
import 'package:terae_app/dados/modelos/consentimento.dart';
import 'package:terae_app/dados/modelos/conta_usuario.dart';
import 'package:terae_app/dados/modelos/convite_acesso.dart';
import 'package:terae_app/dados/modelos/item_medicacao.dart';
import 'package:terae_app/dados/modelos/marco_jornada.dart';
import 'package:terae_app/dados/modelos/meta_terapeutica.dart';
import 'package:terae_app/dados/modelos/paciente.dart';
import 'package:terae_app/dados/modelos/profissional_saude.dart';
import 'package:terae_app/dados/modelos/receita_uso_continuo.dart';
import 'package:terae_app/dados/modelos/registro_de_atividade.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/modelos/vinculo_cuidador.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';

/// Passa pelo JSON de verdade, como o `demonstracao.json` passará.
Mapa _peloJson(Mapa mapa) {
  final volta = jsonDecode(jsonEncode(mapa));
  if (volta is! Map<String, Object?>) throw StateError('não é mapa');
  return volta;
}

final DateTime _instante = DateTime.utc(2026, 10, 7, 18);

void main() {
  group('ida e volta fromMap/toMap das 16 entidades (Figura 3 + TO)', () {
    final casos = <String, (Object, Object Function(Mapa), Mapa Function())>{};

    final conta = ContaUsuario(
      id: 'c-ana',
      nomeExibicao: 'Ana Lúcia',
      email: 'ana@exemplo.test',
      idProvedor: 'google-123',
      situacao: SituacaoConta.ativa,
      ultimoAcessoEm: _instante,
    );
    casos['ContaUsuario'] = (conta, ContaUsuario.fromMap, conta.toMap);

    final paciente = Paciente(
      id: 'p-ana',
      contaId: 'c-ana',
      profissionalRefId: 'pr-helena',
      nome: 'Ana Lúcia Martins',
      cpf: '52998224725',
      dataNascimento: DataCivil(2010, 3, 14),
      ativo: true,
    );
    casos['Paciente'] = (paciente, Paciente.fromMap, paciente.toMap);

    const profissional = ProfissionalSaude(
      id: 'pr-helena',
      nome: 'Dra. Helena Prado',
      registroConselho: 'CRM-MT 12345',
      especialidade: 'Psiquiatria infantil',
    );
    casos['ProfissionalSaude'] = (
      profissional,
      ProfissionalSaude.fromMap,
      profissional.toMap,
    );

    final consentimento = Consentimento(
      id: 'cs-1',
      pacienteId: 'p-ana',
      contaId: 'c-ana',
      qualidade: QualidadeConsentimento.titular,
      versaoTermo: '2026-10',
      canalAutorizado: CanalAutorizado.aplicativo,
      aceitoEm: _instante,
      revogadoEm: _instante.add(const Duration(days: 30)),
    );
    casos['Consentimento'] = (
      consentimento,
      Consentimento.fromMap,
      consentimento.toMap,
    );

    final convite = ConviteAcesso(
      id: 'cv-1',
      pacienteId: 'p-ana',
      codigo: 'K7P2QX',
      tipo: TipoConvite.cuidador,
      cpfConvidado: '11144477735',
      expiraEm: _instante.add(const Duration(days: 7)),
    );
    casos['ConviteAcesso'] = (convite, ConviteAcesso.fromMap, convite.toMap);

    final vinculo = VinculoCuidador(
      id: 'v-1',
      pacienteId: 'p-ana',
      contaCuidadorId: 'c-regina',
      conviteId: 'cv-1',
      nome: 'Regina Martins',
      situacao: SituacaoVinculo.ativo,
      autorizadoEm: _instante,
    );
    casos['VinculoCuidador'] = (
      vinculo,
      VinculoCuidador.fromMap,
      vinculo.toMap,
    );

    final registro = RegistroDiario(
      id: '0b6f6a3e-8f1d-4c2a-9b7e-1d2c3b4a5f60',
      pacienteId: 'p-ana',
      registradoEm: _instante,
      adesao: Adesao.parcial,
      sintomas: 'Recusou o jantar duas vezes.',
      intensidadeSintoma: Intensidade.critico,
      observacoes: 'Dormi mal',
      situacaoEnvio: SituacaoEnvio.enviado,
      versao: 2,
      enviadoEm: _instante,
      atualizadoEm: _instante,
      alertouAEquipe: true,
      revisadoEm: _instante,
      retiradoEm: _instante,
      motivoDaRetirada: RetiradaDoRegistro(
        categoria: MotivoDaRetirada.outro,
        detalhe: 'Era do irmão',
      ),
      versoesAnteriores: [
        VersaoDoRegistro(
          versao: 1,
          enviadaEm: _instante,
          adesao: Adesao.total,
          intensidadeSintoma: Intensidade.leve,
        ),
      ],
    );
    casos['RegistroDiario'] = (
      registro,
      RegistroDiario.fromMap,
      registro.toMap,
    );

    final alerta = Alerta(
      id: 'a-1',
      registroId: registro.id,
      regraDisparada: RegraAlerta.graveConsecutivo,
      emitidoEm: _instante,
      cienteEm: _instante.add(const Duration(minutes: 4)),
    );
    casos['Alerta'] = (alerta, Alerta.fromMap, alerta.toMap);

    final agendamento = Agendamento(
      id: 'ag-1',
      pacienteId: 'p-ana',
      profissionalId: 'pr-helena',
      dataHora: _instante,
      motivoRetorno: 'Ajuste de dose',
      situacao: SituacaoAgendamento.agendado,
    );
    casos['Agendamento'] = (
      agendamento,
      Agendamento.fromMap,
      agendamento.toMap,
    );

    final receita = ReceitaUsoContinuo(
      id: 'r-1',
      pacienteId: 'p-ana',
      profissionalId: 'pr-helena',
      orientacao: 'Tomar pela manhã, depois do café.',
      vigenciaInicio: DataCivil(2026, 9, 1),
      vigenciaFim: DataCivil(2026, 10, 31),
      dataRenovacao: DataCivil(2026, 10, 8),
    );
    casos['ReceitaUsoContinuo'] = (
      receita,
      ReceitaUsoContinuo.fromMap,
      receita.toMap,
    );

    final item = ItemMedicacao(
      id: 'i-1',
      receitaId: 'r-1',
      medicamento: 'Sertralina',
      posologia: '50 mg, 1 comprimido',
      horarios: const ['08:00', '20:00'],
    );
    casos['ItemMedicacao'] = (item, ItemMedicacao.fromMap, item.toMap);

    final marco = MarcoJornada(
      id: 'm-1',
      pacienteId: 'p-ana',
      tipo: TipoMarco.proximoPasso,
      data: DataCivil(2026, 10, 20),
      titulo: 'Reavaliação marcada',
      textoSimples: 'Vamos ver juntos como você está.',
      metaId: 'meta-1',
    );
    casos['MarcoJornada'] = (marco, MarcoJornada.fromMap, marco.toMap);

    final atividade = AtividadeDeCasa(
      id: 'ac-1',
      pacienteId: 'p-miguel',
      profissionalId: 'pr-larissa',
      titulo: 'Vestir a camiseta no espelho',
      texto: 'Ajude só a passar a cabeça.',
      vezesPorSemana: 5,
      ocupacao: Ocupacao.autocuidado,
      publicadaEm: _instante,
      encerradaEm: _instante.add(const Duration(days: 30)),
      metaId: 'meta-1',
    );
    casos['AtividadeDeCasa'] = (
      atividade,
      AtividadeDeCasa.fromMap,
      atividade.toMap,
    );

    final registroCasa = RegistroDeAtividade(
      id: 'rc-1',
      pacienteId: 'p-miguel',
      atividadeId: 'ac-1',
      dia: DataCivil(2026, 10, 7),
      adesao: AdesaoEmCasa.emParte,
      reflexao: 'Passou a cabeça sozinho.',
      quem: QuemRegistrou.responsavel,
      registradoEm: _instante,
      situacaoEnvio: SituacaoEnvio.enviado,
      atualizadoEm: _instante,
      excluidoEm: _instante,
    );
    casos['RegistroDeAtividade'] = (
      registroCasa,
      RegistroDeAtividade.fromMap,
      registroCasa.toMap,
    );

    final confirmacao = ConfirmacaoDePresenca(
      agendamentoId: 'ag-1',
      pacienteId: 'p-miguel',
      resposta: RespostaPresenca.naoVamos,
      respondidaEm: _instante,
      situacaoEnvio: SituacaoEnvio.naFila,
    );
    casos['ConfirmacaoDePresenca'] = (
      confirmacao,
      ConfirmacaoDePresenca.fromMap,
      confirmacao.toMap,
    );

    final meta = MetaTerapeutica(
      id: 'meta-1',
      pacienteId: 'p-miguel',
      profissionalId: 'pr-larissa',
      ocupacao: Ocupacao.autocuidado,
      descricao: 'Vestir a camiseta sozinho',
      combinadaCom: 'Patrícia e Miguel',
      prazo: DataCivil(2026, 11, 30),
      situacao: SituacaoMeta.ativa,
    );
    casos['MetaTerapeutica'] = (meta, MetaTerapeutica.fromMap, meta.toMap);

    test('são exatamente as 16 entidades', () {
      expect(casos, hasLength(16));
    });

    casos.forEach((nome, caso) {
      final (original, fromMap, toMap) = caso;
      test('$nome: fromMap(toMap(x)) == x, inclusive pelo JSON', () {
        expect(fromMap(toMap()), original);
        expect(fromMap(_peloJson(toMap())), original);
        expect(fromMap(toMap()).hashCode, original.hashCode);
      });
    });

    test('campos opcionais vazios voltam nulos', () {
      final semOpcionais = RegistroDiario(
        id: 'r-2',
        pacienteId: 'p-ana',
        registradoEm: _instante,
        adesao: Adesao.total,
        situacaoEnvio: SituacaoEnvio.enviado,
      );
      final volta = RegistroDiario.fromMap(_peloJson(semOpcionais.toMap()));
      expect(volta.sintomas, isNull);
      expect(volta.intensidadeSintoma, isNull);
      expect(volta.observacoes, isNull);
      expect(volta.versao, 1);
      expect(volta.versoesAnteriores, isEmpty);
      expect(volta, semOpcionais);
      // F3: marco e atividade das fases anteriores, sem `metaId`.
      final marcoAntigo = MarcoJornada.fromMap({
        'id': 'm-2',
        'pacienteId': 'p-ana',
        'tipo': 'orientacao',
        'data': '2026-10-01',
        'titulo': 'Rotina de sono',
        'textoSimples': 'Durma sempre no mesmo horário.',
      });
      expect(marcoAntigo.metaId, isNull);
    });
  });

  group('datas com fuso (§23)', () {
    test('toMap grava o instante em UTC com Z', () {
      final ag = Agendamento(
        id: 'ag',
        pacienteId: 'p',
        profissionalId: 'pr',
        dataHora: DateTime.parse('2026-10-07T14:00:00-04:00'),
        situacao: SituacaoAgendamento.agendado,
      );
      expect(ag.toMap()['dataHora'], '2026-10-07T18:00:00.000Z');
      expect(ag.dataHora.isUtc, isTrue);
    });

    test('fromMap aceita deslocamento e normaliza para UTC', () {
      final alerta = Alerta.fromMap({
        'id': 'a',
        'registroId': 'r',
        'regraDisparada': 'intensidadeCritica',
        'emitidoEm': '2026-10-07T14:00:00-04:00',
        'cienteEm': null,
      });
      expect(alerta.emitidoEm, DateTime.utc(2026, 10, 7, 18));
      expect(alerta.emitidoEm.isUtc, isTrue);
    });

    test('fromMap recusa hora sem fuso', () {
      expect(
        () => Alerta.fromMap({
          'id': 'a',
          'registroId': 'r',
          'regraDisparada': 'intensidadeCritica',
          'emitidoEm': '2026-10-07T14:00:00',
        }),
        throwsFormatException,
      );
    });

    test('data civil vai como AAAA-MM-DD', () {
      final p = Paciente(
        id: 'p',
        profissionalRefId: 'pr',
        nome: 'Miguel',
        cpf: '11144477735',
        dataNascimento: DataCivil(2019, 5, 2),
        ativo: true,
      );
      expect(p.toMap()['dataNascimento'], '2019-05-02');
    });
  });

  group('mapa inválido', () {
    test('campo obrigatório ausente lança FormatException com o nome', () {
      expect(
        () => ProfissionalSaude.fromMap({'id': 'x', 'nome': 'Y'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('registroConselho'),
          ),
        ),
      );
    });

    test('enum com nome desconhecido lança FormatException', () {
      expect(
        () => MarcoJornada.fromMap({
          'id': 'm',
          'pacienteId': 'p',
          'tipo': 'consulta',
          'data': '2026-10-01',
          'titulo': 't',
          'textoSimples': 's',
        }),
        throwsFormatException,
      );
    });

    test('horário fora de HH:mm é recusado', () {
      expect(
        () => ItemMedicacao(
          id: 'i',
          receitaId: 'r',
          medicamento: 'm',
          posologia: 'p',
          horarios: const ['8h'],
        ),
        throwsFormatException,
      );
    });

    test('horarios é imutável', () {
      final item = ItemMedicacao.fromMap({
        'id': 'i',
        'receitaId': 'r',
        'medicamento': 'm',
        'posologia': 'p',
        'horarios': ['08:00'],
      });
      expect(() => item.horarios.add('09:00'), throwsUnsupportedError);
    });
  });

  group('copyWith só muda a situação', () {
    test('vínculo pendente → ativo → revogado, sem perder o histórico', () {
      final pendente = VinculoCuidador(
        id: 'v',
        pacienteId: 'p',
        conviteId: 'cv',
        nome: 'Paulo',
        situacao: SituacaoVinculo.pendente,
      );
      final ativo = pendente.copyWith(
        situacao: SituacaoVinculo.ativo,
        contaCuidadorId: 'c-paulo',
        autorizadoEm: _instante,
      );
      final revogado = ativo.copyWith(
        situacao: SituacaoVinculo.revogado,
        revogadoEm: _instante.add(const Duration(days: 1)),
      );
      expect(pendente.contaCuidadorId, isNull);
      expect(revogado.contaCuidadorId, 'c-paulo');
      expect(revogado.autorizadoEm, _instante);
    });

    test('registro naFila → enviado preserva o id gerado no aparelho', () {
      final r = RegistroDiario(
        id: 'uuid-do-aparelho',
        pacienteId: 'p',
        registradoEm: _instante,
        adesao: Adesao.nenhuma,
        intensidadeSintoma: Intensidade.grave,
        situacaoEnvio: SituacaoEnvio.naFila,
      );
      final enviado = r.copyWith(situacaoEnvio: SituacaoEnvio.enviado);
      expect(enviado.id, r.id);
      expect(enviado.situacaoEnvio, SituacaoEnvio.enviado);
    });

    test('convite, consentimento, alerta, conta, paciente e agendamento', () {
      final convite = ConviteAcesso(
        id: 'cv',
        pacienteId: 'p',
        codigo: 'ABC123',
        tipo: TipoConvite.paciente,
        cpfConvidado: '52998224725',
        expiraEm: _instante,
      ).copyWith(usadoEm: _instante);
      expect(convite.usadoEm, _instante);

      final conta = ContaUsuario(
        id: 'c',
        nomeExibicao: 'X',
        email: 'x@exemplo.test',
        idProvedor: 'g',
        situacao: SituacaoConta.ativa,
      ).copyWith(situacao: SituacaoConta.inativa, ultimoAcessoEm: _instante);
      expect(conta.situacao, SituacaoConta.inativa);
      expect(conta.ultimoAcessoEm, _instante);

      final paciente = Paciente(
        id: 'p',
        profissionalRefId: 'pr',
        nome: 'Laura',
        ativo: true,
        linhasDeCuidado: {LinhaDeCuidado.terapiaOcupacional},
      );
      expect(paciente.copyWith(contaId: 'c').contaId, 'c');
      expect(paciente.copyWith(ativo: false).ativo, isFalse);
      expect(paciente.copyWith(ativo: false).linhasDeCuidado, {
        LinhaDeCuidado.terapiaOcupacional,
      });

      final ag = Agendamento(
        id: 'ag',
        pacienteId: 'p',
        profissionalId: 'pr',
        dataHora: _instante,
        situacao: SituacaoAgendamento.agendado,
      ).copyWith(situacao: SituacaoAgendamento.cancelado);
      expect(ag.situacao, SituacaoAgendamento.cancelado);

      final alerta = Alerta(
        id: 'a',
        registroId: 'r',
        regraDisparada: RegraAlerta.intensidadeCritica,
        emitidoEm: _instante,
      ).copyWith(cienteEm: _instante);
      expect(alerta.cienteEm, _instante);

      final cs = Consentimento(
        id: 'cs',
        pacienteId: 'p',
        contaId: 'c',
        qualidade: QualidadeConsentimento.responsavelLegal,
        versaoTermo: 'v1',
        canalAutorizado: CanalAutorizado.email,
        aceitoEm: _instante,
      ).copyWith(revogadoEm: _instante);
      expect(cs.revogadoEm, _instante);
    });
  });

  group('cópia do cuidador (RNFM05)', () {
    test('Paciente.paraCuidador tira CPF, nascimento e conta', () {
      final completo = Paciente(
        id: 'p-ana',
        contaId: 'c-ana',
        profissionalRefId: 'pr',
        nome: 'Ana Lúcia Martins',
        cpf: '52998224725',
        dataNascimento: DataCivil(2010, 3, 14),
        ativo: true,
      );
      final mapa = completo.paraCuidador().toMap();
      expect(mapa['cpf'], isNull);
      expect(mapa['dataNascimento'], isNull);
      expect(mapa['contaId'], isNull);
      expect(mapa['nome'], 'Ana Lúcia Martins');
      expect(completo.primeiroNome, 'Ana');
    });

    test('Agendamento.paraCuidador tira o motivo do retorno', () {
      final ag = Agendamento(
        id: 'ag',
        pacienteId: 'p',
        profissionalId: 'pr',
        dataHora: _instante,
        motivoRetorno: 'Ajuste de dose',
        situacao: SituacaoAgendamento.agendado,
      );
      expect(ag.paraCuidador().toMap()['motivoRetorno'], isNull);
      expect(ag.paraCuidador().dataHora, ag.dataHora);
    });

    test(
      'ReceitaUsoContinuo.paraCuidador tira a orientação e o prescritor',
      () {
        final receita = ReceitaUsoContinuo(
          id: 'r',
          pacienteId: 'p',
          profissionalId: 'pr',
          orientacao: 'Tomar depois do café.',
          vigenciaInicio: DataCivil(2026, 9, 1),
          vigenciaFim: DataCivil(2026, 10, 31),
          dataRenovacao: DataCivil(2026, 10, 8),
        );
        final copia = receita.paraCuidador();
        expect(copia.orientacao, isNull);
        expect(copia.profissionalId, isNull);
        expect(copia.vigenteEm(DataCivil(2026, 10, 2)), isTrue);
        expect(copia.dataRenovacao, receita.dataRenovacao);
        expect(copia.toMap().keys, receita.toMap().keys, reason: 'mesmo mapa');
        expect(ReceitaUsoContinuo.fromMap(copia.toMap()), copia);
      },
    );
  });

  group('clínica e duração, só do Terae local (paridade com o portal)', () {
    test('Agendamento: a duração vai e volta; sem ela o mapa não muda', () {
      final com = Agendamento(
        id: 'a',
        pacienteId: 'p',
        profissionalId: 'pr',
        dataHora: DateTime.utc(2026, 11, 27, 18),
        situacao: SituacaoAgendamento.agendado,
        duracaoMinutos: 50,
      );
      expect(Agendamento.fromMap(_peloJson(com.toMap())), com);
      expect(com.toMap()['duracaoMinutos'], 50);
      expect(com.paraCuidador().duracaoMinutos, 50);
      expect(
        com.copyWith(situacao: SituacaoAgendamento.cancelado).duracaoMinutos,
        50,
      );
      final sem = Agendamento(
        id: 'a',
        pacienteId: 'p',
        profissionalId: 'pr',
        dataHora: DateTime.utc(2026, 11, 27, 18),
        situacao: SituacaoAgendamento.agendado,
      );
      expect(sem.toMap().containsKey('duracaoMinutos'), isFalse);
      expect(sem == com, isFalse);
    });

    test('Paciente: clínica e telefone vão e voltam; sem eles o mapa não '
        'muda (Firebase e SQLite)', () {
      final com = Paciente(
        id: 'p',
        profissionalRefId: '',
        nome: 'Alice Souza',
        ativo: true,
        nomeDaClinica: 'Clínica Raízes',
        telefoneDaClinica: '+55 65 3000-0000',
      );
      expect(Paciente.fromMap(_peloJson(com.toMap())), com);
      expect(com.paraCuidador().nomeDaClinica, 'Clínica Raízes');
      expect(com.copyWith(ativo: false).telefoneDaClinica, '+55 65 3000-0000');
      final sem = Paciente(
        id: 'p',
        profissionalRefId: 'pr',
        nome: 'Alice Souza',
        ativo: true,
      );
      expect(sem.toMap().containsKey('nomeDaClinica'), isFalse);
      expect(sem.toMap().containsKey('telefoneDaClinica'), isFalse);
    });
  });

  group('Paciente.linhasDeCuidado (D21)', () {
    Mapa mapaDoPaciente() => {
      'id': 'p',
      'contaId': null,
      'profissionalRefId': 'pr',
      'nome': 'Antônio Carlos Ribeiro',
      'cpf': '81534726071',
      'dataNascimento': '1955-08-20',
      'ativo': true,
    };

    test('sem o campo (dados das Atividades 3 e 4), é acompanhamento '
        'clínico', () {
      final p = Paciente.fromMap(_peloJson(mapaDoPaciente()));
      expect(p.linhasDeCuidado, Paciente.linhasPadrao);
      expect(p.temAcompanhamentoClinico, isTrue);
      expect(p.temTerapiaOcupacional, isFalse);
    });

    test('ida e volta pelo JSON, na ordem do enum, e vai à cópia do '
        'cuidador', () {
      final p = Paciente.fromMap(
        _peloJson({
          ...mapaDoPaciente(),
          'linhasDeCuidado': ['terapiaOcupacional', 'acompanhamentoClinico'],
        }),
      );
      expect(p.temTerapiaOcupacional && p.temAcompanhamentoClinico, isTrue);
      expect(p.toMap()['linhasDeCuidado'], [
        'acompanhamentoClinico',
        'terapiaOcupacional',
      ]);
      expect(Paciente.fromMap(_peloJson(p.toMap())), p);
      final copia = p.paraCuidador();
      expect(copia.linhasDeCuidado, p.linhasDeCuidado);
      expect(copia.cpf, isNull);
    });

    test('linha desconhecida ou lista vazia não carregam', () {
      expect(
        () => Paciente.fromMap({
          ...mapaDoPaciente(),
          'linhasDeCuidado': ['fonoaudiologia'],
        }),
        throwsFormatException,
      );
      expect(
        () => Paciente.fromMap({...mapaDoPaciente(), 'linhasDeCuidado': []}),
        throwsArgumentError,
      );
    });

    test('a igualdade não depende da ordem das linhas', () {
      Paciente com(Set<LinhaDeCuidado> linhas) => Paciente(
        id: 'p',
        profissionalRefId: 'pr',
        nome: 'X',
        ativo: true,
        linhasDeCuidado: linhas,
      );
      final a = com({
        LinhaDeCuidado.terapiaOcupacional,
        LinhaDeCuidado.acompanhamentoClinico,
      });
      final b = com({
        LinhaDeCuidado.acompanhamentoClinico,
        LinhaDeCuidado.terapiaOcupacional,
      });
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(com({LinhaDeCuidado.terapiaOcupacional})));
    });
  });

  group('MetaTerapeutica (F3; D25)', () {
    Map<String, Object?> mapa() => {
      'id': 'meta-1',
      'pacienteId': 'p',
      'profissionalId': 'pr',
      'ocupacao': 'brincar',
      'descricao': 'Brincar de massinha por 10 minutos',
      'combinadaCom': 'Patrícia e Miguel',
      'prazo': '2026-12-01',
      'situacao': 'alcancada',
    };

    test('escore, nível GAS e peso que viessem no documento são ignorados e '
        'não voltam no mapa', () {
      final meta = MetaTerapeutica.fromMap({
        ...mapa(),
        'escore': 3,
        'nivelGas': 1,
        'peso': 2,
      });
      expect(meta.toMap().keys.toSet(), {
        'id',
        'pacienteId',
        'profissionalId',
        'ocupacao',
        'descricao',
        'combinadaCom',
        'prazo',
        'situacao',
      });
    });

    test('descrição e "combinada com" não podem ser vazias nem longas '
        'demais', () {
      expect(
        () => MetaTerapeutica.fromMap({...mapa(), 'descricao': '  '}),
        throwsArgumentError,
      );
      expect(
        () => MetaTerapeutica.fromMap({...mapa(), 'descricao': 'x' * 201}),
        throwsArgumentError,
      );
      expect(
        () => MetaTerapeutica.fromMap({...mapa(), 'combinadaCom': ''}),
        throwsArgumentError,
      );
      expect(
        () => MetaTerapeutica.fromMap({...mapa(), 'combinadaCom': 'x' * 121}),
        throwsArgumentError,
      );
    });
  });

  group('os 11 enums do §22 (grafia do docx) e os da evolução de TO', () {
    final enums = <String, List<Enum>>{
      'ContaUsuario.situacao': SituacaoConta.values,
      'ConviteAcesso.tipo': TipoConvite.values,
      'Consentimento.qualidade': QualidadeConsentimento.values,
      'Consentimento.canalAutorizado': CanalAutorizado.values,
      'VinculoCuidador.situacao': SituacaoVinculo.values,
      'RegistroDiario.adesao': Adesao.values,
      'RegistroDiario.intensidadeSintoma': Intensidade.values,
      'RegistroDiario.situacaoEnvio': SituacaoEnvio.values,
      'Alerta.regraDisparada': RegraAlerta.values,
      'Agendamento.situacao': SituacaoAgendamento.values,
      'MarcoJornada.tipo': TipoMarco.values,
      'Paciente.linhasDeCuidado': LinhaDeCuidado.values,
      'AtividadeDeCasa.ocupacao': Ocupacao.values,
      'RegistroDeAtividade.adesao': AdesaoEmCasa.values,
      'RegistroDeAtividade.quem': QuemRegistrou.values,
      'ConfirmacaoDePresenca.resposta': RespostaPresenca.values,
      'MetaTerapeutica.situacao': SituacaoMeta.values,
    };

    test('são 17 (os 11 do §22 + 6 da evolução de TO), com os valores '
        'esperados', () {
      expect(enums, hasLength(17));
      final nomes = enums.map(
        (campo, valores) => MapEntry(campo, valores.map((v) => v.name)),
      );
      expect(nomes['ContaUsuario.situacao'], ['ativa', 'inativa']);
      expect(nomes['ConviteAcesso.tipo'], ['paciente', 'cuidador']);
      expect(nomes['Consentimento.qualidade'], ['titular', 'responsavelLegal']);
      expect(nomes['Consentimento.canalAutorizado'], [
        'impresso',
        'email',
        'aplicativo',
      ]);
      expect(nomes['VinculoCuidador.situacao'], [
        'pendente',
        'ativo',
        'revogado',
      ]);
      expect(nomes['RegistroDiario.adesao'], ['total', 'parcial', 'nenhuma']);
      // P3 (D8 revista): os nomes do corpo da API do portal.
      expect(nomes['RegistroDiario.intensidadeSintoma'], [
        'leve',
        'moderado',
        'grave',
        'critico',
      ]);
      expect(nomes['RegistroDiario.situacaoEnvio'], ['naFila', 'enviado']);
      expect(nomes['Alerta.regraDisparada'], [
        'intensidadeCritica',
        'graveConsecutivo',
      ]);
      expect(nomes['Agendamento.situacao'], [
        'agendado',
        'realizado',
        'cancelado',
      ]);
      expect(nomes['MarcoJornada.tipo'], [
        'reavaliacao',
        'orientacao',
        'proximoPasso',
        'metaAlcancada',
        'alta',
      ]);
      expect(nomes['Paciente.linhasDeCuidado'], [
        'acompanhamentoClinico',
        'terapiaOcupacional',
      ]);
      expect(nomes['AtividadeDeCasa.ocupacao'], [
        'autocuidado',
        'tarefasDaCasa',
        'brincar',
        'escola',
        'sonoEDescanso',
        'lazer',
        'convivio',
        'trabalho',
      ]);
      expect(nomes['RegistroDeAtividade.adesao'], [
        'feito',
        'emParte',
        'naoFeito',
      ]);
      expect(nomes['RegistroDeAtividade.quem'], ['paciente', 'responsavel']);
      expect(nomes['ConfirmacaoDePresenca.resposta'], ['vamos', 'naoVamos']);
      expect(nomes['MetaTerapeutica.situacao'], [
        'ativa',
        'alcancada',
        'interrompida',
        'substituida',
      ]);
    });

    test('cada valor volta pelo nome e tem rótulo em linguagem simples', () {
      enums.forEach((campo, valores) {
        for (final valor in valores) {
          expect(
            lerEnum({'v': valor.name}, 'v', valores),
            valor,
            reason: campo,
          );
        }
      });
      final rotulos = <String>[
        for (final v in SituacaoConta.values) v.rotulo,
        for (final v in TipoConvite.values) v.rotulo,
        for (final v in QualidadeConsentimento.values) v.rotulo,
        for (final v in CanalAutorizado.values) v.rotulo,
        for (final v in SituacaoVinculo.values) v.rotulo,
        for (final v in Adesao.values) v.rotulo,
        for (final v in Intensidade.values) v.rotulo,
        for (final v in SituacaoEnvio.values) v.rotulo,
        for (final v in RegraAlerta.values) v.rotulo,
        for (final v in SituacaoAgendamento.values) v.rotulo,
        for (final v in TipoMarco.values) v.rotulo,
        for (final v in LinhaDeCuidado.values) v.rotulo,
        for (final v in Ocupacao.values) v.rotulo,
        for (final v in AdesaoEmCasa.values) v.rotulo,
        for (final v in QuemRegistrou.values) v.rotulo,
        for (final v in RespostaPresenca.values) ...[
          v.rotulo,
          v.rotuloNaPrimeiraPessoa,
        ],
        for (final v in SituacaoMeta.values) v.rotulo,
      ];
      expect(rotulos, everyElement(isNotEmpty));
      expect(Adesao.total.rotulo, 'Fizemos tudo');
      expect(Intensidade.critico.rotulo, 'Muito — precisamos de ajuda');
      expect(Intensidade.grave.curto, 'Bastante');
      expect(Intensidade.moderado.naLista, 'Atrapalhou mais ou menos');
    });

    test('só "Muito" abre a ajuda imediata; "Bastante" e "Muito" mostram os '
        'números quando o registro fica guardado', () {
      expect(Intensidade.values.where((i) => i.ehCritico), [
        Intensidade.critico,
      ]);
      expect(Intensidade.values.where((i) => i.pedeAjudaSemInternet), [
        Intensidade.grave,
        Intensidade.critico,
      ]);
    });

    test('a grafia antiga da intensidade (A3/A4) ainda é lida', () {
      expect(Intensidade.doNome('moderada'), Intensidade.moderado);
      expect(Intensidade.doNome('critica'), Intensidade.critico);
      expect(Intensidade.doNome('grave'), Intensidade.grave);
      expect(Intensidade.doNome('urgente'), isNull);
    });

    test('o motivo da retirada vai com a grafia da API do portal', () {
      expect(
        [for (final m in MotivoDaRetirada.values) m.valor],
        ['dia_errado', 'paciente_errado', 'enviado_sem_querer', 'outro'],
      );
      for (final m in MotivoDaRetirada.values) {
        expect(MotivoDaRetirada.doValor(m.valor), m);
        expect(m.rotulo, isNotEmpty);
      }
      expect(MotivoDaRetirada.doValor('diaErrado'), isNull);
    });
  });

  group('RegistroDiario igual ao do portal (P3, D17 revista)', () {
    RegistroDiario enviado() => RegistroDiario(
      id: 'r-1',
      pacienteId: 'p',
      registradoEm: _instante,
      adesao: Adesao.parcial,
      sintomas: 'Recusou o jantar.',
      intensidadeSintoma: Intensidade.moderado,
      situacaoEnvio: SituacaoEnvio.enviado,
      enviadoEm: _instante,
    );

    test('corrigir guarda a versão vigente e cria a seguinte', () {
      final depois = _instante.add(const Duration(hours: 1));
      final corrigido = enviado().corrigido(
        EntradaDoDiario(adesao: Adesao.total, observacoes: '  Melhorou. '),
        em: depois,
      );
      expect(corrigido.versao, 2);
      expect(corrigido.adesao, Adesao.total);
      expect(corrigido.sintomas, isNull);
      expect(corrigido.intensidadeSintoma, isNull);
      expect(corrigido.observacoes, 'Melhorou.');
      expect(corrigido.atualizadoEm, depois.toUtc());
      expect(corrigido.enviadoEm, _instante.toUtc());
      expect(corrigido.versoesAnteriores.single.versao, 1);
      expect(corrigido.versoesAnteriores.single.sintomas, 'Recusou o jantar.');
      expect(
        corrigido.versoesAnteriores.single.intensidadeSintoma,
        Intensidade.moderado,
      );
      final terceira = corrigido.corrigido(
        EntradaDoDiario(adesao: Adesao.nenhuma),
        em: depois,
      );
      expect(terceira.versao, 3);
      expect([for (final v in terceira.versoesAnteriores) v.versao], [1, 2]);
      expect(terceira.versoesAnteriores.last.enviadaEm, depois.toUtc());
    });

    test('retirar guarda a data e o motivo; nada mais muda', () {
      final motivo = RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado);
      final retirado = enviado().retiradoCom(motivo, em: _instante);
      expect(retirado.retirado, isTrue);
      expect(retirado.situacao, SituacaoDoRegistro.retirado);
      expect(retirado.motivoDaRetirada, motivo);
      expect(retirado.entrada, enviado().entrada);
    });

    test('a situação: retirado vence revisado, que vence enviado', () {
      expect(enviado().situacao, SituacaoDoRegistro.enviado);
      final revisado = RegistroDiario.fromMap({
        ...enviado().toMap(),
        'revisadoEm': escreverInstante(_instante),
      });
      expect(revisado.situacao, SituacaoDoRegistro.revisado);
      expect(
        revisado
            .retiradoCom(
              RetiradaDoRegistro(
                categoria: MotivoDaRetirada.outro,
                detalhe: 'x',
              ),
              em: _instante,
            )
            .situacao,
        SituacaoDoRegistro.retirado,
      );
    });

    test('versões que não conferem e retirada sem motivo são recusadas', () {
      expect(
        () => RegistroDiario.fromMap({...enviado().toMap(), 'versao': 2}),
        throwsFormatException,
      );
      expect(
        () => RegistroDiario.fromMap({
          ...enviado().toMap(),
          'retiradoEm': escreverInstante(_instante),
        }),
        throwsFormatException,
      );
      expect(
        () => RegistroDiario.fromMap({
          ...enviado().toMap(),
          'intensidadeSintoma': 'urgente',
        }),
        throwsFormatException,
      );
      expect(
        () => RegistroDiario.fromMap({
          ...enviado().toMap(),
          'motivoDaRetirada': {'categoria': 'sumiu'},
          'retiradoEm': escreverInstante(_instante),
        }),
        throwsFormatException,
      );
    });

    test('o registro das A3/A4 é lido: o sintoma vira o texto contado e o '
        'excluído vira retirado com "Outro"', () {
      final antigo = RegistroDiario.fromMap({
        'id': 'dd1',
        'pacienteId': 'p',
        'registradoEm': '2026-10-01T00:40:00.000Z',
        'adesao': 'total',
        'intensidade': 'critica',
        'sintomaPredominante': 'Cansaço',
        'observacao': 'Dormi mal',
        'situacaoEnvio': 'enviado',
        'atualizadoEm': null,
        'excluidoEm': '2026-10-01T01:00:00.000Z',
      });
      expect(antigo.sintomas, 'Cansaço');
      expect(antigo.intensidadeSintoma, Intensidade.critico);
      expect(antigo.observacoes, 'Dormi mal');
      expect(antigo.versao, 1);
      expect(antigo.enviadoEm, DateTime.utc(2026, 10, 1, 0, 40));
      expect(antigo.retiradoEm, DateTime.utc(2026, 10, 1, 1));
      expect(antigo.motivoDaRetirada, RegistroDiario.retiradaDoAppAntigo);
      // Gravado de novo, já sai no formato novo.
      expect(RegistroDiario.fromMap(antigo.toMap()), antigo);
    });

    test('a entrada tira os espaços e trata texto vazio como sem resposta', () {
      final e = EntradaDoDiario(
        adesao: Adesao.total,
        sintomas: '   ',
        observacoes: ' oi ',
      );
      expect(e.sintomas, isNull);
      expect(e.observacoes, 'oi');
      expect(e, EntradaDoDiario(adesao: Adesao.total, observacoes: 'oi'));
    });

    test('"Outro" pede um detalhe de até 300 caracteres; as outras '
        'categorias não guardam detalhe', () {
      expect(
        RetiradaDoRegistro(categoria: MotivoDaRetirada.outro).problema,
        isNotNull,
      );
      expect(
        RetiradaDoRegistro(
          categoria: MotivoDaRetirada.outro,
          detalhe: 'a' * 301,
        ).problema,
        isNotNull,
      );
      expect(
        RetiradaDoRegistro(
          categoria: MotivoDaRetirada.outro,
          detalhe: ' Era do irmão ',
        ).detalhe,
        'Era do irmão',
      );
      final dia = RetiradaDoRegistro(
        categoria: MotivoDaRetirada.diaErrado,
        detalhe: 'ignorado',
      );
      expect(dia.detalhe, isNull);
      expect(dia.problema, isNull);
    });
  });
}
