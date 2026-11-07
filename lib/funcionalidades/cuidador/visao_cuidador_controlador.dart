import 'package:flutter/foundation.dart';

import '../../dados/enums/resposta_presenca.dart';
import '../../dados/modelos/agendamento.dart';
import '../../dados/modelos/item_medicacao.dart';
import '../../dados/modelos/profissional_saude.dart';
import '../../dados/modelos/receita_uso_continuo.dart';
import '../../dados/repositorios/falhas.dart';
import '../../dados/repositorios/visao_cuidador_repositorio.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import 'cronograma.dart';

/// Texto do erro que não é recusa de regra (RNFM01).
const String falhaAoCarregar =
    'Não deu para carregar agora. Confira a conexão e tente de novo.';

/// Estado das telas do cuidador (RFM08; TM08, TM11, TM12): somente leitura
/// de agenda, medicação e avisos pela `RepositorioVisaoCuidador`, que já
/// devolve as cópias reduzidas (RNFM05) — sem motivo do retorno, sem CPF nem
/// nascimento, alerta só com data, hora e ciência. Cada tela cria o seu.
class VisaoCuidadorControlador extends ChangeNotifier {
  VisaoCuidadorControlador({
    required this.repositorio,
    required this.relogio,
    required this.contaCuidadorId,
    required this.pacienteId,
  });

  final RepositorioVisaoCuidador repositorio;
  final Relogio relogio;
  final String contaCuidadorId;
  final String pacienteId;

  bool _carregando = true;
  String? _erro;
  List<Agendamento> _consultas = const [];
  Map<String, ProfissionalSaude> _profissionais = const {};
  ReceitaUsoContinuo? _receita;
  List<ItemMedicacao> _itens = const [];
  List<AvisoDeAlerta> _alertas = const [];
  Map<String, RespostaPresenca> _respostas = const {};
  bool _descartado = false;

  bool get carregando => _carregando;

  /// Mensagem simples quando a carga falhou (ex.: `acessoNegado` depois de o
  /// paciente remover o acesso).
  String? get erro => _erro;

  List<Agendamento> get consultas => _consultas;
  ReceitaUsoContinuo? get receita => _receita;
  List<ItemMedicacao> get itens => _itens;
  List<AvisoDeAlerta> get alertas => _alertas;

  /// F2, D29 — o que a família respondeu sobre a presença na sessão.
  RespostaPresenca? respostaDe(Agendamento a) => _respostas[a.id];

  ProfissionalSaude? profissionalDe(Agendamento consulta) =>
      _profissionais[consulta.profissionalId];

  DateTime get agora => relogio.agora();
  DataCivil get hoje => DataCivil.hoje(relogio);

  ProximaDose? get proximaDoseAgora =>
      proximaDose(receita: _receita, itens: _itens, agora: agora);

  Agendamento? get proximaConsultaAgora => proximaConsulta(_consultas, agora);

  /// Carrega (ou recarrega, no "Tentar de novo") tudo o que as três telas
  /// mostram.
  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    _avisar();
    try {
      final consultas = await repositorio.consultas(
        contaCuidadorId: contaCuidadorId,
        pacienteId: pacienteId,
      );
      final receita = await repositorio.receitaVigente(
        contaCuidadorId: contaCuidadorId,
        pacienteId: pacienteId,
      );
      final itens = receita == null
          ? const <ItemMedicacao>[]
          : await repositorio.itensDaReceita(
              contaCuidadorId: contaCuidadorId,
              pacienteId: pacienteId,
              receitaId: receita.id,
            );
      final alertas = await repositorio.alertas(
        contaCuidadorId: contaCuidadorId,
        pacienteId: pacienteId,
      );
      // F2 (revisão): a presença é um extra; se não puder ser lida (regra
      // ainda não publicada, sem conexão e sem cópia), a agenda e os avisos
      // aparecem sem ela.
      Map<String, RespostaPresenca> respostas;
      try {
        respostas = await repositorio.respostasDePresenca(
          contaCuidadorId: contaCuidadorId,
          pacienteId: pacienteId,
        );
      } on RecusaDeRegra {
        respostas = const {};
      }
      final profissionais = <String, ProfissionalSaude>{};
      for (final id in {for (final c in consultas) c.profissionalId}) {
        profissionais[id] = await repositorio.profissional(id);
      }
      _consultas = List.unmodifiable(consultas);
      _receita = receita;
      _itens = List.unmodifiable(itens);
      _alertas = List.unmodifiable(alertas);
      _respostas = Map.unmodifiable(respostas);
      _profissionais = Map.unmodifiable(profissionais);
    } on RecusaDeRegra catch (recusa) {
      _erro = recusa.mensagem;
    } catch (_) {
      // Qualquer outra falha também vira estado de erro com "Tentar de
      // novo": a tela do cuidador nunca fica girando nem quebra.
      _erro = falhaAoCarregar;
    } finally {
      _carregando = false;
      _avisar();
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
