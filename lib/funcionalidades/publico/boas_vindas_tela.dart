import 'package:flutter/material.dart';

/// TM00 — Boas-vindas. RFM10. Pública, sem dado pessoal: marca, “Entrar”, “Primeiro acesso”, faixa CVV 188/SAMU 192 (FaixaEmergencia), SeloAcademico e, só em kDebugMode, o painel D11.
///
/// Stub da fundação: o agente `entrada-cuidador` preenche. A `Key('TM00')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class BoasVindasTela extends StatelessWidget {
  const BoasVindasTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM00'),
      appBar: AppBar(title: const Text('TM00 — Boas-vindas')),
    );
  }
}
