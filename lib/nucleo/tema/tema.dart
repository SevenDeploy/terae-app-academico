import 'package:flutter/material.dart';

import 'cores.dart';

/// Medidas do Terae para o app (RNFM01: botões grandes; D10: texto ≥ 14 sp).
abstract final class MedidasTerae {
  static const double raioCartao = 16;
  static const double raioBotao = 8;
  static const double raioPequeno = 8;

  /// Margem lateral das telas (o `px-4` do portal no telefone).
  static const double margemLateral = 16;
  static const EdgeInsets paddingTela = EdgeInsets.fromLTRB(16, 24, 16, 24);

  /// Espaço interno e entre cartões (`p-5`, `gap-5`).
  static const double espacoCartao = 20;

  /// Alvo de toque mínimo de qualquer botão (WCAG 2.5.8 / Android 48 dp).
  static const double alturaMinimaBotao = 48;

  /// Altura do [BotaoGrande] (o `h-12` dos botões do portal).
  static const double alturaBotaoGrande = 48;

  /// Altura mínima de cada opção do seletor (adesão, intensidade).
  static const double alturaMinimaSeletor = 64;

  /// Nenhum texto do app fica abaixo disto.
  static const double textoMinimo = 14;

  /// Espessura do contorno de foco visível.
  static const double larguraFoco = 3;

  static const double espacoPequeno = 8;
  static const double espaco = 16;
  static const double espacoGrande = 24;
}

/// Inter na interface e na leitura; Lexend nos títulos (como o portal).
const String _fonte = 'Inter';
const String _fonteTitulo = 'Lexend';

/// Contorno de 3 px quando o controle tem foco de teclado (WCAG 2.4.7).
final WidgetStateProperty<BorderSide?> _bordaDeFoco =
    WidgetStateProperty.resolveWith(
      (estados) => estados.contains(WidgetState.focused)
          ? const BorderSide(
              color: CoresTerae.foco,
              width: MedidasTerae.larguraFoco,
            )
          : null,
    );

const RoundedRectangleBorder _formaBotao = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(MedidasTerae.raioBotao)),
);

const TextStyle _textoBotao = TextStyle(
  fontFamily: _fonte,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);

OutlineInputBorder _bordaCampo(Color cor, [double largura = 1.5]) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(MedidasTerae.raioBotao),
      ),
      borderSide: BorderSide(color: cor, width: largura),
    );

/// Tipografia do portal: títulos em Lexend (h1 26, cartão 18), corpo em Inter
/// 16/1,55; o menor tamanho é 14 (D10).
const TextTheme _textos = TextTheme(
  displaySmall: TextStyle(
    fontFamily: _fonteTitulo,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  ),
  headlineMedium: TextStyle(
    fontFamily: _fonteTitulo,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.56,
  ),
  headlineSmall: TextStyle(
    fontFamily: _fonteTitulo,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 32 / 26,
    letterSpacing: -0.52,
  ),
  titleLarge: TextStyle(
    fontFamily: _fonteTitulo,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  titleMedium: TextStyle(
    fontFamily: _fonteTitulo,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
  titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 17, height: 1.55),
  bodyMedium: TextStyle(fontSize: 16, height: 1.55),
  bodySmall: TextStyle(fontSize: 14, height: 1.4),
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
);

/// ThemeData do app: tokens de `cores.dart`, Inter + Lexend, raios 16/8, botões
/// com 48 de altura mínima e foco visível.
ThemeData temaTerae() {
  const esquema = ColorScheme(
    brightness: Brightness.light,
    primary: CoresTerae.primaria600,
    onPrimary: CoresTerae.branco,
    primaryContainer: CoresTerae.primaria50,
    onPrimaryContainer: CoresTerae.primaria700,
    secondary: CoresTerae.clinico600,
    onSecondary: CoresTerae.branco,
    secondaryContainer: CoresTerae.clinico50,
    onSecondaryContainer: CoresTerae.clinico700,
    error: CoresTerae.sevCritica,
    onError: CoresTerae.branco,
    errorContainer: CoresTerae.sevCriticaFundo,
    onErrorContainer: CoresTerae.sevCritica,
    surface: CoresTerae.superficieElevada,
    onSurface: CoresTerae.texto,
    onSurfaceVariant: CoresTerae.neutro600,
    surfaceContainerLowest: CoresTerae.branco,
    surfaceContainerLow: CoresTerae.neutro50,
    surfaceContainer: CoresTerae.neutro50,
    surfaceContainerHigh: CoresTerae.neutro100,
    surfaceContainerHighest: CoresTerae.neutro100,
    outline: CoresTerae.neutro400,
    outlineVariant: CoresTerae.borda,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: _fonte,
    textTheme: _textos,
    scaffoldBackgroundColor: CoresTerae.superficie,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    focusColor: CoresTerae.primaria600.withValues(alpha: 0.16),
    appBarTheme: const AppBarTheme(
      backgroundColor: CoresTerae.superficieElevada,
      foregroundColor: CoresTerae.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: _fonteTitulo,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: CoresTerae.texto,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          MedidasTerae.alturaMinimaBotao,
          MedidasTerae.alturaMinimaBotao,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: _formaBotao,
        textStyle: _textoBotao,
      ).copyWith(side: _bordaDeFoco),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(
          MedidasTerae.alturaMinimaBotao,
          MedidasTerae.alturaMinimaBotao,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: _formaBotao,
        textStyle: _textoBotao,
      ).copyWith(side: _bordaDeFoco),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(
              MedidasTerae.alturaMinimaBotao,
              MedidasTerae.alturaMinimaBotao,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: _formaBotao,
            textStyle: _textoBotao,
            foregroundColor: CoresTerae.primaria700,
            backgroundColor: CoresTerae.branco,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (estados) => estados.contains(WidgetState.focused)
                  ? const BorderSide(
                      color: CoresTerae.foco,
                      width: MedidasTerae.larguraFoco,
                    )
                  : const BorderSide(color: CoresTerae.borda),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          MedidasTerae.alturaMinimaBotao,
          MedidasTerae.alturaMinimaBotao,
        ),
        shape: _formaBotao,
        textStyle: _textoBotao,
        foregroundColor: CoresTerae.primaria700,
      ).copyWith(side: _bordaDeFoco),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(
          MedidasTerae.alturaMinimaBotao,
          MedidasTerae.alturaMinimaBotao,
        ),
      ).copyWith(side: _bordaDeFoco),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CoresTerae.branco,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _bordaCampo(CoresTerae.bordaCampo),
      enabledBorder: _bordaCampo(CoresTerae.bordaCampo),
      focusedBorder: _bordaCampo(CoresTerae.primaria600, 2.5),
      errorBorder: _bordaCampo(CoresTerae.sevCritica),
      focusedErrorBorder: _bordaCampo(CoresTerae.sevCritica, 2.5),
      disabledBorder: _bordaCampo(CoresTerae.borda),
      labelStyle: const TextStyle(fontSize: 16, color: CoresTerae.neutro600),
      floatingLabelStyle: const TextStyle(
        fontSize: 16,
        color: CoresTerae.primaria700,
      ),
      hintStyle: const TextStyle(fontSize: 16, color: CoresTerae.neutro400),
      helperStyle: const TextStyle(fontSize: 14, color: CoresTerae.neutro500),
      errorStyle: const TextStyle(fontSize: 14, color: CoresTerae.sevCritica),
    ),
    cardTheme: const CardThemeData(
      color: CoresTerae.superficieElevada,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(MedidasTerae.raioCartao),
        ),
        side: BorderSide(color: CoresTerae.borda),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: CoresTerae.superficieElevada,
      surfaceTintColor: Colors.transparent,
      // O portal marca a aba ativa só pela cor do ícone e do rótulo.
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => TextStyle(
          fontFamily: _fonte,
          fontSize: MedidasTerae.textoMinimo,
          fontWeight: FontWeight.w600,
          color: estados.contains(WidgetState.selected)
              ? CoresTerae.primaria700
              : CoresTerae.neutro600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          size: 22,
          color: estados.contains(WidgetState.selected)
              ? CoresTerae.primaria700
              : CoresTerae.neutro600,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: CoresTerae.borda),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(MedidasTerae.raioCartao),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: _fonte, fontSize: 16),
    ),
    tooltipTheme: const TooltipThemeData(
      textStyle: TextStyle(
        fontFamily: _fonte,
        fontSize: 14,
        color: CoresTerae.branco,
      ),
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: CoresTerae.texto,
      displayColor: CoresTerae.texto,
    ),
  );
}
