/// Os lembretes no Android (evolução de TO, F2; D28), com o plugin de
/// mentira: fuso da clínica, sem alarme exato, o "Sair" e a ordem das
/// chamadas (achado 4 da revisão da F2).
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terae_app/dados/enums/situacao_agendamento.dart';
import 'package:terae_app/dados/lembretes/lembrete.dart';
import 'package:terae_app/dados/local/preferencias_locais.dart';
import 'package:terae_app/dados/modelos/agendamento.dart';
import 'package:terae_app/dados/persistente/lembretes_locais.dart';
import 'package:terae_app/dados/repositorios/paciente_repositorio.dart';
import 'package:terae_app/dados/repositorios/programa_em_casa_repositorio.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:timezone/timezone.dart' as fuso;

/// Guarda o que seria agendado no Android.
class _PluginDeMentira implements FlutterLocalNotificationsPlugin {
  final Map<int, Map<Symbol, Object?>> agendados = {};
  int cancelamentos = 0;

  @override
  dynamic noSuchMethod(Invocation chamada) {
    switch (chamada.memberName) {
      case #cancelAll:
        cancelamentos++;
        agendados.clear();
      case #zonedSchedule:
        agendados[chamada.namedArguments[#id]! as int] = chamada.namedArguments;
    }
    return Future<bool>.value(true);
  }
}

/// Agenda do paciente que só responde quando a [porta] abre (a leitura do
/// servidor pode levar até 2 s, RNFM03).
class _PacienteLento implements RepositorioPaciente {
  _PacienteLento(this.sessao);

  final DateTime sessao;
  Completer<void> porta = Completer<void>()..complete();

  @override
  Future<List<Agendamento>> agendamentos(String pacienteId) async {
    await porta.future;
    return [
      Agendamento(
        id: 'ag',
        pacienteId: pacienteId,
        profissionalId: 'pr',
        dataHora: sessao,
        situacao: SituacaoAgendamento.agendado,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation chamada) => super.noSuchMethod(chamada);
}

class _SemPrograma implements RepositorioProgramaEmCasa {
  @override
  dynamic noSuchMethod(Invocation chamada) => super.noSuchMethod(chamada);
}

/// 2/10/2026 10:00 na clínica; a sessão é no dia 5, às 08:00.
final DateTime _agora = instanteNaClinica(2026, 10, 2, 10);
final DateTime _sessao = instanteNaClinica(2026, 10, 5, 8);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferenciasLocais prefs;
  late _PluginDeMentira plugin;
  late _PacienteLento paciente;
  late LembretesLocais lembretes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferenciasLocais.abrir();
    plugin = _PluginDeMentira();
    paciente = _PacienteLento(_sessao);
    lembretes = LembretesLocais(
      preferencias: prefs,
      paciente: paciente,
      programa: _SemPrograma(),
      relogio: RelogioFixo(_agora),
      plugin: plugin,
    );
  });

  test('agenda a véspera no fuso da clínica, sem alarme exato, com o texto '
      'genérico', () async {
    await lembretes.salvar(
      const PreferenciasDeLembrete(vesperaDaSessao: true, horaDaVespera: 20),
    );
    final agendados = await lembretes.reagendar(['p']);
    expect(agendados, hasLength(1));
    final args = plugin.agendados.values.single;
    final quando = args[#scheduledDate]! as fuso.TZDateTime;
    expect(quando.location.name, 'America/Cuiaba');
    expect(quando.isAtSameMomentAs(instanteNaClinica(2026, 10, 4, 20)), isTrue);
    expect(quando.hour, 20);
    expect(
      args[#androidScheduleMode],
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
    expect(args[#title], 'Terae');
    expect(args[#body], 'Amanhã às 08:00 tem compromisso na clínica.');
  });

  test('"Sair": cancela no Android e apaga as escolhas', () async {
    await lembretes.salvar(const PreferenciasDeLembrete(vesperaDaSessao: true));
    await lembretes.reagendar(['p']);
    expect(plugin.agendados, isNotEmpty);
    await lembretes.cancelarTudo();
    expect(plugin.agendados, isEmpty);
    expect(await lembretes.preferencias(), const PreferenciasDeLembrete());
  });

  test('"Sair" enquanto um reagendamento lê a agenda: nada volta a ser '
      'agendado (achado 4)', () async {
    await lembretes.salvar(const PreferenciasDeLembrete(vesperaDaSessao: true));
    paciente.porta = Completer<void>();
    final emCurso = lembretes.reagendar(['p']);
    await Future<void>.delayed(Duration.zero);
    await lembretes.cancelarTudo();
    paciente.porta.complete();
    expect(await emCurso, isEmpty);
    expect(plugin.agendados, isEmpty);
  });

  test('reagendamentos seguidos rodam em ordem, e o segundo usa as escolhas '
      'salvas entre eles', () async {
    await lembretes.salvar(
      const PreferenciasDeLembrete(vesperaDaSessao: true, horaDaVespera: 19),
    );
    paciente.porta = Completer<void>();
    final primeiro = lembretes.reagendar(['p']);
    await Future<void>.delayed(Duration.zero);
    await lembretes.salvar(
      const PreferenciasDeLembrete(vesperaDaSessao: true, horaDaVespera: 21),
    );
    final segundo = lembretes.reagendar(['p']);
    paciente.porta.complete();
    await primeiro;
    final finais = await segundo;
    expect(finais.single.quando, instanteNaClinica(2026, 10, 4, 21));
    final quando =
        plugin.agendados.values.single[#scheduledDate]! as fuso.TZDateTime;
    expect(quando.hour, 21);
  });
}
