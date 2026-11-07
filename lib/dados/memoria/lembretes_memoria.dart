import '../lembretes/calculo.dart';
import '../lembretes/lembrete.dart';
import '../repositorios/lembretes_repositorio.dart';
import 'memoria_demonstracao.dart';

/// Lembretes na memória (F2, D28): para a web e os testes, onde não há
/// notificação do Android. Guarda o que seria agendado em [agendados] e
/// quantos testes foram pedidos em [testes], para o teste conferir.
class LembretesMemoria implements RepositorioLembretes {
  LembretesMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  PreferenciasDeLembrete _preferencias = const PreferenciasDeLembrete();

  /// O que está "agendado" agora.
  List<Lembrete> agendados = const [];

  /// Quantos lembretes de teste foram pedidos.
  int testes = 0;

  /// A resposta simulada do pedido de permissão.
  bool permitido = true;

  /// A permissão já foi dada (num pedido anterior).
  bool jaPermitiu = false;

  /// Como em `LembretesLocais`: sobe a cada [cancelarTudo], e um [reagendar]
  /// que começou antes desiste.
  int _geracao = 0;

  @override
  Future<PreferenciasDeLembrete> preferencias() async => _preferencias;

  @override
  Future<void> salvar(PreferenciasDeLembrete preferencias) async =>
      _preferencias = preferencias;

  @override
  Future<bool> pedirPermissao() async => jaPermitiu = permitido;

  @override
  Future<bool> notificacoesPermitidas() async => jaPermitiu;

  @override
  Future<List<Lembrete>> reagendar(List<String> pacienteIds) async {
    final geracao = _geracao;
    final calculados = await calcularLembretes(
      preferencias: _preferencias,
      pacienteIds: pacienteIds,
      paciente: _memoria.repositorios.paciente,
      programa: _memoria.repositorios.programaEmCasa,
      agora: _memoria.agora(),
    );
    if (geracao != _geracao) return const [];
    return agendados = List.unmodifiable(calculados);
  }

  @override
  Future<void> testar() async => testes++;

  @override
  Future<void> cancelarTudo() async {
    _geracao++;
    agendados = const [];
    _preferencias = const PreferenciasDeLembrete();
  }
}
