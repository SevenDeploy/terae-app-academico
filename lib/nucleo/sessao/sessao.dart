import 'package:flutter/foundation.dart';

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

/// O perfil: um papel exercido em relação a um paciente. Não é escolhido
/// livremente nem gravado na conta — decorre dos vínculos (§19, §23).
@immutable
class Perfil {
  const Perfil({required this.papel, required this.paciente});

  final Papel papel;

  /// No papel cuidador, é a cópia sem CPF nem nascimento (RNFM05).
  final Paciente paciente;

  String get pacienteId => paciente.id;

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
/// Só memória (D6: nada persiste no aparelho nesta etapa). O roteador escuta
/// esta classe (`refreshListenable`) e decide a rota a cada mudança: as telas
/// chamam [entrar], [escolherPerfil], [trocarPerfil] e [sair] e NÃO navegam
/// depois — a guarda leva ao lugar certo.
class Sessao extends ChangeNotifier {
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
  /// conta e um cuidador por paciente acompanhado ativo.
  static List<Perfil> perfisDe(VinculosDaConta vinculos) {
    int porNome(Perfil a, Perfil b) =>
        a.paciente.nome.compareTo(b.paciente.nome);
    final familia = [
      for (final p in vinculos.pacientes)
        if (p.ativo) Perfil(papel: Papel.pacienteFamilia, paciente: p),
    ]..sort(porNome);
    final cuidador = [
      for (final p in vinculos.acompanhados)
        if (p.ativo) Perfil(papel: Papel.cuidador, paciente: p),
    ]..sort(porNome);
    return List.unmodifiable([...familia, ...cuidador]);
  }

  /// Abre a sessão. Com um perfil só, ele já fica ativo; com mais de um,
  /// nenhum — o roteador leva à seleção (`/entrar/perfil`). Lança
  /// [StateError] se os vínculos não derem nenhum perfil (o repositório já
  /// recusa esse caso com `contaSemAcesso`).
  void entrar(VinculosDaConta vinculos) {
    final perfis = perfisDe(vinculos);
    if (perfis.isEmpty) {
      throw StateError('Conta sem nenhum perfil ativo');
    }
    _conta = vinculos.conta;
    _perfis = perfis;
    _perfilAtivo = perfis.length == 1 ? perfis.single : null;
    notifyListeners();
  }

  /// Ativa um dos perfis da conta (seleção da TM01). Lança [ArgumentError]
  /// se o perfil não for desta conta.
  void escolherPerfil(Perfil perfil) {
    if (!_perfis.contains(perfil)) {
      throw ArgumentError.value(perfil, 'perfil', 'não é desta conta');
    }
    _perfilAtivo = perfil;
    notifyListeners();
  }

  /// "Trocar perfil": desativa o perfil e o roteador reabre a seleção. Não faz
  /// nada em conta de um perfil só (o menu nem mostra a opção).
  void trocarPerfil() {
    if (!temVariosPerfis || _perfilAtivo == null) return;
    _perfilAtivo = null;
    notifyListeners();
  }

  /// "Sair": encerra a sessão; o roteador leva à TM00.
  void sair() {
    if (_conta == null) return;
    _conta = null;
    _perfis = const [];
    _perfilAtivo = null;
    notifyListeners();
  }
}
