import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/analitica/vista_analitica.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

class _EventoCapturado {
  final String nombre;
  final Map<String, dynamic> props;

  const _EventoCapturado(this.nombre, this.props);
}

class _AnaliticaFalsa implements ServicioAnalitica {
  final List<_EventoCapturado> eventos = [];
  List<EventoAnalitica> eventosConsulta;
  bool fallarTrack;
  bool fallarConsulta;

  _AnaliticaFalsa({
    this.eventosConsulta = const [],
    this.fallarTrack = false,
    this.fallarConsulta = false,
  });

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    if (fallarTrack) throw StateError('Analítica no disponible');
    eventos.add(_EventoCapturado(evento, Map.of(props)));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async {
    if (fallarConsulta) throw StateError('Analítica no disponible');
    return eventosConsulta;
  }
}

ModeloPartido _partido() => ModeloPartido(
  id: 'partido-1',
  titulo: 'Futsal nocturno',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Coliseo Campus',
  fechaHora: '10/10/2099 · 19:00',
  cuposTotales: 10,
  cuposOcupados: 2,
  organizadorNombre: 'Lorgio',
);

Future<ServicioAutenticacionFalso> _mostrarExplorar(
  WidgetTester tester,
  ServicioAnalitica analitica, {
  ModeloPartido? partido,
}) async {
  final auth = ServicioAutenticacionFalso();
  auth.repositorio.sembrar('u-lorgio', partido ?? _partido());
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await tester.pumpWidget(
    MaterialApp(
      home: VistaExplorarPartidos(
        repositorioPartidos: auth.repositorio,
        servicioAnalitica: analitica,
        controladorExplorar: ControladorExplorar(),
        servicioAuth: auth,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  _pruebasEmbudo();
  group('tracking del flujo de union', () {
    testWidgets(
      'el primer boton registra inicio y cancelar no registra exito',
      (tester) async {
        final analitica = _AnaliticaFalsa();
        await _mostrarExplorar(tester, analitica);

        await tester.tap(find.text('Unirme al equipo'));
        await tester.pumpAndSettle();

        expect(analitica.eventos, hasLength(1));
        expect(analitica.eventos.single.nombre, EventosAnalitica.unionIniciada);
        expect(analitica.eventos.single.props, {
          'partido_id': 'partido-1',
          'intento_id': analitica.eventos.single.props['intento_id'],
        });

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(analitica.eventos, hasLength(1));
      },
    );

    testWidgets('una union exitosa registra inicio y final en orden', (
      tester,
    ) async {
      final analitica = _AnaliticaFalsa();
      await _mostrarExplorar(tester, analitica);

      await tester.tap(find.text('Unirme al equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, unirme'));
      await tester.pumpAndSettle();

      expect(analitica.eventos.map((evento) => evento.nombre), [
        EventosAnalitica.unionIniciada,
        EventosAnalitica.partidoUnido,
      ]);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('Unirme al equipo'), findsNothing);
    });

    testWidgets('un fallo de tracking no impide unirse', (tester) async {
      final analitica = _AnaliticaFalsa(fallarTrack: true);
      await _mostrarExplorar(tester, analitica);

      await tester.tap(find.text('Unirme al equipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, unirme'));
      await tester.pumpAndSettle();

      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('Unirme al equipo'), findsNothing);
    });

    testWidgets('un rechazo del servidor no registra el evento final', (
      tester,
    ) async {
      final analitica = _AnaliticaFalsa();
      final auth = await _mostrarExplorar(
        tester,
        analitica,
        partido: _partido().copyWith(cuposTotales: 3),
      );

      await tester.tap(find.text('Unirme al equipo'));
      await tester.pumpAndSettle();

      // Otro jugador ocupa el ultimo cupo mientras el dialogo sigue abierto.
      auth.repositorio.usarSesionDe('u-tercero', 'Tercero');
      await auth.repositorio.unirseAPartido('partido-1');
      auth.repositorio.usarSesionDe('u-diego', 'Diego');

      await tester.tap(find.text('Sí, unirme'));
      await tester.pumpAndSettle();

      expect(analitica.eventos.map((e) => e.nombre), [
        EventosAnalitica.unionIniciada,
        EventosAnalitica.unionFallida,
      ]);
      expect(find.textContaining('No puedes unirte.'), findsOneWidget);
    });
  });

  group('panel de analitica', () {
    testWidgets('muestra evento, props y fecha en una tabla', (tester) async {
      final analitica = _AnaliticaFalsa(
        eventosConsulta: [
          EventoAnalitica(
            evento: EventosAnalitica.unionIniciada,
            props: const {'partido_id': 'partido-1'},
            fecha: DateTime(2026, 11, 10, 16, 5),
          ),
          EventoAnalitica(
            evento: EventosAnalitica.partidoUnido,
            props: const {'partido_id': 'partido-1'},
            fecha: DateTime(2026, 11, 10, 16, 9),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: VistaAnalitica(servicioAnalitica: analitica)),
      );
      await tester.pumpAndSettle();

      await _seleccionarFlujo(tester, 'Unirse');
      await tester.scrollUntilVisible(
        find.byType(DataTable),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('evento'), findsOneWidget);
      expect(find.text('props'), findsOneWidget);
      expect(find.text('fecha'), findsOneWidget);
      expect(find.text(EventosAnalitica.unionIniciada), findsOneWidget);
      expect(find.text(EventosAnalitica.partidoUnido), findsOneWidget);
      expect(find.text('{"partido_id":"partido-1"}'), findsNWidgets(2));
      expect(find.text('2026-11-10 16:05'), findsOneWidget);
      expect(find.text('2026-11-10 16:09'), findsOneWidget);
    });

    testWidgets('muestra el estado vacio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: VistaAnalitica(servicioAnalitica: _AnaliticaFalsa())),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay eventos registrados.'), findsOneWidget);
    });

    testWidgets('permite reintentar despues de un error', (tester) async {
      final analitica = _AnaliticaFalsa(fallarConsulta: true);
      await tester.pumpWidget(
        MaterialApp(home: VistaAnalitica(servicioAnalitica: analitica)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analítica no disponible'), findsOneWidget);
      analitica
        ..fallarConsulta = false
        ..eventosConsulta = [
          EventoAnalitica(
            evento: EventosAnalitica.unionIniciada,
            props: const {'partido_id': 'partido-1'},
            fecha: DateTime(2026, 11, 10, 16, 5),
          ),
        ];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      await _seleccionarFlujo(tester, 'Unirse');
      await tester.scrollUntilVisible(
        find.byType(DataTable),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(EventosAnalitica.unionIniciada), findsOneWidget);
    });
  });
}

void _pruebasEmbudo() {
  EventoAnalitica evento(String nombre, String id, [String? codigo]) =>
      EventoAnalitica(
        evento: nombre,
        props: {'intento_id': id, 'codigo_error': ?codigo},
        fecha: DateTime(2026, 11, 11),
      );

  Future<void> mostrar(
    WidgetTester tester,
    List<EventoAnalitica> eventos,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: VistaAnalitica(
          servicioAnalitica: _AnaliticaFalsa(eventosConsulta: eventos),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'embudo deduplica, ignora finales huerfanos y conserva errores tras exito',
    (tester) async {
      await mostrar(tester, [
        evento('creacion_iniciada', 'a'),
        evento('creacion_iniciada', 'a'),
        evento('creacion_iniciada', 'b'),
        evento('creacion_iniciada', 'c'),
        evento('partido_creado', 'a'),
        evento('partido_creado', 'a'),
        evento('partido_creado', 'historico'),
        evento('creacion_fallida', 'a', 'regla_negocio'),
        evento('creacion_fallida', 'b', 'regla_negocio'),
        evento('creacion_fallida', 'b', 'regla_negocio'),
      ]);
      expect(find.text('Inicios: 3'), findsOneWidget);
      expect(find.text('Finalizados: 1'), findsOneWidget);
      expect(find.text('Finalización: 33.3%'), findsOneWidget);
      expect(find.text('Sin finalizar: 2'), findsOneWidget);
      expect(find.text('Intentos con error: 2'), findsOneWidget);
      expect(find.text('regla_negocio: 2'), findsOneWidget);
      expect(
        tester
            .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .map((w) => w.value),
        [1.0, 1 / 3],
      );
    },
  );

  testWidgets(
    'sin inicios no inventa una tasa ni usa eventos historicos sin ID',
    (tester) async {
      await mostrar(tester, [
        evento('partido_creado', 'solo-final'),
        EventoAnalitica(
          evento: 'creacion_iniciada',
          props: const {},
          fecha: DateTime(2026),
        ),
      ]);
      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.text('Inicios: 0'), findsOneWidget);
      expect(find.text('Finalizados: 0'), findsOneWidget);
    },
  );

  testWidgets(
    'selector cubre las 14 acciones y cuenta decisiones como finalizaciones',
    (tester) async {
      const acciones = {
        'Unirse': ['union_iniciada', 'partido_unido'],
        'Crear partido': ['creacion_iniciada', 'partido_creado'],
        'Buscar': [
          'busqueda_iniciada',
          'busqueda_realizada',
          'busqueda_sin_resultados',
        ],
        'Registrarse': ['registro_iniciado', 'registro_completado'],
        'Iniciar sesión': ['login_iniciado', 'login_exitoso'],
        'Salir': ['salida_iniciada', 'salida_completada'],
        'Entrar en espera': ['espera_iniciada', 'espera_confirmada'],
        'Reprogramar': ['reprogramacion_iniciada', 'partido_reprogramado'],
        'Reconfirmar': [
          'reconfirmacion_iniciada',
          'reprogramacion_rechazada',
          'reprogramacion_aceptada',
        ],
        'Responder propuesta': [
          'respuesta_propuesta_iniciada',
          'propuesta_rechazada',
          'propuesta_aceptada',
        ],
        'Validar resultado': [
          'validacion_resultado_iniciada',
          'resultado_disputado',
          'resultado_confirmado',
        ],
        'Editar': ['edicion_iniciada', 'partido_editado'],
        'Eliminar': ['eliminacion_iniciada', 'partido_eliminado'],
        'Recuperar contraseña': [
          'recuperacion_iniciada',
          'recuperacion_solicitada',
        ],
      };
      await mostrar(tester, [
        for (final accion in acciones.entries)
          for (final nombre in accion.value) evento(nombre, accion.key),
        evento('suplente_promovido', 'promocion'),
      ]);
      for (final accion in acciones.keys) {
        await _seleccionarFlujo(tester, accion);
        final tabla = tester.widget<DataTable>(find.byType(DataTable));
        expect(
          tabla.rows.map((fila) => (fila.cells.first.child as Text).data),
          [
            ...acciones[accion]!,
            if (accion == 'Entrar en espera') 'suplente_promovido',
          ],
        );
        expect(find.text('Inicios: 1'), findsOneWidget);
        expect(find.text('Finalizados: 1'), findsOneWidget);
        expect(find.text('Finalización: 100.0%'), findsOneWidget);
      }
      await _seleccionarFlujo(tester, 'Entrar en espera');
      expect(find.text('Suplentes promovidos: 1'), findsOneWidget);
    },
  );
}

Future<void> _seleccionarFlujo(WidgetTester tester, String accion) async {
  await tester.tap(find.byKey(const Key('analitica_flujo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(accion).last);
  await tester.pumpAndSettle();
}
