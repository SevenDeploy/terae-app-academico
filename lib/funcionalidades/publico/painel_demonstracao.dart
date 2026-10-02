import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/repositorios/demonstracao_repositorio.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/widgets/botao_grande.dart';
import 'folha_inferior.dart';

/// D11 — abre o painel de demonstração. Só a TM00 chama, e só em
/// `kDebugMode` (a condição fica na `BoasVindasTela`).
Future<void> abrirPainelDemonstracao(BuildContext context) =>
    mostrarFolha<void>(
      context: context,
      titulo: 'Painel de demonstração',
      construtor: (folha) =>
          PainelDemonstracao(controle: folha.read<ControleDemonstracao>()),
    );

/// D11 — "sem conexão" liga e desliga (fila `naFila`, TM04/TM05 com envio
/// pendente) e "reiniciar dados" volta às personas iniciais.
class PainelDemonstracao extends StatefulWidget {
  const PainelDemonstracao({super.key, required this.controle});

  final ControleDemonstracao controle;

  @override
  State<PainelDemonstracao> createState() => _PainelDemonstracaoState();
}

class _PainelDemonstracaoState extends State<PainelDemonstracao> {
  late bool _semConexao = widget.controle.semConexao;
  bool _ocupado = false;
  bool _reiniciado = false;

  Future<void> _mudarConexao(bool semConexao) async {
    setState(() => _ocupado = true);
    await widget.controle.definirSemConexao(semConexao: semConexao);
    if (!mounted) return;
    setState(() {
      _semConexao = widget.controle.semConexao;
      _ocupado = false;
    });
  }

  Future<void> _reiniciar() async {
    setState(() {
      _ocupado = true;
      _reiniciado = false;
    });
    await widget.controle.reiniciarDados();
    if (!mounted) return;
    setState(() {
      _semConexao = widget.controle.semConexao;
      _ocupado = false;
      _reiniciado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Só aparece na versão de desenvolvimento, para a apresentação.',
          style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
        ),
        const SizedBox(height: MedidasTerae.espaco),
        SwitchListTile(
          key: const Key('demo-sem-conexao'),
          contentPadding: EdgeInsets.zero,
          value: _semConexao,
          onChanged: _ocupado ? null : _mudarConexao,
          title: const Text('Simular sem conexão'),
          subtitle: const Text(
            'O diário fica na fila e só é enviado quando a conexão voltar.',
          ),
        ),
        const SizedBox(height: MedidasTerae.espaco),
        BotaoGrande(
          key: const Key('demo-reiniciar'),
          rotulo: 'Reiniciar dados de demonstração',
          icone: Icons.restart_alt,
          variante: VarianteBotao.secundario,
          aoTocar: _ocupado ? null : _reiniciar,
        ),
        if (_reiniciado) ...[
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Semantics(
            liveRegion: true,
            child: Text(
              'Pronto: os dados voltaram ao início.',
              style: textos.bodyMedium?.copyWith(color: CoresTerae.clinico700),
            ),
          ),
        ],
      ],
    );
  }
}
