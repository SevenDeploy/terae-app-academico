/// Lembretes na memória e as preferências no aparelho (evolução de TO, F2;
/// D20, D28).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terae_app/dados/lembretes/lembrete.dart';
import 'package:terae_app/dados/local/preferencias_locais.dart';
import 'package:terae_app/dados/memoria/lembretes_memoria.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'memoria_apoio.dart';

void main() {
  test('Antônio: véspera da sessão de daqui a 7 dias e as atividades de '
      'casa', () async {
    final m = memoriaDeTeste();
    final lembretes = m.repositorios.lembretes as LembretesMemoria;
    await lembretes.salvar(
      const PreferenciasDeLembrete(
        vesperaDaSessao: true,
        horaDaVespera: 19,
        atividadesDeCasa: true,
        horaDasAtividades: 17,
      ),
    );
    final agendados = await lembretes.reagendar([idAntonio]);
    expect(
      agendados.where((l) => l.texto.startsWith('Amanhã')).single.quando,
      instanteNaClinica(2026, 10, 8, 19),
    );
    expect(
      agendados.where((l) => l.texto.startsWith('Hora das atividades')),
      hasLength(7),
    );
    expect(lembretes.agendados, agendados);
    await lembretes.cancelarTudo();
    expect(lembretes.agendados, isEmpty);
    expect(await lembretes.preferencias(), const PreferenciasDeLembrete());
  });

  test(
    '"Sair" no meio de um reagendamento: nada fica agendado (achado 4)',
    () async {
      final m = memoriaDeTeste();
      final lembretes = m.repositorios.lembretes as LembretesMemoria;
      await lembretes.salvar(
        const PreferenciasDeLembrete(vesperaDaSessao: true),
      );
      final emCurso = lembretes.reagendar([idAntonio]);
      await lembretes.cancelarTudo();
      expect(await emCurso, isEmpty);
      expect(lembretes.agendados, isEmpty);
    },
  );

  test('João (só clínico, sem atividades): só a véspera', () async {
    final m = memoriaDeTeste();
    final lembretes = m.repositorios.lembretes;
    await lembretes.salvar(
      const PreferenciasDeLembrete(
        vesperaDaSessao: true,
        atividadesDeCasa: true,
      ),
    );
    final agendados = await lembretes.reagendar([idJoao]);
    expect(agendados, isNotEmpty);
    expect(agendados.every((l) => l.texto.startsWith('Amanhã')), isTrue);
  });

  test('as escolhas ficam no aparelho e saem no "Sair" (D20)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferenciasLocais.abrir();
    expect(prefs.lembretes, const PreferenciasDeLembrete());
    const escolhas = PreferenciasDeLembrete(
      vesperaDaSessao: true,
      horaDaVespera: 21,
    );
    await prefs.guardarLembretes(escolhas);
    expect((await PreferenciasLocais.abrir()).lembretes, escolhas);
    await prefs.limpar();
    expect(prefs.lembretes, const PreferenciasDeLembrete());
  });
}
