import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/linha_de_cuidado.dart';

/// Centro do modelo; no aplicativo é somente leitura (RF07): cadastrar,
/// alterar e inativar é ato da clínica, e o app só liga a conta ao registro
/// na TM09. CPF único e inativação lógica por [ativo] (R03).
///
/// RNFM05 — na cópia que vai para o aparelho do cuidador ([paraCuidador]),
/// [cpf] e [dataNascimento] vêm nulos; por isso são anuláveis aqui. Na cópia
/// do paciente/família os dois estão sempre preenchidos.
@immutable
class Paciente {
  Paciente({
    required this.id,
    this.contaId,
    required this.profissionalRefId,
    required this.nome,
    this.cpf,
    this.dataNascimento,
    required this.ativo,
    Set<LinhaDeCuidado> linhasDeCuidado = linhasPadrao,
    this.nomeDaClinica,
    this.telefoneDaClinica,
    this.agendaLiberada,
  }) : linhasDeCuidado = _conferirLinhas(linhasDeCuidado);

  factory Paciente.fromMap(Mapa mapa) => Paciente(
    id: lerCampo<String>(mapa, 'id'),
    contaId: lerOpcional<String>(mapa, 'contaId'),
    profissionalRefId: lerCampo<String>(mapa, 'profissionalRefId'),
    nome: lerCampo<String>(mapa, 'nome'),
    cpf: lerOpcional<String>(mapa, 'cpf'),
    dataNascimento: lerDataCivilOpcional(mapa, 'dataNascimento'),
    ativo: lerCampo<bool>(mapa, 'ativo'),
    linhasDeCuidado: mapa['linhasDeCuidado'] == null
        ? linhasPadrao
        : lerEnums(mapa, 'linhasDeCuidado', LinhaDeCuidado.values).toSet(),
    nomeDaClinica: lerOpcional<String>(mapa, 'nomeDaClinica'),
    telefoneDaClinica: lerOpcional<String>(mapa, 'telefoneDaClinica'),
    agendaLiberada: lerOpcional<bool>(mapa, 'agendaLiberada'),
  );

  /// D21 — paciente sem linha gravada (dados das Atividades 3 e 4, cópias
  /// locais antigas) é do acompanhamento clínico, como era o app até ali.
  static const Set<LinhaDeCuidado> linhasPadrao = {
    LinhaDeCuidado.acompanhamentoClinico,
  };

  static Set<LinhaDeCuidado> _conferirLinhas(Set<LinhaDeCuidado> linhas) {
    if (linhas.isEmpty) {
      throw ArgumentError.value(linhas, 'linhasDeCuidado', 'vazia');
    }
    return Set.unmodifiable(linhas);
  }

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

  /// D21 — o que o paciente faz na clínica (nunca vazio). Decide as abas e o
  /// Início; vai também na cópia do cuidador, que não traz conteúdo clínico.
  final Set<LinhaDeCuidado> linhasDeCuidado;

  /// A clínica que atende o paciente, como o `GET /portal/eu` a manda no
  /// Terae local ("Terça, 10 de novembro · Clínica Raízes"). Nula no Firebase.
  final String? nomeDaClinica;

  /// Telefone da clínica (`telefoneDaClinica` do `/eu`), para "Falar com a
  /// clínica". Nulo no Firebase, onde vale o número fictício da demonstração.
  final String? telefoneDaClinica;

  /// Se a clínica liberou a agenda no portal para esta conta (`agendaLiberada`
  /// do `/eu`). `null` no Firebase, onde a agenda sempre vale. Com `false`, a
  /// agenda não está "vazia": a clínica ainda não a liberou.
  final bool? agendaLiberada;

  /// Tem receita e remédios (TM02, TM06, TM11).
  bool get temAcompanhamentoClinico =>
      linhasDeCuidado.contains(LinhaDeCuidado.acompanhamentoClinico);

  /// Tem a aba "Em casa" (TM16).
  bool get temTerapiaOcupacional =>
      linhasDeCuidado.contains(LinhaDeCuidado.terapiaOcupacional);

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
    linhasDeCuidado: linhasDeCuidado,
    nomeDaClinica: nomeDaClinica,
    telefoneDaClinica: telefoneDaClinica,
    agendaLiberada: agendaLiberada,
  );

  /// RNFM05 — cópia para o aparelho do cuidador: sem CPF, sem data de
  /// nascimento e sem a conta do paciente, que nenhuma tela dele mostra.
  Paciente paraCuidador() => Paciente(
    id: id,
    profissionalRefId: profissionalRefId,
    nome: nome,
    ativo: ativo,
    linhasDeCuidado: linhasDeCuidado,
    nomeDaClinica: nomeDaClinica,
    telefoneDaClinica: telefoneDaClinica,
    agendaLiberada: agendaLiberada,
  );

  Mapa toMap() => {
    'id': id,
    'contaId': contaId,
    'profissionalRefId': profissionalRefId,
    'nome': nome,
    'cpf': cpf,
    'dataNascimento': dataNascimento?.paraIso(),
    'ativo': ativo,
    'linhasDeCuidado': [
      for (final linha in LinhaDeCuidado.values)
        if (linhasDeCuidado.contains(linha)) linha.name,
    ],
    // Só quando existem: o mapa do Firebase e do SQLite não muda.
    if (nomeDaClinica != null) 'nomeDaClinica': nomeDaClinica,
    if (telefoneDaClinica != null) 'telefoneDaClinica': telefoneDaClinica,
    if (agendaLiberada != null) 'agendaLiberada': agendaLiberada,
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
      other.ativo == ativo &&
      other.nomeDaClinica == nomeDaClinica &&
      other.telefoneDaClinica == telefoneDaClinica &&
      other.agendaLiberada == agendaLiberada &&
      setEquals(other.linhasDeCuidado, linhasDeCuidado);

  @override
  int get hashCode => Object.hash(
    id,
    contaId,
    profissionalRefId,
    nome,
    cpf,
    dataNascimento,
    ativo,
    Object.hashAllUnordered(linhasDeCuidado),
    nomeDaClinica,
    telefoneDaClinica,
    agendaLiberada,
  );

  @override
  String toString() => 'Paciente${toMap()}';
}
