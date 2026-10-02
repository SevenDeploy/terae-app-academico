import 'package:flutter/material.dart';

/// TM03 — Diário. RFM03/RFM04. Aba 2; estado em diario_controlador.dart; envia com `context.go(Rotas.pacienteDiarioEnviado ou pacienteDiarioAjuda, extra: ResultadoEnvio)`.
///
/// Stub da fundação: o agente `paciente` preenche. A `Key('TM03')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class DiarioTela extends StatelessWidget {
  const DiarioTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM03'),
      appBar: AppBar(title: const Text('TM03 — Diário')),
    );
  }
}
