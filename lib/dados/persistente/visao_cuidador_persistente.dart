import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../conversao_mapa.dart';
import '../enums/resposta_presenca.dart';
import '../enums/situacao_agendamento.dart';
import '../modelos/agendamento.dart';
import '../modelos/item_medicacao.dart';
import '../modelos/paciente.dart';
import '../modelos/profissional_saude.dart';
import '../modelos/receita_uso_continuo.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/falhas.dart';
import '../repositorios/visao_cuidador_repositorio.dart';
import 'leitura_com_copia.dart';
import 'paciente_persistente.dart';

/// Visão do cuidador no Firestore, com cópia local (RFM08, RNFM05; TM08,
/// TM11, TM12; Atividade 4).
///
/// O cuidador só lê as coleções reduzidas do paciente (`agendaCuidador`,
/// `receitaCuidador`, `itensCuidador`, `avisosCuidador`) e o documento
/// público dele, e só se o uid dele estiver em `cuidadoresAtivos` — a regra
/// do Firestore recusa o resto, e esta classe confere antes (`acessoNegado`).
class VisaoCuidadorPersistente implements RepositorioVisaoCuidador {
  VisaoCuidadorPersistente({
    required this._fonte,
    required this._leitura,
    required this._relogio,
  });

  final FonteFirestore _fonte;
  final LeituraComCopia _leitura;
  final Relogio _relogio;

  Future<Paciente> _autorizado(
    String contaCuidadorId,
    String pacienteId,
  ) async {
    final mapa = await _leitura.documento(
      'pacientesAcompanhados',
      pacienteId,
      pacienteId,
      () => _fonte.ler(_fonte.paciente(pacienteId)),
    );
    final ativos = mapa['cuidadoresAtivos'];
    final autorizado = ativos is List && ativos.contains(contaCuidadorId);
    final paciente = Paciente.fromMap(mapa);
    if (!autorizado || !paciente.ativo) {
      throw const RecusaDeRegra(MotivoRecusa.acessoNegado);
    }
    return paciente.paraCuidador();
  }

  Future<List<Mapa>> _colecao(String nome, String pacienteId) => _leitura.lista(
    nome,
    pacienteId,
    () => _fonte.listar(_fonte.doPaciente(pacienteId, nome)),
  );

  @override
  Future<Paciente> pacienteAcompanhado({
    required String contaCuidadorId,
    required String pacienteId,
  }) => _autorizado(contaCuidadorId, pacienteId);

  @override
  Future<List<Agendamento>> consultas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    final inicioDeHoje = DataCivil.hoje(_relogio).inicioNaClinica;
    return [
          for (final m in await _colecao('agendaCuidador', pacienteId))
            Agendamento.fromMap(m),
        ]
        .where(
          (a) =>
              a.situacao != SituacaoAgendamento.realizado &&
              !a.dataHora.isBefore(inicioDeHoje),
        )
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
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
  Future<ReceitaUsoContinuo?> receitaVigente({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    return receitaVigenteEntre([
      for (final m in await _colecao('receitaCuidador', pacienteId))
        ReceitaUsoContinuo.fromMap(m),
    ], DataCivil.hoje(_relogio));
  }

  @override
  Future<List<ItemMedicacao>> itensDaReceita({
    required String contaCuidadorId,
    required String pacienteId,
    required String receitaId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    return [
      for (final m in await _colecao('itensCuidador', pacienteId))
        if (m['receitaId'] == receitaId) ItemMedicacao.fromMap(m),
    ];
  }

  @override
  Future<Map<String, RespostaPresenca>> respostasDePresenca({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    return {
      for (final m in await _colecao('confirmacoes', pacienteId))
        lerCampo<String>(m, 'agendamentoId'): lerEnum(
          m,
          'resposta',
          RespostaPresenca.values,
        ),
    };
  }

  @override
  Future<List<AvisoDeAlerta>> alertas({
    required String contaCuidadorId,
    required String pacienteId,
  }) async {
    await _autorizado(contaCuidadorId, pacienteId);
    return [
      for (final m in await _colecao('avisosCuidador', pacienteId))
        AvisoDeAlerta(
          emitidoEm: lerInstante(m, 'emitidoEm'),
          cienteEm: lerInstanteOpcional(m, 'cienteEm'),
        ),
    ]..sort((a, b) => b.emitidoEm.compareTo(a.emitidoEm));
  }
}
