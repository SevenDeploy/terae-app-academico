import 'package:flutter/material.dart';

/// TM06 — Jornada. RFM06. Aba 3.
///
/// Stub da fundação: o agente `paciente` preenche. A `Key('TM06')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class JornadaTela extends StatelessWidget {
  const JornadaTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM06'),
      appBar: AppBar(title: const Text('TM06 — Jornada')),
    );
  }
}
