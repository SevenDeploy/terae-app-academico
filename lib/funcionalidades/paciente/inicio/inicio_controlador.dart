import 'package:flutter/foundation.dart';

import '../../../dados/enums/resposta_presenca.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/confirmacao_de_presenca.dart';
import '../../../dados/modelos/item_medicacao.dart';
import '../../../dados/modelos/profissional_saude.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/regras/presenca.dart';
import '../../../dados/regras/programa_em_casa.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../dados/repositorios/presenca_repositorio.dart';
import '../../../dados/repositorios/programa_em_casa_repositorio.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';

/// Estado da TM02 Início (RFM02): próxima consulta, com o profissional, e a
/// receita vigente com os itens, só leitura.
///
/// Qualquer falha de leitura vira [falhou] (a tela mostra "Tentar de novo");
/// a saudação e o atalho ao diário não dependem dela.
///
/// Evolução de TO (F1): com [programa] (só para quem tem terapia
/// ocupacional), também o resumo de hoje das atividades de casa; se essa
/// leitura falhar, o cartão some e o resto do Início segue.
class InicioControlador extends ChangeNotifier {
  InicioControlador({
    required this.repositorio,
    required this.pacienteId,
    this.programa,
    this.relogio,
    this.presenca,
  }) : assert(programa == null || relogio != null);

  final RepositorioPaciente repositorio;
  final String pacienteId;
  final RepositorioProgramaEmCasa? programa;
  final Relogio? relogio;

  /// F2 — para mostrar no cartão se a presença na próxima sessão já foi
  /// respondida.
  final RepositorioPresenca? presenca;

  /// Começa carregando: a tela chama [carregar] ao criar o controlador.
  bool _carregando = true;
  bool _falhou = false;
  Agendamento? _proximaConsulta;
  ProfissionalSaude? _profissionalDaConsulta;
  ReceitaUsoContinuo? _receita;
  List<ItemMedicacao> _itens = const [];
  ({int registradas, int total})? _emCasa;
  List<ItemDoProgramaDeHoje> _programaDeHoje = const [];
  ConfirmacaoDePresenca? _confirmacaoDaProxima;
  bool _mudando = false;
  bool _respondendo = false;
  String? _erroDaResposta;
  bool _descartado = false;

  bool get carregando => _carregando;
  bool get falhou => _falhou;
  Agendamento? get proximaConsulta => _proximaConsulta;
  ProfissionalSaude? get profissionalDaConsulta => _profissionalDaConsulta;
  ReceitaUsoContinuo? get receita => _receita;
  List<ItemMedicacao> get itens => _itens;

  /// "Hoje: 1 de 2 atividades registradas"; `null` sem programa ou se a
  /// leitura falhou.
  ({int registradas, int total})? get emCasa => _emCasa;

  /// A lista do cartão "Programa em casa · hoje" (como no portal): cada
  /// orientação do dia com o estado e, quando a fonte diz, quem registrou.
  List<ItemDoProgramaDeHoje> get itensDoPrograma => _programaDeHoje;

  /// F2 — a resposta de presença da próxima consulta ou sessão, se houver.
  RespostaPresenca? get respostaDaProxima => _confirmacaoDaProxima?.resposta;

  /// A confirmação inteira (com a situação de envio), para o recado.
  ConfirmacaoDePresenca? get confirmacaoDaProxima => _confirmacaoDaProxima;

  /// O Início responde a presença no próprio cartão (18d), como a Agenda.
  bool get temPresenca => presenca != null && _proximaConsulta != null;

  /// Mostra os botões: dá para responder e ainda não há resposta, ou "Mudar a
  /// resposta" foi tocado.
  bool get perguntando =>
      podeResponderNaProxima && (_confirmacaoDaProxima == null || _mudando);

  bool get podeMudar =>
      podeResponderNaProxima && _confirmacaoDaProxima != null && !_mudando;

  /// Só até a sessão começar (D27); `relogio` ausente (dublê antigo) vale
  /// como "dá".
  bool get podeResponderNaProxima {
    final consulta = _proximaConsulta;
    if (!temPresenca || consulta == null) return false;
    final agora = relogio?.agora();
    return agora == null || podeResponder(consulta, agora);
  }

  bool get respondendo => _respondendo;
  String? get erroDaResposta => _erroDaResposta;

  void mudarResposta() {
    _mudando = true;
    _avisar();
  }

  /// Responde a presença da próxima sessão. Falha vira [erroDaResposta].
  Future<void> responder(RespostaPresenca resposta) async {
    final consulta = _proximaConsulta;
    final presenca = this.presenca;
    if (consulta == null || presenca == null || _respondendo) return;
    _respondendo = true;
    _erroDaResposta = null;
    _avisar();
    try {
      _confirmacaoDaProxima = await presenca.responder(
        pacienteId: pacienteId,
        agendamentoId: consulta.id,
        resposta: resposta,
      );
      _mudando = false;
    } on RecusaDeRegra catch (r) {
      _erroDaResposta = r.motivo.mensagem;
    } on Object {
      _erroDaResposta = 'Não foi possível responder agora. Tente de novo.';
    }
    _respondendo = false;
    _avisar();
  }

  /// Lê tudo do repositório. Na primeira vez não avisa no início (a tela já
  /// nasce carregando); em "Tentar de novo", mostra o indicador.
  Future<void> carregar({bool emSilencio = false}) async {
    if (!_carregando && !emSilencio) {
      _carregando = true;
      _falhou = false;
      _avisar();
    }
    try {
      final consulta = await repositorio.proximaConsulta(pacienteId);
      final receita = await repositorio.receitaVigente(pacienteId);
      final profissional = consulta == null
          ? null
          : await repositorio.profissional(consulta.profissionalId);
      final itens = receita == null
          ? const <ItemMedicacao>[]
          : await repositorio.itensDaReceita(receita.id);
      _proximaConsulta = consulta;
      _profissionalDaConsulta = profissional;
      _receita = receita;
      _itens = List.unmodifiable(itens);
      _confirmacaoDaProxima = consulta == null || presenca == null
          ? null
          : (await presenca!.respostas(pacienteId))[consulta.id];
      _mudando = false;
      _falhou = false;
    } catch (_) {
      // Dublê sem dado, recusa ou falha de leitura: a tela oferece de novo.
      _falhou = true;
    }
    await _lerEmCasa();
    _carregando = false;
    _avisar();
  }

  /// Refaz só o resumo das atividades de casa, sem o "carregando" (ao voltar
  /// à aba Início depois de registrar na TM17).
  Future<void> atualizarEmCasa() async {
    if (programa == null) return;
    await _lerEmCasa();
    _avisar();
  }

  Future<void> _lerEmCasa() async {
    final programa = this.programa;
    if (programa == null) return;
    try {
      final atividades = await programa.atividades(pacienteId);
      final registros = await programa.registros(pacienteId, dias: 1);
      final hoje = DataCivil.hoje(relogio!);
      _emCasa = resumoDeHoje(atividades, registros, hoje);
      _programaDeHoje = List.unmodifiable(
        programaDeHoje(atividades, registros, hoje),
      );
    } catch (_) {
      _emCasa = null;
      _programaDeHoje = const [];
    }
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
