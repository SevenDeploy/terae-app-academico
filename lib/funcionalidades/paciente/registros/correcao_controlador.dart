import 'package:flutter/widgets.dart';

import '../../../dados/enums/adesao.dart';
import '../../../dados/enums/intensidade.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Estado da TM15 — Corrigir registro (Atividade 4: atualização do item
/// principal, D13, D17). Abre com as respostas do registro e salva pelo
/// [RepositorioDiario.atualizar], que segue a mesma fila do envio.
class CorrecaoControlador extends ChangeNotifier {
  CorrecaoControlador({
    required this.repositorio,
    required this.relogio,
    required this.registroId,
  });

  final RepositorioDiario repositorio;
  final Relogio relogio;
  final String registroId;

  /// Observação livre, opcional.
  final TextEditingController observacao = TextEditingController();

  RegistroDiario? _original;
  Adesao? _adesao;
  Intensidade? _intensidade;
  String? _sintoma;
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;
  bool _descartado = false;

  RegistroDiario? get original => _original;
  Adesao? get adesao => _adesao;
  Intensidade? get intensidade => _intensidade;
  String? get sintoma => _sintoma;
  bool get carregando => _carregando;
  bool get salvando => _salvando;
  String? get erro => _erro;

  /// D17 — o registro ainda é do dia e não foi excluído.
  bool get podeCorrigir {
    final r = _original;
    return r != null && regra.podeAlterar(r, relogio.agora());
  }

  bool get podeSalvar =>
      podeCorrigir &&
      !_salvando &&
      _adesao != null &&
      _intensidade != null &&
      _sintoma != null;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();
    try {
      final r = await repositorio.registro(registroId);
      _original = r;
      _adesao = r.adesao;
      _intensidade = r.intensidade;
      _sintoma = r.sintomaPredominante;
      observacao.text = r.observacao ?? '';
      if (!regra.podeAlterar(r, relogio.agora())) {
        _erro = MotivoRecusa.edicaoEncerrada.mensagem;
      }
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
    } on Exception {
      _erro = 'Não deu para abrir este registro agora. Tente de novo.';
    }
    _carregando = false;
    _avisar();
  }

  void escolherAdesao(Adesao valor) {
    _adesao = valor;
    _avisar();
  }

  void escolherIntensidade(Intensidade valor) {
    _intensidade = valor;
    _avisar();
  }

  void escolherSintoma(String valor) {
    _sintoma = valor;
    _avisar();
  }

  /// Salva a correção. Devolve o resultado (a tela vai à TM05 se ficou
  /// crítica, ou volta à TM14), ou `null` com a recusa em [erro].
  Future<ResultadoEnvio?> salvar() async {
    final original = _original;
    final adesao = _adesao;
    final intensidade = _intensidade;
    final sintoma = _sintoma;
    if (!podeSalvar ||
        original == null ||
        adesao == null ||
        intensidade == null ||
        sintoma == null) {
      return null;
    }
    _salvando = true;
    _erro = null;
    _avisar();
    final texto = observacao.text.trim();
    try {
      return await repositorio.atualizar(
        original.corrigido(
          adesao: adesao,
          intensidade: intensidade,
          sintomaPredominante: sintoma,
          observacao: texto.isEmpty ? null : texto,
          em: relogio.agora(),
        ),
      );
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
      return null;
    } on Exception {
      _erro = 'Não deu para salvar agora. Tente de novo em instantes.';
      return null;
    } finally {
      _salvando = false;
      _avisar();
    }
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
