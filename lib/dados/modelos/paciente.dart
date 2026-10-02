import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';

/// Centro do modelo; no aplicativo é somente leitura (RF07): cadastrar,
/// alterar e inativar é ato da clínica, e o app só liga a conta ao registro
/// na TM09. CPF único e inativação lógica por [ativo] (R03).
///
/// RNFM05 — na cópia que vai para o aparelho do cuidador ([paraCuidador]),
/// [cpf] e [dataNascimento] vêm nulos; por isso são anuláveis aqui. Na cópia
/// do paciente/família os dois estão sempre preenchidos.
@immutable
class Paciente {
  const Paciente({
    required this.id,
    this.contaId,
    required this.profissionalRefId,
    required this.nome,
    this.cpf,
    this.dataNascimento,
    required this.ativo,
  });

  factory Paciente.fromMap(Mapa mapa) => Paciente(
    id: lerCampo<String>(mapa, 'id'),
    contaId: lerOpcional<String>(mapa, 'contaId'),
    profissionalRefId: lerCampo<String>(mapa, 'profissionalRefId'),
    nome: lerCampo<String>(mapa, 'nome'),
    cpf: lerOpcional<String>(mapa, 'cpf'),
    dataNascimento: lerDataCivilOpcional(mapa, 'dataNascimento'),
    ativo: lerCampo<bool>(mapa, 'ativo'),
  );

  final String id;

  /// Conta que dá acesso a este paciente (titular ou responsável legal). Nula
  /// até ativar o acesso na TM09 — um Paciente tem no máximo uma conta.
  final String? contaId;

  /// Profissional de referência, avisado na ajuda imediata (TM05).
  final String profissionalRefId;
  final String nome;

  /// Só os 11 dígitos. Nulo na cópia do cuidador (RNFM05).
  final String? cpf;

  /// Nula na cópia do cuidador (RNFM05).
  final DataCivil? dataNascimento;

  /// Inativação lógica: nada é apagado.
  final bool ativo;

  /// Primeiro nome, para a saudação (TM02, TM08).
  String get primeiroNome => nome.split(' ').first;

  /// O que o app muda: a ligação com a conta (TM09). A clínica muda [ativo].
  Paciente copyWith({String? contaId, bool? ativo}) => Paciente(
    id: id,
    contaId: contaId ?? this.contaId,
    profissionalRefId: profissionalRefId,
    nome: nome,
    cpf: cpf,
    dataNascimento: dataNascimento,
    ativo: ativo ?? this.ativo,
  );

  /// RNFM05 — cópia para o aparelho do cuidador: sem CPF, sem data de
  /// nascimento e sem a conta do paciente, que nenhuma tela dele mostra.
  Paciente paraCuidador() => Paciente(
    id: id,
    profissionalRefId: profissionalRefId,
    nome: nome,
    ativo: ativo,
  );

  Mapa toMap() => {
    'id': id,
    'contaId': contaId,
    'profissionalRefId': profissionalRefId,
    'nome': nome,
    'cpf': cpf,
    'dataNascimento': dataNascimento?.paraIso(),
    'ativo': ativo,
  };

  @override
  bool operator ==(Object other) =>
      other is Paciente &&
      other.id == id &&
      other.contaId == contaId &&
      other.profissionalRefId == profissionalRefId &&
      other.nome == nome &&
      other.cpf == cpf &&
      other.dataNascimento == dataNascimento &&
      other.ativo == ativo;

  @override
  int get hashCode => Object.hash(
    id,
    contaId,
    profissionalRefId,
    nome,
    cpf,
    dataNascimento,
    ativo,
  );

  @override
  String toString() => 'Paciente${toMap()}';
}
