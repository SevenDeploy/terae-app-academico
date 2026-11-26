import 'package:flutter/widgets.dart';

import '../../dados/enums/adesao.dart';
import '../../dados/enums/adesao_em_casa.dart';
import '../../dados/enums/intensidade.dart';

/// Paleta do Terae, igual à do portal da família: valores copiados de
/// `terae/packages/ui/src/tokens.css` (identidade visual v1, out/2026).
///
/// Nomes: `marinho` → marinho, `primary` → primaria, `clinical` → clinico,
/// `slate` → neutro, `sev-*` → sev*, `amber` → aviso, `rose`/`red` → negativo,
/// e as semânticas `sucesso`, `atencao`, `erro` e `info`. Use sempre a
/// constante, nunca um hex solto. Mudou no web, muda aqui (D38).
abstract final class CoresTerae {
  // Marinho: identidade e estrutura (painel da entrada, logotipo). Nunca em
  // botão de ação.
  static const Color marinho50 = Color(0xFFF2F5FA);
  static const Color marinho100 = Color(0xFFE6ECF5);
  static const Color marinho200 = Color(0xFFC9D4E3);
  static const Color marinho400 = Color(0xFF7D93B2);
  static const Color marinho600 = Color(0xFF2A4A7C);
  static const Color marinho800 = Color(0xFF13294D);
  static const Color marinho900 = Color(0xFF0B1E3B);

  // Azul de ação.
  static const Color primaria50 = Color(0xFFEEF5FF);
  static const Color primaria100 = Color(0xFFDAE8FD);
  static const Color primaria200 = Color(0xFFBCD5FB);

  /// Anel de foco.
  static const Color primaria500 = Color(0xFF3479E6);

  /// Ação primária; branco sobre ela: 5,5:1.
  static const Color primaria600 = Color(0xFF1A66CC);

  /// Hover, aba ativa e texto de realce sobre fundo claro.
  static const Color primaria700 = Color(0xFF1556AD);

  // Turquesa (cuidado e continuidade). Texto só a partir do 600.
  static const Color clinico50 = Color(0xFFEBFAF8);
  static const Color clinico100 = Color(0xFFCFF3EE);
  static const Color clinico300 = Color(0xFF67D4C8);
  static const Color clinico500 = Color(0xFF14A195);
  static const Color clinico600 = Color(0xFF0A7F75);
  static const Color clinico700 = Color(0xFF0B675F);

  // Ardósia. O 400 é igual ao 500 de propósito, como no web.
  static const Color neutro50 = Color(0xFFF4F6F9);
  static const Color neutro100 = Color(0xFFEBEFF4);
  static const Color neutro200 = Color(0xFFDCE2EA);
  static const Color neutro300 = Color(0xFFC3CCD8);

  /// Legenda e ícone inativo.
  static const Color neutro400 = Color(0xFF5F6E82);
  static const Color neutro500 = Color(0xFF5F6E82);
  static const Color neutro600 = Color(0xFF4A586B);
  static const Color neutro700 = Color(0xFF374355);
  static const Color neutro800 = Color(0xFF243041);
  static const Color neutro900 = Color(0xFF151F2D);
  static const Color branco = Color(0xFFFFFFFF);

  // Semânticas do portal (texto / fundo / borda).
  static const Color sucesso = Color(0xFF0E7A4B);
  static const Color sucessoFundo = Color(0xFFE8F6EE);
  static const Color sucessoBorda = Color(0xFFA8DCC0);
  static const Color atencao = Color(0xFF8A5300);
  static const Color atencaoFundo = Color(0xFFFFF5E0);
  static const Color atencaoBorda = Color(0xFFF2CD84);
  static const Color erro = Color(0xFFC4291C);
  static const Color erroFundo = Color(0xFFFDEDEB);
  static const Color erroBorda = Color(0xFFF4B7B0);
  static const Color info = Color(0xFF1556AD);
  static const Color infoFundo = Color(0xFFEEF5FF);
  static const Color infoBorda = Color(0xFFBCD5FB);

  // Severidade (texto/borda sobre o próprio fundo: ≥ 4,7:1).
  static const Color sevLeve = Color(0xFF0B7D55);
  static const Color sevLeveFundo = Color(0xFFEAF7F1);
  static const Color sevModerada = Color(0xFF8F5D00);
  static const Color sevModeradaFundo = Color(0xFFFFF7E6);
  static const Color sevGrave = Color(0xFFB34A00);
  static const Color sevGraveFundo = Color(0xFFFFF1E6);
  static const Color sevCritica = Color(0xFFC4291C);
  static const Color sevCriticaFundo = Color(0xFFFDEDEB);

  // Aviso (amber) e negativo (rose/red) harmonizados com a paleta.
  static const Color aviso50 = Color(0xFFFFF5E0);
  static const Color aviso200 = Color(0xFFF7DCA6);
  static const Color aviso700 = Color(0xFF8A5300);
  static const Color aviso900 = Color(0xFF6B4100);
  static const Color negativo50 = Color(0xFFFDEDEB);
  static const Color negativo700 = Color(0xFFA52217);

  // Interação.
  /// Borda de campo (3:1, WCAG 1.4.11).
  static const Color bordaCampo = Color(0xFF8593A6);
  static const Color desabilitadoFundo = Color(0xFFEBEFF4);
  static const Color desabilitadoTexto = Color(0xFF8593A6);

  // Papéis de interface (tema claro; o portal não usa o escuro).
  /// Fundo das telas do portal (`bg-slate-50`).
  static const Color superficie = neutro50;
  static const Color superficieElevada = branco;
  static const Color texto = neutro900;
  static const Color textoSecundario = neutro500;
  static const Color borda = neutro200;
  static const Color realce = primaria600;

  /// Contorno de foco visível (WCAG 2.4.7).
  static const Color foco = neutro900;

  /// Cores da intensidade no seletor e no resumo do diário.
  static ParDeCores daIntensidade(Intensidade intensidade) =>
      switch (intensidade) {
        Intensidade.leve => const ParDeCores(sevLeve, sevLeveFundo),
        Intensidade.moderada => const ParDeCores(sevModerada, sevModeradaFundo),
        Intensidade.grave => const ParDeCores(sevGrave, sevGraveFundo),
        Intensidade.critica => const ParDeCores(sevCritica, sevCriticaFundo),
      };

  /// Cores da adesão no diário.
  static ParDeCores daAdesao(Adesao adesao) => switch (adesao) {
    Adesao.total => const ParDeCores(sucesso, sucessoFundo),
    Adesao.parcial => const ParDeCores(atencao, atencaoFundo),
    Adesao.nenhuma => const ParDeCores(neutro600, neutro100),
  };

  /// Cores da resposta "Conseguiu fazer hoje?". "Não deu" é neutro, nunca
  /// vermelho: é um dia comum, não uma falta (D26).
  static ParDeCores daAdesaoEmCasa(AdesaoEmCasa adesao) => switch (adesao) {
    AdesaoEmCasa.feito => const ParDeCores(sucesso, sucessoFundo),
    AdesaoEmCasa.emParte => const ParDeCores(atencao, atencaoFundo),
    AdesaoEmCasa.naoFeito => const ParDeCores(neutro600, neutro100),
  };
}

/// Cor de texto/borda e cor de fundo que passam AA juntas.
@immutable
class ParDeCores {
  const ParDeCores(this.texto, this.fundo);

  final Color texto;
  final Color fundo;
}
