import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../nucleo/rotas/rotas.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../capacidades.dart';

/// As áreas da moldura, na ordem da barra de baixo do portal da família
/// (`apps/portal/src/componentes/MolduraDoPortal.tsx`, quadro 18d): Início,
/// Diário, Em casa, Agenda e Conta.
enum AbaDoPortal {
  inicio('aba-inicio', LucideIcons.house, 'Início'),
  diario('aba-diario', LucideIcons.notebookPen, 'Diário'),

  /// D22 — só para quem tem terapia ocupacional.
  casa('aba-casa', LucideIcons.listChecks, 'Em casa'),
  agenda('aba-agenda', LucideIcons.calendar, 'Agenda'),
  conta('aba-conta', LucideIcons.userRound, 'Conta');

  const AbaDoPortal(this.chave, this.icone, this.rotulo);

  /// `Key` do destino na barra (testes).
  final String chave;
  final IconData icone;
  final String rotulo;
}

/// Ramos do paciente/família, na ordem do `StatefulShellRoute` do roteador.
const List<AbaDoPortal> ramosDoPaciente = [
  AbaDoPortal.inicio,
  AbaDoPortal.diario,
  AbaDoPortal.casa,
  AbaDoPortal.agenda,
  AbaDoPortal.conta,
];

/// Ramos do cuidador: como no portal, sem o Diário (o cuidador não o vê). O
/// "Em casa" só aparece quando a fonte entrega o programa a ele.
const List<AbaDoPortal> ramosDoCuidador = [
  AbaDoPortal.inicio,
  AbaDoPortal.casa,
  AbaDoPortal.agenda,
  AbaDoPortal.conta,
];

/// As abas que a barra mostra: os [ramos] do papel, menos "Em casa" para
/// quem não tem terapia ocupacional (D22).
List<AbaDoPortal> abasVisiveis(
  List<AbaDoPortal> ramos, {
  required bool temTerapiaOcupacional,
}) => [
  for (final aba in ramos)
    if (aba != AbaDoPortal.casa || temTerapiaOcupacional) aba,
];

/// A moldura do portal no telefone: o topo branco com o seletor de paciente
/// e a ajuda, a faixa do modo cuidador e a barra de baixo com as áreas.
///
/// Cada aba tem a própria pilha (`StatefulShellRoute`). Voltar do Android
/// numa aba diferente do Início leva ao Início; no Início, fecha o app.
/// [envolver] deixa o roteador pôr algo em volta (os lembretes do paciente).
class MolduraDoPortal extends StatelessWidget {
  const MolduraDoPortal({
    super.key,
    required this.navigationShell,
    required this.ramos,
    this.envolver,
  });

  final StatefulNavigationShell navigationShell;
  final List<AbaDoPortal> ramos;
  final Widget Function(Widget moldura, {required bool noInicio})? envolver;

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    final programaDoCuidador = capacidadesDaFonte(context).programaDoCuidador;
    final temCasa =
        (perfil?.paciente.temTerapiaOcupacional ?? false) &&
        (perfil?.papel != Papel.cuidador || programaDoCuidador);
    final visiveis = abasVisiveis(ramos, temTerapiaOcupacional: temCasa);
    final atual = navigationShell.currentIndex;
    final inicio = ramos.indexOf(AbaDoPortal.inicio);
    final selecionada = visiveis.indexWhere(
      (aba) => ramos.indexOf(aba) == atual,
    );
    final cuidador = perfil?.papel == Papel.cuidador;
    final moldura = PopScope(
      canPop: atual == inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) navigationShell.goBranch(inicio);
      },
      child: Scaffold(
        appBar: const TopoDoPortal(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cuidador && perfil != null)
              FaixaModoCuidador(primeiroNome: perfil.paciente.primeiroNome),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: CoresTerae.borda)),
          ),
          // Cinco rótulos em 72 dp cada: a escala do texto da barra para em
          // 1,15× (o resto do app segue a do aparelho), senão "Em casa"
          // quebra em duas linhas com a fonte grande.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: NavigationBar(
              selectedIndex: selecionada < 0 ? 0 : selecionada,
              onDestinationSelected: (indice) {
                final ramo = ramos.indexOf(visiveis[indice]);
                // Sempre a raiz da aba: o ramo do Diário guardava o local da
                // TM04 (`/paciente/diario/enviado`) depois de "Voltar ao
                // início", e a aba abria com a lista velha, sem reler.
                navigationShell.goBranch(ramo, initialLocation: true);
              },
              destinations: [
                for (final aba in visiveis)
                  NavigationDestination(
                    key: Key(aba.chave),
                    icon: Icon(aba.icone),
                    label: aba.rotulo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final envolver = this.envolver;
    return envolver == null
        ? moldura
        : envolver(moldura, noInicio: atual == inicio);
  }
}

/// O topo do portal no telefone: o seletor de paciente (avatar com as
/// iniciais, o nome inteiro e, com mais de um perfil, a seta que abre "De quem você quer ver?") e o
/// atalho "Ajuda imediata", que abre os números do SAMU 192 e do CVV 188.
///
/// Como a barra de baixo, o topo para a escala do texto em 1,15×: com a
/// fonte grande, "Ajuda imediata" e o nome não cabem lado a lado a 360 dp.
class TopoDoPortal extends StatelessWidget implements PreferredSizeWidget {
  const TopoDoPortal({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    final varios = context.select<Sessao, bool>((s) => s.temVariosPerfis);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        titleSpacing: 12,
        shape: const Border(bottom: BorderSide(color: CoresTerae.borda)),
        title: perfil == null
            ? null
            : _SeletorDePaciente(perfil: perfil, varios: varios),
        actions: [
          // O botão nunca passa de 176 dp: o rótulo encolhe antes de tirar o
          // lugar do nome do paciente (fonte muito larga ou do aparelho).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 176),
            child: TextButton.icon(
              key: const Key('topo-ajuda'),
              onPressed: () => context.push(Rotas.ajuda),
              style: TextButton.styleFrom(
                foregroundColor: CoresTerae.erro,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(LucideIcons.lifeBuoy, size: 20),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Ajuda imediata'),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SeletorDePaciente extends StatelessWidget {
  const _SeletorDePaciente({required this.perfil, required this.varios});

  final Perfil perfil;
  final bool varios;

  @override
  Widget build(BuildContext context) {
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(nome: perfil.paciente.nome),
        const SizedBox(width: 10),
        Flexible(
          // Como o portal ao vivo: o nome inteiro, cortado com reticências
          // quando falta lugar (o botão "Ajuda imediata" nunca encolhe).
          child: Text(
            perfil.paciente.nome,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CoresTerae.texto,
            ),
          ),
        ),
        if (varios) ...[
          const SizedBox(width: 4),
          const Icon(
            LucideIcons.chevronDown,
            size: 18,
            color: CoresTerae.neutro600,
          ),
        ],
      ],
    );
    if (!varios) {
      // O nó de semântica cobre o avatar e o nome, com o nome inteiro lido.
      return Semantics(
        label: perfil.paciente.nome,
        excludeSemantics: true,
        child: conteudo,
      );
    }
    return Semantics(
      button: true,
      label: 'De quem você quer ver? Agora: ${perfil.paciente.nome}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('seletor-de-paciente'),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: () => mostrarEscolhaDePaciente(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: conteudo,
          ),
        ),
      ),
    );
  }
}

/// A folha "De quem você quer ver?" (18l): um item por perfil da conta.
/// Escolher só mexe na [Sessao]; o roteador leva ao início do perfil.
Future<void> mostrarEscolhaDePaciente(BuildContext context) {
  final sessao = context.read<Sessao>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Com fonte grande a lista passa da metade da tela: a folha rola.
    isScrollControlled: true,
    backgroundColor: CoresTerae.branco,
    builder: (folha) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Semantics(
              header: true,
              child: Text(
                'De quem você quer ver?',
                style: Theme.of(folha).textTheme.titleMedium,
              ),
            ),
          ),
          for (final p in sessao.perfis)
            ListTile(
              key: Key('perfil-${p.chave}'),
              minTileHeight: 64,
              leading: Avatar(nome: p.paciente.nome),
              title: Text(p.paciente.nome),
              subtitle: Text(rotuloDoPerfil(p)),
              trailing: p == sessao.perfilAtivo
                  ? const Icon(LucideIcons.check, color: CoresTerae.primaria700)
                  : null,
              selected: p == sessao.perfilAtivo,
              onTap: () {
                Navigator.of(folha).pop();
                if (p != sessao.perfilAtivo) sessao.escolherPerfil(p);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Como a conta se relaciona com o paciente do [perfil].
String rotuloDoPerfil(Perfil perfil) => switch (perfil.papel) {
  Papel.cuidador => 'Você é cuidador',
  Papel.pacienteFamilia =>
    perfil.falaDeOutraPessoa ? 'Você é responsável' : 'Você mesmo',
};

/// As iniciais do `Avatar` do portal (`packages/ui`): a primeira letra das
/// duas primeiras partes do nome, sem contar as de até duas letras ("da",
/// "de"), exceto a última parte. "Alice Fictícia Duarte" → "AF".
String iniciaisDoNome(String nome) {
  final partes = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  final ultima = partes.last;
  final iniciais = partes
      .where((p) => p.length > 2 || p == ultima)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
  return iniciais.isEmpty ? '?' : iniciais;
}

/// Avatar do portal: círculo com as iniciais do nome ([iniciaisDoNome]).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nome, this.tamanho = 36});

  final String nome;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final iniciais = iniciaisDoNome(nome);
    return ExcludeSemantics(
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: CoresTerae.primaria100,
          shape: BoxShape.circle,
        ),
        child: Text(
          iniciais,
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: iniciais.length > 1 ? tamanho * 0.36 : tamanho * 0.42,
            fontWeight: FontWeight.w600,
            color: CoresTerae.primaria700,
          ),
        ),
      ),
    );
  }
}

/// A faixa do modo cuidador (18j), sob o topo.
class FaixaModoCuidador extends StatelessWidget {
  const FaixaModoCuidador({super.key, required this.primeiroNome});

  final String primeiroNome;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: ColoredBox(
        key: const Key('faixa-modo-cuidador'),
        color: CoresTerae.infoFundo,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  LucideIcons.handHeart,
                  size: 20,
                  color: CoresTerae.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Modo cuidador · acesso limitado. ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        // Como no portal: com o programa em casa na fonte, o
                        // cuidador "vê o programa em casa e a agenda".
                        text: capacidadesDaFonte(context).programaDoCuidador
                            ? 'Você vê o programa em casa e a agenda de '
                                  '$primeiroNome.'
                            : 'Você vê a agenda e os avisos de $primeiroNome.',
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14, color: CoresTerae.info),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
