import 'package:flutter/foundation.dart';

import '../../../dados/lembretes/lembrete.dart';
import '../../../dados/repositorios/lembretes_repositorio.dart';

/// Estado da TM19 Lembretes (evolução de TO, F2; D28): as escolhas, o pedido
/// de permissão do Android e os próximos lembretes agendados.
class LembretesControlador extends ChangeNotifier {
  LembretesControlador({
    required this.lembretes,
    required this.pacienteIds,
    required this.temTerapiaOcupacional,
  });

  final RepositorioLembretes lembretes;

  /// Os pacientes da conta (perfis paciente/família) cujos compromissos
  /// entram nos lembretes.
  final List<String> pacienteIds;

  /// Mostra a opção das atividades de casa.
  final bool temTerapiaOcupacional;

  bool _carregando = true;
  bool _salvando = false;
  bool _descartado = false;
  PreferenciasDeLembrete _preferencias = const PreferenciasDeLembrete();
  List<Lembrete> _agendados = const [];
  String? _mensagem;
  bool _semPermissao = false;

  bool get carregando => _carregando;
  bool get salvando => _salvando;
  PreferenciasDeLembrete get preferencias => _preferencias;
  List<Lembrete> get agendados => _agendados;

  /// O que aconteceu depois de salvar ou testar (para o leitor de tela).
  String? get mensagem => _mensagem;

  /// O Android recusou a permissão de notificação.
  bool get semPermissao => _semPermissao;

  /// O Android já deixa mostrar notificações (some o texto do motivo).
  bool get permissaoConcedida => _permissaoConcedida;
  bool _permissaoConcedida = false;

  static const String _falhou =
      'Não foi possível mexer nos lembretes agora. Tente de novo.';

  Future<void> carregar() async {
    try {
      _preferencias = await lembretes.preferencias();
      _permissaoConcedida = await lembretes.notificacoesPermitidas();
      _agendados = await lembretes.reagendar(pacienteIds);
    } on Object catch (erro) {
      // Sem os próximos, a tela ainda deixa escolher e salvar.
      debugPrint('TM19: lembretes não lidos: $erro');
    }
    _carregando = false;
    _avisar();
  }

  void mudar(PreferenciasDeLembrete novas) {
    _preferencias = novas;
    _mensagem = null;
    _avisar();
  }

  Future<void> salvar() async {
    if (_salvando) return;
    _salvando = true;
    _mensagem = null;
    _avisar();
    try {
      await lembretes.salvar(_preferencias);
      if (_preferencias.algumLigado) await _pedirPermissao();
      _agendados = await lembretes.reagendar(pacienteIds);
      _mensagem = !_preferencias.algumLigado
          ? 'Lembretes desligados.'
          : _semPermissao
          ? null
          : 'Lembretes salvos.';
    } on Object catch (erro) {
      debugPrint('TM19: lembretes não salvos: $erro');
      _mensagem = _falhou;
    }
    _salvando = false;
    _avisar();
  }

  Future<void> _pedirPermissao() async {
    _semPermissao = !await lembretes.pedirPermissao();
    _permissaoConcedida = !_semPermissao;
  }

  Future<void> testar() async {
    _mensagem = null;
    try {
      await _pedirPermissao();
      if (!_semPermissao) {
        await lembretes.testar();
        _mensagem =
            'Lembrete de teste enviado. Ele aparece na barra de notificações.';
      }
    } on Object catch (erro) {
      debugPrint('TM19: lembrete de teste falhou: $erro');
      _mensagem = _falhou;
    }
    _avisar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
