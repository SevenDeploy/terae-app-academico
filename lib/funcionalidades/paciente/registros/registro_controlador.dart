import 'package:flutter/foundation.dart';

import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';

/// Texto de falha que não é recusa de regra (RNFM01).
const String falhaAoCarregarRegistro =
    'Não deu para abrir este registro agora. Tente de novo em instantes.';

/// Estado da TM14 — Registro (P3): um registro do diário com as versões, a
/// situação e, enquanto pode mudar, "Corrigir" e "Retirar".
class RegistroControlador extends ChangeNotifier {
  RegistroControlador({required this.repositorio, required this.registroId});

  final RepositorioDiario repositorio;
  final String registroId;

  RegistroDiario? _registro;
  bool _carregando = true;
  bool _retirou = false;
  String? _erro;
  bool _descartado = false;

  RegistroDiario? get registro => _registro;
  bool get carregando => _carregando;

  /// A folha de retirar acabou de retirar este registro.
  bool get retirou => _retirou;

  /// Recusa ou falha a mostrar, em linguagem simples.
  String? get erro => _erro;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();
    try {
      _registro = await repositorio.registro(registroId);
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
    } on Exception {
      _erro = falhaAoCarregarRegistro;
    }
    _carregando = false;
    _avisar();
  }

  /// A folha confirmou a retirada: mostra o aviso e relê.
  Future<void> aoRetirar() async {
    _retirou = true;
    await carregar();
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
