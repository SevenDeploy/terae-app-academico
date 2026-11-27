import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';
import '../diario/campos_do_diario.dart';
import 'registro_controlador.dart' show falhaAoCarregarRegistro;

/// Estado da TM15 — Corrigir registro (P3; quadro 18f; D17 revista): o mesmo
/// formulário do registro novo, preenchido com a versão vigente. Salvar
/// cria a versão seguinte pelo [RepositorioDiario.corrigir], que pede a
/// internet na hora. Se a terapeuta revisou no meio (o 409 do portal), a
/// tela diz isso e oferece um registro novo.
class CorrecaoControlador extends RespostasDoDiario {
  CorrecaoControlador({required this.repositorio, required this.registroId});

  final RepositorioDiario repositorio;
  final String registroId;

  RegistroDiario? _registro;
  bool _carregando = true;
  bool _salvando = false;
  bool _naoMudaMais = false;
  String? _erro;

  /// A versão vigente, como estava ao abrir.
  RegistroDiario? get registro => _registro;
  bool get carregando => _carregando;
  bool get salvando => _salvando;

  /// O registro não pode mais mudar: a tela troca o formulário pelo aviso.
  bool get naoMudaMais => _naoMudaMais;
  String? get erro => _erro;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    avisar();
    try {
      final r = await repositorio.registro(registroId);
      _registro = r;
      final e = r.entrada;
      escolherAdesao(e.adesao);
      escolherIntensidade(e.intensidadeSintoma);
      sintomas.text = e.sintomas ?? '';
      observacoes.text = e.observacoes ?? '';
      _naoMudaMais = !regra.podeAlterar(r);
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
    } on Exception {
      _erro = falhaAoCarregarRegistro;
    }
    _carregando = false;
    avisar();
  }

  /// "Salvar a correção": o resultado confirmado, ou `null` (com [erro] ou
  /// [naoMudaMais]).
  Future<ResultadoEnvio?> salvar() async {
    if (_salvando || _registro == null || _naoMudaMais) return null;
    final entrada = this.entrada();
    if (entrada == null) return null;
    _salvando = true;
    _erro = null;
    avisar();
    try {
      return await repositorio.corrigir(registroId, entrada);
    } on RecusaDeRegra catch (recusa) {
      if (recusa.motivo == MotivoRecusa.registroNaoMudaMais) {
        _naoMudaMais = true;
      } else {
        _erro = recusa.mensagem;
      }
      return null;
    } on Exception {
      _erro =
          'Não deu para salvar a correção agora. Tente de novo em instantes.';
      return null;
    } finally {
      _salvando = false;
      avisar();
    }
  }
}
