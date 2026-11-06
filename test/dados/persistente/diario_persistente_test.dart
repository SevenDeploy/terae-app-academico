/// CRUD do diário com SQLite + Firestore e o fluxo online/offline
/// (Atividade 4: D13, D16, D17, D18).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/sincronizacao/sincronizador.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'apoio_persistencia.dart';

const String _paciente = 'a0000000-0000-4000-8000-000000000001';

int _seq = 0;

RegistroDiario _registro({
  Intensidade intensidade = Intensidade.leve,
  String sintoma = 'Cansaço',
  String? observacao,
  DateTime? em,
}) => RegistroDiario(
  id: 'f0000000-0000-4000-8000-${(++_seq).toString().padLeft(12, '0')}',
  pacienteId: _paciente,
  registradoEm: em ?? agoraDaPersistencia,
  adesao: Adesao.total,
  intensidade: intensidade,
  sintomaPredominante: sintoma,
  observacao: observacao,
  situacaoEnvio: SituacaoEnvio.naFila,
);

void main() {
  late Montagem m;
  late RepositorioDiario diario;

  setUp(() async {
    m = await montar();
    diario = m.persistencia.repositorios.diario;
    m.persistencia.sincronizador.acompanhar([_paciente]);
  });

  Future<Map<String, Object?>?> noServidor(String id) async =>
      (await m.firestore
              .collection('pacientes')
              .doc(_paciente)
              .collection('registros')
              .doc(id)
              .get())
          .data();

  group('cadastrar e consultar (D13)', () {
    test(
      'online: grava no SQLite, envia ao Firestore e volta enviado',
      () async {
        final r = _registro(observacao: 'Dormi mal');
        final resultado = await diario.enviar(r);
        expect(resultado.enviado, isTrue);
        expect(resultado.equipeAvisada, isFalse);
        final remoto = await noServidor(r.id);
        expect(remoto, isNotNull);
        expect(remoto!['situacaoEnvio'], 'enviado');
        expect(remoto['observacao'], 'Dormi mal');
        expect(
          (await diario.registro(r.id)).situacaoEnvio,
          SituacaoEnvio.enviado,
        );
        expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
      },
    );

    test(
      'crítico: o alerta e o aviso do cuidador vão no mesmo lote (D18)',
      () async {
        final r = _registro(intensidade: Intensidade.critica);
        final resultado = await diario.enviar(r);
        expect(resultado.equipeAvisada, isTrue);
        final alerta = resultado.alerta!;
        expect(alerta.regraDisparada, RegraAlerta.intensidadeCritica);
        expect(
          alerta.id,
          idDoAlertaDe(r.id),
          reason: 'id derivado do registro',
        );
        final paciente = m.firestore.collection('pacientes').doc(_paciente);
        expect(
          (await paciente.collection('alertas').doc(alerta.id).get()).exists,
          isTrue,
        );
        final aviso = await paciente
            .collection('avisosCuidador')
            .doc(alerta.id)
            .get();
        expect(
          aviso.data()!.keys,
          unorderedEquals(['id', 'emitidoEm', 'cienteEm']),
        );
        expect(await diario.alertaDoRegistro(r.id), alerta);
      },
    );

    test('grave depois de grave dispara graveConsecutivo (§7.1 b)', () async {
      await diario.enviar(
        _registro(
          intensidade: Intensidade.grave,
          em: agoraDaPersistencia.subtract(const Duration(days: 1)),
        ),
      );
      final segundo = await diario.enviar(
        _registro(intensidade: Intensidade.grave),
      );
      expect(segundo.alerta?.regraDisparada, RegraAlerta.graveConsecutivo);
    });

    test(
      'reenviar o mesmo registro não duplica nem cria outro alerta',
      () async {
        final r = _registro(intensidade: Intensidade.critica);
        final primeiro = await diario.enviar(r);
        final segundo = await diario.enviar(r);
        expect(segundo.alerta, primeiro.alerta);
        final alertas = await m.firestore
            .collection('pacientes')
            .doc(_paciente)
            .collection('alertas')
            .get();
        expect(alertas.docs, hasLength(1));
      },
    );

    test(
      'buscar: texto sem acento nem maiúscula e filtro de intensidade',
      () async {
        await diario.enviar(_registro(sintoma: 'Cansaço'));
        await diario.enviar(
          _registro(
            sintoma: 'Ansiedade',
            intensidade: Intensidade.grave,
            observacao: 'Prova amanhã',
          ),
        );
        expect(
          (await diario.buscar(
            _paciente,
            texto: 'CANSACO',
          )).map((r) => r.sintomaPredominante),
          ['Cansaço'],
        );
        expect(
          (await diario.buscar(
            _paciente,
            texto: 'prova',
          )).single.sintomaPredominante,
          'Ansiedade',
        );
        expect(
          await diario.buscar(_paciente, intensidades: {Intensidade.critica}),
          isEmpty,
        );
        expect(await diario.registros(_paciente), hasLength(2));
      },
    );
  });

  group('online/offline (D16)', () {
    test(
      'sem conexão fica na fila; a conexão volta e a fila sai sozinha',
      () async {
        await m.conexao.desligar();
        final r = _registro(intensidade: Intensidade.critica);
        final resultado = await diario.enviar(r);
        expect(resultado.enviado, isFalse);
        expect(resultado.equipeAvisada, isFalse, reason: '§19: nunca na fila');
        expect(await noServidor(r.id), isNull);
        final situacao = m.persistencia.sincronizador.situacao.value;
        expect(situacao.online, isFalse);
        expect(situacao.pendentes, 1);
        // A TM13 lista do aparelho mesmo sem conexão.
        expect((await diario.registros(_paciente)).single.id, r.id);

        await m.conexao.ligar();
        await m.persistencia.sincronizador.sincronizar();
        expect((await noServidor(r.id))!['situacaoEnvio'], 'enviado');
        expect(await diario.alertaDoRegistro(r.id), isNotNull);
        expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
        expect(m.persistencia.sincronizador.situacao.value.online, isTrue);
      },
    );

    test(
      '"sem conexão" do painel (D11) força o offline e religar envia',
      () async {
        final demo = m.persistencia.repositorios.demonstracao;
        await demo.definirSemConexao(semConexao: true);
        final r = _registro();
        expect((await diario.enviar(r)).enviado, isFalse);
        await demo.definirSemConexao(semConexao: false);
        expect((await noServidor(r.id))!['situacaoEnvio'], 'enviado');
      },
    );

    test(
      'o que veio do servidor entra no SQLite; a mudança na fila vence',
      () async {
        final deOutroAparelho = _registro(sintoma: 'Dor')
            .copyWith(situacaoEnvio: SituacaoEnvio.enviado);
        await m.firestore
            .collection('pacientes')
            .doc(_paciente)
            .collection('registros')
            .doc(deOutroAparelho.id)
            .set(deOutroAparelho.toMap());
        await m.persistencia.sincronizador.sincronizar();
        expect(
          (await diario.registro(deOutroAparelho.id)).sintomaPredominante,
          'Dor',
        );
      },
    );
  });

  group('corrigir e excluir no mesmo dia (D17)', () {
    test('corrigir troca as respostas, guarda atualizadoEm e envia', () async {
      final r = _registro();
      await diario.enviar(r);
      final corrigido = await diario.atualizar(
        r.corrigido(
          adesao: Adesao.parcial,
          intensidade: Intensidade.moderada,
          sintomaPredominante: 'Dor',
          observacao: null,
          em: agoraDaPersistencia,
        ),
      );
      expect(corrigido.enviado, isTrue);
      expect(corrigido.registro.atualizadoEm, agoraDaPersistencia);
      final remoto = (await noServidor(r.id))!;
      expect(remoto['sintomaPredominante'], 'Dor');
      expect(remoto['adesao'], 'parcial');
    });

    test('corrigir para crítico cria o alerta na confirmação', () async {
      final r = _registro();
      await diario.enviar(r);
      final resultado = await diario.atualizar(
        r.corrigido(
          adesao: r.adesao,
          intensidade: Intensidade.critica,
          sintomaPredominante: r.sintomaPredominante,
          observacao: r.observacao,
          em: agoraDaPersistencia,
        ),
      );
      expect(resultado.equipeAvisada, isTrue);
    });

    test(
      'excluir é lógico: some da lista e o servidor guarda excluidoEm',
      () async {
        final r = _registro();
        await diario.enviar(r);
        final excluido = await diario.excluir(r.id);
        expect(excluido.excluidoEm, agoraDaPersistencia);
        expect(await diario.registros(_paciente), isEmpty);
        expect((await diario.registro(r.id)).excluido, isTrue);
        expect((await noServidor(r.id))!['excluidoEm'], isNotNull);
      },
    );

    test(
      'excluir sem conexão fica na fila e sai quando a conexão volta',
      () async {
        final r = _registro();
        await diario.enviar(r);
        await m.conexao.desligar();
        await diario.excluir(r.id);
        expect((await noServidor(r.id))!['excluidoEm'], isNull);
        await m.conexao.ligar();
        await m.persistencia.sincronizador.sincronizar();
        expect((await noServidor(r.id))!['excluidoEm'], isNotNull);
      },
    );

    test('registro de ontem não muda: edicaoEncerrada', () async {
      final ontem = _registro(em: instanteNaClinica(2026, 10, 1, 21));
      await diario.enviar(ontem);
      await expectLater(
        diario.excluir(ontem.id),
        throwsA(
          isA<RecusaDeRegra>().having(
            (e) => e.motivo,
            'motivo',
            MotivoRecusa.edicaoEncerrada,
          ),
        ),
      );
      await expectLater(
        diario.registro('nao-existe'),
        throwsA(
          isA<RecusaDeRegra>().having(
            (e) => e.motivo,
            'motivo',
            MotivoRecusa.registroInexistente,
          ),
        ),
      );
    });
  });
}
