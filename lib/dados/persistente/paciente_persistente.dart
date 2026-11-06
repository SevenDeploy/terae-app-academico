import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../enums/situacao_agendamento.dart';
import '../local/cache_dao.dart';
import '../modelos/agendamento.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/marco_jornada.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import '../repositorios/paciente_repositorio.dart';
import 'leitura_com_copia.dart';

/// Leitura do paciente e da jornada no Firestore, com cópia local (RFM02,
/// RFM06; TM02, TM05, TM06; Atividade 4). Só leitura: cadastrar consulta,
/// receita e marco é da clínica (a semente faz o papel dela).
class PacientePersistente implements RepositorioPaciente {
  PacientePersistente({
    required this._fonte,
    required this._leitura,
    required this._cache,
    required this._relogio,
  });

  final FonteFirestore _fonte;
  final CacheDao _cache;
  final LeituraComCopia _leitura;
  final Relogio _relogio;

  @override
  Future<Paciente> paciente(String pacienteId) async {
    final mapa = await _leitura.documento(
      'pacientes',
      pacienteId,
      pacienteId,
      () async {
        final publico = await _fonte.ler(_fonte.paciente(pacienteId));
        if (publico == null) return null;
        final privado = await _fonte.ler(_fonte.identificacao(pacienteId));
        return {...publico, ...?privado};
      },
    );
    return Paciente.fromMap(mapa);
  }

  @override
  Future<ProfissionalSaude> profissional(String profissionalId) async =>
      ProfissionalSaude.fromMap(
        await _leitura.documento(
          'profissionais',
          profissionalId,
          'todos',
          () => _fonte.ler(_fonte.profissionais.doc(profissionalId)),
        ),
      );

  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) async {
    final mapas = await _leitura.lista(
      'agendamentos',
      pacienteId,
      () => _fonte.listar(_fonte.doPaciente(pacienteId, 'agendamentos')),
    );
    return [for (final m in mapas) Agendamento.fromMap(m)]
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
  }

  @override
  Future<Agendamento?> proximaConsulta(String pacienteId) async {
    final agora = _relogio.agora();
    for (final a in await agendamentos(pacienteId)) {
      if (a.situacao == SituacaoAgendamento.agendado &&
          !a.dataHora.isBefore(agora)) {
        return a;
      }
    }
    return null;
  }

  @override
  Future<ReceitaUsoContinuo?> receitaVigente(String pacienteId) async {
    final mapas = await _leitura.lista(
      'receitas',
      pacienteId,
      () => _fonte.listar(_fonte.doPaciente(pacienteId, 'receitas')),
    );
    return receitaVigenteEntre([
      for (final m in mapas) ReceitaUsoContinuo.fromMap(m),
    ], DataCivil.hoje(_relogio));
  }

  @override
  Future<List<ItemMedicacao>> itensDaReceita(String receitaId) async {
    // O item mora sob o paciente; quem é o paciente sai da cópia da receita,
    // guardada quando a receita vigente foi lida.
    final receita = await _cache.ler('receitas', receitaId);
    final pacienteId = receita?['pacienteId'];
    if (pacienteId is! String) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    final mapas = await _leitura.lista(
      'itensMedicacao',
      pacienteId,
      () => _fonte.listar(_fonte.doPaciente(pacienteId, 'itensMedicacao')),
    );
    return [
      for (final m in mapas)
        if (m['receitaId'] == receitaId) ItemMedicacao.fromMap(m),
    ];
  }

  @override
  Future<List<MarcoJornada>> marcos(String pacienteId) async {
    final mapas = await _leitura.lista(
      'marcos',
      pacienteId,
      () => _fonte.listar(_fonte.doPaciente(pacienteId, 'marcos')),
    );
    return [for (final m in mapas) MarcoJornada.fromMap(m)]
      ..sort((a, b) => a.data.compareTo(b.data));
  }
}

/// RFM02 — a receita vigente em [hoje]; havendo mais de uma, a de início
/// mais recente (a mesma regra da memória).
ReceitaUsoContinuo? receitaVigenteEntre(
  Iterable<ReceitaUsoContinuo> receitas,
  DataCivil hoje,
) {
  ReceitaUsoContinuo? vigente;
  for (final r in receitas) {
    if (!r.vigenteEm(hoje)) continue;
    if (vigente == null ||
        r.vigenciaInicio.ehDepoisDe(vigente.vigenciaInicio)) {
      vigente = r;
    }
  }
  return vigente;
}
