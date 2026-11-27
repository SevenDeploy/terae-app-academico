import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/motivo_da_retirada.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../dados/repositorios/falhas.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/cartao_de_opcao.dart';
import 'componentes_registros.dart';

/// Abre a folha "Retirar este registro?" (quadro 18f, "Retirar com motivo";
/// P3, D17 revista) para o [registro] de [quando]. Devolve `true` se retirou.
Future<bool> mostrarRetirarRegistro(
  BuildContext context, {
  required RegistroDiario registro,
  required String quando,
}) async {
  final repositorio = context.read<RepositorioDiario>();
  final retirou = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: CoresTerae.branco,
    builder: (_) => Provider<RepositorioDiario>.value(
      value: repositorio,
      child: FolhaDeRetirar(registro: registro, quando: quando),
    ),
  );
  return retirou ?? false;
}

/// A folha de retirar: o motivo é uma categoria (dia errado, paciente errado,
/// sem querer, outro); "Outro" exige um detalhe curto, de até 300
/// caracteres. Sem internet, "Retirar o registro" fica travado com o motivo
/// à vista. Se a terapeuta revisou no meio (o 409 do portal), a folha diz
/// isso e não retira nada. O botão vermelho é o único destrutivo da folha.
class FolhaDeRetirar extends StatefulWidget {
  const FolhaDeRetirar({
    super.key,
    required this.registro,
    required this.quando,
  });

  final RegistroDiario registro;
  final String quando;

  @override
  State<FolhaDeRetirar> createState() => _FolhaDeRetirarState();
}

class _FolhaDeRetirarState extends State<FolhaDeRetirar> {
  final TextEditingController _detalhe = TextEditingController();
  MotivoDaRetirada? _categoria;
  String? _erroDaCategoria;
  String? _erroDoDetalhe;
  String? _falha;
  bool _naoMudaMais = false;
  bool _retirando = false;

  @override
  void dispose() {
    _detalhe.dispose();
    super.dispose();
  }

  Future<void> _retirar() async {
    final categoria = _categoria;
    if (categoria == null) {
      setState(() => _erroDaCategoria = 'Escolha por que retirar o registro.');
      return;
    }
    final motivo = RetiradaDoRegistro(
      categoria: categoria,
      detalhe: _detalhe.text,
    );
    final problema = motivo.problema;
    if (problema != null) {
      setState(() => _erroDoDetalhe = problema);
      return;
    }
    setState(() {
      _retirando = true;
      _falha = null;
    });
    final navegador = Navigator.of(context);
    try {
      await context.read<RepositorioDiario>().retirar(
        widget.registro.id,
        motivo,
      );
      navegador.pop(true);
    } on RecusaDeRegra catch (recusa) {
      setState(() {
        _retirando = false;
        if (recusa.motivo == MotivoRecusa.registroNaoMudaMais) {
          _naoMudaMais = true;
        } else {
          _falha = recusa.mensagem;
        }
      });
    } on Exception {
      setState(() {
        _retirando = false;
        _falha = 'Não deu para retirar agora. Tente de novo em instantes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: MedidasTerae.margemLateral,
        right: MedidasTerae.margemLateral,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: ComConexao(
          construtor: (context, online) => Column(
            key: const Key('folha-retirar'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Retirar este registro?',
                  style: textos.headlineSmall,
                ),
              ),
              Text(
                widget.quando,
                style: const TextStyle(
                  fontSize: 15,
                  color: CoresTerae.neutro600,
                ),
              ),
              const SizedBox(height: MedidasTerae.espaco),
              if (_naoMudaMais) ...[
                const _NaoMudaMais(),
                const SizedBox(height: MedidasTerae.espaco),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Voltar ao diário'),
                ),
              ] else ...[
                GrupoDeCartoes<MotivoDaRetirada>(
                  key: const Key('motivo-retirada'),
                  pergunta: 'Por que você quer retirar?',
                  estiloDaPergunta: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CoresTerae.neutro900,
                  ),
                  valor: _categoria,
                  erro: _erroDaCategoria,
                  aoMudar: (m) => setState(() {
                    _categoria = m;
                    _erroDaCategoria = null;
                  }),
                  opcoes: [
                    for (final m in MotivoDaRetirada.values)
                      OpcaoDeCartao(valor: m, titulo: m.rotulo),
                  ],
                ),
                if (_categoria == MotivoDaRetirada.outro) ...[
                  const SizedBox(height: MedidasTerae.espaco),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _detalhe,
                    builder: (context, valor, _) => TextField(
                      key: const Key('detalhe-retirada'),
                      controller: _detalhe,
                      maxLength: MotivoDaRetirada.detalheMaximo,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) {
                        if (_erroDoDetalhe != null) {
                          setState(() => _erroDoDetalhe = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Conte em poucas palavras (obrigatório)',
                        errorText: _erroDoDetalhe,
                        counterText:
                            '${valor.text.length} de '
                            '${MotivoDaRetirada.detalheMaximo} caracteres',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: MedidasTerae.espaco),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        LucideIcons.archive,
                        size: 16,
                        color: CoresTerae.neutro600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'O registro fica marcado como retirado, com o motivo. '
                        'Nada é apagado.',
                        style: TextStyle(
                          fontSize: 14,
                          color: CoresTerae.neutro700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!online) ...[
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                  const Text(
                    'Retirar precisa de internet. Espere a internet voltar; a '
                    'escolha fica nesta folha.',
                    key: Key('retirar-sem-internet'),
                    style: TextStyle(fontSize: 14, color: CoresTerae.neutro600),
                  ),
                ],
                if (_falha case final falha?) ...[
                  const SizedBox(height: MedidasTerae.espacoPequeno),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      falha,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CoresTerae.erro,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: MedidasTerae.espaco),
                FilledButton.icon(
                  key: const Key('confirmar-retirada'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CoresTerae.erro,
                    foregroundColor: CoresTerae.branco,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: online && !_retirando ? _retirar : null,
                  icon: Icon(
                    online ? LucideIcons.archive : LucideIcons.cloudOff,
                    size: 18,
                  ),
                  label: Text(_retirando ? 'Retirando…' : 'Retirar o registro'),
                ),
                const SizedBox(height: MedidasTerae.espacoPequeno),
                OutlinedButton(
                  key: const Key('cancelar-retirada'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Este registro não pode mais mudar." (o 409 do portal, quadro 18f).
class _NaoMudaMais extends StatelessWidget {
  const _NaoMudaMais();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        key: const Key('registro-nao-muda-mais'),
        decoration: BoxDecoration(
          color: CoresTerae.atencaoFundo,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: CoresTerae.atencaoBorda),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  LucideIcons.lock,
                  size: 18,
                  color: CoresTerae.atencao,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este registro não pode mais mudar. A terapeuta pode já '
                  'tê-lo revisado, ou ele foi corrigido em outra tela.',
                  style: TextStyle(fontSize: 15, color: CoresTerae.atencao),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O aviso do 409 também na correção (TM15).
class AvisoNaoMudaMais extends StatelessWidget {
  const AvisoNaoMudaMais({super.key});

  @override
  Widget build(BuildContext context) => const _NaoMudaMais();
}
