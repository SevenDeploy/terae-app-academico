import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/intensidade.dart';
import '../../../dados/modelos/registro_diario.dart';
import '../../../dados/regras/diario.dart' as regra;
import '../../../dados/sincronizacao/situacao_sincronizacao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/data_civil.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../diario/campos_do_diario.dart';

// ------------------------------------------------------------------ datas

String _dois(int n) => n.toString().padLeft(2, '0');

String _diaEMes(DataCivil d) => '${_dois(d.dia)}/${_dois(d.mes)}';

/// O dia de um instante, perto de [agora], no horário da clínica (o
/// `formatarDiaRelativo` do portal): "Hoje, 10/11", "Ontem, 09/11", "Sábado,
/// 07/11" na última semana e, antes dela, "28/10/2026".
String formatarDiaRelativo(DateTime instante, DateTime agora) {
  final dia = DataCivil.doInstante(instante);
  final diasAtras = dia.diasAte(DataCivil.doInstante(agora));
  if (diasAtras == 0) return 'Hoje, ${_diaEMes(dia)}';
  if (diasAtras == 1) return 'Ontem, ${_diaEMes(dia)}';
  if (diasAtras > 1 && diasAtras < 7) {
    final semana = nomeDiaDaSemana(dia.diaDaSemana).split('-').first;
    return '${semana[0].toUpperCase()}${semana.substring(1)}, ${_diaEMes(dia)}';
  }
  return formatarDataCivil(dia);
}

/// "Ontem, 09/11 · 19:10" (quadro 18e).
String formatarMomentoDoRegistro(DateTime instante, DateTime agora) =>
    '${formatarDiaRelativo(instante, agora)} · ${formatarHora(instante)}';

/// Quando a terapeuta revisou, para entrar depois de "Revisado pela
/// terapeuta" (PMC-510): "hoje, às 08:40", "ontem, às 08:40", "na terça,
/// 10/11", "em 28/10/2026".
String formatarQuandoRevisou(DateTime instante, DateTime agora) {
  final dia = DataCivil.doInstante(instante);
  final diasAtras = dia.diasAte(DataCivil.doInstante(agora));
  if (diasAtras == 0) return 'hoje, às ${formatarHora(instante)}';
  if (diasAtras == 1) return 'ontem, às ${formatarHora(instante)}';
  if (diasAtras > 1 && diasAtras < 7) {
    final semana = nomeDiaDaSemana(dia.diaDaSemana).split('-').first;
    final artigo = semana == 'sábado' || semana == 'domingo' ? 'no' : 'na';
    return '$artigo $semana, ${_diaEMes(dia)}';
  }
  return 'em ${formatarDataCivil(dia)}';
}

/// "Hoje, terça, 10/11", o dia do novo registro (quadro 18e).
String formatarHojeDoRegistro(DateTime agora) {
  final hoje = DataCivil.doInstante(agora);
  final semana = nomeDiaDaSemana(hoje.diaDaSemana).split('-').first;
  return 'Hoje, $semana, ${_diaEMes(hoje)}';
}

// ------------------------------------------------------------------ selos

/// A situação do registro na lista (quadro 18e): retirado, a equipe foi
/// avisada, revisado ou aguardando quem lê; sempre com ícone e palavra.
class SeloDaSituacao extends StatelessWidget {
  const SeloDaSituacao({
    super.key,
    required this.registro,
    required this.palavras,
  });

  final RegistroDiario registro;
  final TextosDoDiario palavras;

  @override
  Widget build(BuildContext context) {
    final quem = palavras.quemLe;
    return switch (registro) {
      RegistroDiario(retirado: true) => const Selo(
        key: Key('selo-retirado'),
        texto: 'Retirado por você',
        tom: TomDoSelo.neutro,
        icone: LucideIcons.archive,
      ),
      RegistroDiario(alertouAEquipe: true) => const Selo(
        key: Key('selo-equipe-avisada'),
        texto: 'A equipe foi avisada',
        tom: TomDoSelo.erro,
        icone: LucideIcons.bellRing,
      ),
      RegistroDiario(revisado: true) => Selo(
        key: const Key('selo-revisado'),
        texto: 'Revisado pela $quem',
        tom: TomDoSelo.sucesso,
        icone: LucideIcons.checkCheck,
      ),
      _ => Selo(
        key: const Key('selo-aguardando'),
        texto: 'Aguardando a $quem',
        tom: TomDoSelo.info,
        icone: LucideIcons.clock,
      ),
    };
  }
}

/// O selo de severidade (ícone, palavra e cor, nunca só a cor): na lista com
/// a frase longa, no recibo com a curta ([curto]).
class SeloDaIntensidade extends StatelessWidget {
  const SeloDaIntensidade(this.intensidade, {super.key, this.curto = false});

  final Intensidade intensidade;
  final bool curto;

  static IconData icone(Intensidade i) => switch (i) {
    Intensidade.leve => LucideIcons.circleDot,
    Intensidade.moderado => LucideIcons.circleAlert,
    Intensidade.grave => LucideIcons.triangleAlert,
    Intensidade.critico => LucideIcons.siren,
  };

  @override
  Widget build(BuildContext context) {
    final cores = CoresTerae.daIntensidade(intensidade);
    final critico = intensidade.ehCritico;
    final texto = critico ? CoresTerae.branco : cores.texto;
    return _Pilula(
      texto: curto ? intensidade.curto : intensidade.naLista,
      icone: icone(intensidade),
      cor: texto,
      fundo: critico ? CoresTerae.sevCritica : cores.fundo,
      borda: critico
          ? CoresTerae.sevCritica
          : cores.texto.withValues(alpha: 0.3),
    );
  }
}

/// Selo neutro da lista ("Atividades: fizemos parte", "Corrigido · versão 2").
class SeloNeutro extends StatelessWidget {
  const SeloNeutro(this.texto, {super.key, this.icone});

  final String texto;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => _Pilula(
    texto: texto,
    icone: icone,
    cor: CoresTerae.neutro700,
    fundo: CoresTerae.neutro50,
    borda: CoresTerae.neutro300,
  );
}

class _Pilula extends StatelessWidget {
  const _Pilula({
    required this.texto,
    required this.cor,
    required this.fundo,
    required this.borda,
    this.icone,
  });

  final String texto;
  final IconData? icone;
  final Color cor;
  final Color fundo;
  final Color borda;

  @override
  Widget build(BuildContext context) {
    final icone = this.icone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: borda),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              ExcludeSemantics(child: Icon(icone, size: 14, color: cor)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- o cartão

/// Um registro do diário (quadro 18e): o momento, a situação, os selos, o
/// que foi contado e, enquanto pode mudar (`podeAlterar`, D17 revista),
/// "Corrigir" e "Retirar". O retirado continua, tachado, com o motivo: nada
/// é apagado. "Ver a versão 1" abre as versões anteriores ali mesmo.
class CartaoDoRegistro extends StatefulWidget {
  const CartaoDoRegistro({
    super.key,
    required this.registro,
    required this.agora,
    required this.palavras,
    this.aoCorrigir,
    this.aoRetirar,
  });

  final RegistroDiario registro;
  final DateTime agora;
  final TextosDoDiario palavras;
  final VoidCallback? aoCorrigir;
  final VoidCallback? aoRetirar;

  @override
  State<CartaoDoRegistro> createState() => _CartaoDoRegistroState();
}

class _CartaoDoRegistroState extends State<CartaoDoRegistro> {
  bool _verAnteriores = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.registro;
    final agora = widget.agora;
    final palavras = widget.palavras;
    final quando = formatarMomentoDoRegistro(regra.momentoNaLista(r), agora);
    final retirado = r.retirado;
    final pode = regra.podeAlterar(r);
    final sintomas = r.sintomas;
    final observacoes = r.observacoes;
    final intensidade = r.intensidadeSintoma;
    final motivo = r.motivoDaRetirada;
    final revisadoEm = r.revisadoEm;
    final tachado = TextStyle(
      fontSize: 15,
      color: retirado ? CoresTerae.neutro600 : CoresTerae.neutro800,
      decoration: retirado ? TextDecoration.lineThrough : null,
    );
    return Cartao(
      key: ValueKey('registro-${r.id}'),
      padding: const EdgeInsets.all(MedidasTerae.espaco),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: Text(
                  quando,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SeloDaSituacao(registro: r, palavras: palavras),
            ],
          ),
          if (regra.esperouNaFila(r)) ...[
            const SizedBox(height: 8),
            _LinhaComIcone(
              icone: LucideIcons.notebookPen,
              texto:
                  'Escrito em '
                  '${formatarMomentoDoRegistro(r.registradoEm, agora)}, '
                  'enviado em $quando',
            ),
          ],
          if (!retirado) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (r.versao > 1)
                  SeloNeutro(
                    'Corrigido · versão ${r.versao}',
                    icone: LucideIcons.history,
                  ),
                SeloNeutro(palavras.adesaoNaLista(r.adesao)),
                if (intensidade != null) SeloDaIntensidade(intensidade),
              ],
            ),
          ],
          if (sintomas != null) ...[
            const SizedBox(height: 10),
            Text(sintomas, style: tachado),
          ],
          if (observacoes != null) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Observações: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: observacoes),
                ],
              ),
              style: tachado.copyWith(
                color: retirado ? CoresTerae.neutro600 : CoresTerae.neutro700,
              ),
            ),
          ],
          if (retirado && motivo != null) ...[
            const SizedBox(height: 10),
            _LinhaComIcone(
              icone: LucideIcons.messageSquareQuote,
              texto: textoDoMotivo(motivo),
            ),
          ] else if (!retirado && r.alertouAEquipe) ...[
            const SizedBox(height: 10),
            const _LinhaComIcone(
              icone: LucideIcons.lock,
              texto:
                  'Este registro avisou a equipe. Ele não pode ser corrigido '
                  'nem retirado.',
            ),
          ] else if (!retirado && revisadoEm != null) ...[
            const SizedBox(height: 10),
            _LinhaComIcone(
              icone: LucideIcons.lock,
              texto:
                  'Revisado pela ${palavras.quemLe} '
                  '${formatarQuandoRevisou(revisadoEm, agora)}. Não dá mais '
                  'para corrigir nem retirar.',
            ),
          ],
          if (pode || r.versao > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (pode && widget.aoCorrigir != null)
                  Semantics(
                    label: 'Corrigir o registro de $quando',
                    button: true,
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      key: Key('corrigir-${r.id}'),
                      onPressed: widget.aoCorrigir,
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text('Corrigir'),
                    ),
                  ),
                if (pode && widget.aoRetirar != null)
                  Semantics(
                    label: 'Retirar o registro de $quando',
                    button: true,
                    excludeSemantics: true,
                    child: TextButton.icon(
                      key: Key('retirar-${r.id}'),
                      onPressed: widget.aoRetirar,
                      icon: const Icon(LucideIcons.undo2, size: 16),
                      label: const Text('Retirar'),
                    ),
                  ),
                if (r.versao > 1)
                  Semantics(
                    expanded: _verAnteriores,
                    child: TextButton(
                      key: Key('versoes-${r.id}'),
                      onPressed: () =>
                          setState(() => _verAnteriores = !_verAnteriores),
                      child: Text(
                        _verAnteriores
                            ? 'Esconder as versões anteriores'
                            : r.versao == 2
                            ? 'Ver a versão 1'
                            : 'Ver as versões anteriores',
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (_verAnteriores)
            _VersoesAnteriores(registro: r, agora: agora, palavras: palavras),
        ],
      ),
    );
  }
}

/// "Motivo: registrei no dia errado. Nada foi apagado." (quadro 18e).
String textoDoMotivo(RetiradaDoRegistro motivo) {
  final nome = motivo.categoria.rotulo.toLowerCase();
  final detalhe = motivo.detalhe;
  return 'Motivo: $nome${detalhe == null ? '' : ' (“$detalhe”)'}. '
      'Nada foi apagado.';
}

class _LinhaComIcone extends StatelessWidget {
  const _LinhaComIcone({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ExcludeSemantics(
          child: Icon(icone, size: 15, color: CoresTerae.neutro600),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          texto,
          style: const TextStyle(fontSize: 14, color: CoresTerae.neutro700),
        ),
      ),
    ],
  );
}

/// As versões anteriores à vigente, da mais antiga à mais nova.
class _VersoesAnteriores extends StatelessWidget {
  const _VersoesAnteriores({
    required this.registro,
    required this.agora,
    required this.palavras,
  });

  final RegistroDiario registro;
  final DateTime agora;
  final TextosDoDiario palavras;

  @override
  Widget build(BuildContext context) {
    const texto = TextStyle(fontSize: 14, color: CoresTerae.neutro700);
    return Container(
      key: Key('versoes-anteriores-${registro.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: CoresTerae.borda, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final v in registro.versoesAnteriores) ...[
            Semantics(
              header: true,
              child: Text(
                'Versão ${v.versao} · '
                '${formatarMomentoDoRegistro(v.enviadaEm, agora)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CoresTerae.neutro900,
                ),
              ),
            ),
            Text(palavras.adesaoNaLista(v.adesao), style: texto),
            if (v.intensidadeSintoma case final i?)
              Text('O quanto atrapalhou: ${i.rotulo}', style: texto),
            if (v.sintomas case final s?) Text(s, style: texto),
            if (v.observacoes case final o?)
              Text('Observações: $o', style: texto),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- conexão

/// Constrói com a conexão do app (`ConexaoDoApp`, D16): `online` falso tranca
/// o envio, a correção e a retirada (quadro 18m). Sem a conexão no provider
/// (teste isolado), vale online.
class ComConexao extends StatelessWidget {
  const ComConexao({super.key, required this.construtor});

  final Widget Function(BuildContext context, bool online) construtor;

  @override
  Widget build(BuildContext context) {
    final ConexaoDoApp conexao;
    try {
      conexao = context.read<ConexaoDoApp>();
    } on ProviderNotFoundException {
      return construtor(context, true);
    }
    return ValueListenableBuilder<SituacaoSincronizacao>(
      valueListenable: conexao.situacao,
      builder: (context, situacao, _) => construtor(context, situacao.online),
    );
  }
}

/// Chama [aoMudar] quando uma sincronização termina ou o tamanho da fila
/// muda (D16), para a lista e o registro não ficarem com o que já mudou no
/// servidor (a revisão da terapeuta, o guardado que saiu). Sem
/// [ConexaoDoApp] no provider, não faz nada.
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
