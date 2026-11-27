import 'package:flutter/foundation.dart';

import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';

/// A frase de quando a lista não abre (quadro 18e, "Carregando e erro").
const String diarioNaoAbriu =
    'Não conseguimos abrir o diário agora. Confira a internet e tente de novo.';

/// Estado da TM03 — Diário (P3; quadro 18e): a lista dos registros, de 30 em
/// 30, e os guardados neste aparelho. Lê só pelo [RepositorioDiario].
class DiarioControlador extends ChangeNotifier {
  DiarioControlador({required this.repositorio, required this.pacienteId});

  final RepositorioDiario repositorio;
  final String pacienteId;

  List<RegistroDiario> _registros = const [];
  List<RegistroDiario> _pendentes = const [];
  bool _haMais = false;
  bool _carregando = true;
  bool _carregandoMais = false;
  bool _enviandoPendentes = false;
  bool _retirou = false;
  String? _erro;
  String? _erroDosAntigos;
  bool _descartado = false;

  /// Os que chegaram ao servidor, do mais novo ao mais antigo.
  List<RegistroDiario> get registros => _registros;

  /// "Guardados neste aparelho", do mais antigo ao mais novo.
  List<RegistroDiario> get pendentes => _pendentes;

  /// Liga o "Ver registros mais antigos".
  bool get haMais => _haMais;
  bool get carregando => _carregando;
  bool get carregandoMais => _carregandoMais;
  bool get enviandoPendentes => _enviandoPendentes;

  /// Mostra "Registro retirado. Ele continua na lista…".
  bool get retirou => _retirou;
  String? get erro => _erro;
  String? get erroDosAntigos => _erroDosAntigos;

  /// Lê a primeira página e os pendentes (de novo, depois de uma mudança).
  Future<void> carregar() async {
    _carregando = _registros.isEmpty && _pendentes.isEmpty;
    _erro = null;
    _avisar();
    try {
      final pagina = await repositorio.pagina(pacienteId);
      _pendentes = await repositorio.pendentes(pacienteId);
      _registros = pagina.registros;
      _haMais = pagina.haMais;
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.motivo == MotivoRecusa.acessoNegado
          ? recusa.mensagem
          : diarioNaoAbriu;
    } on Exception {
      _erro = diarioNaoAbriu;
    }
    _carregando = false;
    _avisar();
  }

  /// "Ver registros mais antigos": a página seguinte, a partir do último.
  Future<void> verMaisAntigos() async {
    if (_carregandoMais || !_haMais || _registros.isEmpty) return;
    _carregandoMais = true;
    _erroDosAntigos = null;
    _avisar();
    try {
      final pagina = await repositorio.pagina(
        pacienteId,
        antes: regra.momentoNaLista(_registros.last),
      );
      _registros = List.unmodifiable([..._registros, ...pagina.registros]);
      _haMais = pagina.haMais;
    } on Exception {
      _erroDosAntigos = diarioNaoAbriu;
    }
    _carregandoMais = false;
    _avisar();
  }

  /// "Enviar agora": tenta a fila deste aparelho e relê.
  Future<void> enviarPendentes() async {
    if (_enviandoPendentes) return;
    _enviandoPendentes = true;
    _avisar();
    try {
      await repositorio.reenviarFila();
    } on Exception {
      // O que não saiu continua guardado; a lista diz isso.
    }
    _enviandoPendentes = false;
    await carregar();
  }

  /// A folha de retirar confirmou: mostra o aviso e relê.
  Future<void> aoRetirar() async {
    _retirou = true;
    await carregar();
  }

  /// Ao abrir outra ação, o aviso da retirada some.
  void esquecerRetirada() {
    if (!_retirou) return;
    _retirou = false;
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
