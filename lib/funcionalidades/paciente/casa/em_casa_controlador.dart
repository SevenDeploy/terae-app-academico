import 'package:flutter/foundation.dart';

import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/modelos/meta_terapeutica.dart';
import '../../../dados/modelos/registro_de_atividade.dart';
import '../../../dados/regras/metas.dart';
import '../../../dados/regras/programa_em_casa.dart';
import '../../../dados/repositorios/metas_repositorio.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Estado da TM16 Em casa (evolução de TO, F1): as atividades que valem hoje,
/// os registros dos últimos 14 dias e o nome de quem combinou cada uma.
class EmCasaControlador extends ChangeNotifier {
  EmCasaControlador({
    required this.programa,
    required this.paciente,
    required this.relogio,
    required this.pacienteId,
    this.metas,
  });

  final RepositorioProgramaEmCasa programa;
  final RepositorioPaciente paciente;
  final Relogio relogio;
  final String pacienteId;

  /// F3 — para mostrar a meta que cada atividade ajuda.
  final RepositorioMetas? metas;

  bool _carregando = true;
  bool _falhou = false;
  bool _descartado = false;
  List<AtividadeDeCasa> _atividades = const [];
  List<RegistroDeAtividade> _registros = const [];
  Map<String, String> _profissionais = const {};
  Map<String, MetaTerapeutica> _metas = const {};
  DataCivil? _altaEm;

  bool get carregando => _carregando;
  bool get falhou => _falhou;
  List<AtividadeDeCasa> get atividades => _atividades;
  DataCivil get hoje => DataCivil.hoje(relogio);

  /// F3 — a meta que a atividade ajuda ("Ajuda na meta: …"), se houver.
  MetaTerapeutica? metaDe(AtividadeDeCasa a) =>
      a.metaId == null ? null : _metas[a.metaId];

  /// D36 — o dia da alta da TO, quando o programa está encerrado: há alta e
  /// nenhuma atividade vale hoje. Quem decide é a vigência, como no registro,
  /// no Início e nos lembretes: se a clínica publicar atividades depois da
  /// alta (a volta à TO), o programa reabre sozinho. `null` sem alta.
  DataCivil? get programaEncerradoEm => _atividades.isEmpty ? _altaEm : null;

  /// Nome de quem combinou a atividade (vazio se a leitura falhou).
  String profissionalDe(AtividadeDeCasa a) =>
      _profissionais[a.profissionalId] ?? '';

  RegistroDeAtividade? registroDeHoje(AtividadeDeCasa a) =>
      registroDoDia(_registros, a.id, hoje);

  int vezesNaSemanaDe(AtividadeDeCasa a) =>
      vezesNaSemana(_registros, a.id, hoje);

  ({int registradas, int total}) get resumo =>
      resumoDeHoje(_atividades, _registros, hoje);

  List<DiaDaFaixa> get faixa => faixaDeDias(_registros, hoje);

  /// Lê tudo. [emSilencio] (ao voltar à aba ou quando a fila sai) relê sem o
  /// "carregando".
  Future<void> carregar({bool emSilencio = false}) async {
    if (!emSilencio) {
      _carregando = true;
      _falhou = false;
      _avisar();
    }
    try {
      final atividades = await programa.atividades(pacienteId);
      final registros = await programa.registros(pacienteId, dias: diasDaFaixa);
      final nomes = <String, String>{};
      for (final id in {for (final a in atividades) a.profissionalId}) {
        try {
          nomes[id] = (await paciente.profissional(id)).nome;
        } on Object {
          // Sem o nome, a atividade aparece do mesmo jeito.
        }
      }
      _atividades = atividades;
      _registros = registros;
      _profissionais = nomes;
      _falhou = false;
    } on Object {
      _falhou = true;
    }
    await _lerExtras();
    _carregando = false;
    _avisar();
  }

  /// F3 — a alta (D36) e as metas das atividades: extras. Se a leitura
  /// falhar, a TM16 segue sem eles.
  Future<void> _lerExtras() async {
    try {
      _altaEm = dataDaAlta(await paciente.marcos(pacienteId), hoje);
    } on Object {
      _altaEm = null;
    }
    final metas = this.metas;
    if (metas == null) return;
    try {
      _metas = {for (final m in await metas.metas(pacienteId)) m.id: m};
    } on Object {
      _metas = const {};
    }
  }

  /// "Puxar para atualizar": envia a fila, busca o servidor e relê. Sem
  /// conexão, só relê o que está no aparelho.
  Future<void> atualizar() async {
    try {
      await programa.atualizar(pacienteId);
    } on Object {
      // Sem conexão ou recusa: a tela continua com o que está no aparelho.
    }
    await carregar();
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
