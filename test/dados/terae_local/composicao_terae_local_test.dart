import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terae_app/dados/lembretes/lembrete.dart';
import 'package:terae_app/dados/repositorios/autenticacao_repositorio.dart';
import 'package:terae_app/dados/repositorios/lembretes_repositorio.dart';
import 'package:terae_app/dados/repositorios/repositorios.dart';
import 'package:terae_app/dados/terae_local/autenticacao_terae_local.dart';
import 'package:terae_app/dados/terae_local/composicao_terae_local.dart';
import 'package:terae_app/dados/terae_local/configuracao_terae_local.dart';
import 'package:terae_app/dados/terae_local/diario_terae_local.dart';
import 'package:terae_app/dados/terae_local/indisponiveis_terae_local.dart';
import 'package:terae_app/dados/terae_local/repositorios_terae_local.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'portal_falso.dart';
import 'servidor_falso.dart';

/// Lembretes que só contam o "Sair".
class _LembretesEspiao implements RepositorioLembretes {
  int cancelados = 0;

  @override
  Future<void> cancelarTudo() async => cancelados++;

  @override
  Future<bool> notificacoesPermitidas() async => true;

  @override
  Future<bool> pedirPermissao() async => true;

  @override
  Future<PreferenciasDeLembrete> preferencias() async =>
      const PreferenciasDeLembrete();

  @override
  Future<List<Lembrete>> reagendar(List<String> pacienteIds) async => const [];

  @override
  Future<void> salvar(PreferenciasDeLembrete preferencias) async {}

  @override
  Future<void> testar() async {}
}

void main() {
  late ServidorFalso servidor;
  final relogio = RelogioFixo(DateTime.utc(2026, 11, 26, 18));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    servidor = await ServidorFalso.iniciar();
  });

  tearDown(() => servidor.parar());

  group('composição por fonte', () {
    test('o padrão é o Firebase, com tudo (as telas ficam como na A5)', () {
      final padrao = ConfiguracaoTeraeLocal.de(
        fonte: 'firebase',
        url: urlLocalPadrao,
      );
      expect(padrao.fonte, FonteDeDados.firebase);
      expect(
        ConfiguracaoTeraeLocal.doAmbiente().fonte,
        FonteDeDados.firebase,
        reason: 'sem --dart-define, o Firebase acadêmico',
      );
      expect(CapacidadesDaFonte.completa.diario, isTrue);
      expect(CapacidadesDaFonte.completa.jornada, isTrue);
    });

    test('a fonte local monta os repositórios do Terae local, sem rede na '
        'partida', () async {
      final lembretes = _LembretesEspiao();
      final montado = await montarTeraeLocal(
        configuracao: ConfiguracaoTeraeLocal.de(
          fonte: 'local',
          url: servidor.url.toString(),
        ),
        relogio: relogio,
        lembretes: lembretes,
      );
      final r = montado.repositorios;
      expect(r.autenticacao, isA<AutenticacaoTeraeLocal>());
      expect(r.autenticacao, isA<AutenticacaoComCodigo>());
      expect(r.paciente, isA<PacienteTeraeLocal>());
      expect(r.presenca, isA<PresencaTeraeLocal>());
      expect(r.programaEmCasa, isA<ProgramaTeraeLocal>());
      expect(r.visaoCuidador, isA<VisaoCuidadorTeraeLocal>());
      expect(r.diario, isA<DiarioTeraeLocal>());
      expect(r.cuidadores, isA<CuidadoresIndisponiveisNoTeraeLocal>());
      expect(r.metas, isA<MetasIndisponiveisNoTeraeLocal>());
      expect(r.capacidades, same(CapacidadesDaFonte.teraeLocal));
      expect(r.capacidades.diario, isTrue);
      expect(r.capacidades.jornada, isFalse);
      expect(r.capacidades.cuidadores, isFalse);
      expect(servidor.pedidos, isEmpty);
    });

    test('"Sair" revoga a sessão no servidor e cancela os lembretes', () async {
      final portal = PortalFalso(servidor);
      final lembretes = _LembretesEspiao();
      final montado = await montarTeraeLocal(
        configuracao: ConfiguracaoTeraeLocal.de(
          fonte: 'local',
          url: servidor.url.toString(),
        ),
        relogio: relogio,
        lembretes: lembretes,
      );
      final auth = montado.repositorios.autenticacao as AutenticacaoComCodigo;
      await auth.iniciarEntrada(email: 'm@exemplo.test', senha: portal.senha);
      await auth.confirmarCodigo(portal.codigo, confiarNesteAparelho: false);
      await montado.aoSair();
      expect(servidor.pedidos.last.metodo, 'DELETE');
      expect(servidor.pedidos.last.caminho, '/api/portal/sessoes');
      expect(lembretes.cancelados, 1);
    });

    test('a trava roda antes de montar: produção nunca', () {
      expect(
        () => ConfiguracaoTeraeLocal.de(
          fonte: 'local',
          url: 'https://terae.com.br',
        ),
        throwsA(isA<ConfiguracaoInvalida>()),
      );
    });

    test('montar a fonte local com a configuração do Firebase é erro', () {
      expect(
        montarTeraeLocal(
          configuracao: ConfiguracaoTeraeLocal.de(
            fonte: 'firebase',
            url: urlLocalPadrao,
          ),
          relogio: relogio,
        ),
        throwsArgumentError,
      );
    });
  });
}
