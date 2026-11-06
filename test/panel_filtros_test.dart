import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/widgets/panel_filtros.dart';

/// Pruebas de la interfaz de búsqueda y filtros (Issues #10 y #11, requisito #6).
///
/// Ejecutar con:  flutter test test/panel_filtros_test.dart
void main() {
  late FiltroPartidos? ultimo;

  Future<void> mostrarPanel(WidgetTester tester, FiltroPartidos filtro) {
    ultimo = null;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PanelFiltros(
              filtro: filtro,
              lugares: FiltroPartidos.lugaresSugeridos,
              alCambiar: (nuevo) => ultimo = nuevo,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sin filtros no muestra la sección de filtros activos', (
    tester,
  ) async {
    await mostrarPanel(tester, const FiltroPartidos());

    expect(find.text('Filtros activos'), findsNothing);
    expect(find.text('Deporte'), findsNothing);
    expect(find.text('Con cupos'), findsNothing);
    await tester.tap(find.byKey(const Key('explorar_mostrar_filtros')));
    await tester.pumpAndSettle();
    expect(find.text('Deporte'), findsOneWidget);
    expect(find.text('Con cupos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('explorar_mostrar_filtros')));
    await tester.pumpAndSettle();
    expect(find.text('Deporte'), findsNothing);
    expect(ultimo, isNull);
  });

  testWidgets('muestra qué filtros están activos', (tester) async {
    await mostrarPanel(
      tester,
      const FiltroPartidos(
        texto: 'futsal',
        deporte: 'Futsal',
        fecha: FiltroFecha.proximos7Dias,
        lugar: 'Coliseo Campus',
        soloConCupos: true,
      ),
    );

    expect(find.text('Filtros activos'), findsOneWidget);
    expect(find.text('Nombre: "futsal"'), findsOneWidget);
    expect(find.text('Deporte: Futsal'), findsOneWidget);
    expect(find.text('Fecha: Próximos 7 días'), findsOneWidget);
    expect(find.text('Lugar: Coliseo Campus'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Con cupos'), findsOneWidget);
  });

  testWidgets('quitar un filtro activo conserva los demás', (tester) async {
    await mostrarPanel(
      tester,
      const FiltroPartidos(deporte: 'Futsal', soloConCupos: true),
    );

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Deporte: Futsal'),
        matching: find.byIcon(LucideIcons.x),
      ),
    );

    expect(ultimo, isNotNull);
    expect(ultimo!.deporte, isNull);
    expect(ultimo!.soloConCupos, isTrue);
  });

  testWidgets('"Limpiar todo" quita todos los filtros', (tester) async {
    await mostrarPanel(
      tester,
      const FiltroPartidos(texto: 'vóley', lugar: 'Estadio Módulo'),
    );

    await tester.tap(find.text('Limpiar todo'));

    expect(ultimo!.estaActivo, isFalse);
  });

  testWidgets('escribir en la búsqueda filtra por nombre', (tester) async {
    await mostrarPanel(tester, const FiltroPartidos());

    await tester.enterText(find.byType(TextField), 'básquet');

    expect(ultimo!.texto, 'básquet');
  });

  testWidgets('el botón "Con cupos" activa ese filtro', (tester) async {
    await mostrarPanel(tester, const FiltroPartidos());

    await tester.tap(find.byKey(const Key('explorar_mostrar_filtros')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Con cupos'));

    expect(ultimo!.soloConCupos, isTrue);
  });

  testWidgets('elegir un deporte en la lista lo aplica', (tester) async {
    await mostrarPanel(tester, const FiltroPartidos());

    await tester.tap(find.byKey(const Key('explorar_mostrar_filtros')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deporte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voleibol'));
    await tester.pumpAndSettle();

    expect(ultimo!.deporte, 'Voleibol');
  });

  testWidgets('en vencidos, Con cupos está deshabilitado', (tester) async {
    await mostrarPanel(
      tester,
      const FiltroPartidos(periodo: PeriodoPartidos.vencidos),
    );
    await tester.tap(find.byKey(const Key('explorar_mostrar_filtros')));
    await tester.pumpAndSettle();
    expect(find.text('Disponible solo en partidos próximos'), findsOneWidget);
    final semantica = tester.widget<Semantics>(
      find.descendant(
        of: find.byKey(const Key('explorar_con_cupos')),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Con cupos',
        ),
      ),
    );
    expect(semantica.properties.enabled, isFalse);
    await tester.tap(find.text('Con cupos'));
    expect(ultimo, isNull);
  });

  testWidgets('limpiar conserva la categoría y cerrar conserva las etiquetas', (
    tester,
  ) async {
    await mostrarPanel(
      tester,
      const FiltroPartidos(
        periodo: PeriodoPartidos.vencidos,
        deporte: 'Futsal',
        texto: 'nocturno',
      ),
    );
    final boton = find.byKey(const Key('explorar_mostrar_filtros'));
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.text('Deporte: Futsal'), findsOneWidget);
    expect(find.text('Nombre: "nocturno"'), findsOneWidget);
    expect(find.byKey(const Key('explorar_deporte')), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'nocturno',
    );
    await tester.tap(find.text('Limpiar todo'));
    expect(ultimo!.estaActivo, isFalse);
    expect(ultimo!.periodo, PeriodoPartidos.vencidos);
  });

  testWidgets(
    'sin resultados muestra un mensaje claro y permite quitar filtros',
    (tester) async {
      var quitados = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MensajeSinResultados(alQuitarFiltros: () => quitados = true),
          ),
        ),
      );

      expect(
        find.text('Ningún partido coincide con tu búsqueda'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quitar filtros'));
      expect(quitados, isTrue);
    },
  );
}
