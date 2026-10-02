import 'package:flutter/foundation.dart';

import '../modelos/convite_acesso.dart';
import '../modelos/vinculo_cuidador.dart';

/// No máximo dois VinculoCuidador pendentes ou ativos por paciente (§7.4).
const int limiteCuidadores = 2;

/// Um cuidador na lista da TM07: o vínculo e o convite que o originou (o
/// código a repassar enquanto pendente).
@immutable
class CuidadorAutorizado {
  const CuidadorAutorizado({required this.vinculo, required this.convite});

  final VinculoCuidador vinculo;
  final ConviteAcesso convite;
}

/// Cuidadores do paciente (RFM07; TM07): convidar e revogar, com limite de
/// dois que soma pendentes e ativos (UC02, §7.4). Nada é apagado.
abstract interface class RepositorioCuidadores {
  /// Todos os vínculos do paciente (pendentes, ativos e revogados), os mais
  /// recentes primeiro. O contador "x/2" conta os de
  /// `SituacaoVinculo.contaNoLimite`.
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId);

  /// Convida por nome e CPF: cria ConviteAcesso (tipo cuidador, com validade)
  /// e VinculoCuidador pendente, sem conta. Recusa: `cpfInvalido`,
  /// `cpfJaConvidado`, `limiteDeCuidadores`.
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  });

  /// Revoga: situação `revogado` e `revogadoEm`. Num convite pendente, o
  /// código deixa de valer (a TM10 recusa com `conviteRevogado`).
  Future<CuidadorAutorizado> revogar(String vinculoId);
}
