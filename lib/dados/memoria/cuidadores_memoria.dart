import '../../nucleo/validacao/cpf.dart';
import '../enums/situacao_vinculo.dart';
import '../enums/tipo_convite.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/vinculo_cuidador.dart';
import '../repositorios/cuidadores_repositorio.dart';
import '../repositorios/falhas.dart';
import 'estado_memoria.dart';
import 'memoria_demonstracao.dart';
import 'regras.dart';

/// Cuidadores do paciente (RFM07; TM07): convidar e revogar, com o limite de
/// dois que soma ativos e pendentes com convite em aberto (§7.4, §23;
/// `dados/regras/cuidadores.dart`). Nada é apagado: revogar muda a situação e
/// preenche `revogadoEm`; pendente vencido continua na lista.
class CuidadoresMemoria implements RepositorioCuidadores {
  CuidadoresMemoria(this._memoria);

  final MemoriaDemonstracao _memoria;

  EstadoMemoria get _e => _memoria.estado;

  @override
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId) async {
    await _memoria.esperar();
    _e.exigirPaciente(pacienteId);
    return List.unmodifiable([
      for (final v in _e.vinculos.values.toList().reversed)
        if (v.pacienteId == pacienteId) _autorizado(v),
    ]);
  }

  @override
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  }) async {
    await _memoria.esperar();
    final paciente = _e.exigirPaciente(pacienteId);
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) throw ArgumentError.value(nome, 'nome', 'vazio');
    if (!paciente.ativo) {
      throw const RecusaDeRegra(MotivoRecusa.pacienteInativo);
    }
    if (!cpfValido(cpf)) throw const RecusaDeRegra(MotivoRecusa.cpfInvalido);
    final digitos = somenteDigitos(cpf);
    final agora = _memoria.agora();
    if (_e.cpfComVinculoEmAberto(pacienteId, digitos, agora: agora)) {
      throw const RecusaDeRegra(MotivoRecusa.cpfJaConvidado);
    }
    // §23 — limite conferido ao convidar (e de novo ao aceitar, na TM10).
    if (_e.vinculosNoLimite(pacienteId, agora: agora) >= limiteCuidadores) {
      throw const RecusaDeRegra(MotivoRecusa.limiteDeCuidadores);
    }
    final convite = ConviteAcesso(
      id: _memoria.novoId(),
      pacienteId: pacienteId,
      codigo: _memoria.novoCodigo(),
      tipo: TipoConvite.cuidador,
      cpfConvidado: digitos,
      expiraEm: agora.add(validadeDoConviteCuidador),
    );
    final vinculo = VinculoCuidador(
      id: _memoria.novoId(),
      pacienteId: pacienteId,
      conviteId: convite.id,
      nome: nomeLimpo,
      situacao: SituacaoVinculo.pendente,
    );
    _e.convites[convite.id] = convite;
    _e.vinculos[vinculo.id] = vinculo;
    return CuidadorAutorizado(vinculo: vinculo, convite: convite);
  }

  /// Revogar de novo devolve o vínculo como está (a data não muda).
  @override
  Future<CuidadorAutorizado> revogar(String vinculoId) async {
    await _memoria.esperar();
    final vinculo =
        _e.vinculos[vinculoId] ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
    if (vinculo.situacao == SituacaoVinculo.revogado) {
      return _autorizado(vinculo);
    }
    final revogado = vinculo.copyWith(
      situacao: SituacaoVinculo.revogado,
      revogadoEm: _memoria.agora(),
    );
    _e.vinculos[vinculoId] = revogado;
    return _autorizado(revogado);
  }

  CuidadorAutorizado _autorizado(VinculoCuidador vinculo) => CuidadorAutorizado(
    vinculo: vinculo,
    convite: _e.convites[vinculo.conviteId]!,
  );
}
