import 'package:flutter/widgets.dart';

import '../../../dados/repositorios/cuidadores_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../nucleo/validacao/cpf.dart';

/// Estado da TM07 Cuidadores (RFM07, UC02, §7.4).
///
/// O contador "n/2" soma convites pendentes e cuidadores ativos
/// (`SituacaoVinculo.contaNoLimite`); com 2/2 a tela esconde o convite. O
/// convite pede nome e CPF (com máscara e dígito verificador conferidos aqui
/// antes de ir ao repositório) e mostra o código gerado para repassar.
/// Revogar não apaga nada: o vínculo fica na lista como "Acesso removido".
/// Toda recusa do repositório vira a mensagem simples de [RecusaDeRegra].
class CuidadoresControlador extends ChangeNotifier {
  CuidadoresControlador({required this.repositorio, required this.pacienteId});

  final RepositorioCuidadores repositorio;
  final String pacienteId;

  final TextEditingController nome = TextEditingController();
  final TextEditingController cpf = TextEditingController();

  bool _carregando = true;
  bool _falhouAoCarregar = false;
  List<CuidadorAutorizado> _cuidadores = const [];
  bool _convidando = false;
  String? _revogando;
  String? _erroNome;
  String? _erroCpf;
  String? _mensagem;
  CuidadorAutorizado? _convidado;
  bool _descartado = false;

  bool get carregando => _carregando;
  bool get falhouAoCarregar => _falhouAoCarregar;

  /// Todos os vínculos, como o repositório devolve (mais recentes primeiro).
  List<CuidadorAutorizado> get cuidadores => _cuidadores;

  /// Pendentes + ativos (§7.4).
  int get contagem =>
      _cuidadores.where((c) => c.vinculo.situacao.contaNoLimite).length;

  bool get noLimite => contagem >= limiteCuidadores;

  bool get convidando => _convidando;

  /// Id do vínculo sendo revogado agora (desabilita o botão dele).
  String? get revogando => _revogando;

  String? get erroNome => _erroNome;
  String? get erroCpf => _erroCpf;

  /// Recusa ou falha do último convite/revogação, em linguagem simples.
  String? get mensagem => _mensagem;

  /// O último convite criado nesta tela, com o código a repassar.
  CuidadorAutorizado? get convidado => _convidado;

  Future<void> carregar() async {
    if (!_carregando) {
      _carregando = true;
      _falhouAoCarregar = false;
      _avisar();
    }
    try {
      _cuidadores = List.unmodifiable(await repositorio.cuidadores(pacienteId));
    } catch (_) {
      _falhouAoCarregar = true;
    }
    _carregando = false;
    _avisar();
  }

  /// Confere os campos e convida. Devolve `true` se o convite foi criado.
  Future<bool> convidar() async {
    if (_convidando || noLimite) return false;
    final nome = this.nome.text.trim();
    final cpf = this.cpf.text;
    _erroNome = nome.length < 3 ? 'Escreva o nome completo da pessoa.' : null;
    _erroCpf = somenteDigitos(cpf).isEmpty
        ? 'Escreva o CPF da pessoa.'
        : (cpfValido(cpf) ? null : MotivoRecusa.cpfInvalido.mensagem);
    _mensagem = null;
    if (_erroNome != null || _erroCpf != null) {
      _avisar();
      return false;
    }
    _convidando = true;
    _avisar();
    try {
      final novo = await repositorio.convidar(
        pacienteId: pacienteId,
        nome: nome,
        cpf: somenteDigitos(cpf),
      );
      _cuidadores = List.unmodifiable([
        novo,
        for (final c in _cuidadores)
          if (c.vinculo.id != novo.vinculo.id) c,
      ]);
      _convidado = novo;
      this.nome.clear();
      this.cpf.clear();
      return true;
    } on RecusaDeRegra catch (recusa) {
      _mensagem = recusa.mensagem;
      return false;
    } catch (_) {
      _mensagem = 'Não foi possível criar o convite agora. Tente de novo.';
      return false;
    } finally {
      _convidando = false;
      _avisar();
    }
  }

  /// Revoga o vínculo (pendente ou ativo). O código de um convite pendente
  /// deixa de valer.
  Future<void> revogar(String vinculoId) async {
    if (_revogando != null) return;
    _revogando = vinculoId;
    _mensagem = null;
    _avisar();
    try {
      final atualizado = await repositorio.revogar(vinculoId);
      _cuidadores = List.unmodifiable([
        for (final c in _cuidadores) c.vinculo.id == vinculoId ? atualizado : c,
      ]);
      if (_convidado?.vinculo.id == vinculoId) _convidado = null;
    } on RecusaDeRegra catch (recusa) {
      _mensagem = recusa.mensagem;
    } catch (_) {
      _mensagem = 'Não foi possível remover o acesso agora. Tente de novo.';
    } finally {
      _revogando = null;
      _avisar();
    }
  }

  void _avisar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    nome.dispose();
    cpf.dispose();
    super.dispose();
  }
}
