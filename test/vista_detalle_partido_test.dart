import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/propuesta_equipos.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_detalle_partido.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

void main() {
  testWidgets(
    'Explorar abre el detalle y conserva el acceso rápido para unirse',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = ServicioAutenticacionFalso();
      auth.repositorio.sembrar(
        'organizador',
        ModeloPartido(
          id: 'detalle-1',
          titulo: 'Partido de prueba',
          disciplina: 'Fútbol',
          icono: 'Fútbol',
          ubicacion: 'Cancha central',
          fechaHora: '10/10/2099 · 19:00',
          cuposTotales: 10,
          cuposOcupados: 2,
          organizadorNombre: 'Organizador',
        ),
      );
      await auth.iniciarSesion('diego@unisport.edu', '123456');
      await tester.pumpWidget(
        MaterialApp(
          home: VistaExplorarPartidos(
            servicioAuth: auth,
            repositorioPartidos: auth.repositorio,
            controladorExplorar: ControladorExplorar(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unirme al equipo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('partido_ver_detalle')));
      await tester.pumpAndSettle();

      expect(find.byType(VistaDetallePartido), findsOneWidget);
      expect(find.text('Detalles del partido'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('detalle_encabezado'))).width,
        lessThanOrEqualTo(480),
      );
      expect(
        tester.getSize(find.byKey(const Key('detalle_contenido'))).width,
        lessThanOrEqualTo(480),
      );
      expect(find.text('Partido de prueba'), findsOneWidget);
      expect(find.text('Unirme al partido'), findsOneWidget);
      expect(find.text('Participantes (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detalle conserva sus secciones contraídas inicialmente', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    final partido = ModeloPartido(
      id: 'detalle-2',
      titulo: 'Partido móvil',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Coliseo',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 10,
      cuposOcupados: 2,
      organizadorNombre: 'Organizador',
      estoyUnido: true,
    );
    auth.repositorio.sembrar('organizador', partido);
    await auth.repositorio.unirseAPartido('detalle-2');
    await tester.pumpWidget(
      MaterialApp(
        home: VistaDetallePartido(
          partido: (await auth.repositorio.obtenerPartidosUnidos()).single,
          repositorio: auth.repositorio,
          usuarioId: auth.usuarioActual!.id,
          onSalir: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Participantes (3)'), findsOneWidget);
    expect(find.text('Organizador'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Salir del partido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra carga y bloquea el botón mientras cancela la espera', (
    tester,
  ) async {
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    final accionPendiente = Completer<void>();
    final partido = ModeloPartido(
      id: 'espera-detalle',
      titulo: 'Partido en espera',
      disciplina: 'Básquetbol',
      icono: 'Básquetbol',
      ubicacion: 'Cancha',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 2,
      cuposOcupados: 2,
      organizadorNombre: 'Organizador',
      posicionEspera: 1,
    );
    auth.repositorio.sembrar('organizador', partido);

    await tester.pumpWidget(
      MaterialApp(
        home: VistaDetallePartido(
          partido: partido,
          repositorio: auth.repositorio,
          usuarioId: auth.usuarioActual!.id,
          onSalirDeEspera: () => accionPendiente.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar espera'));
    await tester.pump();
    expect(find.text('Procesando…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    accionPendiente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cancelar espera'), findsOneWidget);
  });

  testWidgets(
    'el capitán rival abre la respuesta de propuesta desde el detalle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = ServicioAutenticacionFalso();
      final repo = auth.repositorio;
      repo.sembrar(
        'u-lorgio',
        ModeloPartido(
          id: 'propuesta-detalle',
          titulo: 'Final de prueba',
          disciplina: 'Fútbol',
          icono: 'Fútbol',
          ubicacion: 'Cancha central',
          fechaHora: '10/10/2099 · 19:00',
          cuposTotales: 2,
          cuposOcupados: 1,
          organizadorNombre: 'Lorgio',
        ),
      );
      repo.usarSesionDe('u-diego', 'Diego');
      await repo.unirseAPartido('propuesta-detalle');
      repo.usarSesionDe('u-lorgio', 'Lorgio');
      await repo.guardarPropuesta(
        'propuesta-detalle',
        PropuestaEquipos(
          revision: '',
          equipoA: const ['u-lorgio'],
          equipoB: const ['u-diego'],
          capitanRivalId: 'u-diego',
        ),
      );
      repo.usarSesionDe('u-diego', 'Diego');
      await auth.iniciarSesion('diego@unisport.edu', '123456');
      final partido = (await repo.obtenerPartidosUnidos()).single;
      await tester.pumpWidget(
        MaterialApp(
          home: VistaDetallePartido(
            partido: partido,
            repositorio: repo,
            usuarioId: 'u-diego',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Responder propuesta'), findsOneWidget);
      await tester.tap(find.text('Responder propuesta'));
      await tester.pumpAndSettle();
      expect(find.byType(VistaEquipos), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
    },
  );
}
