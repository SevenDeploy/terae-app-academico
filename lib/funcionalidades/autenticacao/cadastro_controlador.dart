import '../../dados/enums/canal_autorizado.dart';
import '../../dados/enums/qualidade_consentimento.dart';
import '../../dados/regras/consentimento.dart' as regra;
import '../../dados/repositorios/autenticacao_repositorio.dart';
import '../../dados/repositorios/falhas.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/validacao/cpf.dart';
import 'campos_cadastro.dart';
import 'controlador_de_entrada.dart';

/// Versão do termo de consentimento da TM09 (§22 Consentimento: termo novo
/// gera registro novo — mudar o texto exige mudar a versão).
const String versaoTermoConsentimento = '1.0';

/// Recusas que dizem respeito ao passo 1 (código, CPF ou nascimento): onde
/// quer que aconteçam, a tela volta a esse passo para a pessoa corrigir.
const Set<MotivoRecusa> recusasDoPasso1 = {
  MotivoRecusa.codigoInexistente,
  MotivoRecusa.tipoDeCodigoErrado,
  MotivoRecusa.codigoJaUsado,
  MotivoRecusa.codigoExpirado,
  MotivoRecusa.conviteRevogado,
  MotivoRecusa.cpfInvalido,
  MotivoRecusa.cpfNaoConfere,
  MotivoRecusa.nascimentoNaoConfere,
  MotivoRecusa.pacienteInativo,
};

/// Base dos cadastros por convite em três passos (RFM09; TM09, TM10).
///
/// Passo 1 confere o código sem consumi-lo; o passo 3 confere de novo e ativa.
/// A recusa vira mensagem simples no passo certo ([recusasDoPasso1] voltam ao
/// passo 1); depois da ativação a sessão abre e o roteador leva ao perfil.
abstract class CadastroControlador extends ControladorDeEntrada {
  CadastroControlador({required super.autenticacao, required super.sessao});

  static const int totalDePassos = 3;

  int _passo = 1;
  ConviteConferido? _conferido;
  bool _aceite = false;

  /// Erros locais do passo 1, campo a campo (rótulo ligado ao campo, D10).
  String? erroCodigo;
  String? erroCpf;

  /// Código e CPF já limpos, guardados no passo 1 para o passo 3.
  String _codigo = '';
  String _cpf = '';

  int get passo => _passo;

  /// O convite conferido no passo 1 (com o nome do paciente).
  ConviteConferido? get conferido => _conferido;

  /// Aceite do termo do passo 3.
  bool get aceite => _aceite;

  void marcarAceite({required bool aceite}) {
    _aceite = aceite;
    avisar();
  }

  /// Passo anterior (botão "Voltar" e voltar do Android).
  void voltar() {
    if (_passo == 1) return;
    _irPara(_passo - 1);
  }

  void _irPara(int passo) {
    _passo = passo;
    limparMensagem();
    avisar();
  }

  /// Confere localmente código e CPF e guarda os dois limpos; `false` se
  /// algum está errado (o erro fica no campo).
  bool _conferirCampos(String codigo, String cpf) {
    erroCodigo = erroDoCodigo(codigo);
    erroCpf = erroDoCpf(cpf);
    _codigo = normalizarCodigo(codigo);
    _cpf = somenteDigitos(cpf);
    return erroCodigo == null && erroCpf == null;
  }

  /// Passo 1 → 2 com o convite conferido.
  void _conferiu(ConviteConferido conferido) {
    _conferido = conferido;
    _irPara(2);
  }

  /// Passo 3: recusa do código, do CPF ou do nascimento volta ao passo 1.
  void _recusouNoPasso3(MotivoRecusa motivo) {
    if (recusasDoPasso1.contains(motivo)) _passo = 1;
  }
}

/// Estado da TM09 — Cadastro do paciente/família: (1) código da clínica, CPF e
/// nascimento do paciente; (2) quem vai usar — titular ou responsável legal;
/// (3) termo de consentimento, canal autorizado (R05) e aceite.
class CadastroPacienteControlador extends CadastroControlador {
  CadastroPacienteControlador({
    required super.autenticacao,
    required super.sessao,
    required this.relogio,
  });

  final Relogio relogio;

  String? erroNascimento;
  DataCivil? _nascimento;
  QualidadeConsentimento? _qualidade;
  CanalAutorizado? _canal;

  QualidadeConsentimento? get qualidade => _qualidade;
  CanalAutorizado? get canal => _canal;

  /// O paciente do passo 1 tem menos de 12 anos hoje, no dia da clínica (ECA
  /// art. 2º)? O nascimento digitado é o que o repositório conferiu.
  bool get pacienteEhCrianca {
    final nascimento = _nascimento;
    return nascimento != null &&
        regra.ehCrianca(nascimento: nascimento, hoje: DataCivil.hoje(relogio));
  }

  /// Passo 2 — quem pode aceitar o termo: criança, só o responsável legal
  /// (LGPD art. 14, § 1º); as outras opções aparecem indisponíveis.
  bool qualidadePermitida(QualidadeConsentimento qualidade) {
    final nascimento = _nascimento;
    return nascimento == null ||
        regra.qualidadePermitida(
          qualidade,
          nascimento: nascimento,
          hoje: DataCivil.hoje(relogio),
        );
  }

  /// Passo 3 pronto para "Continuar com Google".
  bool get podeAtivar =>
      _qualidade != null && _canal != null && aceite && !ocupado;

  /// Passo 1: confere no repositório, sem consumir o código.
  Future<void> conferir({
    required String codigo,
    required String cpf,
    required String nascimento,
  }) async {
    final camposOk = _conferirCampos(codigo, cpf);
    erroNascimento = erroDoNascimento(nascimento, DataCivil.hoje(relogio));
    _nascimento = lerDataDigitada(nascimento);
    final nascimentoLido = _nascimento;
    if (!camposOk || erroNascimento != null || nascimentoLido == null) {
      limparMensagem();
      avisar();
      return;
    }
    final conferido = await executar(
      () => autenticacao.conferirCodigoPaciente(
        codigo: _codigo,
        cpf: _cpf,
        dataNascimento: nascimentoLido,
      ),
    );
    if (conferido == null) return;
    // Outro nascimento no passo 1 pode tornar a escolha anterior inválida.
    final escolhida = _qualidade;
    if (escolhida != null && !qualidadePermitida(escolhida)) _qualidade = null;
    _conferiu(conferido);
  }

  void escolherQualidade(QualidadeConsentimento qualidade) {
    if (!qualidadePermitida(qualidade)) return;
    _qualidade = qualidade;
    avisar();
  }

  /// Passo 2 → 3.
  void irParaTermo() {
    final escolhida = _qualidade;
    if (escolhida != null && qualidadePermitida(escolhida)) _irPara(3);
  }

  void escolherCanal(CanalAutorizado canal) {
    _canal = canal;
    avisar();
  }

  /// Passo 3: confere de novo, grava o consentimento e liga a conta; a sessão
  /// abre e o roteador leva ao Início.
  Future<void> ativar(IdentidadeProvedor identidade) async {
    final qualidade = _qualidade;
    final canal = _canal;
    final nascimento = _nascimento;
    if (qualidade == null || canal == null || nascimento == null || !aceite) {
      return;
    }
    final vinculos = await executar(
      () => autenticacao.ativarPaciente(
        codigo: _codigo,
        cpf: _cpf,
        dataNascimento: nascimento,
        qualidade: qualidade,
        canalAutorizado: canal,
        versaoTermo: versaoTermoConsentimento,
        identidade: identidade,
      ),
      aoRecusar: (motivo) {
        if (motivo == MotivoRecusa.criancaComoTitular) {
          // O servidor é quem decide: volta ao passo 2 para escolher de novo.
          _qualidade = null;
          _passo = 2;
        } else {
          _recusouNoPasso3(motivo);
        }
      },
    );
    if (vinculos != null) sessao.entrar(vinculos);
  }
}

/// Estado da TM10 — Cadastro do cuidador: (1) código do convite e CPF do
/// cuidador, que tem de ser o informado pelo paciente; (2) o que verá e o que
/// não verá (RNFM05); (3) aceite do termo de acesso.
class CadastroCuidadorControlador extends CadastroControlador {
  CadastroCuidadorControlador({
    required super.autenticacao,
    required super.sessao,
  });

  /// Passo 3 pronto para "Continuar com Google".
  bool get podeAceitar => aceite && !ocupado;

  /// Passo 1: confere no repositório, sem consumir o convite.
  Future<void> conferir({required String codigo, required String cpf}) async {
    if (!_conferirCampos(codigo, cpf)) {
      limparMensagem();
      avisar();
      return;
    }
    final conferido = await executar(
      () => autenticacao.conferirConviteCuidador(codigo: _codigo, cpf: _cpf),
    );
    if (conferido != null) _conferiu(conferido);
  }

  /// Passo 2 → 3.
  void irParaTermo() => _irPara(3);

  /// Passo 3: confere de novo (inclusive o limite de dois, §7.4) e aceita; a
  /// sessão abre e o roteador leva à TM08.
  Future<void> aceitar(IdentidadeProvedor identidade) async {
    if (!aceite) return;
    final vinculos = await executar(
      () => autenticacao.aceitarConviteCuidador(
        codigo: _codigo,
        cpf: _cpf,
        identidade: identidade,
      ),
      aoRecusar: _recusouNoPasso3,
    );
    if (vinculos != null) sessao.entrar(vinculos);
  }
}
