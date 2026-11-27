import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../conversao_mapa.dart';
import 'falhas_remotas.dart';

/// O Cloud Firestore do projeto acadêmico `terae-app-academico` (D12) — nunca
/// o banco do Terae produção. Concentra os caminhos das coleções e a leitura
/// com prazo; os repositórios persistentes montam os modelos com `fromMap`.
///
/// Coleções (D12; regras de acesso em `firestore.rules`):
/// - `contas/{uid}` — ContaUsuario, uid do Firebase Authentication;
/// - `pacientes/{pid}` — dados que o cuidador também vê (sem CPF nem
///   nascimento), com `cuidadoresAtivos` (uids);
/// - `pacientes/{pid}/privado/identificacao` — CPF e nascimento (só o
///   titular);
/// - `pacientes/{pid}/{registros|alertas|agendamentos|receitas|itensMedicacao
///   |marcos|convites}` — o que é do paciente (P3: o registro do diário
///   leva a versão vigente, as anteriores em `versoesAnteriores`, a revisão
///   da clínica e a retirada com motivo, num documento só);
/// - `pacientes/{pid}/{agendaCuidador|receitaCuidador|itensCuidador|
///   avisosCuidador}` — as cópias reduzidas do cuidador (RNFM05);
/// - `convites/{codigo}` — o código de primeiro acesso, com o CPF e o
///   nascimento só como hash (`cpfHash`, `nascimentoHash`);
/// - `vinculos/{id}`, `consentimentos/{id}`, `profissionais/{id}`.
class FonteFirestore {
  FonteFirestore(this.db, {this.prazo = prazoDoServidor});

  final FirebaseFirestore db;
  final Duration prazo;

  CollectionReference<Mapa> get contas => db.collection('contas');
  CollectionReference<Mapa> get pacientes => db.collection('pacientes');
  CollectionReference<Mapa> get convites => db.collection('convites');
  CollectionReference<Mapa> get vinculos => db.collection('vinculos');
  CollectionReference<Mapa> get consentimentos =>
      db.collection('consentimentos');
  CollectionReference<Mapa> get profissionais => db.collection('profissionais');

  DocumentReference<Mapa> paciente(String pid) => pacientes.doc(pid);

  DocumentReference<Mapa> identificacao(String pid) =>
      pacientes.doc(pid).collection('privado').doc('identificacao');

  /// Subcoleção [nome] do paciente [pid].
  CollectionReference<Mapa> doPaciente(String pid, String nome) =>
      pacientes.doc(pid).collection(nome);

  /// Lê um documento com prazo; `null` se não existe.
  Future<Mapa?> ler(DocumentReference<Mapa> ref) => comPrazo(() async {
    final doc = await ref.get();
    return doc.data();
  }, prazo: prazo);

  /// Lê uma consulta com prazo; os mapas vêm na ordem do servidor.
  Future<List<Mapa>> listar(Query<Mapa> consulta) => comPrazo(() async {
    final r = await consulta.get();
    return [for (final d in r.docs) d.data()];
  }, prazo: prazo);

  /// Grava um lote com prazo: confirma tudo junto ou nada (D18).
  Future<void> gravar(WriteBatch lote) => comPrazo(lote.commit, prazo: prazo);
}

/// Hash com que o convite público guarda o CPF e o nascimento (D12): só quem
/// tem o código e o dado consegue conferir, e o documento não expõe nenhum
/// dos dois. A semente (`ferramentas/semear-firebase.mjs`) usa a mesma conta.
String hashDoConvite(String codigo, String valor) =>
    sha256.convert(utf8.encode('$codigo:$valor')).toString();
