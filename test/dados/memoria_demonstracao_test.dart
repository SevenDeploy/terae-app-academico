import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terae_app/app.dart';
import 'package:terae_app/dados/enums/adesao.dart';
import 'package:terae_app/dados/enums/canal_autorizado.dart';
import 'package:terae_app/dados/enums/intensidade.dart';
import 'package:terae_app/dados/enums/qualidade_consentimento.dart';
import 'package:terae_app/dados/enums/situacao_envio.dart';
import 'package:terae_app/dados/memoria/memoria_demonstracao.dart';
import 'package:terae_app/dados/modelos/registro_diario.dart';
import 'package:terae_app/nucleo/sessao/sessao.dart';
import 'package:terae_app/nucleo/tempo/relogio.dart';
import 'package:terae_app/nucleo/uuid.dart';

import 'memoria_apoio.dart';

RegistroDiario _registro(String pacienteId, Intensidade intensidade) =>
    RegistroDiario(
      id: gerarUuidV4(),
      pacienteId: pacienteId,
      registradoEm: agoraDaMemoria,
      adesao: Adesao.parcial,
      intensidade: intensidade,
      sintomaPredominante: 'Ansiedade',
      situacaoEnvio: SituacaoEnvio.naFila,
    );

void main() {
  test('reiniciarDados volta ao estado inicial (D11)', () async {
    final m = memoriaDeTeste();
    final r = m.repositorios;
    final inicial = m.estado.paraMapa();

    // Mexe em tudo o que o app consegue mexer.
    await r.diario.enviar(_registro(idAna, Intensidade.critica));
    await r.cuidadores.revogar(vinculoRegina);
    await r.autenticacao.aceitarConviteCuidador(
      codigo: codigoPaulo,
      cpf: cpfPaulo,
      identidade: identidadeDe(m, 'Paulo Martins'),
    );
    await r.autenticacao.ativarPaciente(
      codigo: codigoJoao,
      cpf: cpfJoao,
      dataNascimento: nascimentoJoao,
      qualidade: QualidadeConsentimento.titular,
      canalAutorizado: CanalAutorizado.email,
      versaoTermo: '1.0',
      identidade: identidadeDe(m, 'João Pedro Assis'),
    );
    await r.autenticacao.entrar(identidadeDe(m, 'Ana Lúcia Martins'));
    await r.demonstracao.definirSemConexao(semConexao: true);
    await r.diario.enviar(_registro(idJoao, Intensidade.grave));
    expect(m.estado.paraMapa(), isNot(inicial));

    await r.demonstracao.reiniciarDados();
    expect(m.estado.paraMapa(), inicial);
    expect(r.demonstracao.semConexao, isFalse);
    expect(m.estado.fila, isEmpty);
    // E as regras voltam a valer sobre os dados iniciais.
    expect(
      (await r.cuidadores.cuidadores(idAna)).first.convite.usadoEm,
      isNull,
    );
  });

  test('reiniciar resolve as datas relativas ao hoje do relógio', () async {
    final relogio = RelogioFixo(agoraDaMemoria);
    final m = memoriaDeTeste(relogio: relogio);
    final antes = await m.repositorios.paciente.proximaConsulta(idAna);
    relogio.avancar(const Duration(days: 1));
    await m.repositorios.demonstracao.reiniciarDados();
    final depois = await m.repositorios.paciente.proximaConsulta(idAna);
    expect(depois!.dataHora, antes!.dataHora.add(const Duration(days: 1)));
  });

  test('sem conexão liga e desliga', () async {
    final m = memoriaDeTeste();
    final controle = m.repositorios.demonstracao;
    expect(controle.semConexao, isFalse);
    await controle.definirSemConexao(semConexao: true);
    expect(controle.semConexao, isTrue);
    expect(m.semConexao, isTrue);
    await controle.definirSemConexao(semConexao: false);
    expect(controle.semConexao, isFalse);
  });

  testWidgets('latência simulada curta antes de responder', (tester) async {
    final m = MemoriaDemonstracao(
      dados: dadosDaDemonstracao(),
      relogio: RelogioFixo(agoraDaMemoria),
      latencia: MemoriaDemonstracao.latenciaDoApp,
    );
    var respondeu = false;
    final pedido = m.repositorios.paciente
        .paciente(idAna)
        .then((_) => respondeu = true);
    await tester.pump(
      MemoriaDemonstracao.latenciaDoApp - const Duration(milliseconds: 1),
    );
    expect(respondeu, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    await pedido;
    expect(respondeu, isTrue);
  });

  testWidgets('o app abre na TM00 com a memória (main.dart)', (tester) async {
    final memoria = memoriaDeTeste();
    final sessao = Sessao();
    await tester.pumpWidget(
      TeraeApp(
        repositorios: memoria.repositorios,
        sessao: sessao,
        relogio: memoria.relogio,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM00')), findsOneWidget);

    // A Patrícia entra pela memória e cai na seleção de perfil.
    final vinculos = await memoria.repositorios.autenticacao.entrar(
      identidadeDe(memoria, 'Patrícia Andrade Neves'),
    );
    sessao.entrar(vinculos);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('TM01')), findsOneWidget);
  });
}
