import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts_lite.dart';

/// Tema visual de UniSport: modo claro, superficies limpias, verde deportivo
/// como color de acción y cian como acento informativo.
class TemaApp {
  // Base
  static const Color fondo = Color(0xFFF6F8FB);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieSuave = Color(0xFFF1F5F9);
  static const Color textoPrincipal = Color(0xFF0F172A);
  static const Color textoSecundario = Color(0xFF64748B);
  static const Color borde = Color(0xFFE2E8F0);

  // Marca y acentos
  static const Color verdeDeportivo = Color(0xFF16A34A);
  static const Color verdeOscuro = Color(0xFF15803D);
  static const Color verdeSuave = Color(0xFFDCFCE7);
  static const Color azulDeportivo = Color(
    0xFF0284C7,
  ); // cian/azul para enlaces e info
  static const Color azulSuave = Color(0xFFE0F2FE);
  static const Color naranjaAviso = Color(0xFFEA580C);
  static const Color naranjaSuave = Color(0xFFFFEDD5);
  static const Color rojoAlerta = Color(0xFFDC2626);
  static const Color rojoSuave = Color(0xFFFEE2E2);

  static const double radio = 16;

  static const List<BoxShadow> sombraSuave = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Tarjeta estándar: fondo blanco, borde fino y sombra muy sutil.
  static BoxDecoration tarjeta({Color? color, double radio = 18}) =>
      BoxDecoration(
        color: color ?? superficie,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde),
        boxShadow: sombraSuave,
      );

  static ThemeData get tema {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: fondo,
      fontFamily: GoogleFontsLite.getFont('Inter').fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: verdeDeportivo,
        brightness: Brightness.light,
        primary: verdeDeportivo,
        secondary: azulDeportivo,
        surface: superficie,
        error: rojoAlerta,
      ),
    );

    OutlineInputBorder bordeCampo(Color color, [double ancho = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: ancho),
        );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFontsLite.getFont(
          'Plus Jakarta Sans',
          color: textoPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: textoPrincipal),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: textoSecundario,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIconColor: textoSecundario,
        suffixIconColor: textoSecundario,
        border: bordeCampo(borde),
        enabledBorder: bordeCampo(borde),
        focusedBorder: bordeCampo(verdeDeportivo, 1.8),
        errorBorder: bordeCampo(rojoAlerta),
        focusedErrorBorder: bordeCampo(rojoAlerta, 1.8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: verdeDeportivo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBBF7D0),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFontsLite.getFont(
            'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textoPrincipal,
          backgroundColor: superficie,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: borde, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFontsLite.getFont(
            'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: verdeOscuro,
          textStyle: GoogleFontsLite.getFont(
            'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textoPrincipal,
        contentTextStyle: GoogleFontsLite.getFont(
          'Inter',
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: verdeSuave,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => GoogleFontsLite.getFont(
            'Inter',
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: estados.contains(WidgetState.selected)
                ? verdeOscuro
                : textoSecundario,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected)
                ? verdeOscuro
                : textoSecundario,
          ),
        ),
      ),
    );
  }

  /// Fuente para títulos y números destacados.
  static TextStyle titulo({
    double tamano = 24,
    Color color = textoPrincipal,
    FontWeight peso = FontWeight.w800,
  }) => GoogleFontsLite.getFont(
    'Plus Jakarta Sans',
    fontSize: tamano,
    fontWeight: peso,
    color: color,
    letterSpacing: -0.4,
    height: 1.2,
  );
}
