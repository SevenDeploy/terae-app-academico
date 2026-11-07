import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/uuid.dart';
import 'resultado_provisorio.dart';

export 'campos_do_diario.dart' show sintomasDoDiario;

/// Quanto o envio não crítico espera a resposta antes de abrir a TM04 com o
/// registro guardado (RNFM03: resposta percebida em até 2 s).
const Duration prazoDeResposta = Duration(seconds: 2);

/// Para onde o diário vai depois de enviar, e o que passa no `extra`.
@immutable
class DesfechoDoEnvio {
  const DesfechoDoEnvio({required this.rota, required this.resultado});

  /// `Rotas.pacienteDiarioAjuda` (crítica) ou `Rotas.pacienteDiarioEnviado`.
  final String rota;
  final ResultadoEnvio resultado;
}

/// Estado do formulário da TM03 Diário (RFM03, RFM04, RNFM02).
///
/// Três escolhas obrigatórias (adesão, intensidade e sintoma) e a observação
/// opcional: nenhum texto livre é exigido, e o envio cabe em cinco toques a
/// partir do Início. O controlador vive na aba Diário, então o preenchimento
/// sobrevive à troca de aba (§21).
///
/// No envio, o registro nasce no aparelho com UUID próprio e `naFila`; o
/// formulário é limpo antes de navegar (voltar nunca reabre o preenchido) e
/// um segundo toque durante o envio não envia de novo.
///
/// O UUID é do rascunho (§23: evita duplicidade no reenvio): nasce no
/// primeiro envio e só muda quando o registro sai do formulário — resposta do
/// repositório, ou TM04/TM05 com o provisório, que reenviam o mesmo registro
/// — ou quando o formulário é limpo. Depois de uma falha, "Tentar de novo"
/// reenvia com o mesmo UUID.
class DiarioControlador extends ChangeNotifier {
  DiarioControlador({
    required this.repositorio,
    required this.relogio,
    required this.pacienteId,
    String Function()? gerarId,
    this.adesaoQueFalta = 'os remédios',
    this.sintomaQueFalta = 'o sintoma',
  }) : _gerarId = gerarId ?? gerarUuidV4;

  final RepositorioDiario repositorio;
  final Relogio relogio;
  final String pacienteId;
  final String Function() _gerarId;

  /// Como a dica chama a adesão que falta ("os remédios" ou, só com TO, "a
  /// rotina").
  final String adesaoQueFalta;

  /// Como a dica chama o sintoma que falta ("o sintoma" ou, só com TO, "o
  /// que mais pesou").
  final String sintomaQueFalta;

  /// Observação livre, opcional.
  final TextEditingController observacao = TextEditingController();

  Adesao? _adesao;
  Intensidade? _intensidade;
  String? _sintoma;
  bool _enviando = false;
  String? _erro;
  bool _descartado = false;

  /// UUID do registro em preenchimento; `null` até o primeiro envio.
  String? _idDoRascunho;

  Adesao? get adesao => _adesao;
  Intensidade? get intensidade => _intensidade;
  String? get sintoma => _sintoma;
  bool get enviando => _enviando;

  /// Mensagem simples quando o envio falhou de um jeito inesperado.
  String? get erro => _erro;

  bool get completo =>
      _adesao != null && _intensidade != null && _sintoma != null;

  bool get podeEnviar => completo && !_enviando;

  /// O que ainda falta escolher, para a dica abaixo do botão.
  List<String> get faltando => [
    if (_adesao == null) adesaoQueFalta,
    if (_intensidade == null) 'a intensidade',
    if (_sintoma == null) sintomaQueFalta,
  ];

  void escolherAdesao(Adesao valor) {
    _adesao = valor;
    _erro = null;
    _avisar();
  }

  void escolherIntensidade(Intensidade valor) {
    _intensidade = valor;
    _erro = null;
    _avisar();
  }

  void escolherSintoma(String valor) {
    _sintoma = valor;
    _erro = null;
    _avisar();
  }

  /// Envia o registro e diz para onde ir (RFM04, RFM05).
  ///
  /// - Crítica: volta na hora com um [ResultadoProvisorio] para a TM05, sem
  ///   esperar a rede; o envio segue e a TM05 se atualiza com a resposta.
  /// - Demais: espera a resposta até [prazoDeResposta]; passado o prazo, abre
  ///   a TM04 com o provisório ("será enviado quando houver conexão").
  ///
  /// Devolve `null` se o formulário não está completo, se já está enviando ou
  /// se o envio não crítico falhou (aí [erro] explica e o preenchimento fica).
  Future<DesfechoDoEnvio?> enviar() async {
    final adesao = _adesao;
    final intensidade = _intensidade;
    final sintoma = _sintoma;
    if (_enviando || adesao == null || intensidade == null || sintoma == null) {
      return null;
    }
    final texto = observacao.text.trim();
    final registro = RegistroDiario(
      id: _idDoRascunho ??= _gerarId(),
      pacienteId: pacienteId,
      registradoEm: relogio.agora(),
      adesao: adesao,
      intensidade: intensidade,
      sintomaPredominante: sintoma,
      observacao: texto.isEmpty ? null : texto,
      situacaoEnvio: SituacaoEnvio.naFila,
    );
    // Future.sync: um repositório que lança na hora vira falha do futuro.
    final definitivo = Future.sync(() => repositorio.enviar(registro));
    // A falha de um envio crítico já em segundo plano não pode estourar.
    definitivo.ignore();

    if (intensidade.ehCritica) {
      limpar();
      return DesfechoDoEnvio(
        rota: Rotas.pacienteDiarioAjuda,
        resultado: ResultadoProvisorio(
          registro: registro,
          definitivo: definitivo,
        ),
      );
    }

    _enviando = true;
    _erro = null;
    _avisar();
    ResultadoEnvio resultado;
    try {
      resultado = await definitivo.timeout(prazoDeResposta);
    } on TimeoutException {
      resultado = ResultadoProvisorio(
        registro: registro,
        definitivo: definitivo,
      );
    } catch (_) {
      _enviando = false;
      _erro =
          'Não foi possível guardar seu registro agora. '
          'Tente de novo em instantes.';
      _avisar();
      return null;
    }
    _enviando = false;
    limpar();
    return DesfechoDoEnvio(
      rota: Rotas.pacienteDiarioEnviado,
      resultado: resultado,
    );
  }

  /// Volta o formulário ao começo, com um rascunho novo (outro UUID).
  void limpar() {
    _idDoRascunho = null;
    _adesao = null;
    _intensidade = null;
    _sintoma = null;
    _erro = null;
    observacao.clear();
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    observacao.dispose();
    super.dispose();
  }
}
