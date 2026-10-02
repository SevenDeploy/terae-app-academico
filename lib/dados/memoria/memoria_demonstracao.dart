import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/uuid.dart';
import '../conversao_mapa.dart';
import '../repositorios/repositorios.dart';
import 'autenticacao_memoria.dart';
import 'cuidadores_memoria.dart';
import 'demonstracao_memoria.dart';
import 'diario_memoria.dart';
import 'estado_memoria.dart';
import 'paciente_memoria.dart';
import 'regras.dart';
import 'visao_cuidador_memoria.dart';

/// Implementação em memória de todos os contratos (§22), sobre um estado
/// único carregado de `assets/dados/demonstracao.json`.
///
/// Nesta etapa sem servidor, o "servidor simulado" é a própria memória: ela
/// confere os códigos, cria os alertas e guarda o que foi enviado; a fila do
/// aparelho fica em [EstadoMemoria.fila]. Nada persiste (D6): fechar o app
/// volta aos dados de demonstração. "Agora" vem só do [relogio] (D7) e as
/// datas relativas do JSON são resolvidas no fuso da clínica ao carregar e ao
/// reiniciar (D9).
class MemoriaDemonstracao {
  /// [dados] no formato de `demonstracao.json` (o teste passa o mapa direto);
  /// guarda uma cópia, de onde [reiniciar] recarrega.
  /// [latencia] simula a ida ao servidor em cada chamada; zero em teste.
  MemoriaDemonstracao({
    required Mapa dados,
    required this.relogio,
    this.latencia = Duration.zero,
    Random? aleatorio,
  }) : _dados = lerDemonstracao(jsonEncode(dados)),
       _aleatorio = aleatorio ?? Random.secure() {
    _estado = _carregar();
  }

  /// Lê `demonstracao.json` do pacote de assets ([pacote], por padrão o
  /// `rootBundle`).
  static Future<MemoriaDemonstracao> carregar({
    required Relogio relogio,
    AssetBundle? pacote,
    Duration latencia = latenciaDoApp,
  }) async {
    final texto = await (pacote ?? rootBundle).loadString(caminhoDoAsset);
    return MemoriaDemonstracao(
      dados: lerDemonstracao(texto),
      relogio: relogio,
      latencia: latencia,
    );
  }

  static const String caminhoDoAsset = 'assets/dados/demonstracao.json';

  /// Latência curta no app, para a tela mostrar o "carregando" (≤ 300 ms).
  static const Duration latenciaDoApp = Duration(milliseconds: 200);

  final Relogio relogio;
  final Duration latencia;
  final Mapa _dados;
  final Random _aleatorio;
  late EstadoMemoria _estado;

  /// D11 — falta de conexão simulada: o diário vai para a fila (`naFila`).
  /// Só o diário depende dela; as demais operações seguem respondendo.
  /// Religar pelo `ControleDemonstracao` também reenvia a fila.
  bool semConexao = false;

  /// O estado atual (troca de instância a cada [reiniciar]).
  EstadoMemoria get estado => _estado;

  /// Os seis contratos, prontos para o `TeraeApp`.
  late final Repositorios repositorios = Repositorios(
    autenticacao: AutenticacaoMemoria(this),
    paciente: PacienteMemoria(this),
    diario: DiarioMemoria(this),
    cuidadores: CuidadoresMemoria(this),
    visaoCuidador: VisaoCuidadorMemoria(this),
    demonstracao: DemonstracaoMemoria(this),
  );

  EstadoMemoria _carregar() =>
      EstadoMemoria.daDemonstracao(_dados, hoje: DataCivil.hoje(relogio));

  DateTime agora() => relogio.agora();

  DataCivil hoje() => DataCivil.hoje(relogio);

  /// UUID v4 novo (§23: identificadores são UUID).
  String novoId() => gerarUuidV4(aleatorio: _aleatorio);

  /// Código de convite novo, único entre todos os convites.
  String novoCodigo() =>
      gerarCodigoConvite(_aleatorio, existentes: _estado.codigos);

  /// Simula a ida ao servidor. Com latência zero não agenda timer.
  Future<void> esperar() => latencia == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latencia);

  /// D11 — volta aos dados iniciais (datas relativas ao hoje do relógio) e
  /// religa a conexão.
  void reiniciar() {
    _estado = _carregar();
    semConexao = false;
  }
}
