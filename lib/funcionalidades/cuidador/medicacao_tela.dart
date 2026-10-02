import 'package:flutter/material.dart';

/// TM11 — Medicação. RFM08. Empilhada sobre a TM08; o voltar leva à TM08 (roteador).
///
/// Stub da fundação: o agente `entrada-cuidador` preenche. A `Key('TM11')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class MedicacaoTela extends StatelessWidget {
  const MedicacaoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM11'),
      appBar: AppBar(title: const Text('TM11 — Medicação')),
    );
  }
}
