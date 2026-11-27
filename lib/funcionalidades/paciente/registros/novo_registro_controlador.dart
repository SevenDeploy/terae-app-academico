import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/uuid.dart';
import '../diario/campos_do_diario.dart';
import '../diario/resultado_provisorio.dart';

/// Quanto o envio que não é "Muito" espera a resposta antes de abrir a TM04
/// com o registro guardado (RNFM03: resposta percebida em até 2 s).
const Duration prazoDeResposta = Duration(seconds: 2);

/// Para onde o formulário vai depois de enviar, e o que passa no `extra`.
@immutable
class DesfechoDoEnvio {
  const DesfechoDoEnvio({required this.rota, required this.resultado});

  /// `Rotas.pacienteDiarioAjuda` ou `Rotas.pacienteDiarioEnviado`.
  final String rota;
  final ResultadoEnvio resultado;
}

/// Estado da TM13 — Novo registro (P3; quadro 18e): as quatro perguntas, só
/// a primeira obrigatória (RNFM02), e o envio.
///
/// O registro nasce no aparelho com UUID próprio e `naFila`. O UUID é do
/// rascunho (§23: evita duplicidade no reenvio): nasce no primeiro envio e só
/// muda quando o registro sai do formulário. Depois de uma falha, "Tentar de
/// novo" reenvia com o mesmo UUID; um segundo toque durante o envio não
/// envia de novo.
class NovoRegistroControlador extends RespostasDoDiario {
  NovoRegistroControlador({
    required this.repositorio,
    required this.relogio,
    required this.pacienteId,
    String Function()? gerarId,
  }) : _gerarId = gerarId ?? gerarUuidV4;

  final RepositorioDiario repositorio;
  final Relogio relogio;
  final String pacienteId;
  final String Function() _gerarId;

  bool _enviando = false;
  String? _erro;

  /// UUID do registro em preenchimento; `null` até o primeiro envio.
  String? _idDoRascunho;

  bool get enviando => _enviando;

  /// Mensagem simples quando o envio falhou de um jeito inesperado.
  String? get erro => _erro;

  RegistroDiario? _montar() {
    final entrada = this.entrada();
    if (entrada == null) return null;
    return RegistroDiario(
      id: _idDoRascunho ??= _gerarId(),
      pacienteId: pacienteId,
      registradoEm: relogio.agora(),
      adesao: entrada.adesao,
      sintomas: entrada.sintomas,
      intensidadeSintoma: entrada.intensidadeSintoma,
      observacoes: entrada.observacoes,
      situacaoEnvio: SituacaoEnvio.naFila,
    );
  }

  /// "Enviar" (RFM04, RFM05).
  ///
  /// - "Muito": volta na hora com um [ResultadoProvisorio] para a TM05, sem
  ///   esperar a rede; o envio segue e a TM05 se atualiza com a resposta.
  /// - Demais: espera a resposta até [prazoDeResposta]; passado o prazo, abre
  ///   a TM04 com o provisório. Se o servidor avisou a equipe (grave depois
  ///   de grave), vai à TM05.
  ///
  /// Devolve `null` sem a primeira resposta, se já está enviando ou se o
  /// envio falhou (aí [erro] explica e o preenchimento fica).
  Future<DesfechoDoEnvio?> enviar() async {
    if (_enviando) return null;
    final registro = _montar();
    if (registro == null) return null;
    // Future.sync: um repositório que lança na hora vira falha do futuro.
    final definitivo = Future.sync(() => repositorio.enviar(registro));
    // A falha de um envio de "Muito" já em segundo plano não pode estourar.
    definitivo.ignore();

    if (registro.intensidadeSintoma?.ehCritico ?? false) {
      _sair();
      return DesfechoDoEnvio(
        rota: Rotas.pacienteDiarioAjuda,
        resultado: ResultadoProvisorio(
          registro: registro,
          definitivo: definitivo,
        ),
      );
    }
    return _esperar(registro, definitivo);
  }

  /// "Guardar e enviar depois" (sem internet; 19d do portal): o registro vai
  /// para a fila deste aparelho e a TM04 diz que ele ainda não foi enviado.
  Future<DesfechoDoEnvio?> guardar() async {
    if (_enviando) return null;
    final registro = _montar();
    if (registro == null) return null;
    final definitivo = Future.sync(() => repositorio.enviar(registro));
    definitivo.ignore();
    return _esperar(registro, definitivo);
  }

  Future<DesfechoDoEnvio?> _esperar(
    RegistroDiario registro,
    Future<ResultadoEnvio> definitivo,
  ) async {
    _enviando = true;
    _erro = null;
    avisar();
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
      avisar();
      return null;
    }
    _enviando = false;
    _sair();
    return DesfechoDoEnvio(
      rota: resultado.equipeAvisada
          ? Rotas.pacienteDiarioAjuda
          : Rotas.pacienteDiarioEnviado,
      resultado: resultado,
    );
  }

  /// O registro saiu do formulário: o próximo é outro (outro UUID).
  void _sair() {
    _idDoRascunho = null;
    _erro = null;
    limpar();
  }
}
