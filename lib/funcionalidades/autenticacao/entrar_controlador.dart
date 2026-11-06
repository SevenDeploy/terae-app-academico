import 'campos_cadastro.dart';
import 'controlador_de_entrada.dart';

/// Estado da TM01 — Entrar (RFM01) com e-mail e senha (D14).
class EntrarControlador extends ControladorDeEntrada {
  EntrarControlador({required super.autenticacao, required super.sessao});

  /// Erros locais, campo a campo (rótulo ligado ao campo, D10).
  String? erroEmail;
  String? erroSenha;

  /// Confere os campos e entra. Com sucesso, abre a sessão e o roteador leva
  /// ao início do perfil (ou à seleção, se houver vários); recusa
  /// (`credenciaisInvalidas`, `contaSemAcesso`, `contaInativa`, `semConexao`)
  /// fica em [mensagem]. A senha não fica guardada em lugar nenhum.
  Future<void> entrar({required String email, required String senha}) async {
    erroEmail = erroDoEmail(email);
    erroSenha = erroDaSenhaDeEntrada(senha);
    if (erroEmail != null || erroSenha != null) {
      limparMensagem();
      avisar();
      return;
    }
    final vinculos = await executar(
      () => autenticacao.entrar(email: email.trim(), senha: senha),
    );
    if (vinculos != null) sessao.entrar(vinculos);
  }
}
