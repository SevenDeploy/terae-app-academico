/// Um portal da família falso, com estado, sobre o [ServidorFalso]: a senha,
/// o código, o `/eu`, o paciente escolhido na sessão, o início, a agenda, a
/// presença e o programa — o bastante para exercitar os repositórios do
/// Terae local sem rede real.
library;

import 'servidor_falso.dart';

const String idAlice = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String idBento = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const String idCaio = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const String idSessao1 = '51515151-5151-4515-8515-515151515151';
const String idSessao2 = '52525252-5252-4525-8525-525252525252';
const String idOrientacao1 = '01010101-0101-4010-8010-010101010101';
const String idOrientacao2 = '02020202-0202-4020-8020-020202020202';

const String _familia = '__Host-terae_familia';

class PortalFalso {
  PortalFalso(this.servidor) {
    servidor.roteiro = _atender;
  }

  final ServidorFalso servidor;

  String senha = 'senha-de-teste';
  String codigo = '123456';
  int tentativas = 5;

  /// Com aparelho confiável, a senha dispensa o código.
  String? tokenDoAparelho;

  /// Os pacientes do `/eu`.
  List<Map<String, Object?>> pacientes = [
    {
      'idPaciente': idAlice,
      'nome': 'Alice Souza',
      'nomeDaClinica': 'Clínica Exemplo',
      'fusoHorario': 'America/Cuiaba',
      'perfil': 'responsavel_legal',
      'agendaLiberada': true,
    },
    {
      'idPaciente': idBento,
      'nome': 'Bento Souza',
      'nomeDaClinica': 'Clínica Exemplo',
      'fusoHorario': 'America/Cuiaba',
      'perfil': 'titular',
      'agendaLiberada': false,
    },
    {
      'idPaciente': idCaio,
      'nome': 'Caio Lima',
      'nomeDaClinica': 'Outra Clínica',
      'fusoHorario': 'America/Cuiaba',
      'perfil': 'cuidador',
      'agendaLiberada': false,
    },
  ];

  /// O paciente atual na sessão do servidor.
  String? pacienteAtual;

  /// Sessão provisória (código pedido) e completa.
  bool provisoria = false;
  bool completa = false;

  /// Respostas fixas por rota (`'GET agenda'` → resposta), para os casos de
  /// erro; vencem o comportamento normal.
  final Map<String, RespostaFalsa> forcar = {};

  /// Confirmação de cada sessão da Alice.
  final Map<String, String> confirmacoes = {
    idSessao1: 'pendente',
    idSessao2: 'desmarcada_pela_clinica',
  };

  /// Os registros de hoje que o app enviou, por orientação.
  final Map<String, Map<String, Object?>> registros = {};

  int giro = 0;

  String _cookie() =>
      '$_familia=sessao-${giro++}; Path=/; HttpOnly; Secure; '
      'SameSite=Strict';

  RespostaFalsa _atender(PedidoVisto p) {
    final caminho = Uri.parse(p.caminho).path.replaceFirst('/api/portal/', '');
    final chave = '${p.metodo} $caminho';
    if (forcar[chave] case final r?) return r;
    final temCookie = p.cookies.containsKey(_familia);
    switch (chave) {
      case 'POST sessoes':
        final corpo = p.json! as Map<String, Object?>;
        if (corpo['senha'] != senha) {
          return RespostaFalsa(401, json: problema(401, 'nao_autenticado'));
        }
        if (tokenDoAparelho != null &&
            p.cookies['__Host-terae_dispositivo'] == tokenDoAparelho) {
          completa = true;
          return RespostaFalsa(
            201,
            json: {'etapa': 'concluida'},
            setCookies: [_cookie()],
          );
        }
        provisoria = true;
        return RespostaFalsa(
          201,
          json: {
            'etapa': 'codigo',
            'emailMascarado': 'ma***@exemplo.test',
            'codigoEnviado': true,
            'reenviarAPartirDe': '2026-11-26T18:01:00.000Z',
          },
          setCookies: [_cookie()],
        );
      case 'POST sessoes/codigo':
        if (!provisoria || !temCookie) {
          return RespostaFalsa(401, json: problema(401, 'nao_autenticado'));
        }
        final corpo = p.json! as Map<String, Object?>;
        if (corpo['codigo'] != codigo) {
          tentativas--;
          return RespostaFalsa(
            401,
            json: problema(
              401,
              'nao_autenticado',
              extra: {'tentativasRestantes': tentativas},
            ),
          );
        }
        provisoria = false;
        completa = true;
        return RespostaFalsa(
          200,
          json: {'etapa': 'concluida'},
          setCookies: [
            _cookie(),
            if (corpo['confiarNesteDispositivo'] == true)
              '__Host-terae_dispositivo=aparelho-1; Path=/; Max-Age=2592000; '
                  'HttpOnly; Secure',
          ],
        );
      case 'POST sessoes/codigo/reenvio':
        if (!provisoria || !temCookie) {
          return RespostaFalsa(401, json: problema(401, 'nao_autenticado'));
        }
        return const RespostaFalsa(
          200,
          json: {
            'etapa': 'codigo',
            'emailMascarado': 'ma***@exemplo.test',
            'codigoEnviado': true,
            'reenviarAPartirDe': '2026-11-26T18:02:00.000Z',
          },
        );
      case 'DELETE sessoes':
        completa = false;
        pacienteAtual = null;
        return const RespostaFalsa(
          200,
          json: {'sessoesRevogadas': 1},
          setCookies: ['$_familia=; Path=/; Max-Age=0'],
        );
    }
    if (!completa || !temCookie) {
      return RespostaFalsa(401, json: problema(401, 'nao_autenticado'));
    }
    switch (chave) {
      case 'GET eu':
        return RespostaFalsa(200, json: _eu());
      case 'PUT sessoes/paciente':
        final id = (p.json! as Map<String, Object?>)['idPaciente'];
        if (!pacientes.any((x) => x['idPaciente'] == id)) {
          return RespostaFalsa(403, json: problema(403, 'acesso_negado'));
        }
        pacienteAtual = id! as String;
        return RespostaFalsa(200, json: _eu());
    }
    if (pacienteAtual == null) {
      return RespostaFalsa(
        409,
        json: problema(
          409,
          'conflito',
          extra: {'detail': 'Escolha o paciente primeiro.'},
        ),
      );
    }
    if (chave == 'GET inicio') {
      return RespostaFalsa(
        200,
        json: {
          'dia': '2026-11-26',
          'perfil': _perfilAtual(),
          if (_agendaLiberada()) 'proximaSessao': _sessao(idSessao1),
          'avisos': <Object?>[],
        },
      );
    }
    if (chave == 'GET agenda') {
      return RespostaFalsa(
        200,
        json: {
          'liberada': _agendaLiberada(),
          'sessoes': _agendaLiberada()
              ? [_sessao(idSessao2), _sessao(idSessao1)]
              : <Object?>[],
        },
      );
    }
    final presenca = RegExp(r'^POST agenda/([^/]+)/(confirmacao|ausencia)$')
        .firstMatch(chave);
    if (presenca != null) {
      final id = presenca.group(1)!;
      final atual = confirmacoes[id];
      if (atual == null) {
        return RespostaFalsa(404, json: problema(404, 'nao_encontrado'));
      }
      if (presenca.group(2) == 'confirmacao') {
        if (atual != 'pendente') {
          return RespostaFalsa(409, json: problema(409, 'conflito'));
        }
        confirmacoes[id] = 'confirmada';
        return const RespostaFalsa(
          200,
          json: {'confirmadoEm': '2026-11-26T18:00:05.000Z'},
        );
      }
      if (atual == 'ausencia_avisada' || atual == 'desmarcada_pela_clinica') {
        return RespostaFalsa(409, json: problema(409, 'conflito'));
      }
      confirmacoes[id] = 'ausencia_avisada';
      return const RespostaFalsa(
        200,
        json: {'avisadoEm': '2026-11-26T18:00:06.000Z'},
      );
    }
    if (chave == 'GET programa') {
      return RespostaFalsa(
        200,
        json: {
          'dia': '2026-11-26',
          'orientacoes': pacienteAtual == idAlice
              ? [
                  _orientacao(idOrientacao1, 'Escovar os dentes sozinha'),
                  _orientacao(idOrientacao2, 'Guardar os brinquedos'),
                ]
              : <Object?>[],
        },
      );
    }
    if (chave == 'POST programa') {
      final corpo = p.json! as Map<String, Object?>;
      for (final r in corpo['registros']! as List<Object?>) {
        final m = r! as Map<String, Object?>;
        registros[m['idOrientacao']! as String] = m;
      }
      return const RespostaFalsa(
        201,
        json: {'recebidoEm': '2026-11-26T18:00:07.000Z', 'dia': '2026-11-26'},
      );
    }
    return RespostaFalsa(404, json: problema(404, 'nao_encontrado'));
  }

  Map<String, Object?> _paciente() =>
      pacientes.firstWhere((x) => x['idPaciente'] == pacienteAtual);

  String _perfilAtual() => _paciente()['perfil']! as String;

  bool _agendaLiberada() => _paciente()['agendaLiberada']! as bool;

  Map<String, Object?> _eu() => {
    'idUsuario': '99999999-9999-4999-8999-999999999999',
    'nome': 'Mariana Souza',
    'email': 'mariana@exemplo.test',
    'idPacienteAtual': ?pacienteAtual,
    'pacientes': pacientes,
    'idRequisicao': '44444444-4444-4444-8444-444444444444',
  };

  Map<String, Object?> _sessao(String id) => {
    'idSessao': id,
    'inicio': id == idSessao1
        ? '2026-11-27T18:00:00.000Z'
        : '2026-11-28T18:00:00.000Z',
    'fim': id == idSessao1
        ? '2026-11-27T18:50:00.000Z'
        : '2026-11-28T18:50:00.000Z',
    'primeiroNomeDoTerapeuta': 'Ana',
    'especialidade': 'Terapia ocupacional',
    'confirmacao': confirmacoes[id],
    'podeResponder': confirmacoes[id] == 'pendente',
    'podeAvisarAusencia': confirmacoes[id] == 'pendente',
  };

  Map<String, Object?> _orientacao(String id, String titulo) => {
    'idOrientacao': id,
    'titulo': titulo,
    'texto': 'Com o espelho na altura dela.',
    'vezesPorSemana': id == idOrientacao1 ? 5 : 9,
    'primeiroNomeDoTerapeuta': 'Ana',
    'especialidade': 'Terapia ocupacional',
    'publicadaEm': '2026-11-20T13:00:00.000Z',
    if (registros[id] case final r?)
      'registroDeHoje': {
        'adesao': r['adesao'],
        'registradoPor': 'esta_conta',
        'registradoEm': '2026-11-26T18:00:07.000Z',
        'reflexao': ?r['reflexao'],
      }
    else if (id == idOrientacao2)
      'registroDeHoje': {
        'adesao': 'feito',
        'registradoPor': 'outra_conta',
        'primeiroNome': 'Rosa',
      },
  };
}
