import 'package:flutter/material.dart';

import '../../../dados/repositorios/diario_repositorio.dart';

/// TM04 — Diário enviado. RFM05. Tela cheia, fora das abas; volta sozinha ao
/// Início em 3 s (não quando `MediaQuery.accessibleNavigation`, D10) com
/// `context.go(Rotas.pacienteInicio)`. O voltar do Android já leva ao Início
/// (roteador). Com [envio] na fila: "será enviado quando houver conexão".
///
/// Stub da fundação: o agente `paciente` preenche. A `Key('TM04')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class DiarioEnviadoTela extends StatelessWidget {
  const DiarioEnviadoTela({super.key, this.envio});

  /// Resultado do envio, vindo do diário por `extra`; nulo em link direto.
  final ResultadoEnvio? envio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM04'),
      appBar: AppBar(title: const Text('TM04 — Diário enviado')),
    );
  }
}
