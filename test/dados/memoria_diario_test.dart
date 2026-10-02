import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';

import 'memoria_apoio.dart';

/// Registro como o aparelho cria: UUID próprio e `naFila`.
RegistroDiario _registro(
  String pacienteId,
  Intensidade intensidade, {
  DateTime? em,
  String? id,
  String sintoma = 'Tristeza',
}) => RegistroDiario(
  id: id ?? gerarUuidV4(),
  pacienteId: pacienteId,
  registradoEm: em ?? agoraDaMemoria,
  adesao: Adesao.total,
  intensidade: intensidade,
  sintomaPredominante: sintoma,
  situacaoEnvio: SituacaoEnvio.naFila,
);

Future<void> _semConexao(MemoriaDemonstracao m, {required bool sem}) =>
    m.repositorios.demonstracao.definirSemConexao(semConexao: sem);

void main() {
  group('enviar com conexão (RFM05, §7.1)', () {
    test('leve: enviado, sem alerta, equipe não avisada', () async {
      final m = memoriaDeTeste();
      final r = await m.repositorios.diario.enviar(
        _registro(idAna, Intensidade.leve),
      );
      expect(r.enviado, isTrue);
      expect(r.registro.situacaoEnvio, SituacaoEnvio.enviado);
      expect(r.alerta, isNull);
      expect(r.equipeAvisada, isFalse);
      final lista = await m.repositorios.diario.registros(idAna);
      expect(lista.first, r.registro);
    });

    test('crítica: o servidor cria o alerta para o profissional de '
        'referência', () async {
      final m = memoriaDeTeste();
      final r = await m.repositorios.diario.enviar(
        _registro(idAna, Intensidade.critica),
      );
      expect(r.equipeAvisada, isTrue);
      final alerta = r.alerta!;
      expect(alerta.regraDisparada, RegraAlerta.intensidadeCritica);
      expect(alerta.registroId, r.registro.id);
      expect(alerta.emitidoEm, agoraDaMemoria);
      expect(alerta.cienteEm, isNull);
      expect(m.estado.alertasDoProfissional(idHelena), contains(alerta));
      expect(m.estado.alertasDoProfissional(idLarissa), isEmpty);
      expect(
        await m.repositorios.diario.alertaDoRegistro(r.registro.id),
        alerta,
      );
    });

    test('crítica do Miguel vai para a Dra. Larissa', () async {
      final m = memoriaDeTeste();
      final r = await m.repositorios.diario.enviar(
        _registro(idMiguel, Intensidade.critica),
      );
      expect(m.estado.alertasDoProfissional(idLarissa), [r.alerta]);
    });

    test('João: grave depois do grave de ontem → grave consecutivo', () async {
      final m = memoriaDeTeste();
      final r = await m.repositorios.diario.enviar(
        _registro(idJoao, Intensidade.grave),
      );
      expect(r.alerta!.regraDisparada, RegraAlerta.graveConsecutivo);
      expect(r.equipeAvisada, isTrue);
      expect(m.estado.alertasDoProfissional(idHelena), contains(r.alerta));
    });

    test(
      'Ana: grave depois de leve não dispara; o segundo grave sim',
      () async {
        final m = memoriaDeTeste();
        final relogio = m.relogio as RelogioFixo;
        final diario = m.repositorios.diario;
        final primeiro = await diario.enviar(
          _registro(idAna, Intensidade.grave),
        );
        expect(primeiro.alerta, isNull);
        relogio.avancar(const Duration(hours: 2));
        final moderado = await diario.enviar(
          _registro(idAna, Intensidade.moderada, em: relogio.agora()),
        );
        expect(moderado.alerta, isNull);
        relogio.avancar(const Duration(hours: 2));
        final grave = await diario.enviar(
          _registro(idAna, Intensidade.grave, em: relogio.agora()),
        );
        expect(
          grave.alerta,
          isNull,
          reason: 'só o imediatamente anterior conta',
        );
        relogio.avancar(const Duration(hours: 2));
        final consecutivo = await diario.enviar(
          _registro(idAna, Intensidade.grave, em: relogio.agora()),
        );
        expect(
          consecutivo.alerta!.regraDisparada,
          RegraAlerta.graveConsecutivo,
        );
      },
    );

    test(
      'idempotente pelo id do aparelho: sem duplicar nem 2º alerta',
      () async {
        final m = memoriaDeTeste();
        final registro = _registro(idAna, Intensidade.critica);
        final primeiro = await m.repositorios.diario.enviar(registro);
        final alertas = m.estado.alertas.length;
        final registros = m.estado.registros.length;
        final segundo = await m.repositorios.diario.enviar(registro);
        expect(segundo.registro, primeiro.registro);
        expect(segundo.alerta, primeiro.alerta);
        expect(m.estado.alertas, hasLength(alertas));
        expect(m.estado.registros, hasLength(registros));
      },
    );

    test('nenhum registro enviado é editado', () async {
      final m = memoriaDeTeste();
      final id = gerarUuidV4();
      final original = await m.repositorios.diario.enviar(
        _registro(idAna, Intensidade.leve, id: id),
      );
      final antes = m.estado.paraMapa();
      final outra = await m.repositorios.diario.enviar(
        _registro(idAna, Intensidade.critica, id: id, sintoma: 'Outro'),
      );
      expect(outra.registro, original.registro);
      expect(outra.alerta, isNull);
      expect(m.estado.paraMapa(), antes);
    });

    test('paciente inexistente: acessoNegado, nada gravado', () async {
      final m = memoriaDeTeste();
      await recusaSemGravar(
        m,
        () => m.repositorios.diario.enviar(
          _registro(gerarUuidV4(), Intensidade.leve),
        ),
        MotivoRecusa.acessoNegado,
      );
      await expectLater(
        m.repositorios.diario.registros(gerarUuidV4()),
        recusa(MotivoRecusa.acessoNegado),
      );
    });
  });

  group('sem conexão (D11, §19)', () {
    test('crítica fica na fila: sem alerta e equipe não avisada', () async {
      final m = memoriaDeTeste();
      await _semConexao(m, sem: true);
      expect(m.repositorios.demonstracao.semConexao, isTrue);
      final alertas = m.estado.alertas.length;
      final r = await m.repositorios.diario.enviar(
        _registro(idAna, Intensidade.critica),
      );
      expect(r.registro.situacaoEnvio, SituacaoEnvio.naFila);
      expect(r.enviado, isFalse);
      expect(r.alerta, isNull);
      expect(r.equipeAvisada, isFalse);
      expect(m.estado.alertas, hasLength(alertas));
      expect(m.estado.registros.containsKey(r.registro.id), isFalse);
      expect(
        await m.repositorios.diario.alertaDoRegistro(r.registro.id),
        isNull,
      );
      final lista = await m.repositorios.diario.registros(idAna);
      expect(lista.first.id, r.registro.id);
      expect(lista.first.situacaoEnvio, SituacaoEnvio.naFila);
    });

    test('já enviado, reenviado sem conexão: não volta para a fila', () async {
      final m = memoriaDeTeste();
      final registro = _registro(idAna, Intensidade.critica);
      final primeiro = await m.repositorios.diario.enviar(registro);
      await _semConexao(m, sem: true);
      final antes = m.estado.paraMapa();
      final segundo = await m.repositorios.diario.enviar(registro);
      expect(segundo.registro, primeiro.registro);
      expect(segundo.equipeAvisada, isTrue);
      expect(m.estado.fila, isEmpty);
      expect(m.estado.paraMapa(), antes);
    });

    test('enviar de novo na fila não duplica', () async {
      final m = memoriaDeTeste();
      await _semConexao(m, sem: true);
      final registro = _registro(idAna, Intensidade.leve);
      await m.repositorios.diario.enviar(registro);
      await m.repositorios.diario.enviar(registro);
      expect(m.estado.fila, hasLength(1));
    });

    test('sem conexão reenviarFila não envia', () async {
      final m = memoriaDeTeste();
      await _semConexao(m, sem: true);
      await m.repositorios.diario.enviar(_registro(idAna, Intensidade.critica));
      expect(await m.repositorios.diario.reenviarFila(), isEmpty);
      expect(m.estado.fila, hasLength(1));
      final lista = await m.repositorios.diario.registros(idAna);
      expect(lista.first.situacaoEnvio, SituacaoEnvio.naFila);
    });

    test('religar reenvia a fila: a crítica vira enviada e o alerta nasce '
        'ao religar', () async {
      final m = memoriaDeTeste();
      final relogio = m.relogio as RelogioFixo;
      await _semConexao(m, sem: true);
      final critica = _registro(idAna, Intensidade.critica);
      final naFila = await m.repositorios.diario.enviar(critica);
      expect(naFila.equipeAvisada, isFalse);
      relogio.avancar(const Duration(minutes: 40));

      await _semConexao(m, sem: false);
      expect(m.estado.fila, isEmpty);
      final depois = (await m.repositorios.diario.registros(idAna)).first;
      expect(depois.id, critica.id);
      expect(depois.situacaoEnvio, SituacaoEnvio.enviado);
      final alerta = await m.repositorios.diario.alertaDoRegistro(critica.id);
      expect(alerta, isNotNull, reason: 'o alerta nasce ao religar');
      expect(alerta!.regraDisparada, RegraAlerta.intensidadeCritica);
      expect(alerta.emitidoEm, relogio.agora());
      expect(m.estado.alertasDoProfissional(idHelena), contains(alerta));
      expect(await m.repositorios.diario.reenviarFila(), isEmpty);
    });

    test('religar reenvia dois registros na ordem do aparelho', () async {
      final m = memoriaDeTeste();
      final relogio = m.relogio as RelogioFixo;
      await _semConexao(m, sem: true);
      // João: grave ontem. Na fila: moderada e, uma hora depois, grave.
      final moderada = _registro(idJoao, Intensidade.moderada);
      relogio.avancar(const Duration(hours: 1));
      final grave = _registro(idJoao, Intensidade.grave, em: relogio.agora());
      await m.repositorios.diario.enviar(moderada);
      await m.repositorios.diario.enviar(grave);
      final recebidos = m.estado.registros.length;

      await _semConexao(m, sem: false);
      expect(m.estado.fila, isEmpty);
      expect(m.estado.registros.keys.skip(recebidos), [moderada.id, grave.id]);
      expect(
        m.estado.registros[grave.id]!.situacaoEnvio,
        SituacaoEnvio.enviado,
      );
      // Na ordem, o grave vem depois da moderada: sem alerta. Fora de ordem,
      // viria logo depois do grave de ontem e dispararia.
      expect(await m.repositorios.diario.alertaDoRegistro(moderada.id), isNull);
      expect(await m.repositorios.diario.alertaDoRegistro(grave.id), isNull);
    });

    test(
      'reenviarFila: envia na ordem e o servidor avalia a sequência',
      () async {
        final m = memoriaDeTeste();
        final relogio = m.relogio as RelogioFixo;
        await _semConexao(m, sem: true);
        // João: grave ontem. Na fila: moderada e depois grave.
        final moderada = _registro(idJoao, Intensidade.moderada);
        relogio.avancar(const Duration(hours: 1));
        final grave = _registro(idJoao, Intensidade.grave, em: relogio.agora());
        await m.repositorios.diario.enviar(moderada);
        await m.repositorios.diario.enviar(grave);
        relogio.avancar(const Duration(hours: 1));

        // A conexão volta sem passar pelo painel (que já reenviaria).
        m.semConexao = false;
        final saidos = await m.repositorios.diario.reenviarFila();
        expect(saidos.map((r) => r.registro.id), [moderada.id, grave.id]);
        expect(saidos.every((r) => r.enviado), isTrue);
        // Na ordem certa, o grave vem depois da moderada: sem alerta. Fora de
        // ordem, viria logo depois do grave de ontem e dispararia.
        expect(saidos.map((r) => r.alerta), [null, null]);
        expect(m.estado.fila, isEmpty);
        expect(await m.repositorios.diario.reenviarFila(), isEmpty);
      },
    );

    test('crítica reenviada: o alerta nasce no reenvio', () async {
      final m = memoriaDeTeste();
      final relogio = m.relogio as RelogioFixo;
      await _semConexao(m, sem: true);
      final critica = _registro(idAna, Intensidade.critica);
      await m.repositorios.diario.enviar(critica);
      relogio.avancar(const Duration(minutes: 40));
      m.semConexao = false; // sem o painel, que já reenviaria
      final saidos = await m.repositorios.diario.reenviarFila();
      final r = saidos.single;
      expect(r.equipeAvisada, isTrue);
      expect(r.alerta!.regraDisparada, RegraAlerta.intensidadeCritica);
      expect(r.alerta!.emitidoEm, relogio.agora());
      expect(r.registro.registradoEm, agoraDaMemoria);
    });

    test('envio com conexão manda antes o que estava na fila', () async {
      final m = memoriaDeTeste();
      final relogio = m.relogio as RelogioFixo;
      await _semConexao(m, sem: true);
      final naFila = _registro(idJoao, Intensidade.grave);
      await m.repositorios.diario.enviar(naFila);
      m.semConexao = false; // sem o painel, que já reenviaria
      relogio.avancar(const Duration(hours: 3));
      final novo = await m.repositorios.diario.enviar(
        _registro(idJoao, Intensidade.leve, em: relogio.agora()),
      );
      expect(novo.alerta, isNull);
      expect(m.estado.fila, isEmpty);
      final enviado = m.estado.registros[naFila.id]!;
      expect(enviado.situacaoEnvio, SituacaoEnvio.enviado);
      final alerta = await m.repositorios.diario.alertaDoRegistro(naFila.id);
      expect(alerta!.regraDisparada, RegraAlerta.graveConsecutivo);
      expect(await m.repositorios.diario.reenviarFila(), isEmpty);
    });

    test(
      'o mesmo registro reenviado com enviar sai da fila uma vez só',
      () async {
        final m = memoriaDeTeste();
        await _semConexao(m, sem: true);
        final registro = _registro(idAna, Intensidade.critica);
        await m.repositorios.diario.enviar(registro);
        m.semConexao = false; // sem o painel, que já reenviaria
        final r = await m.repositorios.diario.enviar(registro);
        expect(r.equipeAvisada, isTrue);
        expect(m.estado.fila, isEmpty);
        expect(
          m.estado.alertas.values.where((a) => a.registroId == registro.id),
          hasLength(1),
        );
      },
    );
  });

  test('registros do mais recente para o mais antigo', () async {
    final m = memoriaDeTeste();
    final lista = await m.repositorios.diario.registros(idAna);
    expect(lista, hasLength(13));
    for (var i = 1; i < lista.length; i++) {
      expect(lista[i - 1].registradoEm.isAfter(lista[i].registradoEm), isTrue);
    }
    expect(lista.every((r) => r.pacienteId == idAna), isTrue);
  });
}
