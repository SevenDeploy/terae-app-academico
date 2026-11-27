/// Recusas de regra que os repositórios devolvem como exceção ([RecusaDeRegra]).
///
/// A tela mostra [MotivoRecusa.mensagem], já em linguagem simples (RNFM01).
/// Sem conexão no envio do diário NÃO é recusa: o registro vai para a fila
/// (`naFila`, §19). A correção e a exclusão do diário (D17) seguem a mesma
/// fila.
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
    // O texto do portal (Entrar.tsx), com a clínica no lugar do "Esqueci a
    // senha", que o app ainda não tem.
    'E-mail ou senha não conferem. Confira os dois e tente de novo. Se não '
    'lembra a senha, fale com a clínica.',
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

  /// TM14 — D17: só no mesmo dia em que o registro foi feito.
  edicaoEncerrada(
    'Este registro é de outro dia e não pode mais ser mudado. Se precisar, '
    'conte na próxima consulta.',
  ),
  registroInexistente('Não encontramos este registro.'),

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
  agendamentoInexistente('Não encontramos esta sessão.'),

  /// Fonte Terae local — a sessão do portal acabou no servidor (401).
  sessaoTerminou('Por segurança, entre de novo com a sua senha.'),

  /// Fonte Terae local — o portal da família não tem este recurso.
  indisponivelNestaFonte(
    'Esta parte ainda não está disponível ligada ao Terae local.',
  ),

  /// Fonte Terae local — outra conta da família já registrou a atividade
  /// hoje; no portal vale o primeiro registro do dia (409).
  registroDeOutraConta(
    'Outra pessoa da família já registrou esta atividade hoje.',
  );

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
