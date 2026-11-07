import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../dados/repositorios/lembretes_repositorio.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../registros/componentes_registros.dart';

/// F2 (D28) — refaz os lembretes locais com a agenda de agora dos pacientes
/// da conta (os perfis paciente/família). Fica nas abas do paciente e refaz:
/// - quando as abas abrem (login, app aberto do zero);
/// - quando o app volta do segundo plano;
/// - quando a pessoa volta à aba Início ([noInicio]);
/// - quando uma sincronização termina ou a fila muda (sessões novas do
///   servidor).
///
/// Assim os 7 dias de lembretes das atividades de casa não acabam com o app
/// vivo em segundo plano. Pedidos que chegam enquanto um roda viram um só,
/// depois dele. O lembrete é um extra: uma falha só vai para o log.
class ReagendaLembretes extends StatefulWidget {
  const ReagendaLembretes({
    super.key,
    required this.noInicio,
    required this.child,
  });

  /// A aba ativa é o Início.
  final bool noInicio;
  final Widget child;

  @override
  State<ReagendaLembretes> createState() => _ReagendaLembretesState();
}

class _ReagendaLembretesState extends State<ReagendaLembretes> {
  late final AppLifecycleListener _ciclo;
  bool _rodando = false;
  bool _deNovo = false;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: _reagendar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reagendar());
  }

  @override
  void didUpdateWidget(ReagendaLembretes antigo) {
    super.didUpdateWidget(antigo);
    if (widget.noInicio && !antigo.noInicio) _reagendar();
  }

  void _reagendar() => unawaited(_reagendarAgora());

  Future<void> _reagendarAgora() async {
    if (_rodando) {
      _deNovo = true;
      return;
    }
    _rodando = true;
    try {
      do {
        _deNovo = false;
        if (!mounted) return;
        final lembretes = context.read<RepositorioLembretes>();
        final pacienteIds = [
          for (final p in context.read<Sessao>().perfis)
            if (p.papel == Papel.pacienteFamilia) p.pacienteId,
        ];
        try {
          await lembretes.reagendar(pacienteIds);
        } on Object catch (erro) {
          debugPrint('Lembretes não refeitos: $erro');
        }
      } while (_deNovo);
    } finally {
      _rodando = false;
    }
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RecarregaAoSincronizar(aoMudar: _reagendar, child: widget.child);
}
