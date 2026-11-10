import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
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

        expect(find.textContaining('Ver jugadores inscritos'), findsNothing);
        expect(find.text('3/10'), findsOneWidget);
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
