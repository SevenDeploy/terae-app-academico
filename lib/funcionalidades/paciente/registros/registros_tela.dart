import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../dados/enums/intensidade.dart';
import '../../../dados/repositorios/diario_repositorio.dart';
import '../../../nucleo/rotas/rotas.dart';
import '../../../nucleo/sessao/sessao.dart';
import '../../../nucleo/tema/cores.dart';
import '../../../nucleo/tema/tema.dart';
import '../../../nucleo/widgets/aviso_de_conexao.dart';
import '../componentes_paciente.dart';
import 'componentes_registros.dart';
import 'registros_controlador.dart';

/// TM13 — Meus registros (Atividade 4: listagem e busca do item principal,
/// D13). Empilhada sobre as abas, a partir da TM03.
///
/// Lista os registros do diário que valem (o excluído some), do mais recente
/// para o mais antigo, com busca por texto no sintoma e na observação,
/// filtro por intensidade e "puxar para atualizar" (envia a fila e busca de
/// novo). Mostra carregando, vazio e falha (RNFM01), o selo "Aguardando
/// envio" e o aviso de conexão (D16). Tocar abre a TM14.
class RegistrosTela extends StatelessWidget {
  const RegistrosTela({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<Sessao, Perfil?>((s) => s.perfilAtivo);
    return Scaffold(
      key: const Key('TM13'),
      appBar: AppBar(title: const Text('Meus registros')),
      body: perfil == null
          ? const SizedBox.shrink()
          : ChangeNotifierProvider(
              key: ValueKey(perfil.pacienteId),
              create: (contexto) => RegistrosControlador(
                repositorio: contexto.read<RepositorioDiario>(),
                pacienteId: perfil.pacienteId,
              )..carregar(),
              child: Builder(
                builder: (contexto) => RecarregaAoSincronizar(
                  aoMudar: () => unawaited(
                    contexto.read<RegistrosControlador>().carregar(),
                  ),
                  child: const _ListaDeRegistros(),
                ),
              ),
            ),
    );
  }
}

class _ListaDeRegistros extends StatefulWidget {
  const _ListaDeRegistros();

  @override
  State<_ListaDeRegistros> createState() => _ListaDeRegistrosState();
}

class _ListaDeRegistrosState extends State<_ListaDeRegistros> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _abrir(String id) async {
    final controlador = context.read<RegistrosControlador>();
    final mensageiro = ScaffoldMessenger.of(context);
    final excluido = await context.push<bool>(Rotas.registro(id));
    if (excluido ?? false) {
      mensageiro.showSnackBar(
        const SnackBar(content: Text('Registro excluído.')),
      );
    }
    await controlador.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RegistrosControlador>();
    final textos = Theme.of(context).textTheme;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: c.atualizar,
        child: ListView(
          padding: MedidasTerae.paddingTela,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const AvisoDeConexao(),
            TextField(
              key: const Key('campo-busca'),
              controller: _busca,
              textInputAction: TextInputAction.search,
              onSubmitted: c.buscarTexto,
              onChanged: (texto) {
                if (texto.isEmpty) unawaited(c.buscarTexto(''));
              },
              decoration: InputDecoration(
                labelText: 'Buscar no diário',
                hintText: 'Sintoma ou observação',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => unawaited(c.buscarTexto(_busca.text)),
                ),
              ),
            ),
            const SizedBox(height: MedidasTerae.espaco),
            Semantics(
              container: true,
              label: 'Filtrar por intensidade',
              child: Wrap(
                spacing: MedidasTerae.espacoPequeno,
                runSpacing: MedidasTerae.espacoPequeno,
                children: [
                  for (final i in Intensidade.values)
                    FilterChip(
                      key: Key('filtro-${i.name}'),
                      label: Text(i.rotulo),
                      selected: c.intensidades.contains(i),
                      onSelected: (_) => unawaited(c.alternarIntensidade(i)),
                      selectedColor: CoresTerae.daIntensidade(i).fundo,
                      checkmarkColor: CoresTerae.daIntensidade(i).texto,
                    ),
                ],
              ),
            ),
            const SizedBox(height: MedidasTerae.espaco),
            if (c.carregando && c.registros.isEmpty)
              const Carregando()
            else if (c.falhou)
              AvisoDeFalha(
                mensagem:
                    'Não deu para abrir seus registros agora. Tente de novo.',
                aoTentarDeNovo: () => unawaited(c.carregar()),
              )
            else if (c.registros.isEmpty)
              _ListaVazia(
                filtrando: c.filtrando,
                aoLimpar: () {
                  _busca.clear();
                  unawaited(c.limparFiltros());
                },
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  c.registros.length == 1
                      ? '1 registro'
                      : '${c.registros.length} registros',
                  style: textos.labelLarge?.copyWith(
                    color: CoresTerae.neutro600,
                  ),
                ),
              ),
              const SizedBox(height: MedidasTerae.espacoPequeno),
              for (final r in c.registros) ...[
                CartaoDeRegistro(
                  key: Key('registro-${r.id}'),
                  registro: r,
                  aoTocar: () => unawaited(_abrir(r.id)),
                ),
                const SizedBox(height: MedidasTerae.espacoPequeno),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ListaVazia extends StatelessWidget {
  const _ListaVazia({required this.filtrando, required this.aoLimpar});

  final bool filtrando;
  final VoidCallback aoLimpar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MedidasTerae.espacoGrande),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: CoresTerae.neutro400,
          ),
          const SizedBox(height: MedidasTerae.espacoPequeno),
          Text(
            filtrando
                ? 'Nenhum registro com essa busca.'
                : 'Você ainda não tem registros no diário.',
            textAlign: TextAlign.center,
            style: textos.bodyLarge,
          ),
          if (filtrando) ...[
            const SizedBox(height: MedidasTerae.espacoPequeno),
            TextButton(
              key: const Key('limpar-filtros'),
              onPressed: aoLimpar,
              child: const Text('Limpar busca e filtros'),
            ),
          ],
        ],
      ),
    );
  }
}
