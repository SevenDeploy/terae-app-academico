import 'package:flutter/foundation.dart';

import '../../../dados/modelos/atividade_de_casa.dart';
import '../../../dados/modelos/registro_de_atividade.dart';
import '../../../dados/regras/programa_em_casa.dart';
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
  });

  final RepositorioProgramaEmCasa programa;
  final RepositorioPaciente paciente;
  final Relogio relogio;
  final String pacienteId;

  bool _carregando = true;
  bool _falhou = false;
  bool _descartado = false;
  List<AtividadeDeCasa> _atividades = const [];
  List<RegistroDeAtividade> _registros = const [];
  Map<String, String> _profissionais = const {};

  bool get carregando => _carregando;
  bool get falhou => _falhou;
  List<AtividadeDeCasa> get atividades => _atividades;
  DataCivil get hoje => DataCivil.hoje(relogio);

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

  Future<void> carregar() async {
    _carregando = true;
    _falhou = false;
    _avisar();
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
    } on Object {
      _falhou = true;
    }
    _carregando = false;
    _avisar();
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
