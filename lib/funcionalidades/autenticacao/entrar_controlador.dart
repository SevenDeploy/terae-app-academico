import '../../dados/repositorios/autenticacao_repositorio.dart';
import 'controlador_de_entrada.dart';

/// Estado da TM01 — Entrar (RFM01).
class EntrarControlador extends ControladorDeEntrada {
  EntrarControlador({required super.autenticacao, required super.sessao});

  /// Entra com a conta escolhida na folha. Com sucesso, abre a sessão e o
  /// roteador leva ao início do perfil (ou à seleção, se houver vários);
  /// recusa (`contaSemAcesso`, `contaInativa`) fica em [mensagem].
  Future<void> entrar(IdentidadeProvedor identidade) async {
    final vinculos = await executar(() => autenticacao.entrar(identidade));
    if (vinculos != null) sessao.entrar(vinculos);
  }
}
