/// Recusas de regra que os repositórios devolvem como exceção ([RecusaDeRegra]).
///
/// A tela mostra [MotivoRecusa.mensagem], já em linguagem simples (RNFM01).
/// Sem conexão no envio do diário NÃO é recusa: o registro vai para a fila
/// (`naFila`, §19, "Guardar e enviar depois"). Corrigir e retirar pedem a
/// internet na hora (P3, como o portal) e recusam com [semConexao].
enum MotivoRecusa {
  codigoInexistente(
    'Não encontramos esse código. Confira as letras e os números.',
  ),
  codigoJaUsado('Este código já foi usado. Se precisar, peça um novo.'),
  codigoExpirado('Este código venceu. Peça um novo a quem enviou.'),
  conviteRevogado('Este convite foi cancelado por quem convidou.'),
  tipoDeCodigoErrado('Este código é de outro tipo de primeiro acesso.'),
  cpfInvalido('Confira o CPF: algum número está errado.'),
  cpfNaoConfere('O CPF não é o mesmo informado no convite.'),
  nascimentoNaoConfere(
    'A data de nascimento não confere com o cadastro da clínica.',
  ),
  cpfJaConvidado('Esta pessoa já tem um convite em aberto ou acesso ativo.'),
  limiteDeCuidadores(
    'Já há 2 cuidadores, contando os convites em aberto. '
    'Remova um para convidar outra pessoa.',
  ),
  contaSemAcesso('Esta conta ainda não tem acesso. Use o primeiro acesso.'),
  contaInativa('Esta conta está desativada. Fale com a clínica.'),
  pacienteInativo('Este cadastro está inativo na clínica.'),

  /// TM09 passo 2 — paciente com menos de 12 anos (criança, ECA art. 2º) não
  /// é titular: quem aceita é um dos pais ou o responsável legal (LGPD art.
  /// 14, § 1º).
  criancaComoTitular(
    'O paciente tem menos de 12 anos. Quem aceita o termo é a mãe, o pai ou '
    'o responsável legal.',
  ),
  acessoNegado('Você não tem acesso a estas informações.'),
  semConexao('Sem internet agora. Tente de novo quando a conexão voltar.'),

  /// TM01 — e-mail ou senha não conferem (D14). Não diz qual dos dois, para
  /// não revelar quem tem conta.
  credenciaisInvalidas(
    'E-mail ou senha não conferem. Confira e tente de novo.',
  ),

  /// TM09/TM10 passo 4 — o e-mail já tem acesso, com outra senha.
  emailJaCadastrado(
    'Este e-mail já tem acesso ao Terae. Use a mesma senha dele ou outro '
    'e-mail.',
  ),
  emailInvalido('Confira o e-mail: ele precisa ter @ e um domínio.'),

  /// O Firebase bloqueia por um tempo depois de várias tentativas erradas.
  muitasTentativas(
    'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.',
  ),
  senhaFraca('A senha precisa ter pelo menos 8 caracteres.'),

  /// TM17 — o registro da atividade de casa só muda no mesmo dia (D26).
  edicaoEncerrada(
    'Este registro é de outro dia e não pode mais ser mudado. Se precisar, '
    'conte na próxima consulta.',
  ),
  registroInexistente('Não encontramos este registro.'),

  /// TM15 e a folha de retirar (P3, D17 revista) — a terapeuta revisou, o
  /// registro avisou a equipe, já foi retirado ou foi corrigido em outra
  /// tela (o 409 do portal).
  registroNaoMudaMais(
    'Este registro não pode mais mudar. A terapeuta pode já tê-lo revisado, '
    'ou ele foi corrigido em outra tela.',
  ),

  /// TM17 — a atividade não existe, não é deste paciente ou foi encerrada.
  atividadeInexistente(
    'Não encontramos esta atividade. Ela pode ter sido encerrada na terapia.',
  ),

  /// TM20 (F3) — a meta não existe ou não é deste paciente.
  metaInexistente('Não encontramos esta meta. Fale com a clínica.'),

  /// TM18 — D27: a sessão já começou, já passou ou foi cancelada.
  sessaoEncerrada(
    'Esta sessão já começou ou foi cancelada. Para remarcar, fale com a '
    'clínica.',
  ),

  /// TM18 — o agendamento não existe ou não é deste paciente.
  agendamentoInexistente('Não encontramos esta sessão.');

  const MotivoRecusa(this.mensagem);

  /// Texto para a pessoa, em linguagem simples.
  final String mensagem;
}

/// Regra de negócio recusou a operação (§23). Nada foi gravado.
class RecusaDeRegra implements Exception {
  const RecusaDeRegra(this.motivo);

  final MotivoRecusa motivo;

  String get mensagem => motivo.mensagem;

  @override
  String toString() => 'RecusaDeRegra(${motivo.name})';
}
