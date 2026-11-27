import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../dados/enums/qualidade_consentimento.dart';
import '../../dados/modelos/conta_usuario.dart';
import '../../dados/modelos/paciente.dart';
import '../../dados/repositorios/autenticacao_repositorio.dart';

/// Papel exercido em relação a um paciente (§19).
enum Papel {
  pacienteFamilia('Paciente ou família'),
  cuidador('Cuidador');

  const Papel(this.rotulo);

  final String rotulo;
}

/// D24 — de quem o app fala neste perfil.
enum Voz {
  /// O próprio paciente usa o app: "Como foi hoje?", "Fiz".
  primeiraPessoa,

  /// Outra pessoa usa o app pelo paciente (responsável legal ou cuidador):
  /// "Como foi com Miguel hoje?", "Fizemos".
  terceiraPessoa,
}

/// O perfil: um papel exercido em relação a um paciente. Não é escolhido
/// livremente nem gravado na conta — decorre dos vínculos (§19, §23).
@immutable
class Perfil {
  const Perfil({
    required this.papel,
    required this.paciente,
    this.voz = Voz.primeiraPessoa,
  });

  final Papel papel;

  /// No papel cuidador, é a cópia sem CPF nem nascimento (RNFM05).
  final Paciente paciente;

  /// D24 — calculada uma vez pela [Sessao.perfisDe]: o cuidador e o
  /// responsável legal falam do paciente; o titular fala de si.
  final Voz voz;

  bool get falaDeOutraPessoa => voz == Voz.terceiraPessoa;

  String get pacienteId => paciente.id;

  /// Identifica o perfil entre aberturas do app (SharedPreferences, D16):
  /// `papel:pacienteId`. Não leva dado pessoal além do id.
  String get chave => '${papel.name}:$pacienteId';

  @override
  bool operator ==(Object other) =>
      other is Perfil &&
      other.papel == papel &&
      other.paciente.id == pacienteId;

  @override
  int get hashCode => Object.hash(papel, pacienteId);

  @override
  String toString() => 'Perfil(${papel.name}, $pacienteId)';
}

/// Conta autenticada, perfis derivados dos vínculos e perfil ativo (RFM01).
///
/// O roteador escuta esta classe (`refreshListenable`) e decide a rota a cada
/// mudança: as telas chamam [entrar], [escolherPerfil], [trocarPerfil] e
/// [sair] e NÃO navegam depois — a guarda leva ao lugar certo.
///
/// Atividade 4: a sessão do provedor sobrevive ao fechar o app (o Firebase
/// guarda o token), e o `main.dart` a reabre com [entrar] passando o
/// [Perfil.chave] guardado. [aoMudarPerfil] grava a chave do perfil ativo
/// (SharedPreferences) e [aoSair] encerra a sessão no provedor e apaga os
/// dados locais (D20).
class Sessao extends ChangeNotifier {
  Sessao({this.aoMudarPerfil, this.aoSair, this.aoSessaoAcabar});

  /// Chamado com a [Perfil.chave] do perfil ativo, ou `null` sem perfil.
  final void Function(String? chaveDoPerfil)? aoMudarPerfil;

  /// Chamado depois de [sair] (D20), sem esperar.
  final Future<void> Function()? aoSair;

  /// Chamado depois de [encerrarPorFimDeSessao], sem esperar. Não apaga o
  /// que a pessoa guardou no aparelho (o diário na fila): só o "Sair" que ela
  /// escolheu apaga (revisão da P4, B1).
  final Future<void> Function()? aoSessaoAcabar;

  ContaUsuario? _conta;
  List<Perfil> _perfis = const [];
  Perfil? _perfilAtivo;

  ContaUsuario? get conta => _conta;

  bool get autenticada => _conta != null;

  /// Perfis da conta, paciente/família primeiro, depois por nome.
  List<Perfil> get perfis => _perfis;

  /// `null` sem sessão, ou com sessão de vários perfis antes da escolha.
  Perfil? get perfilAtivo => _perfilAtivo;

  /// Mostra "Trocar perfil" no menu da TM02/TM08.
  bool get temVariosPerfis => _perfis.length > 1;

  /// Deriva os perfis dos vínculos: um paciente/família por paciente ativo da
  /// conta e um cuidador por paciente acompanhado ativo. A voz (D24) vem da
  /// qualidade do termo: responsável legal e cuidador falam do paciente.
  static List<Perfil> perfisDe(VinculosDaConta vinculos) {
    int porNome(Perfil a, Perfil b) =>
        a.paciente.nome.compareTo(b.paciente.nome);
    final familia = [
      for (final p in vinculos.pacientes)
        if (p.ativo)
          Perfil(
            papel: Papel.pacienteFamilia,
            paciente: p,
            voz:
                vinculos.qualidades[p.id] ==
                    QualidadeConsentimento.responsavelLegal
                ? Voz.terceiraPessoa
                : Voz.primeiraPessoa,
          ),
    ]..sort(porNome);
    final cuidador = [
      for (final p in vinculos.acompanhados)
        if (p.ativo)
          Perfil(papel: Papel.cuidador, paciente: p, voz: Voz.terceiraPessoa),
    ]..sort(porNome);
    return List.unmodifiable([...familia, ...cuidador]);
  }

  /// Abre a sessão. Com um perfil só, ele já fica ativo; com mais de um,
  /// fica ativo o de [perfilGuardado] (a [Perfil.chave] da última abertura),
  /// se ainda existir — senão nenhum, e o roteador leva à seleção
  /// (`/entrar/perfil`). Lança [StateError] se os vínculos não derem nenhum
  /// perfil (o repositório já recusa esse caso com `contaSemAcesso`).
  void entrar(VinculosDaConta vinculos, {String? perfilGuardado}) {
    final perfis = perfisDe(vinculos);
    if (perfis.isEmpty) {
      throw StateError('Conta sem nenhum perfil ativo');
    }
    _conta = vinculos.conta;
    _perfis = perfis;
    _perfilAtivo = perfis.length == 1
        ? perfis.single
        : perfis.where((p) => p.chave == perfilGuardado).firstOrNull;
    _avisar();
  }

  /// Ativa um dos perfis da conta (seleção da TM01). Lança [ArgumentError]
  /// se o perfil não for desta conta.
  void escolherPerfil(Perfil perfil) {
    if (!_perfis.contains(perfil)) {
      throw ArgumentError.value(perfil, 'perfil', 'não é desta conta');
    }
    _perfilAtivo = perfil;
    _avisar();
  }

  /// "Trocar perfil": desativa o perfil e o roteador reabre a seleção. Não faz
  /// nada em conta de um perfil só (o menu nem mostra a opção).
  void trocarPerfil() {
    if (!temVariosPerfis || _perfilAtivo == null) return;
    _perfilAtivo = null;
    _avisar();
  }

  /// "Sair": encerra a sessão; o roteador leva à TM00, e [aoSair] apaga os
  /// dados locais em seguida (D20).
  void sair() {
    if (!_limpar()) return;
    final aoSair = this.aoSair;
    if (aoSair != null) unawaited(aoSair().catchError((Object _) {}));
  }

  /// A sessão acabou no servidor (401, Terae local): volta à entrada como o
  /// [sair], mas chama [aoSessaoAcabar] em vez de [aoSair]. O que a pessoa
  /// guardou no aparelho fica, e sai quando ela entrar de novo.
  void encerrarPorFimDeSessao() {
    if (!_limpar()) return;
    final aoSessaoAcabar = this.aoSessaoAcabar;
    if (aoSessaoAcabar != null) {
      unawaited(aoSessaoAcabar().catchError((Object _) {}));
    }
  }

  bool _limpar() {
    if (_conta == null) return false;
    _conta = null;
    _perfis = const [];
    _perfilAtivo = null;
    _avisar();
    return true;
  }

  void _avisar() {
    aoMudarPerfil?.call(_perfilAtivo?.chave);
    notifyListeners();
  }
}
