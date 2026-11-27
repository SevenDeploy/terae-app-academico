import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../nucleo/tempo/relogio.dart';
import 'campos_cadastro.dart';
import 'controlador_de_entrada.dart';

/// Quanto tempo depois do pedido "Enviar um código novo" libera (portal:
/// `SEGUNDOS_PARA_REENVIAR_O_CODIGO`).
const Duration esperaParaReenviar = Duration(seconds: 60);

/// Quanto tempo vale cada código (portal: `MINUTOS_DO_CODIGO_DE_ACESSO`).
const Duration validadeDoCodigo = Duration(minutes: 10);

/// Estado da TM01 — Entrar (RFM01) com e-mail e senha (D14) e, na fonte
/// Terae local ([AutenticacaoComCodigo]), a etapa 2 do portal: o código de 6
/// dígitos do e-mail.
class EntrarControlador extends ControladorDeEntrada {
  EntrarControlador({
    required super.autenticacao,
    required super.sessao,
    this.relogio = const RelogioSistema(),
  });

  /// Fonte do "agora" para os prazos da etapa do código.
  final Relogio relogio;

  /// Erros locais, campo a campo (rótulo ligado ao campo, D10).
  String? erroEmail;
  String? erroSenha;

  CodigoDeAcessoPedido? _codigo;
  DateTime? _codigoPedidoEm;
  bool _reenviado = false;
  String? _erroDoCodigo;

  /// A etapa do código, quando a senha conferiu e o código foi pedido.
  CodigoDeAcessoPedido? get etapaDoCodigo => _codigo;

  /// "Enviamos um código novo. O anterior deixou de valer."
  bool get reenviado => _reenviado;

  /// O código que não confere, sob as caixas.
  String? get erroDoCodigo => _erroDoCodigo;

  /// Quanto falta para "Enviar um código novo" (zero: já pode). Como no
  /// portal, conta do instante em que a resposta chegou neste aparelho.
  Duration get paraReenviar {
    final pedido = _codigoPedidoEm;
    if (pedido == null) return Duration.zero;
    final resta = pedido.add(esperaParaReenviar).difference(relogio.agora());
    return resta.isNegative ? Duration.zero : resta;
  }

  /// O código enviado já passou dos 10 minutos.
  bool get codigoVencido {
    final pedido = _codigoPedidoEm;
    final codigo = _codigo;
    if (pedido == null || codigo == null || !codigo.codigoEnviado) {
      return false;
    }
    return !relogio.agora().isBefore(pedido.add(validadeDoCodigo));
  }

  /// Confere os campos e entra. Com sucesso, abre a sessão e o roteador leva
  /// ao início do perfil (ou à seleção, se houver vários); recusa
  /// (`credenciaisInvalidas`, `contaSemAcesso`, `contaInativa`, `semConexao`)
  /// fica em [mensagem]. A senha não fica guardada em lugar nenhum. Na fonte
  /// com código, a senha certa leva a [etapaDoCodigo].
  Future<void> entrar({required String email, required String senha}) async {
    erroEmail = erroDoEmail(email);
    erroSenha = erroDaSenhaDeEntrada(senha);
    if (erroEmail != null || erroSenha != null) {
      limparMensagem();
      avisar();
      return;
    }
    final autenticacao = this.autenticacao;
    if (autenticacao is AutenticacaoComCodigo) {
      final passo = await executar(
        () => autenticacao.iniciarEntrada(email: email.trim(), senha: senha),
      );
      switch (passo) {
        case EntradaConcluida(:final vinculos):
          sessao.entrar(vinculos);
        case CodigoDeAcessoPedido():
          _mostrarCodigo(passo, reenviado: false);
        case null:
          break;
      }
      return;
    }
    final vinculos = await executar(
      () => autenticacao.entrar(email: email.trim(), senha: senha),
    );
    if (vinculos != null) sessao.entrar(vinculos);
  }

  /// Envia o código do e-mail. Errado: [erroDoCodigo] com as tentativas;
  /// sem tentativas ou sessão vencida: volta à senha com o recado.
  Future<void> confirmarCodigo(
    String codigo, {
    required bool confiarNesteAparelho,
  }) async {
    final autenticacao = this.autenticacao;
    if (autenticacao is! AutenticacaoComCodigo || codigo.length != 6) return;
    _erroDoCodigo = null;
    final vinculos = await executar(
      () => _naEtapaDoCodigo(
        () => autenticacao.confirmarCodigo(
          codigo,
          confiarNesteAparelho: confiarNesteAparelho,
        ),
      ),
    );
    if (vinculos != null) sessao.entrar(vinculos);
  }

  /// "Enviar um código novo" (60 s depois do último).
  Future<void> reenviarCodigo() async {
    final autenticacao = this.autenticacao;
    if (autenticacao is! AutenticacaoComCodigo ||
        paraReenviar > Duration.zero) {
      return;
    }
    _erroDoCodigo = null;
    final novo = await executar(
      () => _naEtapaDoCodigo(autenticacao.reenviarCodigo),
    );
    if (novo != null) _mostrarCodigo(novo, reenviado: novo.codigoEnviado);
  }

  /// "Voltar para a entrada": de volta à senha, sem recado.
  void voltarParaASenha() {
    _sairDaEtapaDoCodigo();
    limparMensagem();
    avisar();
  }

  /// Traduz as exceções próprias da etapa do código; `null` quando tratou.
  Future<T?> _naEtapaDoCodigo<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } on CodigoNaoConfere catch (e) {
      final n = e.tentativasRestantes;
      _erroDoCodigo = n == null
          ? 'O código não confere ou venceu. Peça um código novo.'
          : 'O código não confere. Você ainda tem $n '
                '${n == 1 ? 'tentativa' : 'tentativas'}.';
      return null;
    } on VoltarParaASenha catch (e) {
      _sairDaEtapaDoCodigo();
      definirMensagem(e.recado);
      return null;
    }
  }

  void _mostrarCodigo(CodigoDeAcessoPedido codigo, {required bool reenviado}) {
    _codigo = codigo;
    _codigoPedidoEm = relogio.agora();
    _reenviado = reenviado;
    _erroDoCodigo = null;
    avisar();
  }

  void _sairDaEtapaDoCodigo() {
    _codigo = null;
    _codigoPedidoEm = null;
    _reenviado = false;
    _erroDoCodigo = null;
  }
}
