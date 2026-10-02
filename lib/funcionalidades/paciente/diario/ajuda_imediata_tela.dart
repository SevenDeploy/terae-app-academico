import 'package:flutter/material.dart';

import '../../../dados/repositorios/diario_repositorio.dart';

/// TM05 — Ajuda imediata. RFM04. Tela cheia, fora das abas: CVV 188 e SAMU 192
/// em destaque (`FaixaEmergencia(destaque: true)`); "seu profissional foi
/// avisado" só se `envio?.equipeAvisada`, senão "envio pendente"; botão
/// "Ciente" faz `context.go(Rotas.pacienteInicio)`. O voltar do Android já
/// leva ao Início (roteador).
///
/// Stub da fundação: o agente `paciente` preenche. A `Key('TM05')` no Scaffold
/// raiz faz parte do contrato (testes de navegação).
class AjudaImediataTela extends StatelessWidget {
  const AjudaImediataTela({super.key, this.envio});

  /// Resultado do envio, vindo do diário por `extra`; nulo em link direto.
  final ResultadoEnvio? envio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM05'),
      appBar: AppBar(title: const Text('TM05 — Ajuda imediata')),
    );
  }
}
