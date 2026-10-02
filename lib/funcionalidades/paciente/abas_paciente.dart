import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra de abas do perfil paciente/família (§15, §21): Início, Diário,
/// Jornada e Cuidadores, cada uma com a própria pilha (`StatefulShellRoute`),
/// o que preserva o diário em preenchimento ao trocar de aba.
///
/// Voltar do Android numa aba diferente do Início leva ao Início; no Início,
/// fecha o aplicativo. A `NavigationBar` expõe cada aba com papel de aba e
/// `selected` na ativa. Chaves `aba-inicio`, `aba-diario`, `aba-jornada` e
/// `aba-cuidadores` para teste.
class AbasPaciente extends StatelessWidget {
  const AbasPaciente({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Índice da aba Início.
  static const int inicio = 0;

  @override
  Widget build(BuildContext context) {
    final atual = navigationShell.currentIndex;
    return PopScope(
      canPop: atual == inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) navigationShell.goBranch(inicio);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: atual,
          onDestinationSelected: (indice) => navigationShell.goBranch(
            indice,
            initialLocation: indice == atual,
          ),
          destinations: const [
            NavigationDestination(
              key: Key('aba-inicio'),
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
            ),
            NavigationDestination(
              key: Key('aba-diario'),
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Diário',
            ),
            NavigationDestination(
              key: Key('aba-jornada'),
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Jornada',
            ),
            NavigationDestination(
              key: Key('aba-cuidadores'),
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Cuidadores',
            ),
          ],
        ),
      ),
    );
  }
}
