import 'package:flutter/widgets.dart';

import '../../../dados/repositorios/diario_repositorio.dart';

/// Resultado de um envio que ainda não respondeu (RFM04, RNFM03).
///
/// A TM05 abre na hora em que a pessoa envia um registro crítico, sem esperar
/// a rede, e a TM04 abre em no máximo 2 s mesmo com conexão lenta. Nesses
/// casos o diário passa este resultado pelo `extra`: o registro como saiu do
/// aparelho (`naFila`, sem alerta — portanto `equipeAvisada` é falso) e o
/// [definitivo], que completa com a resposta do repositório.
///
/// É um [ResultadoEnvio] de verdade: quem só conhece o contrato (o roteador)
/// trata como qualquer outro, e nunca diz "avisado" antes da confirmação.
class ResultadoProvisorio extends ResultadoEnvio {
  const ResultadoProvisorio({
    required super.registro,
    required this.definitivo,
  });

  /// A resposta do repositório. Pode falhar; quem escuta mantém o provisório.
  final Future<ResultadoEnvio> definitivo;
}

/// Em que pé está o envio que a TM04/TM05 mostram.
enum AndamentoDoEnvio {
  /// Ainda sem resposta do repositório ([ResultadoProvisorio]).
  aguardando,

  /// O repositório respondeu: enviado ou na fila (`naFila`).
  respondido,

  /// O repositório falhou de um jeito inesperado: nada garante que o
  /// registro ficou guardado, então a tela não diz que ficou.
  falhou,
}

/// Mostra o envio e se refaz quando um [ResultadoProvisorio] responde.
///
/// [construtor] recebe o resultado atual (nulo em link direto) e o
/// [AndamentoDoEnvio].
class AcompanharEnvio extends StatefulWidget {
  const AcompanharEnvio({
    super.key,
    required this.envio,
    required this.construtor,
  });

  final ResultadoEnvio? envio;
  final Widget Function(
    BuildContext context,
    ResultadoEnvio? envio,
    AndamentoDoEnvio andamento,
  )
  construtor;

  @override
  State<AcompanharEnvio> createState() => _AcompanharEnvioState();
}

class _AcompanharEnvioState extends State<AcompanharEnvio> {
  ResultadoEnvio? _atual;
  AndamentoDoEnvio _andamento = AndamentoDoEnvio.respondido;

  @override
  void initState() {
    super.initState();
    _acompanhar(widget.envio);
  }

  @override
  void didUpdateWidget(AcompanharEnvio antigo) {
    super.didUpdateWidget(antigo);
    if (!identical(antigo.envio, widget.envio)) _acompanhar(widget.envio);
  }

  void _acompanhar(ResultadoEnvio? envio) {
    _atual = envio;
    if (envio is! ResultadoProvisorio) {
      _andamento = AndamentoDoEnvio.respondido;
      return;
    }
    _andamento = AndamentoDoEnvio.aguardando;
    envio.definitivo.then(
      (resposta) {
        if (!mounted || !identical(widget.envio, envio)) return;
        setState(() {
          _atual = resposta;
          _andamento = AndamentoDoEnvio.respondido;
        });
      },
      onError: (Object _) {
        // Continua sem confirmação: "envio pendente", nunca "avisado".
        if (!mounted || !identical(widget.envio, envio)) return;
        setState(() => _andamento = AndamentoDoEnvio.falhou);
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.construtor(context, _atual, _andamento);
}
