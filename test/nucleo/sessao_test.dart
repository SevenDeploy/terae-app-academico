import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';

import '../apoio/dubles.dart';

void main() {
  late Sessao sessao;
  late int avisos;

  setUp(() {
    sessao = Sessao();
    avisos = 0;
    sessao.addListener(() => avisos++);
  });

  test('começa sem sessão', () {
    expect(sessao.autenticada, isFalse);
    expect(sessao.conta, isNull);
    expect(sessao.perfis, isEmpty);
    expect(sessao.perfilAtivo, isNull);
  });

  test('um perfil só já fica ativo ao entrar', () {
    sessao.entrar(vinculosAna());
    expect(sessao.autenticada, isTrue);
    expect(sessao.conta?.id, 'c-ana');
    expect(sessao.perfis, hasLength(1));
    expect(sessao.perfilAtivo?.papel, Papel.pacienteFamilia);
    expect(sessao.perfilAtivo?.pacienteId, 'p-ana');
    expect(sessao.temVariosPerfis, isFalse);
    expect(avisos, 1);
  });

  test('perfil cuidador vem da cópia sem CPF nem nascimento', () {
    sessao.entrar(vinculosRegina());
    final perfil = sessao.perfilAtivo!;
    expect(perfil.papel, Papel.cuidador);
    expect(perfil.paciente.cpf, isNull);
    expect(perfil.paciente.dataNascimento, isNull);
  });

  test('vários perfis: nenhum ativo até escolher; família antes, por nome', () {
    sessao.entrar(vinculosMistos());
    expect(sessao.perfilAtivo, isNull);
    expect(sessao.temVariosPerfis, isTrue);
    expect(sessao.perfis.map((p) => p.papel), [
      Papel.pacienteFamilia,
      Papel.cuidador,
    ]);

    sessao.entrar(vinculosPatricia());
    expect(sessao.perfis.map((p) => p.paciente.nome), [
      'Laura Andrade Neves',
      'Miguel Andrade Neves',
    ]);
    sessao.escolherPerfil(sessao.perfis.last);
    expect(sessao.perfilAtivo?.pacienteId, 'p-miguel');
  });

  test('paciente inativo não vira perfil; conta sem perfil é recusada', () {
    final v = vinculosPatricia();
    final soMiguel = VinculosDaConta(
      conta: v.conta,
      pacientes: [v.pacientes.first, v.pacientes.last.copyWith(ativo: false)],
    );
    expect(Sessao.perfisDe(soMiguel), hasLength(1));
    expect(
      () => sessao.entrar(VinculosDaConta(conta: v.conta)),
      throwsStateError,
    );
    expect(sessao.autenticada, isFalse);
  });

  test('escolher perfil de outra conta é erro', () {
    sessao.entrar(vinculosPatricia());
    final alheio = Sessao.perfisDe(vinculosRegina()).single;
    expect(() => sessao.escolherPerfil(alheio), throwsArgumentError);
  });

  test('trocar perfil desativa só em conta de vários perfis', () {
    sessao.entrar(vinculosAna());
    sessao.trocarPerfil();
    expect(sessao.perfilAtivo, isNotNull);

    sessao.entrar(vinculosPatricia());
    sessao.escolherPerfil(sessao.perfis.first);
    sessao.trocarPerfil();
    expect(sessao.perfilAtivo, isNull);
    expect(sessao.autenticada, isTrue);
  });

  test('sair limpa tudo e avisa', () {
    sessao.entrar(vinculosAna());
    sessao.sair();
    expect(sessao.autenticada, isFalse);
    expect(sessao.perfis, isEmpty);
    expect(sessao.perfilAtivo, isNull);
    expect(avisos, 2);
  });
}
