import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../nucleo/tempo/relogio.dart';
import '../local/preferencias_locais.dart';
import '../persistente/lembretes_locais.dart';
import '../repositorios/lembretes_repositorio.dart';
import '../repositorios/repositorios.dart';
import 'autenticacao_terae_local.dart';
import 'cliente_do_portal.dart';
import 'configuracao_terae_local.dart';
import 'contexto_do_portal.dart';
import 'diario_terae_local.dart';
import 'guarda_do_dispositivo_em_preferencias.dart';
import 'indisponiveis_terae_local.dart';
import 'repositorios_terae_local.dart';

/// O app montado sobre o Terae local. Quem monta a `Sessao` (o `main.dart`)
/// liga [aoSair] ao "Sair" dela e a `Sessao.sair` ao
/// [ContextoDoPortal.aoSessaoAcabar] (401 fora da entrada volta à TM01).
class TeraeLocalMontado {
  const TeraeLocalMontado({
    required this.repositorios,
    required this.contexto,
    required this.aoSair,
  });

  final Repositorios repositorios;
  final ContextoDoPortal contexto;

  /// D20 — "Sair": revoga a sessão no servidor e cancela os lembretes.
  final Future<void> Function() aoSair;
}

/// Monta a fonte `local` (decisão do dono de 26/11/2026): os repositórios
/// do Terae local sobre o [ClienteDoPortal], sem Firebase e sem SQLite.
///
/// A [configuracao] já passou pela trava ([exigirUrlLocal]); o cliente
/// confere de novo ao nascer. Os lembretes continuam locais (D28),
/// calculados da agenda e do programa que vêm do portal. Nenhuma chamada de
/// rede acontece aqui: a primeira é a senha, na TM01.
Future<TeraeLocalMontado> montarTeraeLocal({
  required ConfiguracaoTeraeLocal configuracao,
  required Relogio relogio,
  SharedPreferences? preferencias,
  HttpClient? http,
  RepositorioLembretes? lembretes,
}) async {
  if (configuracao.fonte != FonteDeDados.local) {
    throw ArgumentError.value(configuracao.fonte, 'fonte', 'não é a local');
  }
  final prefs = preferencias ?? await SharedPreferences.getInstance();
  final contexto = ContextoDoPortal(
    cliente: ClienteDoPortal(
      url: configuracao.url,
      dispositivo: GuardaDoDispositivoEmPreferencias(prefs),
      relogio: relogio,
      http: http,
    ),
  );
  final autenticacao = AutenticacaoTeraeLocal(contexto);
  final paciente = PacienteTeraeLocal(contexto);
  final programa = ProgramaTeraeLocal(contexto);
  final diario = DiarioTeraeLocal(
    contexto,
    fila: GuardaDaFilaEmPreferencias(prefs),
  );
  final lembretesDaFonte =
      lembretes ??
      LembretesLocais(
        preferencias: PreferenciasLocais(prefs),
        paciente: paciente,
        programa: programa,
        relogio: relogio,
      );
  final repositorios = Repositorios(
    autenticacao: autenticacao,
    paciente: paciente,
    diario: diario,
    cuidadores: const CuidadoresIndisponiveisNoTeraeLocal(),
    visaoCuidador: VisaoCuidadorTeraeLocal(contexto),
    demonstracao: const SemDemonstracaoNoTeraeLocal(),
    programaEmCasa: programa,
    presenca: PresencaTeraeLocal(contexto),
    lembretes: lembretesDaFonte,
    metas: const MetasIndisponiveisNoTeraeLocal(),
    capacidades: CapacidadesDaFonte.teraeLocal,
  );
  return TeraeLocalMontado(
    repositorios: repositorios,
    contexto: contexto,
    aoSair: () async {
      await autenticacao.sair();
      await lembretesDaFonte.cancelarTudo();
      await diario.esquecer();
    },
  );
}
