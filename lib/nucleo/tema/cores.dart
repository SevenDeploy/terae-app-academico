import 'package:flutter/widgets.dart';

import '../../dados/enums/adesao.dart';
import '../../dados/enums/intensidade.dart';

/// Paleta do Terae, copiada dos tokens de `terae/packages/ui/src/tokens.css`
/// (tabela e contrastes em `terae/docs/design/tokens.md`).
///
/// Nomes: `primary` → primaria, `clinical` → clinico, `slate` → neutro,
/// `sev-*` → sev*, `amber` → aviso, `rose` → negativo. Os seis tokens
/// escurecidos para WCAG AA (primaria600, clinico600 e as quatro severidades)
/// estão com o valor novo. Use sempre a constante, nunca um hex solto.
abstract final class CoresTerae {
  // Azul-saúde.
  static const Color primaria50 = Color(0xFFEFF8FF);
  static const Color primaria100 = Color(0xFFDBEEFE);
  static const Color primaria500 = Color(0xFF3B96EF);

  /// Ação primária; branco sobre ela: 4,63:1.
  static const Color primaria600 = Color(0xFF1D72E0);

  /// Texto/realce sobre fundo claro qualquer (5,3:1 sobre primaria50).
  static const Color primaria700 = Color(0xFF1D61D0);

  // Verde-clínico.
  static const Color clinico50 = Color(0xFFECFDF7);
  static const Color clinico100 = Color(0xFFD2F9EA);
  static const Color clinico500 = Color(0xFF16B48D);

  /// Sucesso; branco sobre ela: 4,65:1.
  static const Color clinico600 = Color(0xFF0A8468);
  static const Color clinico700 = Color(0xFF0A745E);

  // Neutros (slate do Tailwind v4; o 400 é o escurecido do Terae).
  static const Color neutro50 = Color(0xFFF8FAFC);
  static const Color neutro100 = Color(0xFFF1F5F9);
  static const Color neutro200 = Color(0xFFE2E8F0);
  static const Color neutro300 = Color(0xFFCAD5E2);

  /// Legenda e ícone inativo: 4,76:1 sobre branco.
  static const Color neutro400 = Color(0xFF64748B);
  static const Color neutro500 = Color(0xFF62748E);
  static const Color neutro600 = Color(0xFF45556C);
  static const Color neutro700 = Color(0xFF314158);
  static const Color neutro900 = Color(0xFF0F172B);
  static const Color branco = Color(0xFFFFFFFF);

  // Severidade (texto/borda sobre o próprio fundo: ≥ 4,6:1).
  static const Color sevLeve = Color(0xFF0B815A);
  static const Color sevLeveFundo = Color(0xFFECFDF5);
  static const Color sevModerada = Color(0xFF9F6607);
  static const Color sevModeradaFundo = Color(0xFFFFFBEB);
  static const Color sevGrave = Color(0xFFBC5005);
  static const Color sevGraveFundo = Color(0xFFFFF7ED);
  static const Color sevCritica = Color(0xFFD72323);
  static const Color sevCriticaFundo = Color(0xFFFEF2F2);

  // Aviso (lembrete de renovação, acesso limitado) e negativo.
  static const Color aviso50 = Color(0xFFFFFBEB);
  static const Color aviso200 = Color(0xFFFEE685);
  static const Color aviso700 = Color(0xFFBB4D00);
  static const Color aviso900 = Color(0xFF7B3306);
  static const Color negativo50 = Color(0xFFFFF1F2);
  static const Color negativo700 = Color(0xFFC70036);

  // Papéis de interface (tokens semânticos, tema claro).
  static const Color superficie = neutro50;
  static const Color superficieElevada = branco;
  static const Color texto = neutro900;
  static const Color textoSecundario = neutro500;
  static const Color borda = neutro200;

  /// Contorno de foco visível (WCAG 2.4.7).
  static const Color foco = neutro900;

  /// Cores da intensidade no seletor e no resumo do diário (TM03, TM04).
  static ParDeCores daIntensidade(Intensidade intensidade) =>
      switch (intensidade) {
        Intensidade.leve => const ParDeCores(sevLeve, sevLeveFundo),
        Intensidade.moderada => const ParDeCores(sevModerada, sevModeradaFundo),
        Intensidade.grave => const ParDeCores(sevGrave, sevGraveFundo),
        Intensidade.critica => const ParDeCores(sevCritica, sevCriticaFundo),
      };

  /// Cores da adesão no seletor do diário (TM03).
  static ParDeCores daAdesao(Adesao adesao) => switch (adesao) {
    Adesao.total => const ParDeCores(clinico700, clinico50),
    Adesao.parcial => const ParDeCores(aviso700, aviso50),
    Adesao.nenhuma => const ParDeCores(negativo700, negativo50),
  };
}

/// Cor de texto/borda e cor de fundo que passam AA juntas.
@immutable
class ParDeCores {
  const ParDeCores(this.texto, this.fundo);

  final Color texto;
  final Color fundo;
}
