/// Apoio dos testes da implementação em memória: o `demonstracao.json` de
/// verdade, um relógio parado e os ids, códigos e CPFs das personas.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/conversao_mapa.dart';
import 'package:terae_app/dados/memoria/estado_memoria.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/nucleo/tempo/data_civil.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

/// 2/10/2026 10:00 em Cuiabá (14:00Z).
DateTime get agoraDaMemoria => instanteNaClinica(2026, 10, 2, 10);

/// O mapa de `assets/dados/demonstracao.json` (o teste roda na raiz).
Mapa dadosDaDemonstracao() => lerDemonstracao(
  File(MemoriaDemonstracao.caminhoDoAsset).readAsStringSync(),
);

/// Memória sem latência, com [dados] (padrão: a demonstração) e o relógio
/// parado em [agoraDaMemoria] se nenhum for passado.
MemoriaDemonstracao memoriaDeTeste({Mapa? dados, RelogioFixo? relogio}) =>
    MemoriaDemonstracao(
      dados: dados ?? dadosDaDemonstracao(),
      relogio: relogio ?? RelogioFixo(agoraDaMemoria),
    );

/// Lista mutável de uma coleção do mapa, para montar cenários de teste.
List<Object?> colecao(Mapa dados, String chave) =>
    dados[chave]! as List<Object?>;

/// O item da coleção com este `id`, para alterar no cenário.
Mapa itemDe(Mapa dados, String chave, String id) =>
    colecao(dados, chave).cast<Mapa>().firstWhere((m) => m['id'] == id);

String _id(String prefixo, int n) =>
    '$prefixo-0000-4000-8000-${n.toString().padLeft(12, '0')}';

// Profissionais
final String idHelena = _id('d0000000', 1);
final String idLarissa = _id('d0000000', 2);
final String idTiago = _id('d0000000', 3);

// Contas
final String contaAna = _id('c0000000', 1);
final String contaPatricia = _id('c0000000', 2);
final String contaRegina = _id('c0000000', 3);
final String contaAntonio = _id('c0000000', 4);

// Pacientes
final String idAna = _id('a0000000', 1);
final String idMiguel = _id('a0000000', 2);
final String idLaura = _id('a0000000', 3);
final String idJoao = _id('a0000000', 4);
final String idAntonio = _id('a0000000', 5);

// Vínculos e receitas
final String vinculoRegina = _id('b0000000', 1);
final String vinculoPaulo = _id('b0000000', 2);
final String conviteJoao = _id('e0000000', 7);
final String receitaAna = _id('e1000000', 1);
final String receitaJoao = _id('e1000000', 2);

// Códigos (TM09, TM10)
const String codigoJoao = 'K7M4QX';
const String codigoJoaoExpirado = 'H3T9WB';
const String codigoAnaUsado = 'R2D8NZ';
const String codigoLauraUsado = 'F6W3HY';
const String codigoReginaUsado = 'G8B5VA';
const String codigoPaulo = 'P4X9RC';

// CPFs fictícios com dígito verificador válido
const String cpfAna = '41850372608';
const String cpfJoao = '58304921642';
const String cpfRegina = '60937184500';
const String cpfPaulo = '84712056371';
const List<String> cpfsLivres = [
  '35196840206',
  '19273560407',
  '92540671802',
  '47618203903',
  '63805729103',
];

final DataCivil nascimentoJoao = DataCivil(1999, 7, 19);

/// E-mail de cada persona da demonstração (as que têm conta e as que ainda
/// vão criar o acesso no primeiro acesso).
const Map<String, String> emailDe = {
  'Ana Lúcia Martins': 'ana.lucia.martins@exemplo.test',
  'Patrícia Andrade Neves': 'patricia.neves@exemplo.test',
  'Regina Martins': 'regina.martins@exemplo.test',
  'Antônio Carlos Ribeiro': 'antonio.ribeiro@exemplo.test',
  'João Pedro Assis': 'joao.pedro.assis@exemplo.test',
  'Paulo Martins': 'paulo.martins@exemplo.test',
};

/// O acesso (D14) da persona pelo nome, com a senha de demonstração. Para
/// quem já tem conta, é o e-mail e a senha dela; para João e Paulo, o acesso
/// que eles criam no passo 4.
NovoAcesso identidadeDe(MemoriaDemonstracao m, String nome) =>
    NovoAcesso(nome: nome, email: emailDe[nome]!, senha: senhaDeDemonstracao);

/// Acesso de quem não tem nada na demonstração (senha de fixture).
const NovoAcesso identidadeNova = NovoAcesso(
  nome: 'Pessoa Nova',
  email: 'pessoa.nova@exemplo.test',
  senha: 'senha-de-teste-nova',
);

/// Entra com o e-mail e a senha do [acesso] (D14).
extension EntrarComAcesso on RepositorioAutenticacao {
  Future<VinculosDaConta> entrarCom(NovoAcesso acesso) =>
      entrar(email: acesso.email, senha: acesso.senha);
}

/// Espera a recusa com este [motivo].
Matcher recusa(MotivoRecusa motivo) =>
    throwsA(isA<RecusaDeRegra>().having((r) => r.motivo, 'motivo', motivo));

/// Confere que [acao] recusa com [motivo] e não grava nada no estado.
Future<void> recusaSemGravar(
  MemoriaDemonstracao m,
  Future<Object?> Function() acao,
  MotivoRecusa motivo,
) async {
  final antes = m.estado.paraMapa();
  await expectLater(acao(), recusa(motivo));
  expect(m.estado.paraMapa(), antes);
}
