import 'package:flutter/material.dart';

/// TM12 — Agenda e avisos. RFM08. Empilhada sobre a TM08; o voltar leva à TM08 (roteador). Alerta só com data, hora e ciência.
///
/// Stub da fundação: o agente `entrada-cuidador` preenche. A `Key('TM12')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class AgendaAvisosTela extends StatelessWidget {
  const AgendaAvisosTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM12'),
      appBar: AppBar(title: const Text('TM12 — Agenda e avisos')),
    );
  }
}
