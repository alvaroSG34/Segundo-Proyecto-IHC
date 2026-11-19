import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unisport/tema/tema_app.dart';

/// WCAG 2.2: contraste de colores sRGB del Design System.
double _luminancia(Color color) {
  final argb = color.toARGB32();
  // Exponente 2.4 de WCAG 2.2.
  double canalWcag(int shift) {
    final value = ((argb >> shift) & 0xFF) / 255.0;
    return value <= 0.04045
        ? value / 12.92
        : _pow24((value + 0.055) / 1.055);
  }

  return 0.2126 * canalWcag(16) +
      0.7152 * canalWcag(8) +
      0.0722 * canalWcag(0);
}

double _pow24(double value) {
  // Preferencia explícita por dart:math.pow para la curva WCAG.
  return math.pow(value, 2.4).toDouble();
}

double _contraste(Color a, Color b) {
  final x = _luminancia(a);
  final y = _luminancia(b);
  final claro = x > y ? x : y;
  final oscuro = x > y ? y : x;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  test('tokens principales coinciden con el modo Claro de Figma', () {
    expect(TemaApp.verdeDeportivo, const Color(0xFF15803D));
    expect(TemaApp.azulDeportivo, const Color(0xFF0369A1));
    expect(TemaApp.naranjaAviso, const Color(0xFFC2410C));
    expect(TemaApp.textoSecundario, const Color(0xFF475569));
    expect(TemaApp.rojoAlerta, const Color(0xFFB91C1C));
    expect(TemaApp.bordeControlAa, const Color(0xFF7D8EA3));
  });

  test('texto normal cumple 4.5:1', () {
    expect(_contraste(Colors.white, TemaApp.verdeDeportivo), greaterThanOrEqualTo(4.5));
    expect(_contraste(Colors.white, TemaApp.rojoAlerta), greaterThanOrEqualTo(4.5));
    expect(_contraste(TemaApp.textoSecundario, TemaApp.fondo), greaterThanOrEqualTo(4.5));
    expect(_contraste(TemaApp.textoPrincipal, const Color(0xFF26C99A)), greaterThanOrEqualTo(4.5));
    expect(_contraste(TemaApp.textoPrincipal, const Color(0xFFF59E0B)), greaterThanOrEqualTo(4.5));
  });

  test('contornos funcionales cumplen 3:1', () {
    expect(_contraste(TemaApp.bordeControlAa, Colors.white), greaterThanOrEqualTo(3));
    expect(_contraste(TemaApp.bordeControlAa, TemaApp.fondo), greaterThanOrEqualTo(3));
  });

  test('el tema Flutter aplica los tokens accesibles', () {
    final tema = TemaApp.tema;
    expect(tema.colorScheme.primary, TemaApp.verdeDeportivo);
    expect(tema.colorScheme.secondary, TemaApp.azulDeportivo);
    expect(tema.colorScheme.error, TemaApp.rojoAlerta);
    expect(tema.inputDecorationTheme.enabledBorder!.borderSide.color, TemaApp.bordeControlAa);
  });
}
