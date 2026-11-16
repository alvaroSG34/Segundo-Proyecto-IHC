import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/analitica/vista_analitica.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/partidos/vista_historial.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';

import 'package:unisport/servicios/partidos/controlador_explorar.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

/// Pruebas de navegación pública y acceso a Explorar.
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
  late ControladorExplorar controladorExplorar;
  setUp(() {
    controladorExplorar = ControladorExplorar();
  });

  for (final explorar in [false, true]) {
    testWidgets(
      'inscritos consultan su partido en ${explorar ? 'Explorar' : 'Mis partidos'}',
      (tester) async {
        final auth = conPartidoDeLorgio();
        await auth.iniciarSesion('diego@unisport.edu', '123456');
        await auth.repositorio.unirseAPartido('p-1');
        auth.repositorio.usarSesionDe('u-ana', 'Ana');
        await auth.repositorio.unirseAPartido('p-1');
        await auth.iniciarSesion('diego@unisport.edu', '123456');

        await tester.pumpWidget(
          MaterialApp(
            home: explorar
                ? VistaExplorarPartidos(
                    repositorioPartidos: auth.repositorio,
                    controladorExplorar: controladorExplorar,
                    servicioAuth: auth,
                  )
                : VistaMisPartidos(
                    repositorioPartidos: auth.repositorio,
                    controladorExplorar: controladorExplorar,
                    servicioAuth: auth,
                  ),
          ),
        );
        await tester.pumpAndSettle();

        if (!explorar) {
          await tester.tap(find.bySemanticsLabel('Como jugador'));
          await tester.pumpAndSettle();
        }
        expect(find.textContaining('Ver jugadores inscritos'), findsNothing);
        expect(find.textContaining('3/10'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets(
    'la portada pública no muestra barra y conserva acceso y registro',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VistaInicioPublico(servicioAuth: ServicioAutenticacionFalso()),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Crear nueva cuenta'), findsOneWidget);
    },
  );

  testWidgets(
    'con sesión, el menú abre Explorar con los partidos de otros estudiantes',
    (tester) async {
      final auth = conPartidoDeLorgio();
      await auth.iniciarSesion('diego@unisport.edu', '123456');
      await tester.pumpWidget(
        MaterialApp(
          home: VistaPrincipal(
            servicioAuth: auth,
            repositorioPartidos: auth.repositorio,
          ),
        ),
      );

      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();

      expect(find.text('Explorar partidos'), findsOneWidget);
      expect(find.text('Futsal 5 vs 5 nocturno'), findsOneWidget);
      expect(find.text('Unirme al equipo'), findsOneWidget);
    },
  );

  testWidgets('el menú muestra iconos y conserva sus accesos en móvil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = conPartidoDeLorgio();
    await auth.iniciarSesion('diego@unisport.edu', '123456');

    await tester.pumpWidget(
      MaterialApp(
        home: VistaPrincipal(
          servicioAuth: auth,
          repositorioPartidos: auth.repositorio,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(find.byIcon(LucideIcons.compass), findsOneWidget);
    expect(find.byIcon(LucideIcons.history), findsOneWidget);
    expect(find.byIcon(LucideIcons.barChart3), findsOneWidget);
    for (final icono in [
      LucideIcons.plus,
      LucideIcons.calendarDays,
      LucideIcons.compass,
      LucideIcons.history,
      LucideIcons.barChart3,
    ]) {
      expect(tester.widget<Icon>(find.byIcon(icono)).color, Colors.white);
    }
    for (final etiqueta in [
      'Crear\nPartido',
      'Mis\nPartidos',
      'Explorar',
      'Historial',
      'Analítica',
    ]) {
      expect(
        tester.widget<Text>(find.text(etiqueta)).style!.color,
        Colors.white,
      );
    }
    final botonAnalitica = find.ancestor(
      of: find.text('Analítica'),
      matching: find.byType(ElevatedButton),
    );
    expect(tester.getSize(botonAnalitica).height, 56);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpAndSettle();

    Future<void> comprobarAcceso(String etiqueta, Type pantalla) async {
      final opcion = find.text(etiqueta);
      await tester.ensureVisible(opcion);
      await tester.tap(opcion);
      await tester.pumpAndSettle();
      expect(find.byType(pantalla), findsOneWidget);
      Navigator.of(tester.element(find.byType(pantalla))).pop();
      await tester.pumpAndSettle();
    }

    await comprobarAcceso('Crear\nPartido', VistaCrearPartido);
    await comprobarAcceso('Mis\nPartidos', VistaMisPartidos);
    await comprobarAcceso('Explorar', VistaExplorarPartidos);
    await comprobarAcceso('Historial', VistaHistorial);
    await comprobarAcceso('Analítica', VistaAnalitica);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desde Mis partidos, la pestaña Explorar también está visible', (
    tester,
  ) async {
    final auth = conPartidoDeLorgio();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(
        home: VistaMisPartidos(
          repositorioPartidos: auth.repositorio,
          controladorExplorar: controladorExplorar,
          servicioAuth: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Explorar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explorar partidos'), findsOneWidget);
    expect(find.text('Futsal 5 vs 5 nocturno'), findsOneWidget);
  });
}
