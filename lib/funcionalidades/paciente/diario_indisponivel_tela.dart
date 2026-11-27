import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../nucleo/tema/cores.dart';
import '../../nucleo/tema/tema.dart';
import '../capacidades.dart';
import 'componentes_paciente.dart';
import 'diario/diario_tela.dart';

/// A aba Diário pela fonte de dados: a TM03 de sempre, ou, onde a fonte
/// ainda não tem o diário (`CapacidadesDaFonte.diario`), o aviso de que ele
/// está indisponível.
class DiarioDaFonte extends StatelessWidget {
  const DiarioDaFonte({super.key});

  @override
  Widget build(BuildContext context) => capacidadesDaFonte(context).diario
      ? const DiarioTela()
      : const DiarioIndisponivelTela();
}

/// Fonte Terae local: o diário chega depois da P3 (outra branch refaz o
/// modelo do diário igual ao do portal; a coordenação liga
/// `/api/portal/diario` depois). A aba existe, como no portal, e diz por que
/// está vazia, sem botão que não faz nada.
class DiarioIndisponivelTela extends StatelessWidget {
  const DiarioIndisponivelTela({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('diario-indisponivel'),
      body: CorpoDaTela(
        children: [
          CabecalhoDaTela(
            titulo: 'Diário',
            subtitulo: 'Como foram os dias entre uma sessão e outra.',
          ),
          SizedBox(height: MedidasTerae.espacoCartao),
          Cartaozinho(
            cores: ParDeCores(CoresTerae.neutro700, CoresTerae.neutro100),
            icone: LucideIcons.notebookPen,
            children: [
              Text(
                'Diário ainda indisponível aqui',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: CoresTerae.neutro700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ligado ao Terae local, o diário chega na próxima versão do '
                'app. Por enquanto, registre o dia pelo portal da família.',
                style: TextStyle(fontSize: 14, color: CoresTerae.neutro700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
