/// De onde o app lê os dados e, na fonte `local`, onde está o Terae web LOCAL
/// (decisão do dono de 26/11/2026).
///
/// O app fala com o Firebase acadêmico (D12) por padrão. Com
/// `--dart-define=TERAE_FONTE=local` ele passa a falar com a API do portal da
/// família de um Terae que roda **na máquina de desenvolvimento** — nunca com a
/// produção. A trava fica aqui, na partida: [ConfiguracaoTeraeLocal.doAmbiente]
/// recusa qualquer endereço que não seja de loopback ou do emulador Android, e
/// o [ClienteDoPortal] confere de novo ao nascer.
///
/// ```
/// flutter run --dart-define=TERAE_FONTE=local
/// flutter run --dart-define=TERAE_FONTE=local \
///   --dart-define=TERAE_LOCAL_URL=http://127.0.0.1:3000
/// ```
library;

/// A fonte de dados do app.
enum FonteDeDados {
  /// O Firebase acadêmico `terae-app-academico` (D12), o padrão.
  firebase,

  /// O Terae web local, pela API `/api/portal/*`.
  local,
}

/// Configuração errada na partida: o app não deve abrir com ela.
class ConfiguracaoInvalida implements Exception {
  const ConfiguracaoInvalida(this.mensagem);

  final String mensagem;

  @override
  String toString() => 'ConfiguracaoInvalida: $mensagem';
}

/// Os hosts que contam como "esta máquina": o loopback, o `localhost` (e os
/// subdomínios `*.localhost`, que a RFC 6761 reserva ao loopback) e o
/// `10.0.2.2`, o apelido do computador dentro do emulador Android.
const Set<String> hostsLocaisAceitos = {'10.0.2.2', '127.0.0.1', 'localhost'};

/// Endereço padrão: a API do Terae local vista de dentro do emulador Android.
const String urlLocalPadrao = 'http://10.0.2.2:3000';

/// A fonte escolhida e o endereço do Terae local, já conferido.
class ConfiguracaoTeraeLocal {
  const ConfiguracaoTeraeLocal._(this.fonte, this.url);

  /// Lê `TERAE_FONTE` e `TERAE_LOCAL_URL` do `--dart-define` e confere.
  ///
  /// Lança [ConfiguracaoInvalida] com a explicação quando a fonte é
  /// desconhecida ou o endereço não é local — mesmo com a fonte `firebase`:
  /// um `TERAE_LOCAL_URL` apontado para fora é erro de quem montou o comando,
  /// e calar agora só o adiaria para o dia em que a fonte mudar.
  factory ConfiguracaoTeraeLocal.doAmbiente() => ConfiguracaoTeraeLocal.de(
    fonte: const String.fromEnvironment(
      'TERAE_FONTE',
      defaultValue: 'firebase',
    ),
    url: const String.fromEnvironment(
      'TERAE_LOCAL_URL',
      defaultValue: urlLocalPadrao,
    ),
  );

  /// A mesma conferência de [ConfiguracaoTeraeLocal.doAmbiente], com os
  /// valores passados (testes).
  factory ConfiguracaoTeraeLocal.de({
    required String fonte,
    required String url,
  }) {
    final escolhida = FonteDeDados.values
        .where((f) => f.name == fonte.trim().toLowerCase())
        .firstOrNull;
    if (escolhida == null) {
      throw ConfiguracaoInvalida(
        'TERAE_FONTE="$fonte" não existe: use "firebase" (padrão) ou "local".',
      );
    }
    return ConfiguracaoTeraeLocal._(escolhida, exigirUrlLocal(url));
  }

  final FonteDeDados fonte;

  /// A raiz do Terae local, sem barra no fim (`http://10.0.2.2:3000`).
  final Uri url;
}

/// Confere que [texto] é a raiz de um Terae **local** e a devolve.
///
/// Aceita só `http`/`https`, sem usuário, caminho, consulta nem fragmento, e
/// só os hosts de [hostsLocaisAceitos] ou terminados em `.localhost`.
/// Qualquer outro lança [ConfiguracaoInvalida]: é a trava contra apontar o app
/// para a produção (`https://terae.com.br`) ou para outra máquina da rede.
Uri exigirUrlLocal(String texto) {
  final Uri? uri = Uri.tryParse(texto.trim());
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw ConfiguracaoInvalida(
      'TERAE_LOCAL_URL="$texto" não é um endereço completo '
      '(ex.: $urlLocalPadrao).',
    );
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw ConfiguracaoInvalida(
      'TERAE_LOCAL_URL="$texto": o esquema tem de ser http ou https.',
    );
  }
  if (uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.any((s) => s.isNotEmpty)) {
    throw ConfiguracaoInvalida(
      'TERAE_LOCAL_URL="$texto": use só esquema, host e porta, '
      'sem usuário, caminho ou consulta.',
    );
  }
  if (!ehHostLocal(uri.host)) {
    throw ConfiguracaoInvalida(
      'TERAE_LOCAL_URL="$texto" não é local: o app só fala com o Terae '
      'desta máquina (10.0.2.2, 127.0.0.1, localhost ou *.localhost), '
      'nunca com a produção nem com outro computador.',
    );
  }
  return uri.replace(path: '');
}

/// O host é desta máquina (ver [hostsLocaisAceitos]).
bool ehHostLocal(String host) {
  final h = host.toLowerCase();
  if (hostsLocaisAceitos.contains(h)) return true;
  // `.localhost` com algo antes, e só letras, dígitos, hífen e ponto entre
  // eles: `portal.localhost` sim; `.localhost` e `a..localhost` não.
  return RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)*\.localhost$').hasMatch(h);
}
