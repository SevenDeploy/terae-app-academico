import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dados/modelos/receita_uso_continuo.dart';
import '../../dados/repositorios/visao_cuidador_repositorio.dart';
import '../../nucleo/sessao/sessao.dart';
import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../../nucleo/tempo/data_civil.dart';
import '../../nucleo/tempo/relogio.dart';
import '../../nucleo/widgets/botao_grande.dart';
import '../../nucleo/widgets/cartao.dart';
import 'visao_cuidador_controlador.dart';

/// Cria o controlador da tela do cuidador com a conta e o perfil ativos e já
/// começa a carregar. Use no `create` do `ChangeNotifierProvider`.
VisaoCuidadorControlador criarControladorDoCuidador(BuildContext context) {
  final sessao = context.read<Sessao>();
  final controlador = VisaoCuidadorControlador(
    repositorio: context.read<RepositorioVisaoCuidador>(),
    relogio: context.read<Relogio>(),
    contaCuidadorId: sessao.conta?.id ?? '',
    pacienteId: sessao.perfilAtivo?.pacienteId ?? '',
  );
  unawaited(controlador.carregar());
  return controlador;
}

/// Primeira letra em maiúscula (`hoje` → `Hoje`).
String comMaiuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// `Hoje às 21:00`, `Amanhã às 08:00`, `Em 3 dias às 09:00` — no horário da
/// clínica, pelos formatadores do `Relogio`.
String diaEHora(DateTime instante, DataCivil hoje) {
  final dia = descricaoRelativa(DataCivil.doInstante(instante), hoje: hoje);
  return '${comMaiuscula(dia)} às ${formatarHora(instante)}';
}

/// Data de renovação da receita em linguagem simples (TM11, TM12):
/// `Renovar a receita até 08/10/2026 (em 6 dias).` ou, se já passou, `A data
/// de renovar a receita era 30/09/2026 (há 2 dias).`
String textoDaRenovacao(ReceitaUsoContinuo receita, DataCivil hoje) {
  final data = formatarDataCivil(receita.dataRenovacao);
  final quando = descricaoRelativa(receita.dataRenovacao, hoje: hoje);
  return receita.dataRenovacao.ehAntesDe(hoje)
      ? 'A data de renovar a receita era $data ($quando).'
      : 'Renovar a receita até $data ($quando).';
}

/// Faixa âmbar "acesso limitado" da TM08 (§7.4, RNFM05).
class AvisoAcessoLimitado extends StatelessWidget {
  const AvisoAcessoLimitado({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: DecoratedBox(
        key: const Key('aviso-acesso-limitado'),
        decoration: const BoxDecoration(
          color: CoresTerae.aviso50,
          border: Border(bottom: BorderSide(color: CoresTerae.aviso200)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MedidasTerae.margemLateral,
            vertical: 10,
          ),
          child: Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: CoresTerae.aviso700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Você está no modo cuidador: acesso limitado.',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: CoresTerae.aviso900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título de seção com ícone, marcado como cabeçalho para o leitor de tela.
class TituloDeSecao extends StatelessWidget {
  const TituloDeSecao(
    this.texto, {
    super.key,
    required this.icone,
    this.cor = CoresTerae.neutro700,
  });

  final String texto;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icone, size: 20, color: cor)),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                texto,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: cor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta arredondada com a distância no tempo ("em 5 dias").
class EtiquetaRelativa extends StatelessWidget {
  const EtiquetaRelativa(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CoresTerae.primaria50,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: CoresTerae.primaria700),
        ),
      ),
    );
  }
}

/// Mostra "carregando", o erro com "Tentar de novo", ou o [construtor].
class ConteudoCarregado extends StatelessWidget {
  const ConteudoCarregado({
    super.key,
    required this.controlador,
    required this.construtor,
  });

  final VisaoCuidadorControlador controlador;
  final WidgetBuilder construtor;

  @override
  Widget build(BuildContext context) {
    if (controlador.carregando) {
      return const Padding(
        padding: EdgeInsets.all(MedidasTerae.espacoGrande),
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
        ),
      );
    }
    final erro = controlador.erro;
    if (erro != null) {
      return Cartao(
        key: const Key('erro-carga'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(erro, style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: MedidasTerae.espaco),
            BotaoGrande(
              key: const Key('tentar-de-novo'),
              rotulo: 'Tentar de novo',
              icone: Icons.refresh,
              variante: VarianteBotao.secundario,
              aoTocar: () => unawaited(controlador.carregar()),
            ),
          ],
        ),
      );
    }
    return construtor(context);
  }
}

/// Bloco "conteúdo clínico bloqueado" (§7.4): o cuidador sabe que o diário e
/// a evolução clínica existem, mas não há rota nem dado para eles (RNFM05).
class BlocoClinicoBloqueado extends StatelessWidget {
  const BlocoClinicoBloqueado({super.key, required this.primeiroNome});

  final String primeiroNome;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloDeSecao(
          'Conteúdo clínico',
          icone: Icons.lock_outline,
          cor: CoresTerae.neutro600,
        ),
        Cartao(
          key: const Key('conteudo-clinico-bloqueado'),
          corFundo: CoresTerae.neutro50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.lock_outline, color: CoresTerae.neutro600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bloqueado para cuidadores. O diário e a evolução clínica '
                  'ficam só com $primeiroNome e a equipe de saúde (LGPD).',
                  style: textos.bodyMedium?.copyWith(
                    color: CoresTerae.neutro700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
