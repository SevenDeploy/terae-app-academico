import 'package:flutter/material.dart';

/// TM08 — Início do cuidador. RFM08. Sem abas; abre TM11/TM12 com `context.push`; menu com “Sair” e “Trocar perfil”.
///
/// Stub da fundação: o agente `entrada-cuidador` preenche. A `Key('TM08')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class InicioCuidadorTela extends StatelessWidget {
  const InicioCuidadorTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM08'),
      appBar: AppBar(title: const Text('TM08 — Início do cuidador')),
    );
  }
}
