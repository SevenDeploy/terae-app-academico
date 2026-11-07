import 'package:flutter/widgets.dart';

import '../../../dados/enums/adesao_em_casa.dart';
import '../../../dados/enums/quem_registrou.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/modelos/registro_de_atividade.dart';
import '../../../dados/regras/programa_em_casa.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Estado da TM17 Atividade (evolução de TO, F1; D26): a atividade, o
/// registro de hoje (registrar, corrigir, desfazer) e os últimos 14 dias.
class AtividadeControlador extends ChangeNotifier {
  AtividadeControlador({
    required this.programa,
    required this.paciente,
    required this.relogio,
    required this.pacienteId,
    required this.atividadeId,
    required this.quem,
  });

  final RepositorioProgramaEmCasa programa;
  final RepositorioPaciente paciente;
  final Relogio relogio;
  final String pacienteId;
  final String atividadeId;

  /// Quem conta como foi (D24): o titular ou quem cuida.
  final QuemRegistrou quem;

  /// "Quer contar como foi?" — opcional.
  final TextEditingController reflexao = TextEditingController();

  bool _carregando = true;
  bool _falhou = false;
  bool _naoEncontrada = false;
  bool _descartado = false;
  AtividadeDeCasa? _atividade;
  String _profissional = '';
  List<RegistroDeAtividade> _registros = const [];
  AdesaoEmCasa? _adesao;
  bool _corrigindo = false;
  bool _salvando = false;
  String? _erro;
  String? _mensagem;

  bool get carregando => _carregando;
  bool get falhou => _falhou;

  /// A atividade não existe, não é deste paciente ou foi encerrada.
  bool get naoEncontrada => _naoEncontrada;
  AtividadeDeCasa? get atividade => _atividade;
  String get profissional => _profissional;
  AdesaoEmCasa? get adesao => _adesao;
  bool get corrigindo => _corrigindo;
  bool get salvando => _salvando;

  /// Falha ao registrar ou desfazer, em linguagem simples.
  String? get erro => _erro;

  /// O que aconteceu depois de registrar ou desfazer (para o leitor de tela).
  String? get mensagem => _mensagem;

  DataCivil get hoje => DataCivil.hoje(relogio);

  RegistroDeAtividade? get registroDeHoje =>
      registroDoDia(_registros, atividadeId, hoje);

  /// O formulário aparece sem registro hoje, ou ao corrigir.
  bool get mostrarFormulario => registroDeHoje == null || _corrigindo;

  bool get podeRegistrar => _adesao != null && !_salvando;

  /// "Esta semana: 2 de 3".
  int get vezesEstaSemana => vezesNaSemana(_registros, atividadeId, hoje);

  List<DiaDaFaixa> get faixa =>
      faixaDeDias(_registros, hoje, atividadeId: atividadeId);

  /// Os dias anteriores com algo contado, do mais recente ao mais antigo.
  List<RegistroDeAtividade> get historico => [
    for (final r in _registros)
      if (r.dia != hoje && r.reflexao != null) r,
  ];

  Future<void> carregar() async {
    _carregando = true;
    _falhou = false;
    _naoEncontrada = false;
    _avisar();
    try {
      final atividade = await programa.atividade(pacienteId, atividadeId);
      _atividade = atividade;
      await _lerRegistros();
      try {
        _profissional = (await paciente.profissional(atividade.profissionalId))
            .nome;
      } on Object {
        _profissional = '';
      }
    } on RecusaDeRegra catch (r) {
      if (r.motivo == MotivoRecusa.atividadeInexistente) {
        _naoEncontrada = true;
      } else {
        _falhou = true;
      }
    } on Object {
      _falhou = true;
    }
    _carregando = false;
    _avisar();
  }

  Future<void> _lerRegistros() async {
    final todos = await programa.registros(pacienteId, dias: diasDaFaixa);
    _registros = [
      for (final r in todos)
        if (r.atividadeId == atividadeId) r,
    ];
  }

  void escolherAdesao(AdesaoEmCasa adesao) {
    _adesao = adesao;
    _erro = null;
    _avisar();
  }

  /// Reabre o formulário com a resposta de hoje.
  void corrigir() {
    final r = registroDeHoje;
    if (r == null) return;
    _corrigindo = true;
    _adesao = r.adesao;
    reflexao.text = r.reflexao ?? '';
    _mensagem = null;
    _erro = null;
    _avisar();
  }

  void cancelarCorrecao() {
    _corrigindo = false;
    _limparFormulario();
    _avisar();
  }

  Future<void> registrar() async {
    final adesao = _adesao;
    if (adesao == null || _salvando) return;
    _salvando = true;
    _erro = null;
    _mensagem = null;
    _avisar();
    try {
      final r = await programa.registrar(
        pacienteId: pacienteId,
        atividadeId: atividadeId,
        adesao: adesao,
        reflexao: reflexao.text,
        quem: quem,
      );
      final corrigiu = _corrigindo;
      await _lerRegistros();
      _corrigindo = false;
      _limparFormulario();
      _mensagem = r.situacaoEnvio == SituacaoEnvio.naFila
          ? 'Registrado, sem conexão agora.'
          : corrigiu
          ? 'Correção registrada.'
          : 'Registrado. Obrigado por contar!';
    } on RecusaDeRegra catch (r) {
      _erro = r.motivo.mensagem;
    } on Object {
      _erro = 'Não foi possível registrar agora. Tente de novo.';
    }
    _salvando = false;
    _avisar();
  }

  Future<void> desfazer() async {
    final r = registroDeHoje;
    if (r == null || _salvando) return;
    _salvando = true;
    _erro = null;
    _mensagem = null;
    _avisar();
    try {
      await programa.desfazer(pacienteId, r.id);
      await _lerRegistros();
      _corrigindo = false;
      _limparFormulario();
      _mensagem = 'Registro de hoje desfeito.';
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.motivo.mensagem;
    } on Object {
      _erro = 'Não foi possível desfazer agora. Tente de novo.';
    }
    _salvando = false;
    _avisar();
  }

  void _limparFormulario() {
    _adesao = null;
    reflexao.clear();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    reflexao.dispose();
    super.dispose();
  }
}
