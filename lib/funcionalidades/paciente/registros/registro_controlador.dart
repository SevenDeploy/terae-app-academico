import 'package:flutter/foundation.dart';

import '../../../dados/modelos/alerta.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Texto de falha que não é recusa de regra (RNFM01).
const String falhaAoCarregarRegistro =
    'Não deu para abrir este registro agora. Tente de novo em instantes.';

/// Estado da TM14 — Registro (Atividade 4: visualização e exclusão do item
/// principal, D13, D17).
class RegistroControlador extends ChangeNotifier {
  RegistroControlador({
    required this.repositorio,
    required this.relogio,
    required this.registroId,
  });

  final RepositorioDiario repositorio;
  final Relogio relogio;
  final String registroId;

  RegistroDiario? _registro;
  Alerta? _alerta;
  bool _carregando = true;
  bool _excluindo = false;
  String? _erro;
  bool _descartado = false;

  RegistroDiario? get registro => _registro;

  /// Alerta do registro, se o servidor já o confirmou e a regra disparou.
  Alerta? get alerta => _alerta;
  bool get carregando => _carregando;
  bool get excluindo => _excluindo;

  /// Recusa ou falha a mostrar, em linguagem simples.
  String? get erro => _erro;

  /// D17 — "Corrigir" e "Excluir" só no mesmo dia, e nunca no excluído.
  bool get podeAlterar {
    final r = _registro;
    return r != null && regra.podeAlterar(r, relogio.agora());
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();
    try {
      _registro = await repositorio.registro(registroId);
      _alerta = await repositorio.alertaDoRegistro(registroId);
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
    } on Exception {
      _erro = falhaAoCarregarRegistro;
    }
    _carregando = false;
    _avisar();
  }

  /// D17 — exclusão lógica. `true` se excluiu (a tela volta à TM13); com
  /// recusa ou falha, a mensagem fica em [erro].
  Future<bool> excluir() async {
    if (_excluindo || !podeAlterar) return false;
    _excluindo = true;
    _erro = null;
    _avisar();
    try {
      _registro = await repositorio.excluir(registroId);
      return true;
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
      return false;
    } on Exception {
      _erro = 'Não deu para excluir agora. Tente de novo em instantes.';
      return false;
    } finally {
      _excluindo = false;
      _avisar();
    }
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
