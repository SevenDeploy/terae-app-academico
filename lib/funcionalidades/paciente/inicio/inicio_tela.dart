import 'package:flutter/material.dart';

/// TM02 — Início. RFM02. Aba 1; menu com “Sair” e, com vários perfis, “Trocar perfil”.
///
/// Stub da fundação: o agente `paciente` preenche. A `Key('TM02')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class InicioTela extends StatelessWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM02'),
      appBar: AppBar(title: const Text('TM02 — Início')),
    );
  }
}
