import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/vista_explorar_partidos.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

/// Prueba de punta a punta del requisito #6 con la pantalla real:
/// interfaz (Explorar) -> repositorio (buscarPartidos) -> datos de otro usuario.
///
/// Ejecutar con:  flutter test test/explorar_filtros_test.dart
/// (Los avisos de google_fonts en consola son normales: la prueba no descarga
/// la tipografía de internet; no afectan el resultado.)
ModeloPartido partido(String id, String titulo, String disciplina) {
  return ModeloPartido(
    id: id,
    titulo: titulo,
    disciplina: disciplina,
    icono: disciplina,
    ubicacion: 'Coliseo Campus',
    fechaHora: '10/10/2099 · 19:00',
    cuposTotales: 10,
    cuposOcupados: 2,
    organizadorNombre: 'Lorgio',
  );
}

void main() {
  testWidgets('filtrar desde la pantalla consulta los partidos de otros', (
    tester,
  ) async {
    final auth = ServicioAutenticacionFalso();
    // Partidos que organizó Lorgio
    auth.repositorio
      ..sembrar('u-lorgio', partido('a', 'Futsal nocturno', 'Futsal'))
      ..sembrar('u-lorgio', partido('b', 'Vóley mixto', 'Voleibol'));
    // Diego abre la app y explora
    await auth.iniciarSesion('diego@unisport.edu', '123456');

    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();

    expect(find.text('2 partidos encontrados'), findsOneWidget);
    expect(find.text('Organiza: Lorgio'), findsNWidgets(2));

    // Búsqueda con resultados
    await tester.enterText(find.byType(TextField), 'vóley');
    await tester.pump();
    expect(find.text('1 partido encontrado'), findsOneWidget);
    expect(find.text('Vóley mixto'), findsOneWidget);
    expect(find.text('Futsal nocturno'), findsNothing);

    // Búsqueda sin resultados: mensaje claro en lugar de lista vacía
    await tester.enterText(find.byType(TextField), 'rugby');
    await tester.pump();
    expect(
      find.text('Ningún partido coincide con tu búsqueda'),
      findsOneWidget,
    );

    // Quitar filtros vuelve a mostrar todo
    await tester.tap(find.text('Quitar filtros'));
    await tester.pump();
    expect(find.text('2 partidos encontrados'), findsOneWidget);
  });

  testWidgets('unirse desde la pantalla actualiza los cupos', (tester) async {
    final auth = ServicioAutenticacionFalso();
    auth.repositorio.sembrar(
      'u-lorgio',
      partido('a', 'Futsal nocturno', 'Futsal'),
    );
    await auth.iniciarSesion('diego@unisport.edu', '123456');

    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();

    await tester.tap(find.text('Unirme al equipo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Unirte al equipo?'), findsOneWidget);
    await tester.tap(find.text('Sí, unirme'));
    await tester.pump();

    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Ya formas parte de este equipo.'), findsOneWidget);
    expect(find.text('Se unieron (1): Diego'), findsOneWidget);
    expect(find.text('Unirme al equipo'), findsNothing);
  });

  testWidgets('H3: cancelar la confirmación no ocupa ningún cupo', (tester) async {
    final auth = ServicioAutenticacionFalso();
    auth.repositorio.sembrar('u-lorgio', partido('a', 'Futsal nocturno', 'Futsal'));
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();

    await tester.tap(find.text('Unirme al equipo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('Unirme al equipo'), findsOneWidget);
  });

  testWidgets('H7: el filtro se conserva al salir y volver a Explorar', (tester) async {
    final auth = ServicioAutenticacionFalso();
    auth.repositorio.sembrar('u-lorgio', partido('a', 'Futsal nocturno', 'Futsal'));
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'futsal');
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();

    expect(find.text('Nombre: "futsal"'), findsOneWidget);
  });

  testWidgets('H3: tras unirse se puede salir del partido y el cupo se libera', (
    tester,
  ) async {
    final auth = ServicioAutenticacionFalso();
    auth.repositorio.sembrar('u-lorgio', partido('a', 'Futsal nocturno', 'Futsal'));
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(home: VistaExplorarPartidos(servicioAuth: auth)),
    );
    await tester.pump();

    await tester.tap(find.text('Unirme al equipo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, unirme'));
    await tester.pumpAndSettle();
    expect(find.text('3/10'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salir del partido'));
    await tester.tap(find.text('Salir del partido'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir del partido?'), findsOneWidget);
    await tester.tap(find.text('Sí, salir'));
    await tester.pumpAndSettle();

    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('Unirme al equipo'), findsOneWidget);
    expect(find.textContaining('Se unieron'), findsNothing);
  });
}
