import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/uuid.dart';
import '../conversao_mapa.dart';
import '../repositorios/repositorios.dart';
import '../sincronizacao/situacao_sincronizacao.dart';
import 'autenticacao_memoria.dart';
import 'cuidadores_memoria.dart';
import 'demonstracao_memoria.dart';
import 'diario_memoria.dart';
import 'estado_memoria.dart';
import 'lembretes_memoria.dart';
import 'metas_memoria.dart';
import 'paciente_memoria.dart';
import 'presenca_memoria.dart';
import 'programa_em_casa_memoria.dart';
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

  bool _semConexao = false;

  /// D11 — falta de conexão simulada: o diário e os registros das atividades
  /// de casa vão para a fila (`naFila`). Só eles dependem dela; as demais
  /// operações seguem respondendo.
  /// Religar pelo `ControleDemonstracao` também reenvia a fila.
  bool get semConexao => _semConexao;

  set semConexao(bool valor) {
    _semConexao = valor;
    atualizarConexao();
  }

  final ValueNotifier<SituacaoSincronizacao> _conexao = ValueNotifier(
    const SituacaoSincronizacao(),
  );

  /// Para o aviso "Sem conexão" das telas (D16): a conexão simulada e o
  /// tamanho da fila.
  ValueListenable<SituacaoSincronizacao> get conexao => _conexao;

  /// Recalcula [conexao] depois de mexer na fila ou na conexão.
  void atualizarConexao() {
    _conexao.value = SituacaoSincronizacao(
      online: !_semConexao,
      pendentes:
          _estado.fila.length +
          _estado.filaCasa.length +
          _estado.filaPresenca.length,
    );
  }

  /// O estado atual (troca de instância a cada [reiniciar]).
  EstadoMemoria get estado => _estado;

  /// Os contratos, prontos para o `TeraeApp`.
  late final Repositorios repositorios = Repositorios(
    autenticacao: AutenticacaoMemoria(this),
    paciente: PacienteMemoria(this),
    diario: DiarioMemoria(this),
    cuidadores: CuidadoresMemoria(this),
    visaoCuidador: VisaoCuidadorMemoria(this),
    demonstracao: DemonstracaoMemoria(this),
    programaEmCasa: ProgramaEmCasaMemoria(this),
    presenca: PresencaMemoria(this),
    lembretes: LembretesMemoria(this),
    metas: MetasMemoria(this),
    conexao: conexao,
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
