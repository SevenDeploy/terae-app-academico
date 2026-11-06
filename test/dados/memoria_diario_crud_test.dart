/// CRUD do diário na memória (Atividade 4: D13, D17) — a mesma regra que a
/// persistência real segue, usada pela web e pelos testes de tela.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/regras/diario.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'memoria_apoio.dart';

RegistroDiario _deHoje(String id, {Intensidade i = Intensidade.leve}) =>
    RegistroDiario(
      id: id,
      pacienteId: idAna,
      registradoEm: instanteNaClinica(2026, 10, 2, 8),
      adesao: Adesao.total,
      intensidade: i,
      sintomaPredominante: 'Cansaço',
      situacaoEnvio: SituacaoEnvio.naFila,
    );

const String _id = 'f0000000-0000-4000-8000-000000000001';
const String _deOntem = 'dd000000-0000-4000-8000-000000000013';

void main() {
  group('regras puras (D17)', () {
    test('podeAlterar: só no mesmo dia da clínica e nunca o excluído', () {
      final r = _deHoje(_id);
      expect(podeAlterar(r, instanteNaClinica(2026, 10, 2, 23, 59)), isTrue);
      expect(podeAlterar(r, instanteNaClinica(2026, 10, 3, 0, 1)), isFalse);
      expect(
        podeAlterar(r.excluidoAs(agoraDaMemoria), agoraDaMemoria),
        isFalse,
      );
    });

    test('busca sem acento nem maiúscula', () {
      expect(normalizarBusca('  Cansaço À NOITE '), 'cansaco a noite');
      final r = _deHoje(_id);
      expect(passaNoFiltro(r, texto: 'CANSACO'), isTrue);
      expect(passaNoFiltro(r, intensidades: {Intensidade.grave}), isFalse);
      expect(passaNoFiltro(r.excluidoAs(agoraDaMemoria)), isFalse);
    });

    test('toMap/fromMap levam atualizadoEm e excluidoEm', () {
      final r = _deHoje(_id)
          .corrigido(
            adesao: Adesao.parcial,
            intensidade: Intensidade.grave,
            sintomaPredominante: 'Dor',
            observacao: null,
            em: agoraDaMemoria,
          )
          .excluidoAs(agoraDaMemoria);
      expect(RegistroDiario.fromMap(r.toMap()), r);
      expect(r.toMap()['excluidoEm'], '2026-10-02T14:00:00.000Z');
    });
  });

  group('memória', () {
    test(
      'buscar e registros escondem o excluído; registro ainda o acha',
      () async {
        final m = memoriaDeTeste();
        final d = m.repositorios.diario;
        await d.enviar(_deHoje(_id));
        expect(await d.registros(idAna), hasLength(14));
        await d.excluir(_id);
        expect(await d.registros(idAna), hasLength(13));
        expect((await d.registro(_id)).excluido, isTrue);
        expect(await d.buscar(idAna, texto: 'sono'), hasLength(2));
      },
    );

    test('corrigir sem conexão fica na fila e sai ao religar', () async {
      final m = memoriaDeTeste();
      final d = m.repositorios.diario;
      await d.enviar(_deHoje(_id));
      m.semConexao = true;
      final r = await d.atualizar(
        (await d.registro(_id)).corrigido(
          adesao: Adesao.nenhuma,
          intensidade: Intensidade.critica,
          sintomaPredominante: 'Dor',
          observacao: 'Piorou',
          em: agoraDaMemoria,
        ),
      );
      expect(r.enviado, isFalse);
      expect(r.equipeAvisada, isFalse);
      expect(m.conexao.value.pendentes, 1);
      expect(
        (await d.registros(idAna)).first.situacaoEnvio,
        SituacaoEnvio.naFila,
      );
      await m.repositorios.demonstracao.definirSemConexao(semConexao: false);
      expect(await d.alertaDoRegistro(_id), isNotNull);
      expect(m.conexao.value.pendentes, 0);
    });

    test('registro de outro dia recusa edicaoEncerrada sem gravar', () async {
      final m = memoriaDeTeste();
      await recusaSemGravar(
        m,
        () => m.repositorios.diario.excluir(_deOntem),
        MotivoRecusa.edicaoEncerrada,
      );
      await recusaSemGravar(
        m,
        () => m.repositorios.diario.registro('nao-existe'),
        MotivoRecusa.registroInexistente,
      );
    });

    test('alerta já emitido não some nem duplica ao corrigir', () async {
      final m = memoriaDeTeste();
      final d = m.repositorios.diario;
      final primeiro = await d.enviar(_deHoje(_id, i: Intensidade.critica));
      final corrigido = await d.atualizar(
        (await d.registro(_id)).corrigido(
          adesao: Adesao.total,
          intensidade: Intensidade.leve,
          sintomaPredominante: 'Cansaço',
          observacao: null,
          em: agoraDaMemoria,
        ),
      );
      expect(corrigido.alerta, primeiro.alerta);
      expect(
        m.estado.alertas.values.where((a) => a.registroId == _id),
        hasLength(1),
      );
    });
  });
}
