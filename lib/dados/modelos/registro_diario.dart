import 'package:flutter/foundation.dart';

import '../conversao_mapa.dart';
import '../enums/adesao.dart';
import '../enums/intensidade.dart';
import '../enums/motivo_da_retirada.dart';
import '../enums/situacao_envio.dart';

/// Quanto cabe em cada texto do diário, como no contrato do portal.
const int limiteDoTextoDoDiario = 2000;

/// As quatro respostas do diário, como o corpo de `POST /portal/diario`
/// (`EsquemaEntradaDoDiario`; quadro 18e): só a [adesao] é obrigatória.
///
/// Texto vazio ou só de espaços vale "sem resposta" (`null`), e o texto vai
/// sem os espaços das pontas, como o `montarEntrada` do portal.
@immutable
class EntradaDoDiario {
  EntradaDoDiario({
    required this.adesao,
    String? sintomas,
    this.intensidadeSintoma,
    String? observacoes,
  }) : sintomas = _texto(sintomas),
       observacoes = _texto(observacoes);

  static String? _texto(String? texto) {
    final limpo = texto?.trim();
    return limpo == null || limpo.isEmpty ? null : limpo;
  }

  final Adesao adesao;

  /// "Aconteceu alguma coisa que você queira contar?" (opcional).
  final String? sintomas;

  /// "O quanto isso atrapalhou o dia?" (opcional).
  final Intensidade? intensidadeSintoma;

  /// "Quer deixar mais alguma observação?" (opcional).
  final String? observacoes;

  @override
  bool operator ==(Object other) =>
      other is EntradaDoDiario &&
      other.adesao == adesao &&
      other.sintomas == sintomas &&
      other.intensidadeSintoma == intensidadeSintoma &&
      other.observacoes == observacoes;

  @override
  int get hashCode =>
      Object.hash(adesao, sintomas, intensidadeSintoma, observacoes);
}

/// Uma versão de um registro ("Ver a versão 1", quadro 18e;
/// `EsquemaVersaoDoDiarioNoPortal`). Corrigir guarda a versão anterior aqui
/// e cria a nova: nada se perde (R04 do Terae).
@immutable
class VersaoDoRegistro {
  VersaoDoRegistro({
    required this.versao,
    required DateTime enviadaEm,
    required this.adesao,
    this.sintomas,
    this.intensidadeSintoma,
    this.observacoes,
  }) : enviadaEm = enviadaEm.toUtc();

  factory VersaoDoRegistro.fromMap(Mapa mapa) => VersaoDoRegistro(
    versao: lerCampo<int>(mapa, 'versao'),
    enviadaEm: lerInstante(mapa, 'enviadaEm'),
    adesao: lerEnum(mapa, 'adesao', Adesao.values),
    sintomas: lerOpcional<String>(mapa, 'sintomas'),
    intensidadeSintoma: _intensidade(mapa, 'intensidadeSintoma'),
    observacoes: lerOpcional<String>(mapa, 'observacoes'),
  );

  final int versao;

  /// Quando esta versão foi enviada (a 1, o relato; as outras, a correção).
  final DateTime enviadaEm;
  final Adesao adesao;
  final String? sintomas;
  final Intensidade? intensidadeSintoma;
  final String? observacoes;

  Mapa toMap() => {
    'versao': versao,
    'enviadaEm': escreverInstante(enviadaEm),
    'adesao': adesao.name,
    'sintomas': sintomas,
    'intensidadeSintoma': intensidadeSintoma?.name,
    'observacoes': observacoes,
  };

  @override
  bool operator ==(Object other) =>
      other is VersaoDoRegistro &&
      other.versao == versao &&
      other.enviadaEm == enviadaEm &&
      other.adesao == adesao &&
      other.sintomas == sintomas &&
      other.intensidadeSintoma == intensidadeSintoma &&
      other.observacoes == observacoes;

  @override
  int get hashCode => Object.hash(
    versao,
    enviadaEm,
    adesao,
    sintomas,
    intensidadeSintoma,
    observacoes,
  );
}

/// O motivo de retirar um registro (quadro 18f): a categoria e, em "Outro",
/// o detalhe curto (obrigatório nele, até 300 caracteres).
@immutable
class RetiradaDoRegistro {
  RetiradaDoRegistro({required this.categoria, String? detalhe})
    : detalhe = categoria == MotivoDaRetirada.outro ? detalhe?.trim() : null;

  factory RetiradaDoRegistro.fromMap(Mapa mapa) {
    final valor = lerCampo<String>(mapa, 'categoria');
    final categoria =
        MotivoDaRetirada.doValor(valor) ??
        (throw FormatException('Categoria de retirada inválida', valor));
    return RetiradaDoRegistro(
      categoria: categoria,
      detalhe: lerOpcional<String>(mapa, 'detalhe'),
    );
  }

  final MotivoDaRetirada categoria;

  /// Só em [MotivoDaRetirada.outro].
  final String? detalhe;

  /// A mensagem do que falta, ou `null` se o motivo vale (a regra do
  /// `EsquemaRetirarRegistroDoDiario`).
  String? get problema {
    if (categoria != MotivoDaRetirada.outro) return null;
    final texto = detalhe ?? '';
    if (texto.isEmpty) return 'Conte em poucas palavras por que retirar.';
    if (texto.length > MotivoDaRetirada.detalheMaximo) {
      return 'Use até ${MotivoDaRetirada.detalheMaximo} caracteres.';
    }
    return null;
  }

  Mapa toMap() => {'categoria': categoria.valor, 'detalhe': detalhe};

  @override
  bool operator ==(Object other) =>
      other is RetiradaDoRegistro &&
      other.categoria == categoria &&
      other.detalhe == detalhe;

  @override
  int get hashCode => Object.hash(categoria, detalhe);
}

/// A situação que a família lê na lista (`SITUACOES_DO_REGISTRO_NO_PORTAL`).
enum SituacaoDoRegistro { enviado, revisado, retirado }

/// O dado que o aplicativo produz: o diário da família, igual ao do portal
/// (RFM03; P3; quadros 18e e 18f; `RegistroDoDiarioNoPortal`).
///
/// O [id] é UUID gerado no aparelho (`gerarUuidV4`), o que permite criar sem
/// rede e reenviar sem duplicar (e é a `Idempotency-Key` da fonte Terae
/// local). [situacaoEnvio] sustenta a fila "Guardar e enviar depois";
/// enquanto `naFila`, nenhuma tela diz que a equipe foi avisada.
///
/// D17 revista (P3) — corrigir cria a versão seguinte ([versao], com as
/// anteriores em [versoesAnteriores]) e retirar marca [retiradoEm] com o
/// motivo: nada é apagado (§23). As duas só valem enquanto a terapeuta não
/// revisou ([revisadoEm]) e o registro não avisou a equipe
/// ([alertouAEquipe]); a regra mora em `dados/regras/diario.dart`.
@immutable
class RegistroDiario {
  RegistroDiario({
    required this.id,
    required this.pacienteId,
    required DateTime registradoEm,
    required this.adesao,
    this.sintomas,
    this.intensidadeSintoma,
    this.observacoes,
    required this.situacaoEnvio,
    this.versao = 1,
    DateTime? enviadoEm,
    DateTime? atualizadoEm,
    this.alertouAEquipe = false,
    DateTime? revisadoEm,
    DateTime? retiradoEm,
    this.motivoDaRetirada,
    List<VersaoDoRegistro> versoesAnteriores = const [],
  }) : registradoEm = registradoEm.toUtc(),
       enviadoEm = enviadoEm?.toUtc(),
       atualizadoEm = atualizadoEm?.toUtc(),
       revisadoEm = revisadoEm?.toUtc(),
       retiradoEm = retiradoEm?.toUtc(),
       versoesAnteriores = List.unmodifiable(versoesAnteriores) {
    if (versao < 1 || this.versoesAnteriores.length != versao - 1) {
      throw FormatException('Versões do registro não conferem', id);
    }
    if ((this.retiradoEm == null) != (motivoDaRetirada == null)) {
      throw FormatException('Retirada sem motivo (ou motivo sem data)', id);
    }
  }

  /// Lê o mapa do registro. Aceita também o registro das A3/A4 (sem
  /// `sintomas`: `sintomaPredominante`, `intensidade`, `observacao` e
  /// `excluidoEm`), para o documento que ficou no Firebase antes da semente
  /// nova: o sintoma escolhido vira o texto contado, e o excluído vira
  /// retirado com o motivo "Outro".
  factory RegistroDiario.fromMap(Mapa mapa) {
    if (!mapa.containsKey('sintomas') &&
        mapa.containsKey('sintomaPredominante')) {
      return _doMapaAntigo(mapa);
    }
    final motivo = mapa['motivoDaRetirada'];
    return RegistroDiario(
      id: lerCampo<String>(mapa, 'id'),
      pacienteId: lerCampo<String>(mapa, 'pacienteId'),
      registradoEm: lerInstante(mapa, 'registradoEm'),
      adesao: lerEnum(mapa, 'adesao', Adesao.values),
      sintomas: lerOpcional<String>(mapa, 'sintomas'),
      intensidadeSintoma: _intensidade(mapa, 'intensidadeSintoma'),
      observacoes: lerOpcional<String>(mapa, 'observacoes'),
      situacaoEnvio: lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values),
      versao: lerOpcional<int>(mapa, 'versao') ?? 1,
      enviadoEm: lerInstanteOpcional(mapa, 'enviadoEm'),
      atualizadoEm: lerInstanteOpcional(mapa, 'atualizadoEm'),
      alertouAEquipe: lerOpcional<bool>(mapa, 'alertouAEquipe') ?? false,
      revisadoEm: lerInstanteOpcional(mapa, 'revisadoEm'),
      retiradoEm: lerInstanteOpcional(mapa, 'retiradoEm'),
      motivoDaRetirada: switch (motivo) {
        null => null,
        final Map<String, Object?> m => RetiradaDoRegistro.fromMap(m),
        final Map<Object?, Object?> m => RetiradaDoRegistro.fromMap({
          for (final MapEntry(:key, :value) in m.entries) '$key': value,
        }),
        _ => throw FormatException('motivoDaRetirada inválido', motivo),
      },
      versoesAnteriores: lerMapas(
        mapa,
        'versoesAnteriores',
        VersaoDoRegistro.fromMap,
      ),
    );
  }

  static RegistroDiario _doMapaAntigo(Mapa mapa) {
    final registradoEm = lerInstante(mapa, 'registradoEm');
    final excluidoEm = lerInstanteOpcional(mapa, 'excluidoEm');
    final situacao = lerEnum(mapa, 'situacaoEnvio', SituacaoEnvio.values);
    return RegistroDiario(
      id: lerCampo<String>(mapa, 'id'),
      pacienteId: lerCampo<String>(mapa, 'pacienteId'),
      registradoEm: registradoEm,
      adesao: lerEnum(mapa, 'adesao', Adesao.values),
      sintomas: lerOpcional<String>(mapa, 'sintomaPredominante'),
      intensidadeSintoma: _intensidade(mapa, 'intensidade'),
      observacoes: lerOpcional<String>(mapa, 'observacao'),
      situacaoEnvio: situacao,
      enviadoEm: situacao == SituacaoEnvio.enviado ? registradoEm : null,
      atualizadoEm: lerInstanteOpcional(mapa, 'atualizadoEm'),
      retiradoEm: excluidoEm,
      motivoDaRetirada: excluidoEm == null ? null : retiradaDoAppAntigo,
    );
  }

  /// O motivo dado ao registro excluído antes da P3 (D17 antiga), quando ele
  /// passa a retirado.
  static final RetiradaDoRegistro retiradaDoAppAntigo = RetiradaDoRegistro(
    categoria: MotivoDaRetirada.outro,
    detalhe: 'Excluído no app antes da mudança do diário.',
  );

  final String id;
  final String pacienteId;

  /// Quando a família escreveu o registro no aparelho (o `guardadoEm` do
  /// corpo da API, se ele esperou na fila).
  final DateTime registradoEm;
  final Adesao adesao;
  final String? sintomas;
  final Intensidade? intensidadeSintoma;
  final String? observacoes;
  final SituacaoEnvio situacaoEnvio;

  /// 1 na criação; cada correção é uma versão nova.
  final int versao;

  /// Quando o servidor recebeu o registro; `null` enquanto está na fila.
  final DateTime? enviadoEm;

  /// Quando a versão vigente foi feita (a correção); `null` na versão 1.
  final DateTime? atualizadoEm;

  /// O registro avisou a equipe (RF14/§7.1): a lista diz "A equipe foi
  /// avisada", e ele não muda mais.
  final bool alertouAEquipe;

  /// Quando a terapeuta revisou; só a clínica escreve.
  final DateTime? revisadoEm;

  /// A retirada pela família, com o motivo; nada é apagado.
  final DateTime? retiradoEm;
  final RetiradaDoRegistro? motivoDaRetirada;

  /// As versões anteriores à vigente, da 1 à `versao - 1`.
  final List<VersaoDoRegistro> versoesAnteriores;

  bool get retirado => retiradoEm != null;
  bool get revisado => revisadoEm != null;
  bool get enviado => situacaoEnvio == SituacaoEnvio.enviado;

  SituacaoDoRegistro get situacao => retirado
      ? SituacaoDoRegistro.retirado
      : revisado
      ? SituacaoDoRegistro.revisado
      : SituacaoDoRegistro.enviado;

  /// As respostas da versão vigente.
  EntradaDoDiario get entrada => EntradaDoDiario(
    adesao: adesao,
    sintomas: sintomas,
    intensidadeSintoma: intensidadeSintoma,
    observacoes: observacoes,
  );

  /// A versão vigente, no formato das anteriores.
  VersaoDoRegistro get versaoVigente => VersaoDoRegistro(
    versao: versao,
    enviadaEm: atualizadoEm ?? enviadoEm ?? registradoEm,
    adesao: adesao,
    sintomas: sintomas,
    intensidadeSintoma: intensidadeSintoma,
    observacoes: observacoes,
  );

  /// O que o servidor confirma: a situação de envio, quando recebeu e se o
  /// registro avisou a equipe.
  RegistroDiario copyWith({
    SituacaoEnvio? situacaoEnvio,
    DateTime? enviadoEm,
    bool? alertouAEquipe,
  }) => RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: registradoEm,
    adesao: adesao,
    sintomas: sintomas,
    intensidadeSintoma: intensidadeSintoma,
    observacoes: observacoes,
    situacaoEnvio: situacaoEnvio ?? this.situacaoEnvio,
    versao: versao,
    enviadoEm: enviadoEm ?? this.enviadoEm,
    atualizadoEm: atualizadoEm,
    alertouAEquipe: alertouAEquipe ?? this.alertouAEquipe,
    revisadoEm: revisadoEm,
    retiradoEm: retiradoEm,
    motivoDaRetirada: motivoDaRetirada,
    versoesAnteriores: versoesAnteriores,
  );

  /// D17 revista — a correção feita [em] um instante: a versão vigente vai
  /// para [versoesAnteriores] e a [entrada] vira a versão seguinte. Mantém
  /// id, paciente, `registradoEm` e `enviadoEm`.
  RegistroDiario corrigido(EntradaDoDiario entrada, {required DateTime em}) =>
      RegistroDiario(
        id: id,
        pacienteId: pacienteId,
        registradoEm: registradoEm,
        adesao: entrada.adesao,
        sintomas: entrada.sintomas,
        intensidadeSintoma: entrada.intensidadeSintoma,
        observacoes: entrada.observacoes,
        situacaoEnvio: situacaoEnvio,
        versao: versao + 1,
        enviadoEm: enviadoEm,
        atualizadoEm: em,
        alertouAEquipe: alertouAEquipe,
        revisadoEm: revisadoEm,
        versoesAnteriores: [...versoesAnteriores, versaoVigente],
      );

  /// D17 revista — a retirada feita [em] um instante, com o [motivo].
  RegistroDiario retiradoCom(
    RetiradaDoRegistro motivo, {
    required DateTime em,
  }) => RegistroDiario(
    id: id,
    pacienteId: pacienteId,
    registradoEm: registradoEm,
    adesao: adesao,
    sintomas: sintomas,
    intensidadeSintoma: intensidadeSintoma,
    observacoes: observacoes,
    situacaoEnvio: situacaoEnvio,
    versao: versao,
    enviadoEm: enviadoEm,
    atualizadoEm: atualizadoEm,
    alertouAEquipe: alertouAEquipe,
    revisadoEm: revisadoEm,
    retiradoEm: em,
    motivoDaRetirada: motivo,
    versoesAnteriores: versoesAnteriores,
  );

  Mapa toMap() => {
    'id': id,
    'pacienteId': pacienteId,
    'registradoEm': escreverInstante(registradoEm),
    'adesao': adesao.name,
    'sintomas': sintomas,
    'intensidadeSintoma': intensidadeSintoma?.name,
    'observacoes': observacoes,
    'situacaoEnvio': situacaoEnvio.name,
    'versao': versao,
    'enviadoEm': escreverInstanteOpcional(enviadoEm),
    'atualizadoEm': escreverInstanteOpcional(atualizadoEm),
    'alertouAEquipe': alertouAEquipe,
    'revisadoEm': escreverInstanteOpcional(revisadoEm),
    'retiradoEm': escreverInstanteOpcional(retiradoEm),
    'motivoDaRetirada': motivoDaRetirada?.toMap(),
    'versoesAnteriores': [for (final v in versoesAnteriores) v.toMap()],
  };

  @override
  bool operator ==(Object other) =>
      other is RegistroDiario &&
      other.id == id &&
      other.pacienteId == pacienteId &&
      other.registradoEm == registradoEm &&
      other.adesao == adesao &&
      other.sintomas == sintomas &&
      other.intensidadeSintoma == intensidadeSintoma &&
      other.observacoes == observacoes &&
      other.situacaoEnvio == situacaoEnvio &&
      other.versao == versao &&
      other.enviadoEm == enviadoEm &&
      other.atualizadoEm == atualizadoEm &&
      other.alertouAEquipe == alertouAEquipe &&
      other.revisadoEm == revisadoEm &&
      other.retiradoEm == retiradoEm &&
      other.motivoDaRetirada == motivoDaRetirada &&
      listEquals(other.versoesAnteriores, versoesAnteriores);

  @override
  int get hashCode => Object.hash(
    id,
    pacienteId,
    registradoEm,
    adesao,
    sintomas,
    intensidadeSintoma,
    observacoes,
    situacaoEnvio,
    versao,
    enviadoEm,
    atualizadoEm,
    alertouAEquipe,
    revisadoEm,
    retiradoEm,
    motivoDaRetirada,
    Object.hashAll(versoesAnteriores),
  );

  @override
  String toString() => 'RegistroDiario${toMap()}';
}

Intensidade? _intensidade(Mapa mapa, String chave) {
  final nome = lerOpcional<String>(mapa, chave);
  if (nome == null) return null;
  return Intensidade.doNome(nome) ??
      (throw FormatException('Intensidade inválida em $chave', nome));
}
