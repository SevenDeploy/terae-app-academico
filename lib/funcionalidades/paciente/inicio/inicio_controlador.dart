import 'package:flutter/foundation.dart';

import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/item_medicacao.dart';
import '../../../dados/modelos/profissional_saude.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';

/// Estado da TM02 Início (RFM02): próxima consulta, com o profissional, e a
/// receita vigente com os itens, só leitura.
///
/// Qualquer falha de leitura vira [falhou] (a tela mostra "Tentar de novo");
/// a saudação e o atalho ao diário não dependem dela.
class InicioControlador extends ChangeNotifier {
  InicioControlador({required this.repositorio, required this.pacienteId});

  final RepositorioPaciente repositorio;
  final String pacienteId;

  /// Começa carregando: a tela chama [carregar] ao criar o controlador.
  bool _carregando = true;
  bool _falhou = false;
  Agendamento? _proximaConsulta;
  ProfissionalSaude? _profissionalDaConsulta;
  ReceitaUsoContinuo? _receita;
  List<ItemMedicacao> _itens = const [];
  bool _descartado = false;

  bool get carregando => _carregando;
  bool get falhou => _falhou;
  Agendamento? get proximaConsulta => _proximaConsulta;
  ProfissionalSaude? get profissionalDaConsulta => _profissionalDaConsulta;
  ReceitaUsoContinuo? get receita => _receita;
  List<ItemMedicacao> get itens => _itens;

  /// Lê tudo do repositório. Na primeira vez não avisa no início (a tela já
  /// nasce carregando); em "Tentar de novo", mostra o indicador.
  Future<void> carregar() async {
    if (!_carregando) {
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
    } catch (_) {
      // Dublê sem dado, recusa ou falha de leitura: a tela oferece de novo.
      _falhou = true;
    }
    _carregando = false;
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
