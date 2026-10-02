import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/dados/enums/situacao_vinculo.dart';
import 'package:terae_app/dados/enums/tipo_convite.dart';
import 'package:terae_app/dados/modelos/convite_acesso.dart';
import 'package:terae_app/dados/modelos/vinculo_cuidador.dart';
import 'package:terae_app/dados/regras/cuidadores.dart';

void main() {
  final agora = DateTime.utc(2026, 10, 2, 14);
  ConviteAcesso convite({required DateTime expiraEm, DateTime? usadoEm}) =>
      ConviteAcesso(
        id: 'cv',
        pacienteId: 'p',
        codigo: 'P4X9RC',
        tipo: TipoConvite.cuidador,
        cpfConvidado: '84712056371',
        expiraEm: expiraEm,
        usadoEm: usadoEm,
      );
  VinculoCuidador vinculo(SituacaoVinculo situacao) => VinculoCuidador(
    id: 'v',
    pacienteId: 'p',
    conviteId: 'cv',
    nome: 'Paulo',
    situacao: situacao,
  );
  final emAberto = convite(expiraEm: agora.add(const Duration(minutes: 1)));
  final vencido = convite(expiraEm: agora);
  final usado = convite(
    expiraEm: agora.subtract(const Duration(days: 30)),
    usadoEm: agora.subtract(const Duration(days: 40)),
  );

  group('contaNoLimite (§7.4, §23)', () {
    test('ativo conta, mesmo com o convite já vencido (foi usado)', () {
      expect(
        contaNoLimite(
          vinculo: vinculo(SituacaoVinculo.ativo),
          convite: usado,
          agora: agora,
        ),
        isTrue,
      );
    });

    test('pendente só conta com o convite em aberto', () {
      final pendente = vinculo(SituacaoVinculo.pendente);
      expect(
        contaNoLimite(vinculo: pendente, convite: emAberto, agora: agora),
        isTrue,
      );
      expect(
        contaNoLimite(vinculo: pendente, convite: vencido, agora: agora),
        isFalse,
        reason: 'vence no instante de expiraEm',
      );
    });

    test('revogado não conta', () {
      expect(
        contaNoLimite(
          vinculo: vinculo(SituacaoVinculo.revogado),
          convite: emAberto,
          agora: agora,
        ),
        isFalse,
      );
    });
  });

  test('conviteExpirado: só pendente com convite vencido e não usado', () {
    expect(
      conviteExpirado(
        vinculo: vinculo(SituacaoVinculo.pendente),
        convite: vencido,
        agora: agora,
      ),
      isTrue,
    );
    expect(
      conviteExpirado(
        vinculo: vinculo(SituacaoVinculo.pendente),
        convite: emAberto,
        agora: agora,
      ),
      isFalse,
    );
    for (final situacao in [SituacaoVinculo.ativo, SituacaoVinculo.revogado]) {
      expect(
        conviteExpirado(
          vinculo: vinculo(situacao),
          convite: vencido,
          agora: agora,
        ),
        isFalse,
        reason: situacao.name,
      );
    }
    expect(conviteEmAberto(usado, agora), isFalse);
  });
}
