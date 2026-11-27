import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dados/repositorios/diario_repositorio.dart';
import 'funcionalidades/autenticacao/cadastro_cuidador_tela.dart';
import 'funcionalidades/autenticacao/cadastro_paciente_tela.dart';
import 'funcionalidades/autenticacao/entrar_tela.dart';
import 'funcionalidades/conta/conta_tela.dart';
import 'funcionalidades/cuidador/agenda_avisos_tela.dart';
import 'funcionalidades/cuidador/inicio_cuidador_tela.dart';
import 'funcionalidades/cuidador/medicacao_tela.dart';
import 'funcionalidades/moldura/moldura_do_portal.dart';
import 'funcionalidades/paciente/casa/atividade_tela.dart';
import 'funcionalidades/paciente/casa/em_casa_tela.dart';
import 'funcionalidades/paciente/cuidadores/cuidadores_tela.dart';
import 'funcionalidades/paciente/diario/ajuda_imediata_tela.dart';
import 'funcionalidades/paciente/diario/diario_enviado_tela.dart';
import 'funcionalidades/paciente/diario_indisponivel_tela.dart';
import 'funcionalidades/paciente/inicio/inicio_tela.dart';
import 'funcionalidades/paciente/jornada/jornada_tela.dart';
import 'funcionalidades/paciente/lembretes/lembretes_tela.dart';
import 'funcionalidades/paciente/lembretes/reagenda_lembretes.dart';
import 'funcionalidades/paciente/metas/meta_tela.dart';
import 'funcionalidades/paciente/registros/correcao_tela.dart';
import 'funcionalidades/paciente/registros/novo_registro_tela.dart';
import 'funcionalidades/paciente/registros/registro_tela.dart';
import 'funcionalidades/paciente/sessoes/sessoes_tela.dart';
import 'funcionalidades/publico/boas_vindas_tela.dart';
import 'nucleo/rotas/rotas.dart';
import 'nucleo/sessao/sessao.dart';

/// Rota inicial de cada papel: TM02 ou TM08.
String inicioDoPapel(Papel papel) => switch (papel) {
  Papel.pacienteFamilia => Rotas.pacienteInicio,
  Papel.cuidador => Rotas.cuidadorInicio,
};

/// Guarda de perfil — a única do app (§21 "Regras de navegação", RNFM05 na
/// navegação). Devolve para onde redirecionar, ou `null` se [caminho] abre:
///
/// - sem sessão, só as rotas públicas abrem; o resto vai para a TM00;
/// - com sessão e sem perfil ativo (conta de vários perfis), tudo vai para a
///   seleção `/entrar/perfil`, que só abre com sessão;
/// - com perfil ativo, rota pública (e a seleção) leva ao início do perfil, e
///   cada papel só alcança as próprias rotas — nem por link direto o cuidador
///   chega ao diário;
/// - D22: rota de linha de cuidado que o paciente não tem (a aba "Em casa"
///   sem terapia ocupacional) leva ao início, como as de outro papel;
/// - caminho desconhecido segue a mesma regra (cai no início ou na TM00);
/// - a ajuda imediata do topo ([Rotas.livres]) abre sempre, como no portal.
String? guardaDePerfil(Sessao sessao, String caminho) {
  if (Rotas.livres.contains(caminho)) return null;
  if (!sessao.autenticada) {
    return Rotas.publicas.contains(caminho) ? null : Rotas.boasVindas;
  }
  final ativo = sessao.perfilAtivo;
  if (ativo == null) {
    return caminho == Rotas.entrarPerfil ? null : Rotas.entrarPerfil;
  }
  final permitidas = switch (ativo.papel) {
    Papel.pacienteFamilia => Rotas.doPaciente,
    Papel.cuidador => Rotas.doCuidador,
  };
  final foraDaLinha =
      (Rotas.daTerapiaOcupacional.contains(caminho) &&
          !ativo.paciente.temTerapiaOcupacional) ||
      (Rotas.doAcompanhamentoClinico.contains(caminho) &&
          !ativo.paciente.temAcompanhamentoClinico);
  return permitidas.contains(caminho) && !foraDaLinha
      ? null
      : inicioDoPapel(ativo.papel);
}

/// GoRouter do app: guarda única; as abas do paciente e as do cuidador na
/// [MolduraDoPortal], cada papel num `StatefulShellRoute.indexedStack` (ramos
/// fixos na ordem de [ramosDoPaciente] e [ramosDoCuidador]; a barra mostra
/// só os da linha de cuidado, D22),
/// TM04/TM05 no navegador raiz (tela cheia,
/// acima das abas), TM11/TM12 sobre a TM08 e TM13 (novo registro), TM14 e
/// TM15 (corrigir) empilhadas sobre as abas (P3). Reavalia a guarda a cada
/// mudança da [sessao].
GoRouter criarRoteador({
  required Sessao sessao,
  String localInicial = Rotas.boasVindas,
}) {
  final raiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');
  return GoRouter(
    navigatorKey: raiz,
    initialLocation: localInicial,
    refreshListenable: sessao,
    redirect: (context, state) => guardaDePerfil(sessao, state.uri.path),
    routes: [
      GoRoute(
        path: Rotas.boasVindas,
        pageBuilder: (context, state) => _pagina(state, const BoasVindasTela()),
      ),
      GoRoute(
        path: Rotas.entrar,
        pageBuilder: (context, state) => _pagina(state, const EntrarTela()),
      ),
      GoRoute(
        path: Rotas.entrarPerfil,
        pageBuilder: (context, state) =>
            _pagina(state, const EntrarTela(selecaoDePerfil: true)),
      ),
      GoRoute(
        path: Rotas.cadastroPaciente,
        pageBuilder: (context, state) =>
            _pagina(state, const CadastroPacienteTela()),
      ),
      GoRoute(
        path: Rotas.cadastroCuidador,
        pageBuilder: (context, state) =>
            _pagina(state, const CadastroCuidadorTela()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => _pagina(
          state,
          MolduraDoPortal(
            navigationShell: navigationShell,
            ramos: ramosDoPaciente,
            envolver: (moldura, {required noInicio}) =>
                ReagendaLembretes(noInicio: noInicio, child: moldura),
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.pacienteInicio,
                pageBuilder: (context, state) =>
                    _pagina(state, const InicioTela()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.pacienteDiario,
                pageBuilder: (context, state) =>
                    _pagina(state, const DiarioDaFonte()),
                routes: [
                  GoRoute(
                    path: Rotas.segmentoEnviado,
                    parentNavigatorKey: raiz,
                    pageBuilder: (context, state) => _pagina(
                      state,
                      _VoltaPara(
                        destino: Rotas.pacienteInicio,
                        child: DiarioEnviadoTela(envio: _envio(state)),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: Rotas.segmentoAjuda,
                    parentNavigatorKey: raiz,
                    pageBuilder: (context, state) => _pagina(
                      state,
                      _VoltaPara(
                        destino: Rotas.pacienteInicio,
                        child: AjudaImediataTela(envio: _envio(state)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.pacienteCasa,
                pageBuilder: (context, state) =>
                    _pagina(state, const EmCasaTela()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.pacienteSessoes,
                pageBuilder: (context, state) =>
                    _pagina(state, const SessoesTela()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.pacienteConta,
                pageBuilder: (context, state) =>
                    _pagina(state, const ContaTela()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rotas.ajuda,
        pageBuilder: (context, state) =>
            _pagina(state, const AjudaImediataTela(envio: null)),
      ),
      // A Jornada (marcos e metas) saiu da barra: empilha sobre as abas,
      // aberta pelo Em casa.
      GoRoute(
        path: Rotas.pacienteJornada,
        pageBuilder: (context, state) => _pagina(state, const JornadaTela()),
      ),
      // D22: a TM07 saiu da barra de abas e abre pelo menu do Início,
      // empilhada; voltar leva ao Início, mesmo por link direto.
      GoRoute(
        path: Rotas.pacienteCuidadores,
        pageBuilder: (context, state) => _pagina(
          state,
          const _VoltaPara(
            destino: Rotas.pacienteInicio,
            child: CuidadoresTela(),
          ),
        ),
      ),
      // F1: a TM17 empilha sobre as abas e desempilha ao voltar (a TM16
      // espera a volta para reler o dia); por link direto, a seta leva à TM16.
      GoRoute(
        path: Rotas.pacienteAtividade,
        pageBuilder: (context, state) =>
            _pagina(state, AtividadeTela(atividadeId: _id(state))),
      ),
      // F3: a TM20 empilha sobre as abas (aberta pela Jornada e pela TM17) e
      // desempilha ao voltar; por link direto, a seta vai à Jornada.
      GoRoute(
        path: Rotas.pacienteMeta,
        pageBuilder: (context, state) =>
            _pagina(state, MetaTela(metaId: _id(state))),
      ),
      GoRoute(
        path: Rotas.pacienteLembretes,
        pageBuilder: (context, state) => _pagina(state, const LembretesTela()),
      ),
      GoRoute(
        path: Rotas.pacienteNovoRegistro,
        pageBuilder: (context, state) =>
            _pagina(state, const NovoRegistroTela()),
      ),
      GoRoute(
        path: Rotas.pacienteRegistro,
        pageBuilder: (context, state) =>
            _pagina(state, RegistroTela(registroId: _id(state))),
      ),
      GoRoute(
        path: Rotas.pacienteCorrigirRegistro,
        pageBuilder: (context, state) =>
            _pagina(state, CorrecaoTela(registroId: _id(state))),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => _pagina(
          state,
          MolduraDoPortal(
            navigationShell: navigationShell,
            ramos: ramosDoCuidador,
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.cuidadorInicio,
                pageBuilder: (context, state) =>
                    _pagina(state, const InicioCuidadorTela()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.cuidadorAgenda,
                pageBuilder: (context, state) =>
                    _pagina(state, const AgendaAvisosTela()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.cuidadorConta,
                pageBuilder: (context, state) =>
                    _pagina(state, const ContaTela()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rotas.cuidadorMedicacao,
        pageBuilder: (context, state) => _pagina(
          state,
          const _VoltaPara(
            destino: Rotas.cuidadorInicio,
            child: MedicacaoTela(),
          ),
        ),
      ),
    ],
  );
}

/// Página Material (o go_router 18 só reconhece o `MaterialApp` do pacote
/// material_ui; sem isto cairia em página sem transição).
Page<void> _pagina(GoRouterState state, Widget tela) =>
    MaterialPage<void>(key: state.pageKey, name: state.uri.path, child: tela);

/// O id na consulta (`?id=`) da TM14/TM15/TM17; vazio se faltar (a tela
/// mostra "não encontramos").
String _id(GoRouterState state) => state.uri.queryParameters['id'] ?? '';

/// O `ResultadoEnvio` passado pelo diário em `extra`; nulo em link direto.
ResultadoEnvio? _envio(GoRouterState state) {
  final extra = state.extra;
  return extra is ResultadoEnvio ? extra : null;
}

/// Voltar (Android, seta da AppBar) vai a [destino] em vez de desempilhar:
/// TM04/TM05 → Início, nunca de volta ao formulário (evita reenvio); TM11/TM12
/// → TM08, e TM07 → TM02 (D22), mesmo se abertas por link direto (§21).
class _VoltaPara extends StatelessWidget {
  const _VoltaPara({required this.destino, required this.child});

  final String destino;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) GoRouter.of(context).go(destino);
      },
      child: child,
    );
  }
}
