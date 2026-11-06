import 'package:flutter/foundation.dart';

import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/falhas.dart';
import '../../nucleo/sessao/sessao.dart';

/// Texto de falha que não é recusa de regra (RNFM01: nada de código de erro).
const String falhaInesperada =
    'Não deu para continuar agora. Tente de novo em instantes.';

/// Base dos controladores da TM01, TM09 e TM10 (RFM01, RFM09): marca
/// [ocupado] durante a chamada ao repositório e transforma a recusa em
/// [mensagem] simples.
///
/// Depois de `sessao.entrar`, ninguém navega: o roteador escuta a sessão.
abstract class ControladorDeEntrada extends ChangeNotifier {
  ControladorDeEntrada({required this.autenticacao, required this.sessao});

  final RepositorioAutenticacao autenticacao;
  final Sessao sessao;

  bool _ocupado = false;
  String? _mensagem;
  bool _descartado = false;

  bool get ocupado => _ocupado;

  /// Recusa (ou falha) a mostrar na tela, já em linguagem simples.
  String? get mensagem => _mensagem;

  /// Roda [operacao] com [ocupado] ligado. Recusa de regra vira [mensagem]
  /// (e chega a [aoRecusar]); outra exceção vira [falhaInesperada]. Devolve
  /// `null` nos dois casos, e também se já havia uma operação em curso.
  @protected
  Future<T?> executar<T>(
    Future<T> Function() operacao, {
    void Function(MotivoRecusa motivo)? aoRecusar,
  }) async {
    if (_ocupado) return null;
    _ocupado = true;
    _mensagem = null;
    avisar();
    try {
      return await operacao();
    } on RecusaDeRegra catch (recusa) {
      _mensagem = recusa.mensagem;
      aoRecusar?.call(recusa.motivo);
      return null;
    } on Exception {
      _mensagem = falhaInesperada;
      return null;
    } finally {
      _ocupado = false;
      avisar();
    }
  }

  /// Apaga a mensagem (ao mudar de passo, por exemplo).
  @protected
  void limparMensagem() => _mensagem = null;

  /// `notifyListeners` que não falha se a tela já saiu (o roteador troca de
  /// tela assim que a sessão abre).
  @protected
  void avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
