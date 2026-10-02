import 'package:flutter/material.dart';

/// TM01 — Entrar. RFM01. Em `/entrar` (pública): “Continuar com Google” (e
/// Apple só no iOS), aviso de que nenhuma senha fica no aparelho, atalho para
/// o primeiro acesso. Em `/entrar/perfil` ([selecaoDePerfil], exige sessão):
/// lista de `Sessao.perfis`; tocar chama `Sessao.escolherPerfil` e o roteador
/// leva ao início do papel — a tela não navega.
///
/// Stub da fundação: o agente `entrada-cuidador` preenche. A `Key('TM01')` no
/// Scaffold raiz faz parte do contrato (testes de navegação).
class EntrarTela extends StatelessWidget {
  const EntrarTela({super.key, this.selecaoDePerfil = false});

  final bool selecaoDePerfil;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('TM01'),
      appBar: AppBar(title: const Text('TM01 — Entrar')),
    );
  }
}
