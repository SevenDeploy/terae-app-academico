import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../nucleo/sessao/sessao.dart';

/// As abas do perfil paciente/família, na ordem dos ramos do
/// `StatefulShellRoute` em `lib/roteador.dart` (o índice do enum é o índice
/// do ramo).
enum AbaDoPaciente {
  inicio('aba-inicio', Icons.home_outlined, Icons.home, 'Início'),
  diario('aba-diario', Icons.favorite_border, Icons.favorite, 'Diário'),

  /// D22 — só para quem tem terapia ocupacional.
  casa('aba-casa', Icons.extension_outlined, Icons.extension, 'Em casa'),
  jornada('aba-jornada', Icons.map_outlined, Icons.map, 'Jornada');

  const AbaDoPaciente(this.chave, this.icone, this.iconeAtivo, this.rotulo);

  /// `Key` do destino na barra (testes).
  final String chave;
  final IconData icone;
  final IconData iconeAtivo;
  final String rotulo;
}

/// As abas que a barra mostra para o paciente: todas, menos "Em casa" para
/// quem não tem terapia ocupacional (D22). No máximo 4: com 5, o rótulo
/// "Cuidadores" quebrava em duas linhas a 360 dp mesmo com a fonte normal, e
/// a TM07 foi para o menu do Início.
List<AbaDoPaciente> abasVisiveis({required bool temTerapiaOcupacional}) => [
  for (final aba in AbaDoPaciente.values)
    if (aba != AbaDoPaciente.casa || temTerapiaOcupacional) aba,
];

/// Barra de abas do perfil paciente/família (§15, §21): Início, Diário,
/// Em casa (só com terapia ocupacional, D22) e Jornada, cada uma com a
/// própria pilha (`StatefulShellRoute`), o que preserva o diário em
/// preenchimento ao trocar de aba.
///
/// Voltar do Android numa aba diferente do Início leva ao Início; no Início,
/// fecha o aplicativo. A `NavigationBar` expõe cada aba com papel de aba e
/// `selected` na ativa. Chaves das abas em [AbaDoPaciente.chave] para teste.
class AbasPaciente extends StatelessWidget {
  const AbasPaciente({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Índice do ramo do Início.
  static final int inicio = AbaDoPaciente.inicio.index;

  @override
  Widget build(BuildContext context) {
    final temTerapiaOcupacional = context.select<Sessao, bool>(
      (s) => s.perfilAtivo?.paciente.temTerapiaOcupacional ?? false,
    );
    final visiveis = abasVisiveis(temTerapiaOcupacional: temTerapiaOcupacional);
    final atual = navigationShell.currentIndex;
    final selecionada = visiveis.indexWhere((aba) => aba.index == atual);
    return PopScope(
      canPop: atual == inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) navigationShell.goBranch(inicio);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selecionada < 0 ? 0 : selecionada,
          onDestinationSelected: (indice) {
            final ramo = visiveis[indice].index;
            navigationShell.goBranch(ramo, initialLocation: ramo == atual);
          },
          destinations: [
            for (final aba in visiveis)
              NavigationDestination(
                key: Key(aba.chave),
                icon: Icon(aba.icone),
                selectedIcon: Icon(aba.iconeAtivo),
                label: aba.rotulo,
              ),
          ],
        ),
      ),
    );
  }
}
