import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/intensidade.dart';
import '../../../dados/enums/situacao_envio.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/sincronizacao/situacao_sincronizacao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import '../diario/campos_do_diario.dart';

/// Etiqueta da intensidade: cor de severidade sempre com o nome e o ícone.
class EtiquetaDeIntensidade extends StatelessWidget {
  const EtiquetaDeIntensidade(this.intensidade, {super.key});

  final Intensidade intensidade;

  @override
  Widget build(BuildContext context) => Etiqueta(
    texto: intensidade.rotulo,
    cores: CoresTerae.daIntensidade(intensidade),
    icone: iconeDaIntensidade(intensidade),
  );
}

/// "Aguardando envio" (fila, D16) ou "Enviado".
class EtiquetaDeEnvio extends StatelessWidget {
  const EtiquetaDeEnvio(this.situacao, {super.key});

  final SituacaoEnvio situacao;

  @override
  Widget build(BuildContext context) => switch (situacao) {
    SituacaoEnvio.naFila => const Etiqueta(
      key: Key('etiqueta-na-fila'),
      texto: 'Aguardando envio',
      cores: ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
      icone: Icons.cloud_upload_outlined,
    ),
    SituacaoEnvio.enviado => const Etiqueta(
      texto: 'Enviado',
      cores: ParDeCores(CoresTerae.clinico700, CoresTerae.clinico50),
      icone: Icons.cloud_done_outlined,
    ),
  };
}

/// Um registro na lista da TM13: dia e hora, sintoma, intensidade e envio.
class CartaoDeRegistro extends StatelessWidget {
  const CartaoDeRegistro({
    super.key,
    required this.registro,
    required this.aoTocar,
  });

  final RegistroDiario registro;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final observacao = registro.observacao;
    return Cartao(
      aoTocar: aoTocar,
      rotuloSemantico:
          '${formatarDataHora(registro.registradoEm)}, '
          '${registro.sintomaPredominante}, intensidade '
          '${registro.intensidade.rotulo}, ${registro.situacaoEnvio.rotulo}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatarDataHora(registro.registradoEm),
                  style: textos.labelLarge?.copyWith(
                    color: CoresTerae.neutro600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: CoresTerae.neutro400),
            ],
          ),
          const SizedBox(height: 4),
          Text(registro.sintomaPredominante, style: textos.titleMedium),
          if (observacao != null) ...[
            const SizedBox(height: 2),
            Text(
              observacao,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textos.bodyMedium?.copyWith(color: CoresTerae.neutro700),
            ),
          ],
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Wrap(
            spacing: MedidasTerae.espacoPequeno,
            runSpacing: MedidasTerae.espacoPequeno,
            children: [
              EtiquetaDeIntensidade(registro.intensidade),
              EtiquetaDeEnvio(registro.situacaoEnvio),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chama [aoMudar] quando uma sincronização termina ou o tamanho da fila
/// muda (D16), para a TM13 e a TM14 não ficarem com "Aguardando envio" depois
/// que o registro já saiu. Sem [ConexaoDoApp] no provider, não faz nada.
class RecarregaAoSincronizar extends StatefulWidget {
  const RecarregaAoSincronizar({
    super.key,
    required this.aoMudar,
    required this.child,
  });

  final VoidCallback aoMudar;
  final Widget child;

  @override
  State<RecarregaAoSincronizar> createState() => _RecarregaAoSincronizarState();
}

class _RecarregaAoSincronizarState extends State<RecarregaAoSincronizar> {
  ValueListenable<SituacaoSincronizacao>? _situacao;
  SituacaoSincronizacao? _anterior;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ValueListenable<SituacaoSincronizacao>? nova;
    try {
      nova = context.read<ConexaoDoApp>().situacao;
    } on ProviderNotFoundException {
      nova = null;
    }
    if (identical(nova, _situacao)) return;
    _situacao?.removeListener(_aoMudarSituacao);
    _situacao = nova;
    _anterior = nova?.value;
    nova?.addListener(_aoMudarSituacao);
  }

  void _aoMudarSituacao() {
    final atual = _situacao?.value;
    final anterior = _anterior;
    _anterior = atual;
    if (atual == null || anterior == null) return;
    final terminou = anterior.sincronizando && !atual.sincronizando;
    if (terminou || anterior.pendentes != atual.pendentes) widget.aoMudar();
  }

  @override
  void dispose() {
    _situacao?.removeListener(_aoMudarSituacao);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
