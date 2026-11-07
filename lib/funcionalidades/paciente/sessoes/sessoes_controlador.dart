import 'package:flutter/foundation.dart';

import '../../../dados/enums/resposta_presenca.dart';
import '../../../dados/enums/situacao_agendamento.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/confirmacao_de_presenca.dart';
import '../../../dados/modelos/profissional_saude.dart';
import '../../../dados/regras/presenca.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/presenca_repositorio.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Estado da TM18 Sessões (evolução de TO, F2; D27): as sessões e consultas
/// marcadas e as anteriores, com o profissional, e a resposta de presença de
/// cada uma que ainda não começou.
class SessoesControlador extends ChangeNotifier {
  SessoesControlador({
    required this.paciente,
    required this.presenca,
    required this.relogio,
    required this.pacienteId,
  });

  final RepositorioPaciente paciente;
  final RepositorioPresenca presenca;
  final Relogio relogio;
  final String pacienteId;

  bool _carregando = true;
  bool _falhou = false;
  bool _descartado = false;
  List<Agendamento> _agendamentos = const [];
  Map<String, ProfissionalSaude> _profissionais = const {};
  Map<String, ConfirmacaoDePresenca> _respostas = const {};
  final Set<String> _mudando = {};
  String? _respondendo;
  String? _erro;
  String? _erroDe;

  bool get carregando => _carregando;
  bool get falhou => _falhou;

  /// Marcadas de agora em diante, da mais próxima à mais distante.
  List<Agendamento> get proximas => [
    for (final a in _agendamentos)
      if (a.situacao == SituacaoAgendamento.agendado &&
          !a.dataHora.isBefore(relogio.agora()))
        a,
  ];

  /// As que já passaram ou foram canceladas, da mais recente à mais antiga.
  List<Agendamento> get anteriores => [
    for (final a in _agendamentos.reversed)
      if (a.situacao != SituacaoAgendamento.agendado ||
          a.dataHora.isBefore(relogio.agora()))
        a,
  ];

  ProfissionalSaude? profissionalDe(Agendamento a) =>
      _profissionais[a.profissionalId];

  ConfirmacaoDePresenca? respostaDe(Agendamento a) => _respostas[a.id];

  /// Mostra os botões: ainda sem resposta, ou "Mudar a resposta" tocado.
  bool perguntando(Agendamento a) =>
      podeResponder(a, relogio.agora()) &&
      (_respostas[a.id] == null || _mudando.contains(a.id));

  bool podeMudar(Agendamento a) =>
      podeResponder(a, relogio.agora()) &&
      _respostas[a.id] != null &&
      !_mudando.contains(a.id);

  /// O agendamento cuja resposta está indo (desliga os botões dele).
  String? get respondendo => _respondendo;

  /// Falha ao responder, em linguagem simples, e de qual agendamento.
  String? erroDe(Agendamento a) => _erroDe == a.id ? _erro : null;

  Future<void> carregar() async {
    _carregando = true;
    _falhou = false;
    _avisar();
    try {
      final agendamentos = await paciente.agendamentos(pacienteId);
      final profissionais = <String, ProfissionalSaude>{};
      for (final id in {for (final a in agendamentos) a.profissionalId}) {
        profissionais[id] = await paciente.profissional(id);
      }
      _agendamentos = agendamentos;
      _profissionais = profissionais;
      _respostas = await presenca.respostas(pacienteId);
    } on Object {
      _falhou = true;
    }
    _carregando = false;
    _avisar();
  }

  void mudarResposta(Agendamento a) {
    _mudando.add(a.id);
    _avisar();
  }

  Future<void> responder(Agendamento a, RespostaPresenca resposta) async {
    if (_respondendo != null) return;
    _respondendo = a.id;
    _erro = null;
    _erroDe = null;
    _avisar();
    try {
      final c = await presenca.responder(
        pacienteId: pacienteId,
        agendamentoId: a.id,
        resposta: resposta,
      );
      _respostas = {..._respostas, a.id: c};
      _mudando.remove(a.id);
    } on RecusaDeRegra catch (r) {
      _erro = r.motivo.mensagem;
      _erroDe = a.id;
    } on Object {
      _erro = 'Não foi possível responder agora. Tente de novo.';
      _erroDe = a.id;
    }
    _respondendo = null;
    _avisar();
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
