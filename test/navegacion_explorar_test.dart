import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

/// Clase 15 · Hallazgo #1 (H6 Reconocimiento): "Explorar" debe estar visible
/// en la navegación principal para encontrar partidos de otros estudiantes.
///
/// Ejecutar con:  flutter test test/navegacion_explorar_test.dart
ServicioAutenticacionFalso conPartidoDeLorgio() {
  final auth = ServicioAutenticacionFalso();
  auth.repositorio.sembrar(
    'u-lorgio',
    ModeloPartido(
      id: 'p-1',
      titulo: 'Futsal 5 vs 5 nocturno',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Cancha Campus',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 10,
      cuposOcupados: 1,
      organizadorNombre: 'Lorgio',
    ),
  );
  return auth;
}

void main() {
  for (final explorar in [false, true]) {
    testWidgets('inscritos ven a sus compañeros en ${explorar ? 'Explorar' : 'Mis partidos'}', (tester) async {
      final auth = conPartidoDeLorgio();
      await auth.iniciarSesion('diego@unisport.edu', '123456');
      await auth.partidos.unirseAPartido('p-1');
      auth.repositorio.usarSesionDe('u-ana', 'Ana');
      await auth.partidos.unirseAPartido('p-1');
      await auth.iniciarSesion('diego@unisport.edu', '123456');

      await tester.pumpWidget(MaterialApp(
        home: explorar
            ? VistaExplorarPartidos(servicioAuth: auth)
            : VistaMisPartidos(servicioAuth: auth),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver jugadores inscritos (2)'));
      await tester.tap(find.text('Ver jugadores inscritos (2)'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Diego')), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Ana')), findsOneWidget);
    });
  }

  testWidgets('la portada muestra la pestaña Explorar en la barra inferior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VistaInicioPublico(servicioAuth: ServicioAutenticacionFalso()),
      ),
    );

    final barra = find.byType(NavigationBar);
    expect(
      find.descendant(of: barra, matching: find.text('Explorar')),
      findsOneWidget,
    );
  });

  testWidgets('con sesión, Explorar abre los partidos de otros estudiantes', (
    tester,
  ) async {
    final auth = conPartidoDeLorgio();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(home: VistaInicioPublico(servicioAuth: auth)),
    );

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();

    expect(find.text('Explorar partidos'), findsOneWidget);
    expect(find.text('Futsal 5 vs 5 nocturno'), findsOneWidget);
    expect(find.text('Unirme al equipo'), findsOneWidget);
  });

  testWidgets('sin sesión, Explorar lleva al login y explica el motivo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VistaInicioPublico(servicioAuth: ServicioAutenticacionFalso()),
      ),
    );

    await tester.tap(find.text('Explorar'));
    // El login tiene un cursor que parpadea sin fin: se avanza un tiempo fijo
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Inicia sesión para explorar partidos.'), findsOneWidget);
  });

  testWidgets('desde Mis partidos, la pestaña Explorar también está visible', (
    tester,
  ) async {
    final auth = conPartidoDeLorgio();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(home: VistaMisPartidos(servicioAuth: auth)),
    );
    await tester.pumpAndSettle();

    final barra = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: barra, matching: find.text('Explorar')));
    await tester.pumpAndSettle();

    expect(find.text('Explorar partidos'), findsOneWidget);
    expect(find.text('Futsal 5 vs 5 nocturno'), findsOneWidget);
  });
}
