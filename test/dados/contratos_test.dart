import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/regra_alerta.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/modelos/alerta.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/dados/repositorios/diario_repositorio.dart';
import 'package:terae_app/dados/repositorios/falhas.dart';
import 'package:terae_app/dados/repositorios/visao_cuidador_repositorio.dart';

final DateTime _instante = DateTime.utc(2026, 10, 7, 18);

RegistroDiario _registro(SituacaoEnvio situacao) => RegistroDiario(
  id: 'r',
  pacienteId: 'p',
  registradoEm: _instante,
  adesao: Adesao.total,
  intensidade: Intensidade.critica,
  sintomaPredominante: 'Tristeza',
  situacaoEnvio: situacao,
);

final Alerta _alerta = Alerta(
  id: 'a',
  registroId: 'r',
  regraDisparada: RegraAlerta.intensidadeCritica,
  emitidoEm: _instante,
);

void main() {
  group('ResultadoEnvio (§19, §23)', () {
    test('na fila, nunca diz que a equipe foi avisada', () {
      final r = ResultadoEnvio(registro: _registro(SituacaoEnvio.naFila));
      expect(r.enviado, isFalse);
      expect(r.equipeAvisada, isFalse);
    });

    test('enviado sem alerta: enviado, mas equipe não avisada', () {
      final r = ResultadoEnvio(registro: _registro(SituacaoEnvio.enviado));
      expect(r.enviado, isTrue);
      expect(r.equipeAvisada, isFalse);
    });

    test('enviado com alerta do servidor: equipe avisada', () {
      final r = ResultadoEnvio(
        registro: _registro(SituacaoEnvio.enviado),
        alerta: _alerta,
      );
      expect(r.equipeAvisada, isTrue);
    });
  });

  test('AvisoDeAlerta leva só data, hora e ciência (RNFM05)', () {
    final aviso = AvisoDeAlerta.doAlerta(_alerta.copyWith(cienteEm: _instante));
    expect(aviso.toMap().keys, unorderedEquals(['emitidoEm', 'cienteEm']));
    expect(aviso.emitidoEm, _instante);
    expect(aviso.cienteEm, _instante);
  });

  test('toda recusa tem mensagem em linguagem simples', () {
    for (final motivo in MotivoRecusa.values) {
      expect(motivo.mensagem, isNotEmpty);
      expect(RecusaDeRegra(motivo).mensagem, motivo.mensagem);
    }
  });
}
