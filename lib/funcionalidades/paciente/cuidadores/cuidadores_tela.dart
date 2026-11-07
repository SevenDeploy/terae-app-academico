import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/situacao_vinculo.dart';
import '../../../dados/repositorios/cuidadores_repositorio.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/tempo/relogio.dart';
import '../../../nucleo/textos/encontros.dart';
import '../../../nucleo/validacao/formatador_cpf.dart';
import '../../../nucleo/widgets/botao_grande.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';
import 'cuidadores_controlador.dart';

/// TM07 — Cuidadores. RFM07, UC02, §7.4. Aberta pelo menu do Início (D22;
/// era a aba 4), com a seta de voltar: contador "n/2" (pendentes +
/// ativos), lista com a situação de cada um e "Revogar" (com confirmação), e
/// convite por nome e CPF que mostra o código a repassar. Com 2/2 o convite
/// some e fica o aviso do limite.
///
/// A `Key('TM07')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class CuidadoresTela extends StatelessWidget {
  const CuidadoresTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM07'),
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cuidadores'),
      ),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (context) => CuidadoresControlador(
                repositorio: context.read<RepositorioCuidadores>(),
                pacienteId: perfil.pacienteId,
                relogio: context.read<Relogio>(),
              )..carregar(),
              child: const _ConteudoCuidadores(),
            ),
    );
  }
}

class _ConteudoCuidadores extends StatelessWidget {
  const _ConteudoCuidadores();

  /// F2 — o que o cuidador acompanha depende das linhas de cuidado.
  static String _oQueAcompanha(Perfil? perfil) {
    final clinico = perfil?.paciente.temAcompanhamentoClinico ?? true;
    final terapia = perfil?.paciente.temTerapiaOcupacional ?? false;
    final agenda = encontrosDoPaciente(perfil!.paciente);
    if (clinico && terapia) {
      return 'a agenda de $agenda, os horários de remédio e a rotina';
    }
    if (terapia) return 'a agenda de $agenda e a rotina';
    return 'sua agenda e seus horários de remédio';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CuidadoresControlador>();
    final textos = Theme.of(context).textTheme;
    return CorpoDaTela(
      children: [
        CabecalhoDaTela(
          titulo: 'Quem cuida com você',
          subtitulo:
              'Autorize pessoas de confiança para acompanhar '
              '${_oQueAcompanha(context.select<Sessao, Perfil?>((s) => s.perfilAtivo))}.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        if (c.carregando)
          const Carregando()
        else if (c.falhouAoCarregar)
          AvisoDeFalha(
            mensagem: 'Não foi possível mostrar seus cuidadores agora.',
            aoTentarDeNovo: c.carregar,
          )
        else ...[
          _Contador(contagem: c.contagem),
          if (c.mensagem case final mensagem?) ...[
            const SizedBox(height: MedidasTerae.espaco),
            Semantics(
              liveRegion: true,
              child: Cartaozinho(
                key: const Key('mensagem-cuidadores'),
                cores: const ParDeCores(
                  CoresTerae.negativo700,
                  CoresTerae.negativo50,
                ),
                icone: Icons.error_outline,
                children: [
                  Text(
                    mensagem,
                    style: const TextStyle(
                      fontSize: 16,
                      color: CoresTerae.negativo700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.convidado case final convidado?
              when convidado.vinculo.situacao == SituacaoVinculo.pendente) ...[
            const SizedBox(height: MedidasTerae.espaco),
            _CodigoGerado(convidado: convidado),
          ],
          const SizedBox(height: MedidasTerae.espaco),
          if (c.cuidadores.isEmpty)
            Text(
              'Nenhum cuidador por enquanto.',
              style: textos.bodyMedium?.copyWith(
                color: CoresTerae.textoSecundario,
              ),
            )
          else
            for (final cuidador in c.cuidadores) ...[
              _CartaoDoCuidador(cuidador: cuidador),
              const SizedBox(height: MedidasTerae.espacoPequeno + 4),
            ],
          const SizedBox(height: MedidasTerae.espaco),
          if (c.noLimite)
            const Cartaozinho(
              key: Key('aviso-limite'),
              cores: ParDeCores(CoresTerae.aviso900, CoresTerae.aviso50),
              icone: Icons.info_outline,
              children: [
                Text(
                  'Você já tem 2 cuidadores, contando os convites em aberto. '
                  'Para convidar outra pessoa, revogue um acesso acima.',
                  style: TextStyle(fontSize: 16, color: CoresTerae.aviso900),
                ),
              ],
            )
          else
            const _FormularioDeConvite(),
          const SizedBox(height: MedidasTerae.espaco),
          const _NotaDePrivacidade(),
        ],
      ],
    );
  }
}

/// "n/2" com as bolinhas, lido como "n de 2 cuidadores…".
class _Contador extends StatelessWidget {
  const _Contador({required this.contagem});

  final int contagem;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Semantics(
      key: const Key('contador-cuidadores'),
      container: true,
      label:
          '$contagem de $limiteCuidadores cuidadores, contando os convites em '
          'aberto',
      excludeSemantics: true,
      child: Cartao(
        child: Row(
          children: [
            const Icon(Icons.group_outlined, color: CoresTerae.primaria700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$contagem/$limiteCuidadores',
                    style: textos.headlineSmall,
                  ),
                  Text(
                    'cuidadores, contando os convites em aberto',
                    style: textos.bodySmall?.copyWith(
                      color: CoresTerae.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < limiteCuidadores; i++)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < contagem
                        ? CoresTerae.primaria500
                        : CoresTerae.neutro200,
                  ),
                  child: const SizedBox.square(dimension: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// O código do convite recém-criado, grande, para repassar ao cuidador.
class _CodigoGerado extends StatelessWidget {
  const _CodigoGerado({required this.convidado});

  final CuidadorAutorizado convidado;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final codigo = convidado.convite.codigo;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Cartao(
        key: const Key('codigo-gerado'),
        corBorda: CoresTerae.clinico500,
        corFundo: CoresTerae.clinico50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Convite criado para ${convidado.vinculo.nome}',
              style: textos.titleMedium?.copyWith(color: CoresTerae.clinico700),
            ),
            const SizedBox(height: 4),
            Text(
              'Repasse este código para a pessoa:',
              style: textos.bodyMedium,
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              codigo,
              key: const Key('codigo-convite'),
              // Soletrado para o leitor de tela: "A B C 1 2 3".
              semanticsLabel: 'Código ${codigo.split('').join(' ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
                color: CoresTerae.texto,
              ),
            ),
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Text(
              'Vale até ${formatarDataHora(convidado.convite.expiraEm)}. No '
              'app, a pessoa toca em "Primeiro acesso" e escolhe "Recebi um '
              'convite de cuidador".',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoDoCuidador extends StatelessWidget {
  const _CartaoDoCuidador({required this.cuidador});

  final CuidadorAutorizado cuidador;

  Future<void> _confirmarRevogacao(BuildContext context) async {
    final controlador = context.read<CuidadoresControlador>();
    final vinculo = cuidador.vinculo;
    final pendente = vinculo.situacao == SituacaoVinculo.pendente;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revogar o acesso de ${vinculo.nome}?'),
        content: Text(
          pendente
              ? 'O código do convite deixa de valer.'
              : '${vinculo.nome} não vai mais ver sua agenda nem seus '
                    'horários de remédio.',
        ),
        actions: [
          TextButton(
            key: const Key('cancelar-revogar'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmar-revogar'),
            style: FilledButton.styleFrom(
              backgroundColor: CoresTerae.sevCritica,
              foregroundColor: CoresTerae.branco,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (confirmou ?? false) await controlador.revogar(vinculo.id);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final c = context.watch<CuidadoresControlador>();
    final vinculo = cuidador.vinculo;
    final situacao = vinculo.situacao;
    final removido = situacao == SituacaoVinculo.revogado;
    // Pendente vencido: não conta no limite; fica até ser revogado (§7.4).
    final expirado = c.conviteExpirado(cuidador);
    final cores = switch (situacao) {
      _ when expirado => const ParDeCores(
        CoresTerae.neutro600,
        CoresTerae.neutro100,
      ),
      SituacaoVinculo.ativo => const ParDeCores(
        CoresTerae.clinico700,
        CoresTerae.clinico50,
      ),
      SituacaoVinculo.pendente => const ParDeCores(
        CoresTerae.aviso700,
        CoresTerae.aviso50,
      ),
      SituacaoVinculo.revogado => const ParDeCores(
        CoresTerae.neutro600,
        CoresTerae.neutro100,
      ),
    };
    final detalhe = switch (situacao) {
      _ when expirado =>
        'Código ${cuidador.convite.codigo}, venceu em '
            '${formatarData(cuidador.convite.expiraEm)}',
      SituacaoVinculo.pendente =>
        'Código ${cuidador.convite.codigo}, vale até '
            '${formatarData(cuidador.convite.expiraEm)}',
      SituacaoVinculo.ativo => switch (vinculo.autorizadoEm) {
        final em? => 'Autorizado em ${formatarData(em)}',
        null => null,
      },
      SituacaoVinculo.revogado => switch (vinculo.revogadoEm) {
        final em? => 'Removido em ${formatarData(em)}',
        null => null,
      },
    };
    return Cartao(
      key: Key('cuidador-${vinculo.id}'),
      corFundo: removido ? CoresTerae.neutro50 : CoresTerae.superficieElevada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: _Iniciais(nome: vinculo.nome)),
              const SizedBox(width: 12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vinculo.nome, style: textos.titleMedium),
                      const SizedBox(height: 4),
                      Etiqueta(
                        texto: expirado ? 'Convite expirado' : situacao.rotulo,
                        cores: cores,
                      ),
                      if (detalhe != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          detalhe,
                          style: textos.bodySmall?.copyWith(
                            color: CoresTerae.textoSecundario,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!removido) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('revogar-${vinculo.id}'),
                style: TextButton.styleFrom(
                  foregroundColor: CoresTerae.negativo700,
                ),
                onPressed: c.revogando == null
                    ? () => _confirmarRevogacao(context)
                    : null,
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(
                  'Revogar',
                  semanticsLabel: 'Revogar ${vinculo.nome}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Iniciais extends StatelessWidget {
  const _Iniciais({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    final iniciais = [
      if (partes.first.isNotEmpty) partes.first[0],
      if (partes.length > 1) partes.last[0],
    ].join().toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CoresTerae.primaria50,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Text(
            iniciais,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: CoresTerae.primaria700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormularioDeConvite extends StatelessWidget {
  const _FormularioDeConvite();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CuidadoresControlador>();
    final textos = Theme.of(context).textTheme;
    return Cartao(
      key: const Key('formulario-convite'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Convidar um cuidador', style: textos.titleMedium),
          ),
          const SizedBox(height: 4),
          Text(
            'Vamos gerar um código para você repassar. O CPF precisa ser o da '
            'pessoa convidada.',
            style: textos.bodySmall?.copyWith(
              color: CoresTerae.textoSecundario,
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          TextField(
            key: const Key('campo-nome-cuidador'),
            controller: c.nome,
            enabled: !c.convidando,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(
              labelText: 'Nome completo',
              hintText: 'ex.: Maria da Silva',
              errorText: c.erroNome,
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          TextField(
            key: const Key('campo-cpf-cuidador'),
            controller: c.cpf,
            enabled: !c.convidando,
            keyboardType: TextInputType.number,
            inputFormatters: const [FormatadorCpf()],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => c.convidar(),
            decoration: InputDecoration(
              labelText: 'CPF',
              hintText: '000.000.000-00',
              errorText: c.erroCpf,
            ),
          ),
          const SizedBox(height: MedidasTerae.espaco),
          BotaoGrande(
            key: const Key('convidar'),
            rotulo: c.convidando ? 'Gerando convite…' : 'Gerar convite',
            icone: Icons.person_add_alt,
            aoTocar: c.convidando ? null : c.convidar,
          ),
        ],
      ),
    );
  }
}

class _NotaDePrivacidade extends StatelessWidget {
  const _NotaDePrivacidade();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CoresTerae.neutro50,
        borderRadius: BorderRadius.all(
          Radius.circular(MedidasTerae.raioCartao),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MedidasTerae.espaco),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.verified_user_outlined,
                color: CoresTerae.clinico700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cuidadores veem só sua agenda, seus horários de remédio e os '
                'avisos enviados à equipe. O que você conta no diário fica '
                'entre você e sua equipe.',
                style: textos.bodySmall?.copyWith(color: CoresTerae.neutro600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
