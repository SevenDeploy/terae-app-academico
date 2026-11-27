/// Entrar, o código por e-mail, sair, o Eu e o seletor de paciente do portal
/// da família do Terae local (`/api/portal/sessoes`, `/api/portal/eu`).
///
/// Contratos de referência, no monorepo do Terae web:
/// `packages/contratos/src/portal/index.ts` (`EtapaDoLoginDoPortal`,
/// `EuDoPortal`, `PacienteDaConta`) e os controladores de
/// `apps/api/src/modulos/identidade-e-acesso/apresentacao/portal/`.
///
/// Os DTOs são lidos campo a campo, sem cast: campo ausente ou de tipo errado
/// vira [RespostaInesperadaDoPortal].
library;

import '../../nucleo/tempo/data_civil.dart';
import '../conversao_mapa.dart';
import 'cliente_do_portal.dart';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// Resposta da senha certa (`EtapaDoLoginDoPortal`).
sealed class EtapaDoLogin {
  const EtapaDoLogin();
}

/// O código foi pedido: a sessão é provisória até [SessaoDoPortal.enviarCodigo].
final class CodigoPedido extends EtapaDoLogin {
  const CodigoPedido({
    required this.emailMascarado,
    required this.codigoEnviado,
    required this.reenviarAPartirDe,
  });

  /// `ma***@exemplo.com.br`.
  final String emailMascarado;

  /// `false` quando o teto de e-mails segurou o envio agora.
  final bool codigoEnviado;

  /// A partir de quando "Reenviar" vale (60 s depois do último pedido), UTC.
  final DateTime reenviarAPartirDe;
}

/// A sessão está aberta (o aparelho confiável dispensou o código, ou o código
/// conferiu).
final class LoginConcluido extends EtapaDoLogin {
  const LoginConcluido();
}

/// Perfil de quem está no portal em relação a um paciente.
enum PerfilDoPortal {
  responsavelLegal('responsavel_legal'),
  cuidador('cuidador'),
  titular('titular');

  const PerfilDoPortal(this.valor);

  /// O valor no contrato do Terae.
  final String valor;
}

/// Um paciente que a conta alcança, como o seletor o mostra.
class PacienteDaConta {
  const PacienteDaConta({
    required this.idPaciente,
    required this.nome,
    required this.nomeDaClinica,
    required this.fusoHorario,
    required this.perfil,
    required this.agendaLiberada,
    this.telefoneDaClinica,
    this.acessoTerminaEm,
  });

  final String idPaciente;
  final String nome;
  final String nomeDaClinica;

  /// IANA (`America/Cuiaba`).
  final String fusoHorario;
  final String? telefoneDaClinica;
  final PerfilDoPortal perfil;
  final bool agendaLiberada;

  /// Só para o responsável legal: o 18º aniversário do paciente.
  final DataCivil? acessoTerminaEm;
}

/// Resposta de `GET /api/portal/eu`.
class EuDoPortal {
  const EuDoPortal({
    required this.idUsuario,
    required this.nome,
    required this.email,
    required this.pacientes,
    required this.idRequisicao,
    this.idPacienteAtual,
  });

  final String idUsuario;
  final String nome;
  final String email;

  /// Ausente enquanto a conta não escolheu paciente (ou não alcança ninguém).
  final String? idPacienteAtual;
  final List<PacienteDaConta> pacientes;
  final String idRequisicao;
}

// ---------------------------------------------------------------------------
// Sessão
// ---------------------------------------------------------------------------

/// O ciclo da sessão do portal sobre o [ClienteDoPortal].
class SessaoDoPortal {
  SessaoDoPortal(this._cliente);

  final ClienteDoPortal _cliente;

  /// Há sessão (completa ou provisória) em memória.
  bool get temSessao => _cliente.temSessao;

  /// `POST /portal/sessoes`: a senha. Com aparelho confiável guardado, a API
  /// dispensa o código ([LoginConcluido]); senão pede o código ([CodigoPedido]).
  /// E-mail sem conta e senha errada respondem igual: 401.
  Future<EtapaDoLogin> entrar(String email, String senha) async {
    final r = await _cliente.post(
      'sessoes',
      corpo: {'email': email, 'senha': senha},
    );
    return _lerEtapa(r);
  }

  /// `POST /portal/sessoes/codigo`: o código de 6 dígitos do e-mail. Com
  /// [confiarNesteDispositivo], a API manda o cookie do aparelho confiável
  /// (30 dias sem código), que o cliente guarda.
  ///
  /// Código errado é [SessaoDoPortalAcabou] com `tentativasRestantes`; com
  /// zero, a sessão provisória acabou e é esquecida aqui.
  Future<void> enviarCodigo(
    String codigo, {
    bool confiarNesteDispositivo = false,
  }) async {
    try {
      final r = await _cliente.post(
        'sessoes/codigo',
        corpo: {
          'codigo': codigo,
          'confiarNesteDispositivo': confiarNesteDispositivo,
        },
      );
      if (_lerEtapa(r) is! LoginConcluido) {
        throw const RespostaInesperadaDoPortal(
          status: 200,
          detalhe: 'O código conferiu, mas a etapa não veio "concluida".',
        );
      }
    } on SessaoDoPortalAcabou catch (e) {
      if (e.tentativasRestantes == null || e.tentativasRestantes == 0) {
        _cliente.esquecerSessao();
      }
      rethrow;
    }
  }

  /// `POST /portal/sessoes/codigo/reenvio`: outro código (60 s depois do
  /// último).
  Future<EtapaDoLogin> reenviarCodigo() async =>
      _lerEtapa(await _cliente.post('sessoes/codigo/reenvio'));

  /// `DELETE /portal/sessoes`: revoga a sessão no servidor e esquece os
  /// cookies, mesmo sem rede. Por padrão esquece também o aparelho confiável,
  /// como o "Sair" do app apaga tudo do aparelho (D20); com
  /// [manterAparelhoConfiavel], o próximo login dispensa o código.
  ///
  /// Devolve quantas sessões o servidor revogou (0 sem sessão ou sem rede).
  Future<int> sair({bool manterAparelhoConfiavel = false}) async {
    // Um login feito enquanto o DELETE espera não perde o cookie novo.
    final geracao = _cliente.geracaoDaSessao;
    try {
      if (!_cliente.temSessao) return 0;
      final r = await _cliente.delete('sessoes');
      return _ler<int>(() => lerCampo<int>(r.objeto, 'sessoesRevogadas'));
    } on FalhaDoPortal {
      return 0;
    } finally {
      if (!manterAparelhoConfiavel) {
        await _cliente.esquecerAparelho(daGeracao: geracao);
      }
      _cliente.esquecerSessao(daGeracao: geracao);
    }
  }

  /// `GET /portal/eu`: quem está no portal e os pacientes que alcança.
  Future<EuDoPortal> eu() =>
      _comSessao(() async => _lerEu((await _cliente.get('eu')).objeto));

  /// `PUT /portal/sessoes/paciente`: escolhe o paciente atual. Outra clínica
  /// gira a sessão (o cliente absorve o cookie novo).
  Future<EuDoPortal> escolherPaciente(String idPaciente) => _comSessao(
    () async => _lerEu(
      (await _cliente.put(
        'sessoes/paciente',
        corpo: {'idPaciente': idPaciente},
      )).objeto,
    ),
  );

  /// 401 numa rota de sessão completa: a sessão acabou no servidor.
  Future<T> _comSessao<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } on SessaoDoPortalAcabou {
      _cliente.esquecerSessao();
      rethrow;
    }
  }
}

T _ler<T>(T Function() leitura) {
  try {
    return leitura();
  } on FormatException catch (e) {
    throw RespostaInesperadaDoPortal(detalhe: e.message);
  }
}

EtapaDoLogin _lerEtapa(RespostaDoPortal r) => _ler(() {
  final m = r.objeto;
  final etapa = lerCampo<String>(m, 'etapa');
  return switch (etapa) {
    'codigo' => CodigoPedido(
      emailMascarado: lerCampo<String>(m, 'emailMascarado'),
      codigoEnviado: lerCampo<bool>(m, 'codigoEnviado'),
      reenviarAPartirDe: lerInstante(m, 'reenviarAPartirDe'),
    ),
    'concluida' => const LoginConcluido(),
    _ => throw FormatException('Etapa desconhecida', etapa),
  };
});

EuDoPortal _lerEu(Mapa m) => _ler(
  () => EuDoPortal(
    idUsuario: lerCampo<String>(m, 'idUsuario'),
    nome: lerCampo<String>(m, 'nome'),
    email: lerCampo<String>(m, 'email'),
    idPacienteAtual: lerOpcional<String>(m, 'idPacienteAtual'),
    pacientes: [
      for (final p in lerCampo<List<Object?>>(m, 'pacientes'))
        if (p is Mapa)
          _lerPaciente(p)
        else
          throw FormatException('Paciente que não é objeto', p),
    ],
    idRequisicao: lerCampo<String>(m, 'idRequisicao'),
  ),
);

PacienteDaConta _lerPaciente(Mapa m) {
  final perfil = lerCampo<String>(m, 'perfil');
  return PacienteDaConta(
    idPaciente: lerCampo<String>(m, 'idPaciente'),
    nome: lerCampo<String>(m, 'nome'),
    nomeDaClinica: lerCampo<String>(m, 'nomeDaClinica'),
    fusoHorario: lerCampo<String>(m, 'fusoHorario'),
    telefoneDaClinica: lerOpcional<String>(m, 'telefoneDaClinica'),
    perfil:
        PerfilDoPortal.values.where((p) => p.valor == perfil).firstOrNull ??
        (throw FormatException('Perfil desconhecido', perfil)),
    agendaLiberada: lerCampo<bool>(m, 'agendaLiberada'),
    acessoTerminaEm: lerDataCivilOpcional(m, 'acessoTerminaEm'),
  );
}
