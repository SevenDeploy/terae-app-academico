import 'package:flutter/foundation.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../enums/situacao_envio.dart';

/// Como foi uma atividade de casa num dia (evolução de TO, F1; D26): a
/// resposta a "Conseguiu fazer hoje?" e, se quiser, como foi.
///
/// No máximo um por atividade e por [dia] civil da clínica: registrar de novo
/// no mesmo dia corrige o mesmo registro (mesmo [id]). O [id] é UUID gerado
/// no aparelho, como o do diário, e [situacaoEnvio] sustenta a fila sem
/// conexão. Corrigir e desfazer só no mesmo dia; desfazer é exclusão lógica
/// ([excluidoEm]), nunca física (§23).
@immutable
class RegistroDeAtividade {
  RegistroDeAtividade({
    required this.id,
    required this.pacienteId,
    required this.atividadeId,
    required this.dia,
    required this.adesao,
    String? reflexao,
    required this.quem,
    required DateTime registradoEm,
    required this.situacaoEnvio,
    DateTime? atualizadoEm,
    DateTime? excluidoEm,
  }) : reflexao = _semVazio(reflexao),
       registradoEm = registradoEm.toUtc(),
       atualizadoEm = atualizadoEm?.toUtc(),
       excluidoEm = excluidoEm?.toUtc() {
    if ((this.reflexao?.length ?? 0) > tamanhoMaximoDaReflexao) {
      throw ArgumentError.value(reflexao?.length, 'reflexao', 'longa demais');
    }
  }

  factory RegistroDeAtividade.fromMap(Mapa mapa) => RegistroDeAtividade(
    id: lerCampo<String>(mapa, 'id'),
    pacienteId: lerCampo<String>(mapa, 'pacienteId'),
    atividadeId: lerCampo<String>(mapa, 'atividadeId'),
    dia: lerDataCivil(mapa, 'dia'),
    adesao: lerEnum(mapa, 'adesao', AdesaoEmCasa.values),
    reflexao: lerOpcional<String>(mapa, 'reflexao'),
    quem: lerEnum(mapa, 'quem', QuemRegistrou.values),
    registradoEm: lerInstante(mapa, 'registradoEm'),
    situacaoEnvio: lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values),
    atualizadoEm: lerInstanteOpcional(mapa, 'atualizadoEm'),
    excluidoEm: lerInstanteOpcional(mapa, 'excluidoEm'),
  );

  /// Como no programa em casa do Terae web.
  static const int tamanhoMaximoDaReflexao = 500;

  static String? _semVazio(String? texto) {
    final limpo = texto?.trim();
    return limpo == null || limpo.isEmpty ? null : limpo;
  }

  final String id;
  final String pacienteId;
  final String atividadeId;

  /// O dia civil da clínica a que o registro se refere.
  final DataCivil dia;
  final AdesaoEmCasa adesao;

  /// "Quer contar como foi?" — opcional, até 500 caracteres; texto em branco
  /// vira `null`.
  final String? reflexao;
  final QuemRegistrou quem;
  final DateTime registradoEm;
  final SituacaoEnvio situacaoEnvio;

  /// Última correção, no mesmo dia; `null` se nunca mudou.
  final DateTime? atualizadoEm;

  /// "Desfazer", no mesmo dia; `null` enquanto vale.
  final DateTime? excluidoEm;

  bool get excluido => excluidoEm != null;

  /// Só a situação de envio muda (`naFila` → `enviado`).
  RegistroDeAtividade copyWith({SituacaoEnvio? situacaoEnvio}) =>
      RegistroDeAtividade(
        id: id,
        pacienteId: pacienteId,
        atividadeId: atividadeId,
        dia: dia,
        adesao: adesao,
        reflexao: reflexao,
        quem: quem,
        registradoEm: registradoEm,
        situacaoEnvio: situacaoEnvio ?? this.situacaoEnvio,
        atualizadoEm: atualizadoEm,
        excluidoEm: excluidoEm,
      );

  /// A correção feita [em] um instante, no mesmo dia: nova resposta e nova
  /// reflexão; se estava desfeito, volta a valer. Volta para a fila.
  RegistroDeAtividade corrigido({
    required AdesaoEmCasa adesao,
    required String? reflexao,
    required QuemRegistrou quem,
    required DateTime em,
  }) => RegistroDeAtividade(
    id: id,
    pacienteId: pacienteId,
    atividadeId: atividadeId,
    dia: dia,
    adesao: adesao,
    reflexao: reflexao,
    quem: quem,
    registradoEm: registradoEm,
    situacaoEnvio: SituacaoEnvio.naFila,
    atualizadoEm: em,
  );

  /// "Desfazer" feito [em] um instante; volta para a fila.
  RegistroDeAtividade desfeitoAs(DateTime em) => RegistroDeAtividade(
    id: id,
    pacienteId: pacienteId,
    atividadeId: atividadeId,
    dia: dia,
    adesao: adesao,
    reflexao: reflexao,
    quem: quem,
    registradoEm: registradoEm,
    situacaoEnvio: SituacaoEnvio.naFila,
    atualizadoEm: atualizadoEm,
    excluidoEm: em,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'atividadeId': atividadeId,
    'dia': dia.paraIso(),
    'adesao': adesao.name,
    'reflexao': reflexao,
    'quem': quem.name,
    'registradoEm': escreverInstante(registradoEm),
    'situacaoEnvio': situacaoEnvio.name,
    'atualizadoEm': escreverInstanteOpcional(atualizadoEm),
    'excluidoEm': escreverInstanteOpcional(excluidoEm),
  };

  @override
  bool operator ==(Object other) =>
      other is RegistroDeAtividade &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.atividadeId == atividadeId &&
      other.dia == dia &&
      other.adesao == adesao &&
      other.reflexao == reflexao &&
      other.quem == quem &&
      other.registradoEm == registradoEm &&
      other.situacaoEnvio == situacaoEnvio &&
      other.atualizadoEm == atualizadoEm &&
      other.excluidoEm == excluidoEm;

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    atividadeId,
    dia,
    adesao,
    reflexao,
    quem,
    registradoEm,
    situacaoEnvio,
    atualizadoEm,
    excluidoEm,
  );

  @override
  String toString() => 'RegistroDeAtividade${toMap()}';
}
