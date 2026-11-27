import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/terae_local/cliente_do_portal.dart';
import 'package:terae_app/dados/terae_local/configuracao_terae_local.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';

import 'servidor_falso.dart';

void main() {
  group('trava contra produção (TERAE_LOCAL_URL)', () {
    const aceitos = [
      'http://10.0.2.2:3000',
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://[::1]:3000',
      'https://LOCALHOST:8443/',
    ];
    for (final url in aceitos) {
      test('aceita $url', () {
        final c = ConfiguracaoTeraeLocal.de(fonte: 'local', url: url);
        expect(c.fonte, FonteDeDados.local);
        expect(c.url.path, isEmpty);
      });
    }

    const recusados = [
      'https://terae.com.br',
      'https://portal.terae.com.br',
      'http://192.168.0.10:3000',
      'http://10.0.2.3:3000',
      'http://localhost.terae.com.br',
      'http://localhost@terae.com.br',
      'http://terae.com.br@localhost:3000',
      'http://.localhost',
      // M2 (revisão da P4): `*.localhost` depende do resolvedor; no Android
      // vai ao DNS da rede. O Host `portal.localhost` vai no cabeçalho.
      'http://portal.localhost:3000',
      'http://app.dev.localhost',
      'http://[::2]:3000',
      'ftp://localhost',
      'http://localhost:3000/api',
      'http://localhost:3000?x=1',
      'localhost:3000',
      '',
    ];
    for (final url in recusados) {
      test('recusa "$url" com erro claro', () {
        expect(
          () => ConfiguracaoTeraeLocal.de(fonte: 'firebase', url: url),
          throwsA(isA<ConfiguracaoInvalida>()),
        );
      });
    }

    test('a mensagem diz que é a produção/outra máquina', () {
      expect(
        () => exigirUrlLocal('https://terae.com.br'),
        throwsA(
          isA<ConfiguracaoInvalida>().having(
            (e) => e.mensagem,
            'mensagem',
            contains('nunca com a produção'),
          ),
        ),
      );
    });

    test('o cliente confere de novo ao nascer', () {
      expect(
        () => ClienteDoPortal(
          url: Uri.parse('https://terae.com.br'),
          dispositivo: GuardaEmMemoria(),
          relogio: const RelogioSistema(),
        ),
        throwsA(isA<ConfiguracaoInvalida>()),
      );
    });
  });

  group('TERAE_FONTE', () {
    test('padrão do ambiente de teste: firebase em 10.0.2.2:3000', () {
      final c = ConfiguracaoTeraeLocal.doAmbiente();
      expect(c.fonte, FonteDeDados.firebase);
      expect(c.url, Uri.parse(urlLocalPadrao));
    });

    test('fonte desconhecida é erro', () {
      expect(
        () => ConfiguracaoTeraeLocal.de(fonte: 'producao', url: urlLocalPadrao),
        throwsA(isA<ConfiguracaoInvalida>()),
      );
    });
  });
}
