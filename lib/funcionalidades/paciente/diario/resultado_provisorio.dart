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

/// Mostra o envio e se refaz quando um [ResultadoProvisorio] confirma.
///
/// [construtor] recebe o resultado atual (nulo em link direto) e se ainda
/// espera a resposta.
class AcompanharEnvio extends StatefulWidget {
  const AcompanharEnvio({
    super.key,
    required this.envio,
    required this.construtor,
  });

  final ResultadoEnvio? envio;
  final Widget Function(
    BuildContext context,
    ResultadoEnvio? envio, {
    required bool aguardando,
  })
  construtor;

  @override
  State<AcompanharEnvio> createState() => _AcompanharEnvioState();
}

class _AcompanharEnvioState extends State<AcompanharEnvio> {
  ResultadoEnvio? _atual;
  bool _aguardando = false;

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
    _aguardando = envio is ResultadoProvisorio;
    if (envio is! ResultadoProvisorio) return;
    envio.definitivo.then(
      (resposta) {
        if (!mounted || !identical(widget.envio, envio)) return;
        setState(() {
          _atual = resposta;
          _aguardando = false;
        });
      },
      onError: (Object _) {
        // Sem resposta: continua "envio pendente", nunca "avisado".
        if (!mounted || !identical(widget.envio, envio)) return;
        setState(() => _aguardando = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.construtor(context, _atual, aguardando: _aguardando);
}
