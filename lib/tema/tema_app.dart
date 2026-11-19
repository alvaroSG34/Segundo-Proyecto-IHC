import 'package:material_ui/material_ui.dart';

/// Tema visual de UniSport: modo claro, superficies limpias, verde deportivo
/// como color de acción y cian como acento informativo.
class TemaApp {
  static const String fuenteTipografica = 'Inter';

  // Base
  static const Color fondo = Color(0xFFF6F8FB);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieSuave = Color(0xFFF1F5F9);
  static const Color textoPrincipal = Color(0xFF0F172A);
  static const Color textoSecundario = Color(0xFF475569);
  static const Color borde = Color(0xFFE2E8F0);
  // WCAG 2.2 AA: bordes necesarios para identificar controles (>= 3:1).
  // Equivalente al token de Figma `border-control-aa`.
  static const Color bordeControlAa = Color(0xFF7D8EA3);

  // Marca y acentos
  static const Color verdeDeportivo = Color(0xFF15803D);
  static const Color verdeOscuro = Color(0xFF15803D);
  static const Color verdeSuave = Color(0xFFDCFCE7);
  static const Color azulDeportivo = Color(
    0xFF0369A1,
  ); // cian/azul para enlaces e info
  static const Color azulSuave = Color(0xFFE0F2FE);
  static const Color naranjaAviso = Color(0xFFC2410C);
  static const Color naranjaSuave = Color(0xFFFFEDD5);
  static const Color rojoAlerta = Color(0xFFB91C1C);
  static const Color rojoSuave = Color(0xFFFEE2E2);
  static const Color amarilloSuave = Color(0xFFFEF9C3);
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
      fontFamily: fuenteTipografica,
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
        titleTextStyle: const TextStyle(
          fontFamily: fuenteTipografica,
          color: textoPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
        hintStyle: const TextStyle(color: textoSecundario),
        prefixIconColor: textoSecundario,
        suffixIconColor: textoSecundario,
        border: bordeCampo(bordeControlAa),
        enabledBorder: bordeCampo(bordeControlAa),
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
          textStyle: const TextStyle(
            fontFamily: fuenteTipografica,
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
          side: const BorderSide(color: bordeControlAa, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fuenteTipografica,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: verdeOscuro,
          textStyle: const TextStyle(
            fontFamily: fuenteTipografica,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textoPrincipal,
        contentTextStyle: const TextStyle(
          fontFamily: fuenteTipografica,
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
          (estados) => TextStyle(
            fontFamily: fuenteTipografica,
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
    FontWeight peso = FontWeight.w700,
  }) => TextStyle(
    fontFamily: fuenteTipografica,
    fontSize: tamano,
    fontWeight: peso,
    color: color,
    letterSpacing: -0.4,
    height: 1.2,
  );
}
