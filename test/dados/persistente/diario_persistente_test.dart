/// O diário com SQLite + Firestore e o fluxo online/offline (Atividade 4:
/// D13, D16, D18; P3: o diário igual ao do portal, D17 revista).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/regras/diario.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/sincronizacao/sincronizador.dart';

import 'apoio_persistencia.dart';

const String _paciente = 'a0000000-0000-4000-8000-000000000001';

int _seq = 0;

RegistroDiario _registro({
  Intensidade? intensidade = Intensidade.leve,
  String? sintomas = 'Cansada à tarde.',
  String? observacoes,
  DateTime? em,
}) => RegistroDiario(
  id: 'f0000000-0000-4000-8000-${(++_seq).toString().padLeft(12, '0')}',
  pacienteId: _paciente,
  registradoEm: em ?? agoraDaPersistencia,
  adesao: Adesao.total,
  sintomas: sintomas,
  intensidadeSintoma: intensidade,
  observacoes: observacoes,
  situacaoEnvio: SituacaoEnvio.naFila,
);

Matcher _recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((e) => e.motivo, 'motivo', motivo));

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

  /// A clínica revisa no servidor (o que a terapeuta faz no Terae web).
  Future<void> revisarNoServidor(String id) => m.firestore
      .collection('pacientes')
      .doc(_paciente)
      .collection('registros')
      .doc(id)
      .update({'revisadoEm': escreverInstante(agoraDaPersistencia)});

  group('cadastrar e consultar (D13)', () {
    test(
      'online: grava no SQLite, envia ao Firestore e volta enviado',
      () async {
        final r = _registro(observacoes: 'Dormi mal');
        final resultado = await diario.enviar(r);
        expect(resultado.enviado, isTrue);
        expect(resultado.equipeAvisada, isFalse);
        final remoto = await noServidor(r.id);
        expect(remoto, isNotNull);
        expect(remoto!['situacaoEnvio'], 'enviado');
        expect(remoto['observacoes'], 'Dormi mal');
        expect(remoto['sintomas'], 'Cansada à tarde.');
        expect(remoto['intensidadeSintoma'], 'leve');
        expect(remoto['versao'], 1);
        expect(remoto['alertouAEquipe'], isFalse);
        expect(remoto['enviadoEm'], escreverInstante(agoraDaPersistencia));
        final local = await diario.registro(r.id);
        expect(local.situacaoEnvio, SituacaoEnvio.enviado);
        expect(local.enviadoEm, agoraDaPersistencia);
        expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
      },
    );

    test('só a adesão: as três perguntas opcionais vão nulas', () async {
      final r = _registro(intensidade: null, sintomas: null);
      await diario.enviar(r);
      final remoto = (await noServidor(r.id))!;
      expect(remoto['sintomas'], isNull);
      expect(remoto['intensidadeSintoma'], isNull);
      expect(remoto['observacoes'], isNull);
      expect(await diario.registro(r.id), isA<RegistroDiario>());
    });

    test(
      '"Muito": o alerta e o aviso do cuidador vão no mesmo lote (D18)',
      () async {
        final r = _registro(intensidade: Intensidade.critico);
        final resultado = await diario.enviar(r);
        expect(resultado.equipeAvisada, isTrue);
        expect(resultado.registro.alertouAEquipe, isTrue);
        final alerta = resultado.alerta!;
        expect(alerta.regraDisparada, RegraAlerta.intensidadeCritica);
        expect(
          alerta.id,
          idDoAlertaDe(r.id),
          reason: 'id derivado do registro',
        );
        expect((await noServidor(r.id))!['alertouAEquipe'], isTrue);
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
        final r = _registro(intensidade: Intensidade.critico);
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

    test('a lista: do mais novo ao mais antigo, 30 por vez', () async {
      for (var i = 0; i < 33; i++) {
        m.relogio.avancar(const Duration(minutes: 1));
        await diario.enviar(_registro(em: m.relogio.agora()));
      }
      final primeira = await diario.pagina(_paciente);
      expect(primeira.registros, hasLength(registrosPorPagina));
      expect(primeira.haMais, isTrue);
      for (var i = 1; i < primeira.registros.length; i++) {
        expect(
          maisNovoPrimeiro(primeira.registros[i - 1], primeira.registros[i]),
          lessThan(0),
        );
      }
      final segunda = await diario.pagina(
        _paciente,
        antes: momentoNaLista(primeira.registros.last),
      );
      expect(segunda.registros, hasLength(3));
      expect(segunda.haMais, isFalse);
      expect({
        for (final r in [...primeira.registros, ...segunda.registros]) r.id,
      }, hasLength(33));
    });
  });

  group('online/offline (D16)', () {
    test('sem conexão fica em "Guardados neste aparelho"; a conexão volta e a '
        'fila sai sozinha', () async {
      await m.conexao.desligar();
      final r = _registro(intensidade: Intensidade.critico);
      final resultado = await diario.enviar(r);
      expect(resultado.enviado, isFalse);
      expect(resultado.equipeAvisada, isFalse, reason: '§19: nunca na fila');
      expect(await noServidor(r.id), isNull);
      final situacao = m.persistencia.sincronizador.situacao.value;
      expect(situacao.online, isFalse);
      expect(situacao.pendentes, 1);
      // A TM03 mostra o guardado mesmo sem conexão, fora da lista.
      expect((await diario.pendentes(_paciente)).single.id, r.id);
      expect((await diario.pagina(_paciente)).registros, isEmpty);

      m.relogio.avancar(const Duration(minutes: 30));
      await m.conexao.ligar();
      await m.persistencia.sincronizador.sincronizar();
      final remoto = (await noServidor(r.id))!;
      expect(remoto['situacaoEnvio'], 'enviado');
      expect(remoto['enviadoEm'], escreverInstante(m.relogio.agora()));
      expect(await diario.alertaDoRegistro(r.id), isNotNull);
      expect(await diario.pendentes(_paciente), isEmpty);
      final naLista = (await diario.pagina(_paciente)).registros.single;
      expect(esperouNaFila(naLista), isTrue, reason: '"Escrito em…"');
      expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
      expect(m.persistencia.sincronizador.situacao.value.online, isTrue);
    });

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

    test('o que veio do servidor entra no SQLite (a revisão da terapeuta '
        'também); o registro na fila vence', () async {
      final r = _registro();
      await diario.enviar(r);
      await revisarNoServidor(r.id);
      final deOutroAparelho = _registro(sintomas: 'Dor')
          .copyWith(situacaoEnvio: SituacaoEnvio.enviado);
      await m.firestore
          .collection('pacientes')
          .doc(_paciente)
          .collection('registros')
          .doc(deOutroAparelho.id)
          .set(deOutroAparelho.toMap());
      await m.persistencia.sincronizador.sincronizar();
      expect((await diario.registro(deOutroAparelho.id)).sintomas, 'Dor');
      expect((await diario.registro(r.id)).revisado, isTrue);
    });
  });

  group('corrigir e retirar (P3, D17 revista)', () {
    test('corrigir cria a versão 2, guarda a 1 e envia', () async {
      final r = _registro();
      await diario.enviar(r);
      m.relogio.avancar(const Duration(days: 2));
      final corrigido = await diario.corrigir(
        r.id,
        EntradaDoDiario(
          adesao: Adesao.parcial,
          intensidadeSintoma: Intensidade.moderado,
          sintomas: 'Dor nas costas.',
        ),
      );
      expect(corrigido.enviado, isTrue);
      expect(corrigido.registro.versao, 2);
      expect(corrigido.registro.atualizadoEm, m.relogio.agora());
      final remoto = (await noServidor(r.id))!;
      expect(remoto['sintomas'], 'Dor nas costas.');
      expect(remoto['adesao'], 'parcial');
      expect(remoto['versao'], 2);
      expect(remoto['versoesAnteriores'], [
        {
          'versao': 1,
          'enviadaEm': escreverInstante(agoraDaPersistencia),
          'adesao': 'total',
          'sintomas': 'Cansada à tarde.',
          'intensidadeSintoma': 'leve',
          'observacoes': null,
        },
      ]);
      expect(await diario.registro(r.id), corrigido.registro);
    });

    test('corrigir para "Muito" cria o alerta na confirmação', () async {
      final r = _registro();
      await diario.enviar(r);
      final resultado = await diario.corrigir(
        r.id,
        EntradaDoDiario(
          adesao: r.adesao,
          intensidadeSintoma: Intensidade.critico,
        ),
      );
      expect(resultado.equipeAvisada, isTrue);
      expect((await noServidor(r.id))!['alertouAEquipe'], isTrue);
      await expectLater(
        diario.corrigir(r.id, EntradaDoDiario(adesao: Adesao.total)),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
    });

    test('retirar guarda a data e o motivo no servidor e no aparelho; '
        'continua na lista', () async {
      final r = _registro();
      await diario.enviar(r);
      final retirado = await diario.retirar(
        r.id,
        RetiradaDoRegistro(
          categoria: MotivoDaRetirada.outro,
          detalhe: 'Era do irmão',
        ),
      );
      expect(retirado.retiradoEm, agoraDaPersistencia);
      final remoto = (await noServidor(r.id))!;
      expect(remoto['retiradoEm'], isNotNull);
      expect(remoto['motivoDaRetirada'], {
        'categoria': 'outro',
        'detalhe': 'Era do irmão',
      });
      expect((await diario.pagina(_paciente)).registros.single, retirado);
      await expectLater(
        diario.retirar(
          r.id,
          RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado),
        ),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
    });

    test('sem conexão, corrigir e retirar recusam semConexao e nada muda '
        '(pedem internet, como no portal)', () async {
      final r = _registro();
      await diario.enviar(r);
      final antes = await diario.registro(r.id);
      await m.conexao.desligar();
      await expectLater(
        diario.corrigir(r.id, EntradaDoDiario(adesao: Adesao.nenhuma)),
        _recusa(MotivoRecusa.semConexao),
      );
      await expectLater(
        diario.retirar(
          r.id,
          RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado),
        ),
        _recusa(MotivoRecusa.semConexao),
      );
      expect(await diario.registro(r.id), antes);
      expect(m.persistencia.sincronizador.situacao.value.pendentes, 0);
      expect((await noServidor(r.id))!['versao'], 1);
    });

    test('revisado pela terapeuta (chegou pela sincronização): '
        'registroNaoMudaMais, o 409 do portal', () async {
      final r = _registro();
      await diario.enviar(r);
      await revisarNoServidor(r.id);
      await m.persistencia.sincronizador.sincronizar();
      await expectLater(
        diario.corrigir(r.id, EntradaDoDiario(adesao: Adesao.parcial)),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
      await expectLater(
        diario.retirar(
          r.id,
          RetiradaDoRegistro(categoria: MotivoDaRetirada.diaErrado),
        ),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
    });

    test('o documento das A3–A5 com alerta continua "avisou a equipe" '
        'depois da sincronização e não muda mais (revisão da P3)', () async {
      final paciente = m.firestore.collection('pacientes').doc(_paciente);
      const id = 'dd000000-0000-4000-8000-000000000077';
      await paciente.collection('registros').doc(id).set({
        'id': id,
        'pacienteId': _paciente,
        'registradoEm': '2026-10-01T00:40:00.000Z',
        'adesao': 'total',
        'intensidade': 'critica',
        'sintomaPredominante': 'Tristeza',
        'observacao': null,
        'situacaoEnvio': 'enviado',
        'atualizadoEm': null,
        'excluidoEm': null,
      });
      final alerta = idDoAlertaDe(id);
      await paciente.collection('alertas').doc(alerta).set({
        'id': alerta,
        'registroId': id,
        'regraDisparada': 'intensidadeCritica',
        'emitidoEm': '2026-10-01T00:40:00.000Z',
        'cienteEm': null,
      });
      await m.persistencia.sincronizador.sincronizar();
      final local = await diario.registro(id);
      expect(local.sintomas, 'Tristeza');
      expect(local.alertouAEquipe, isTrue);
      await expectLater(
        diario.corrigir(id, EntradaDoDiario(adesao: Adesao.parcial)),
        _recusa(MotivoRecusa.registroNaoMudaMais),
      );
    });

    test(
      'o guardado neste aparelho ainda não muda; inexistente recusa',
      () async {
        await m.conexao.desligar();
        final r = _registro();
        await diario.enviar(r);
        // A regra do aparelho recusa antes de tentar o servidor.
        await expectLater(
          diario.corrigir(r.id, EntradaDoDiario(adesao: Adesao.parcial)),
          _recusa(MotivoRecusa.registroNaoMudaMais),
        );
        await expectLater(
          diario.registro('nao-existe'),
          _recusa(MotivoRecusa.registroInexistente),
        );
        await expectLater(
          diario.corrigir('nao-existe', EntradaDoDiario(adesao: Adesao.total)),
          _recusa(MotivoRecusa.registroInexistente),
        );
      },
    );
  });
}
