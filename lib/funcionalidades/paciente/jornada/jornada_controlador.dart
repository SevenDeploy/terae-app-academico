import 'package:flutter/foundation.dart';

import '../../../dados/enums/situacao_agendamento.dart';
import '../../../dados/enums/tipo_marco.dart';
import '../../../dados/modelos/agendamento.dart';
import '../../../dados/modelos/marco_jornada.dart';
import '../../../dados/modelos/profissional_saude.dart';
import '../../../dados/modelos/receita_uso_continuo.dart';
import '../../../dados/repositorios/paciente_repositorio.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';

/// Tipo de um ponto da linha do tempo da TM06.
enum TipoItemJornada { consulta, reavaliacao, orientacao, proximoPasso }

/// Um ponto da linha do tempo, já em linguagem simples (RFM06, RNFM01).
@immutable
class ItemJornada {
  const ItemJornada({
    required this.id,
    required this.tipo,
    required this.instante,
    required this.titulo,
    required this.quando,
    this.texto,
    this.situacao,
    this.rotulo,
  });

  final String id;
  final TipoItemJornada tipo;

  /// Para ordenar: a hora da consulta ou o começo do dia do marco.
  final DateTime instante;
  final String titulo;

  /// "Quarta-feira, 7 de outubro às 14:00 · em 5 dias".
  final String quando;

  /// Texto simples do marco.
  final String? texto;

  /// Situação da consulta quando não é "marcada" (realizada, cancelada).
  final SituacaoAgendamento? situacao;

  /// F2 — o rótulo acima do título, quando não é o do [tipo] ("Sessão" na
  /// terapia ocupacional).
  final String? rotulo;
}

/// Estado da TM06 Jornada (RFM06): linha do tempo de consultas e marcos,
/// orientação vigente e próximos passos. Só leitura.
class JornadaControlador extends ChangeNotifier {
  JornadaControlador({
    required this.repositorio,
    required this.relogio,
    required this.pacienteId,
  });

  final RepositorioPaciente repositorio;
  final Relogio relogio;
  final String pacienteId;

  bool _carregando = true;
  bool _falhou = false;
  ReceitaUsoContinuo? _receita;
  List<ItemJornada> _proximos = const [];
  List<ItemJornada> _historia = const [];
  bool _descartado = false;

  bool get carregando => _carregando;
  bool get falhou => _falhou;
  ReceitaUsoContinuo? get receita => _receita;

  /// Consultas marcadas e marcos de hoje em diante, do mais perto ao mais
  /// longe.
  List<ItemJornada> get proximos => _proximos;

  /// O que já aconteceu (e consultas canceladas), do mais recente ao mais
  /// antigo.
  List<ItemJornada> get historia => _historia;

  bool get vazia => _proximos.isEmpty && _historia.isEmpty && _receita == null;

  Future<void> carregar() async {
    if (!_carregando) {
      _carregando = true;
      _falhou = false;
      _avisar();
    }
    try {
      final consultas = await repositorio.agendamentos(pacienteId);
      final marcos = await repositorio.marcos(pacienteId);
      final receita = await repositorio.receitaVigente(pacienteId);
      final profissionais = <String, ProfissionalSaude>{};
      for (final id in {for (final c in consultas) c.profissionalId}) {
        profissionais[id] = await repositorio.profissional(id);
      }
      _montar(consultas, marcos, profissionais);
      _receita = receita;
    } catch (_) {
      // Dublê sem dado, recusa ou falha de leitura: a tela oferece de novo.
      _falhou = true;
    }
    _carregando = false;
    _avisar();
  }

  void _montar(
    List<Agendamento> consultas,
    List<MarcoJornada> marcos,
    Map<String, ProfissionalSaude> profissionais,
  ) {
    final agora = relogio.agora();
    final hoje = DataCivil.hoje(relogio);
    final proximos = <ItemJornada>[];
    final historia = <ItemJornada>[];

    for (final c in consultas) {
      final profissional = profissionais[c.profissionalId];
      final relativo = descricaoRelativa(
        DataCivil.doInstante(c.dataHora),
        hoje: hoje,
      );
      final item = ItemJornada(
        id: c.id,
        tipo: TipoItemJornada.consulta,
        instante: c.dataHora,
        // F2: "Sessão de terapia ocupacional com …" ou "Consulta com …".
        titulo: profissional == null
            ? nomeDoEncontro(null)
            : '${nomeDoEncontro(profissional)} com ${profissional.nome}',
        quando:
            '${formatarDiaPorExtenso(c.dataHora)} às '
            '${formatarHora(c.dataHora)} · $relativo',
        situacao: c.situacao == SituacaoAgendamento.agendado
            ? null
            : c.situacao,
        rotulo: tituloDoEncontro(profissional),
      );
      final marcada = c.situacao == SituacaoAgendamento.agendado;
      (marcada && !c.dataHora.isBefore(agora) ? proximos : historia).add(item);
    }

    for (final m in marcos) {
      final item = ItemJornada(
        id: m.id,
        tipo: switch (m.tipo) {
          TipoMarco.reavaliacao => TipoItemJornada.reavaliacao,
          TipoMarco.orientacao => TipoItemJornada.orientacao,
          TipoMarco.proximoPasso => TipoItemJornada.proximoPasso,
        },
        instante: m.data.inicioNaClinica,
        titulo: m.titulo,
        quando:
            '${formatarDataCivilPorExtenso(m.data)} · '
            '${descricaoRelativa(m.data, hoje: hoje)}',
        texto: m.textoSimples,
      );
      (m.data.ehAntesDe(hoje) ? historia : proximos).add(item);
    }

    proximos.sort((a, b) => a.instante.compareTo(b.instante));
    historia.sort((a, b) => b.instante.compareTo(a.instante));
    _proximos = List.unmodifiable(proximos);
    _historia = List.unmodifiable(historia);
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
