import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/cartao.dart';
import '../componentes_paciente.dart';

/// TM16 — Em casa (D21, D22). Aba só do paciente com terapia ocupacional: as
/// atividades de casa combinadas na terapia com a família ou com o próprio
/// paciente. Nesta etapa (fundação) mostra só o estado vazio; as atividades
/// e o registro de cada dia entram na fase seguinte.
///
/// Fala com quem está com o aparelho (D24): o titular ("você") ou quem cuida
/// do paciente ("vocês", com o primeiro nome dele).
///
/// A `Key('TM16')` no Scaffold raiz faz parte do contrato (testes de
/// navegação).
class EmCasaTela extends StatelessWidget {
  const EmCasaTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM16'),
      body: perfil == null
          ? const SizedBox.shrink()
          : _ConteudoEmCasa(perfil: perfil),
    );
  }
}

class _ConteudoEmCasa extends StatelessWidget {
  const _ConteudoEmCasa({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final nome = perfil.paciente.primeiroNome;
    final deOutro = perfil.falaDeOutraPessoa;
    return CorpoDaTela(
      children: [
        CabecalhoDaTela(
          titulo: 'Em casa',
          subtitulo: deOutro
              ? 'O que fazer com $nome entre uma sessão e outra.'
              : 'O que fazer entre uma sessão e outra.',
        ),
        const SizedBox(height: MedidasTerae.espacoGrande),
        Cartao(
          key: const Key('em-casa-vazio'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.extension_outlined,
                  size: 32,
                  color: CoresTerae.primaria600,
                ),
              ),
              const SizedBox(width: MedidasTerae.espaco),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhuma atividade por enquanto',
                      style: textos.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deOutro
                          ? 'Quando a terapia ocupacional de $nome tiver '
                                'atividades de casa, elas aparecem aqui, com '
                                'o que fazer e quantas vezes por semana.'
                          : 'Quando a sua terapia ocupacional tiver '
                                'atividades de casa, elas aparecem aqui, com '
                                'o que fazer e quantas vezes por semana.',
                      style: textos.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
