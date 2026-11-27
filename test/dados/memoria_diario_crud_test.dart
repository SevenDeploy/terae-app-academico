/// Corrigir e retirar na memória (P3, D17 revista: o diário igual ao do
/// portal) — a mesma regra que a persistência real segue, usada pela web e
/// pelos testes de tela.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/motivo_da_retirada.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'memoria_apoio.dart';

RegistroDiario _novo(String id, {Intensidade? i = Intensidade.leve}) =>
    RegistroDiario(
      id: id,
      pacienteId: idAna,
      registradoEm: agoraDaMemoria,
      adesao: Adesao.total,
      sintomas: 'Cansada à tarde.',
      intensidadeSintoma: i,
      situacaoEnvio: SituacaoEnvio.naFila,
    );

const String _id = 'f0000000-0000-4000-8000-000000000001';

/// Ana na demonstração: o de ontem, corrigido e ainda sem revisão; um
/// revisado; o retirado; o que avisou a equipe.
const String _deOntem = 'dd000000-0000-4000-8000-000000000013';
const String _revisado = 'dd000000-0000-4000-8000-000000000011';
const String _retirado = 'dd000000-0000-4000-8000-000000000012';
const String _avisou = 'dd000000-0000-4000-8000-000000000002';

final RetiradaDoRegistro _diaErrado = RetiradaDoRegistro(
  categoria: MotivoDaRetirada.diaErrado,
);

void main() {
  group('corrigir', () {
    test(
      'cria a versão seguinte e guarda a anterior, em qualquer dia',
      () async {
        final m = memoriaDeTeste();
        final d = m.repositorios.diario;
        final relogio = m.relogio as RelogioFixo;
        await d.enviar(_novo(_id));
        relogio.avancar(const Duration(days: 3));
        final r = await d.corrigir(
          _id,
          EntradaDoDiario(
            adesao: Adesao.parcial,
            intensidadeSintoma: Intensidade.moderado,
            observacoes: 'Dormiu mal.',
          ),
        );
        expect(r.enviado, isTrue);
        expect(r.registro.versao, 2);
        expect(r.registro.adesao, Adesao.parcial);
        expect(r.registro.sintomas, isNull);
        expect(r.registro.atualizadoEm, relogio.agora());
        expect(r.registro.enviadoEm, agoraDaMemoria, reason: 'o 1º envio');
        final anterior = r.registro.versoesAnteriores.single;
        expect(anterior.versao, 1);
        expect(anterior.sintomas, 'Cansada à tarde.');
        expect(anterior.intensidadeSintoma, Intensidade.leve);
        expect(await d.registro(_id), r.registro);
      },
    );

    test(
      'a correção para "Muito" avisa a equipe, e depois ele não muda mais',
      () async {
        final m = memoriaDeTeste();
        final d = m.repositorios.diario;
        await d.enviar(_novo(_id));
        final r = await d.corrigir(
          _id,
          EntradaDoDiario(
            adesao: Adesao.nenhuma,
            intensidadeSintoma: Intensidade.critico,
          ),
        );
        expect(r.equipeAvisada, isTrue);
        expect(r.registro.alertouAEquipe, isTrue);
        expect(m.estado.alertasDoProfissional(idHelena), contains(r.alerta));
        await recusaSemGravar(
          m,
          () => d.corrigir(_id, EntradaDoDiario(adesao: Adesao.total)),
          MotivoRecusa.registroNaoMudaMais,
        );
      },
    );

    test('o revisado, o retirado e o que avisou a equipe recusam '
        'registroNaoMudaMais sem gravar (o 409 do portal)', () async {
      final m = memoriaDeTeste();
      for (final id in [_revisado, _retirado, _avisou]) {
        await recusaSemGravar(
          m,
          () => m.repositorios.diario.corrigir(
            id,
            EntradaDoDiario(adesao: Adesao.total),
          ),
          MotivoRecusa.registroNaoMudaMais,
        );
      }
    });

    test('o de ontem, ainda sem revisão, pode ser corrigido de novo (versão '
        '3)', () async {
      final m = memoriaDeTeste();
      final r = await m.repositorios.diario.corrigir(
        _deOntem,
        EntradaDoDiario(adesao: Adesao.total, sintomas: 'Tudo certo.'),
      );
      expect(r.registro.versao, 3);
      expect([for (final v in r.registro.versoesAnteriores) v.versao], [1, 2]);
    });

    test('sem conexão recusa semConexao e nada muda (pede internet, como no '
        'portal)', () async {
      final m = memoriaDeTeste();
      m.semConexao = true;
      await recusaSemGravar(
        m,
        () => m.repositorios.diario.corrigir(
          _deOntem,
          EntradaDoDiario(adesao: Adesao.nenhuma),
        ),
        MotivoRecusa.semConexao,
      );
    });

    test(
      'o guardado neste aparelho ainda não muda; inexistente recusa',
      () async {
        final m = memoriaDeTeste();
        final d = m.repositorios.diario;
        m.semConexao = true;
        await d.enviar(_novo(_id));
        m.semConexao = false; // sem o painel, que já reenviaria a fila
        await recusaSemGravar(
          m,
          () => d.corrigir(_id, EntradaDoDiario(adesao: Adesao.parcial)),
          MotivoRecusa.registroNaoMudaMais,
        );
        await recusaSemGravar(
          m,
          () => d.corrigir('nao-existe', EntradaDoDiario(adesao: Adesao.total)),
          MotivoRecusa.registroInexistente,
        );
        await recusaSemGravar(
          m,
          () => d.registro('nao-existe'),
          MotivoRecusa.registroInexistente,
        );
      },
    );
  });

  group('retirar', () {
    test(
      'marca a data e o motivo; continua na lista e em registro()',
      () async {
        final m = memoriaDeTeste();
        final d = m.repositorios.diario;
        final retirado = await d.retirar(
          _deOntem,
          RetiradaDoRegistro(
            categoria: MotivoDaRetirada.outro,
            detalhe:
                'Era '
                'do Miguel',
          ),
        );
        expect(retirado.retirado, isTrue);
        expect(retirado.retiradoEm, agoraDaMemoria);
        expect(retirado.motivoDaRetirada!.detalhe, 'Era do Miguel');
        expect(retirado.versao, 2, reason: 'as respostas ficam como estavam');
        final lista = (await d.pagina(idAna)).registros;
        expect(lista.firstWhere((r) => r.id == _deOntem), retirado);
        expect(await d.registro(_deOntem), retirado);
      },
    );

    test('o retirado não conta para o "grave depois de grave"', () async {
      final m = memoriaDeTeste();
      final d = m.repositorios.diario;
      final relogio = m.relogio as RelogioFixo;
      final grave = await d.enviar(_novo(_id, i: Intensidade.grave));
      expect(grave.alerta, isNull);
      await d.retirar(_id, _diaErrado);
      relogio.avancar(const Duration(hours: 1));
      final outro = await d.enviar(
        RegistroDiario(
          id: 'f0000000-0000-4000-8000-000000000002',
          pacienteId: idAna,
          registradoEm: relogio.agora(),
          adesao: Adesao.total,
          intensidadeSintoma: Intensidade.grave,
          situacaoEnvio: SituacaoEnvio.naFila,
        ),
      );
      expect(outro.alerta, isNull);
    });

    test(
      'revisado, retirado, que avisou e sem conexão recusam sem gravar',
      () async {
        final m = memoriaDeTeste();
        for (final id in [_revisado, _retirado, _avisou]) {
          await recusaSemGravar(
            m,
            () => m.repositorios.diario.retirar(id, _diaErrado),
            MotivoRecusa.registroNaoMudaMais,
          );
        }
        m.semConexao = true;
        await recusaSemGravar(
          m,
          () => m.repositorios.diario.retirar(_deOntem, _diaErrado),
          MotivoRecusa.semConexao,
        );
      },
    );
  });

  test('o alerta já emitido não some nem duplica', () async {
    final m = memoriaDeTeste();
    final d = m.repositorios.diario;
    final primeiro = await d.enviar(_novo(_id, i: Intensidade.critico));
    expect(primeiro.registro.alertouAEquipe, isTrue);
    expect(await d.alertaDoRegistro(_id), primeiro.alerta);
    await recusaSemGravar(
      m,
      () => d.retirar(_id, _diaErrado),
      MotivoRecusa.registroNaoMudaMais,
    );
    expect(
      m.estado.alertas.values.where((a) => a.registroId == _id),
      hasLength(1),
    );
  });
}
