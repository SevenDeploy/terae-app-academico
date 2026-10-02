/// Recusas de regra que os repositórios devolvem como exceção ([RecusaDeRegra]).
///
/// A tela mostra [MotivoRecusa.mensagem], já em linguagem simples (RNFM01).
/// Sem conexão no envio do diário NÃO é recusa: o registro vai para a fila
/// (`naFila`, §19).
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
  acessoNegado('Você não tem acesso a estas informações.'),
  semConexao('Sem internet agora. Tente de novo quando a conexão voltar.');

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
