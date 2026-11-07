import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as dados_de_fuso;
import 'package:timezone/timezone.dart' as fuso;

import '../../nucleo/tempo/relogio.dart';
import '../lembretes/calculo.dart';
import '../lembretes/lembrete.dart';
import '../local/preferencias_locais.dart';
import '../repositorios/lembretes_repositorio.dart';
import '../repositorios/paciente_repositorio.dart';
import '../repositorios/programa_em_casa_repositorio.dart';

/// Lembretes locais do Android (evolução de TO, F2; D28), pelo
/// `flutter_local_notifications`, no fuso da clínica (`America/Cuiaba`,
/// −04:00, como na D7). Sem alarme exato (`inexactAllowWhileIdle`): o
/// lembrete pode atrasar alguns minutos, e o app não pede a permissão de
/// alarme exato. As preferências ficam em SharedPreferences.
class LembretesLocais implements RepositorioLembretes {
  LembretesLocais({
    required this._preferencias,
    required this._paciente,
    required this._programa,
    required this._relogio,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final PreferenciasLocais _preferencias;
  final RepositorioPaciente _paciente;
  final RepositorioProgramaEmCasa _programa;
  final Relogio _relogio;
  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _iniciado;
  late fuso.Location _fusoDaClinica;

  /// Sobe a cada [cancelarTudo]: um [reagendar] que começou antes desiste.
  int _geracao = 0;

  /// Os [reagendar] rodam em fila, um depois do outro.
  Future<void> _anterior = Future.value();

  static const NotificationDetails _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes',
      'Lembretes',
      channelDescription:
          'Véspera das sessões e consultas e atividades de casa.',
    ),
  );

  Future<void> _iniciar() => _iniciado ??= () async {
    dados_de_fuso.initializeTimeZones();
    _fusoDaClinica = fuso.getLocation('America/Cuiaba');
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }();

  @override
  Future<PreferenciasDeLembrete> preferencias() async =>
      _preferencias.lembretes;

  @override
  Future<void> salvar(PreferenciasDeLembrete preferencias) =>
      _preferencias.guardarLembretes(preferencias);

  @override
  Future<bool> pedirPermissao() async {
    await _iniciar();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> notificacoesPermitidas() async {
    await _iniciar();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  @override
  Future<List<Lembrete>> reagendar(List<String> pacienteIds) {
    final esta = _anterior.then((_) => _reagendar(pacienteIds));
    _anterior = esta.then<void>((_) {}, onError: (Object _) {});
    return esta;
  }

  Future<List<Lembrete>> _reagendar(List<String> pacienteIds) async {
    final geracao = _geracao;
    await _iniciar();
    final lembretes = await calcularLembretes(
      preferencias: _preferencias.lembretes,
      pacienteIds: pacienteIds,
      paciente: _paciente,
      programa: _programa,
      agora: _relogio.agora(),
    );
    // A leitura pode levar segundos (RNFM03): se o "Sair" veio no meio, não
    // agenda nada.
    if (geracao != _geracao) return const [];
    await _plugin.cancelAll();
    for (final l in lembretes) {
      if (geracao != _geracao) break;
      await _plugin.zonedSchedule(
        id: l.id,
        scheduledDate: fuso.TZDateTime.from(l.quando, _fusoDaClinica),
        notificationDetails: _detalhes,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: l.titulo,
        body: l.texto,
      );
    }
    if (geracao != _geracao) {
      // O "Sair" cancelou durante o agendamento: cancela de novo o que
      // entrou depois dele.
      await _plugin.cancelAll();
      return const [];
    }
    return lembretes;
  }

  @override
  Future<void> testar() async {
    await _iniciar();
    await _plugin.show(
      id: 1,
      title: 'Terae',
      body: 'Os lembretes do Terae estão ligados neste celular.',
      notificationDetails: _detalhes,
    );
  }

  @override
  Future<void> cancelarTudo() async {
    _geracao++;
    await _preferencias.apagarLembretes();
    await _iniciar();
    await _plugin.cancelAll();
  }
}
