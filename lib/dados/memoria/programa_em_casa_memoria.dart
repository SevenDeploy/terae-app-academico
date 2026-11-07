import '../enums/adesao_em_casa.dart';
import '../enums/quem_registrou.dart';
import '../enums/situacao_envio.dart';
import '../modelos/atividade_de_casa.dart';
import '../modelos/registro_de_atividade.dart';
import '../regras/programa_em_casa.dart';
import '../repositorios/falhas.dart';
import '../repositorios/programa_em_casa_repositorio.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// O programa em casa (evolução de TO, F1; D26; TM16, TM17) sobre a memória:
/// as atividades vêm da demonstração e os registros seguem a mesma fila
/// simulada do diário — sem conexão ficam em [EstadoMemoria.filaCasa] e saem
/// quando a conexão volta (`DemonstracaoMemoria`).
class ProgramaEmCasaMemoria implements RepositorioProgramaEmCasa {
  ProgramaEmCasaMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<List<AtividadeDeCasa>> atividades(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable(
      atividadesVigentes(
        _e.atividadesCasa.values.where((a) => a.pacienteId == pacienteId),
        _memoria.hoje(),
      ),
    );
  }

  @override
  Future<AtividadeDeCasa> atividade(
    String pacienteId,
    String atividadeId,
  ) async {
    await _memoria.esperar();
    return _vigente(pacienteId, atividadeId);
  }

  @override
  Future<List<RegistroDeAtividade>> registros(
    String pacienteId, {
    int dias = 14,
  }) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    final inicio = _memoria.hoje().somarDias(-(dias - 1));
    return List.unmodifiable(
      _doPaciente(pacienteId)
          .where((r) => !r.excluido && !r.dia.ehAntesDe(inicio)),
    );
  }

  @override
  Future<RegistroDeAtividade> registrar({
    required String pacienteId,
    required String atividadeId,
    required AdesaoEmCasa adesao,
    String? reflexao,
    required QuemRegistrou quem,
  }) async {
    await _memoria.esperar();
    _vigente(pacienteId, atividadeId);
    final hoje = _memoria.hoje();
    final agora = _memoria.agora();
    final existente = registroParaReaproveitar(
      _doPaciente(pacienteId),
      atividadeId,
      hoje,
    );
    final novo =
        existente?.corrigido(
          adesao: adesao,
          reflexao: reflexao,
          quem: quem,
          em: agora,
        ) ??
        RegistroDeAtividade(
          id: _memoria.novoId(),
          pacienteId: pacienteId,
          atividadeId: atividadeId,
          dia: hoje,
          adesao: adesao,
          reflexao: reflexao,
          quem: quem,
          registradoEm: agora,
          situacaoEnvio: SituacaoEnvio.naFila,
        );
    return _enfileirarOuEnviar(novo);
  }

  @override
  Future<RegistroDeAtividade> desfazer(
    String pacienteId,
    String registroId,
  ) async {
    await _memoria.esperar();
    final atual = _e.filaCasa[registroId] ?? _e.registrosCasa[registroId];
    if (atual == null || atual.pacienteId != pacienteId) {
      throw const RecusaDeRegra(MotivoRecusa.registroInexistente);
    }
    if (!podeAlterarRegistro(atual, _memoria.hoje())) {
      throw const RecusaDeRegra(MotivoRecusa.edicaoEncerrada);
    }
    return _enfileirarOuEnviar(atual.desfeitoAs(_memoria.agora()));
  }

  @override
  Future<void> atualizar(String pacienteId) async {
    await _memoria.esperar();
    if (_memoria.semConexao) return;
    _e.receberFilaCasa();
    _memoria.atualizarConexao();
  }

  /// A atividade que vale hoje, deste paciente; senão recusa.
  AtividadeDeCasa _vigente(String pacienteId, String atividadeId) {
    final a = _e.atividadesCasa[atividadeId];
    if (a == null ||
        a.pacienteId != pacienteId ||
        !a.vigenteEm(_memoria.hoje())) {
      throw const RecusaDeRegra(MotivoRecusa.atividadeInexistente);
    }
    return a;
  }

  /// Todos os registros do paciente na última versão (a da fila vence a do
  /// servidor), mesmo os desfeitos, do mais recente ao mais antigo.
  List<RegistroDeAtividade> _doPaciente(String pacienteId) => ordenar(
    {
      ..._e.registrosCasa,
      ..._e.filaCasa,
    }.values.where((r) => r.pacienteId == pacienteId),
    (a, b) {
      final porDia = b.dia.compareTo(a.dia);
      return porDia != 0 ? porDia : b.registradoEm.compareTo(a.registradoEm);
    },
  );

  /// Sem conexão, a nova versão fica na fila; com conexão, o servidor recebe
  /// a fila inteira (ela inclusive).
  RegistroDeAtividade _enfileirarOuEnviar(RegistroDeAtividade novo) {
    _e.filaCasa[novo.id] = novo;
    if (!_memoria.semConexao) _e.receberFilaCasa();
    _memoria.atualizarConexao();
    return _e.filaCasa[novo.id] ?? _e.registrosCasa[novo.id]!;
  }
}
