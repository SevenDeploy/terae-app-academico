import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'dados/repositorios/autenticacao_repositorio.dart';
import 'dados/repositorios/cuidadores_repositorio.dart';
import 'dados/repositorios/demonstracao_repositorio.dart';
import 'dados/repositorios/diario_repositorio.dart';
import 'dados/repositorios/lembretes_repositorio.dart';
import 'dados/repositorios/paciente_repositorio.dart';
import 'dados/repositorios/presenca_repositorio.dart';
import 'dados/repositorios/programa_em_casa_repositorio.dart';
import 'dados/repositorios/repositorios.dart';
import 'dados/repositorios/visao_cuidador_repositorio.dart';
import 'dados/sincronizacao/situacao_sincronizacao.dart';
import 'nucleo/rotas/rotas.dart';
import 'nucleo/sessao/sessao.dart';
import 'nucleo/tema/tema.dart';
import 'nucleo/tempo/relogio.dart';
import 'nucleo/widgets/faixa_emergencia.dart';
import 'roteador.dart';

/// O aplicativo: tema, localização pt-BR e roteador (§24).
///
/// Recebe tudo por construtor (o `main.dart` cria; o teste passa dublês) e
/// disponibiliza por provider, acima do roteador, para qualquer tela:
/// cada contrato de [Repositorios] pelo próprio tipo, a situação da conexão
/// (`ConexaoDoApp`, Atividade 4), [Relogio],
/// [LancadorExterno] e a [Sessao] (`ChangeNotifierProvider`).
class TeraeApp extends StatefulWidget {
  const TeraeApp({
    super.key,
    required this.repositorios,
    required this.sessao,
    required this.relogio,
    this.lancador = const LancadorExterno(),
    this.localInicial = Rotas.boasVindas,
  });

  final Repositorios repositorios;
  final Sessao sessao;
  final Relogio relogio;
  final LancadorExterno lancador;

  /// Rota de partida (teste de link direto); a guarda vale igual.
  final String localInicial;

  @override
  State<TeraeApp> createState() => _TeraeAppState();
}

class _TeraeAppState extends State<TeraeApp> {
  late final GoRouter _roteador = criarRoteador(
    sessao: widget.sessao,
    localInicial: widget.localInicial,
  );

  @override
  void dispose() {
    _roteador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.repositorios;
    return MultiProvider(
      providers: [
        Provider<RepositorioAutenticacao>.value(value: r.autenticacao),
        Provider<RepositorioPaciente>.value(value: r.paciente),
        Provider<RepositorioDiario>.value(value: r.diario),
        Provider<RepositorioCuidadores>.value(value: r.cuidadores),
        Provider<RepositorioVisaoCuidador>.value(value: r.visaoCuidador),
        Provider<ControleDemonstracao>.value(value: r.demonstracao),
        Provider<RepositorioProgramaEmCasa>.value(value: r.programaEmCasa),
        Provider<RepositorioPresenca>.value(value: r.presenca),
        Provider<RepositorioLembretes>.value(value: r.lembretes),
        Provider<ConexaoDoApp>.value(value: ConexaoDoApp(r.conexao)),
        Provider<Relogio>.value(value: widget.relogio),
        Provider<LancadorExterno>.value(value: widget.lancador),
        ChangeNotifierProvider<Sessao>.value(value: widget.sessao),
      ],
      child: MaterialApp.router(
        title: 'Terae',
        debugShowCheckedModeBanner: false,
        theme: temaTerae(),
        routerConfig: _roteador,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}
