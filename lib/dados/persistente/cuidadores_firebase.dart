import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/uuid.dart';
import '../../nucleo/validacao/cpf.dart';
import '../conversao_mapa.dart';
import '../enums/situacao_vinculo.dart';
import '../enums/tipo_convite.dart';
import '../memoria/regras.dart'
    show gerarCodigoConvite, validadeDoConviteCuidador;
import '../modelos/convite_acesso.dart';
import '../modelos/vinculo_cuidador.dart';
import '../remoto/fonte_firestore.dart';
import '../repositorios/cuidadores_repositorio.dart';
import '../repositorios/falhas.dart';
import '../sincronizacao/monitor_conexao.dart';
import 'leitura_com_copia.dart';

/// Cuidadores do paciente no Firestore (RFM07; TM07; Atividade 4), com as
/// regras da memória: limite de dois (ativos e pendentes em aberto), CPF que
/// já ocupa vaga, nada apagado. Convidar e revogar pedem conexão
/// (`semConexao`); a lista usa a cópia local quando não há conexão.
///
/// Convidar grava, num lote: o vínculo pendente, o convite completo do
/// paciente (`pacientes/{pid}/convites`) e o convite público
/// (`convites/{codigo}`, com o CPF só como hash) que a TM10 confere.
class CuidadoresFirebase implements RepositorioCuidadores {
  CuidadoresFirebase({
    required this._fonte,
    required this._leitura,
    required this._monitor,
    required this._relogio,
    String Function()? gerarId,
    Random? aleatorio,
  }) : _gerarId = gerarId ?? gerarUuidV4,
       _aleatorio = aleatorio ?? Random.secure();

  final FonteFirestore _fonte;
  final LeituraComCopia _leitura;
  final MonitorConexao _monitor;
  final Relogio _relogio;
  final String Function() _gerarId;
  final Random _aleatorio;

  @override
  Future<List<CuidadorAutorizado>> cuidadores(String pacienteId) async {
    final vinculos = await _leitura.lista(
      'vinculos',
      pacienteId,
      () => _fonte.listar(
        _fonte.vinculos.where('pacienteId', isEqualTo: pacienteId),
      ),
    );
    final convites = {
      for (final m in await _leitura.lista(
        'convitesDoPaciente',
        pacienteId,
        () => _fonte.listar(_fonte.doPaciente(pacienteId, 'convites')),
      ))
        lerCampo<String>(m, 'id'): ConviteAcesso.fromMap(m),
    };
    // Mais novo primeiro, como na memória.
    final lista = [
      for (final m in vinculos)
        if (convites[m['conviteId']] case final convite?)
          CuidadorAutorizado(
            vinculo: VinculoCuidador.fromMap(m),
            convite: convite,
          ),
    ]..sort((a, b) => b.convite.expiraEm.compareTo(a.convite.expiraEm));
    return List.unmodifiable(lista);
  }

  @override
  Future<CuidadorAutorizado> convidar({
    required String pacienteId,
    required String nome,
    required String cpf,
  }) async {
    if (!_monitor.online) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) throw ArgumentError.value(nome, 'nome', 'vazio');
    if (!cpfValido(cpf)) throw const RecusaDeRegra(MotivoRecusa.cpfInvalido);
    final digitos = somenteDigitos(cpf);
    final agora = _relogio.agora();
    final atuais = await cuidadores(pacienteId);
    final ocupando = atuais.where((c) => c.contaNoLimite(agora));
    if (ocupando.any((c) => c.convite.cpfConvidado == digitos)) {
      throw const RecusaDeRegra(MotivoRecusa.cpfJaConvidado);
    }
    // §23 — limite conferido ao convidar (e, no aceite, pela regra do
    // Firestore sobre `cuidadoresAtivos`).
    if (ocupando.length >= limiteCuidadores) {
      throw const RecusaDeRegra(MotivoRecusa.limiteDeCuidadores);
    }
    final paciente =
        await _fonte.ler(_fonte.paciente(pacienteId)) ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
    if (paciente['ativo'] == false) {
      throw const RecusaDeRegra(MotivoRecusa.pacienteInativo);
    }
    final codigo = await _codigoLivre();
    final convite = ConviteAcesso(
      id: _gerarId(),
      pacienteId: pacienteId,
      codigo: codigo,
      tipo: TipoConvite.cuidador,
      cpfConvidado: digitos,
      expiraEm: agora.add(validadeDoConviteCuidador),
    );
    final vinculo = VinculoCuidador(
      id: _gerarId(),
      pacienteId: pacienteId,
      conviteId: convite.id,
      nome: nomeLimpo,
      situacao: SituacaoVinculo.pendente,
    );
    final lote = _fonte.db.batch()
      ..set(_fonte.vinculos.doc(vinculo.id), vinculo.toMap())
      ..set(
        _fonte.doPaciente(pacienteId, 'convites').doc(convite.id),
        convite.toMap(),
      )
      ..set(_fonte.convites.doc(codigo), {
        'id': convite.id,
        'codigo': codigo,
        'pacienteId': pacienteId,
        'tipo': TipoConvite.cuidador.name,
        'cpfHash': hashDoConvite(codigo, digitos),
        'expiraEm': escreverInstante(convite.expiraEm),
        'usadoEm': null,
        'revogado': false,
        'vinculoId': vinculo.id,
        'nomePaciente': lerCampo<String>(paciente, 'nome'),
        'pacienteAtivo': true,
      });
    await _fonte.gravar(lote);
    return CuidadorAutorizado(vinculo: vinculo, convite: convite);
  }

  /// Revogar de novo devolve o vínculo como está (a data não muda).
  @override
  Future<CuidadorAutorizado> revogar(String vinculoId) async {
    if (!_monitor.online) {
      throw const RecusaDeRegra(MotivoRecusa.semConexao);
    }
    final mapa =
        await _fonte.ler(_fonte.vinculos.doc(vinculoId)) ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
    final vinculo = VinculoCuidador.fromMap(mapa);
    final conviteMapa =
        await _fonte.ler(
          _fonte
              .doPaciente(vinculo.pacienteId, 'convites')
              .doc(vinculo.conviteId),
        ) ??
        (throw const RecusaDeRegra(MotivoRecusa.acessoNegado));
    final convite = ConviteAcesso.fromMap(conviteMapa);
    if (vinculo.situacao == SituacaoVinculo.revogado) {
      return CuidadorAutorizado(vinculo: vinculo, convite: convite);
    }
    final revogado = vinculo.copyWith(
      situacao: SituacaoVinculo.revogado,
      revogadoEm: _relogio.agora(),
    );
    final lote = _fonte.db.batch()
      ..update(_fonte.vinculos.doc(vinculoId), {
        'situacao': SituacaoVinculo.revogado.name,
        'revogadoEm': revogado.toMap()['revogadoEm'],
      })
      ..update(_fonte.convites.doc(convite.codigo), {'revogado': true});
    final conta = vinculo.contaCuidadorId;
    if (conta != null) {
      lote.update(_fonte.paciente(vinculo.pacienteId), {
        'cuidadoresAtivos': FieldValue.arrayRemove([conta]),
      });
    }
    await _fonte.gravar(lote);
    return CuidadorAutorizado(vinculo: revogado, convite: convite);
  }

  /// Código de convite que ainda não existe no Firestore.
  Future<String> _codigoLivre() async {
    while (true) {
      final codigo = gerarCodigoConvite(_aleatorio);
      if (await _fonte.ler(_fonte.convites.doc(codigo)) == null) return codigo;
    }
  }
}
