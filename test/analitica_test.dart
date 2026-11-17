import 'package:material_ui/material_ui.dart';
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
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
    testWidgets('muestra tarjetas de evento, propiedades y fecha', (
      tester,
    ) async {
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

      await _seleccionarFlujo(tester, 'Unirse a un partido');
      await tester.scrollUntilVisible(
        find.byKey(const Key('analitica_evento_0')),
        400,
        scrollable: _scrollableAnalitica(),
      );
      expect(find.text(EventosAnalitica.unionIniciada), findsOneWidget);
      expect(find.text(EventosAnalitica.partidoUnido), findsOneWidget);
      expect(find.text('Propiedades'), findsNWidgets(2));
      expect(find.textContaining('partido-1'), findsNWidgets(2));
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

    testWidgets('adapta el resumen al ancho de movil y escritorio', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: VistaAnalitica(
            servicioAnalitica: _AnaliticaFalsa(
              eventosConsulta: [
                EventoAnalitica(
                  evento: EventosAnalitica.creacionIniciada,
                  props: const {'intento_id': 'intento-1'},
                  fecha: DateTime(2026, 11, 10, 16, 5),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final anchoEscritorio = tester
          .getSize(find.byKey(const Key('analitica_resumen')))
          .width;
      expect(anchoEscritorio, lessThanOrEqualTo(480));

      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpAndSettle();
      final anchoMovil = tester
          .getSize(find.byKey(const Key('analitica_resumen')))
          .width;
      expect(anchoMovil, lessThan(anchoEscritorio));
      expect(anchoMovil, lessThanOrEqualTo(480));
    });

    testWidgets(
      'muestra hasta diez eventos sin controles si caben en una página',
      (tester) async {
        final eventos = [
          for (var indice = 0; indice < 10; indice++)
            EventoAnalitica(
              evento: EventosAnalitica.creacionIniciada,
              props: {'intento_id': 'intento-$indice'},
              fecha: DateTime(2026, 11, 10, 16, indice),
            ),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: VistaAnalitica(
              servicioAnalitica: _AnaliticaFalsa(eventosConsulta: eventos),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('analitica_evento_0')), findsOneWidget);
        expect(find.byKey(const Key('analitica_evento_9')), findsOneWidget);
        expect(
          find.byKey(const Key('analitica_paginacion_siguiente')),
          findsNothing,
        );
        expect(find.text('Mostrando 1–10 de 10'), findsOneWidget);
      },
    );

    testWidgets('permite avanzar y volver entre páginas de eventos', (
      tester,
    ) async {
      await _usarViewportAnaliticaAlto(tester);
      final eventos = [
        for (var indice = 0; indice < 10; indice++)
          EventoAnalitica(
            evento: EventosAnalitica.creacionIniciada,
            props: {'intento_id': 'intento-$indice'},
            fecha: DateTime(2026, 11, 10, 16, indice),
          ),
        EventoAnalitica(
          evento: EventosAnalitica.partidoCreado,
          props: const {'intento_id': 'intento-0'},
          fecha: DateTime(2026, 11, 10, 17),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: VistaAnalitica(
            servicioAnalitica: _AnaliticaFalsa(eventosConsulta: eventos),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mostrando 1–10 de 11'), findsOneWidget);
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.byKey(const Key('analitica_evento_0')), findsOneWidget);
      expect(find.byKey(const Key('analitica_evento_10')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('analitica_Inicios'))).data,
        '10',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('analitica_Finalizados')))
            .data,
        '1',
      );

      await tester.tap(find.byKey(const Key('analitica_paginacion_siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Mostrando 11–11 de 11'), findsOneWidget);
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(find.byKey(const Key('analitica_evento_0')), findsNothing);
      expect(find.byKey(const Key('analitica_evento_10')), findsOneWidget);

      await tester.tap(find.byKey(const Key('analitica_paginacion_anterior')));
      await tester.pumpAndSettle();
      expect(find.text('Mostrando 1–10 de 11'), findsOneWidget);
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.byKey(const Key('analitica_evento_0')), findsOneWidget);
    });

    testWidgets('cambiar de flujo y actualizar reinician la página', (
      tester,
    ) async {
      await _usarViewportAnaliticaAlto(tester);
      final eventos = [
        for (var indice = 0; indice < 11; indice++) ...[
          EventoAnalitica(
            evento: EventosAnalitica.creacionIniciada,
            props: {'intento_id': 'crear-$indice'},
            fecha: DateTime(2026, 11, 10, 16, indice),
          ),
          EventoAnalitica(
            evento: EventosAnalitica.unionIniciada,
            props: {'intento_id': 'unir-$indice'},
            fecha: DateTime(2026, 11, 10, 15, indice),
          ),
        ],
      ];
      final analitica = _AnaliticaFalsa(eventosConsulta: eventos);
      await tester.pumpWidget(
        MaterialApp(home: VistaAnalitica(servicioAnalitica: analitica)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('analitica_paginacion_siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);

      await _seleccionarFlujo(tester, 'Unirse a un partido');
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.text('Mostrando 1–10 de 11'), findsOneWidget);

      await tester.tap(find.byKey(const Key('analitica_paginacion_siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2'), findsOneWidget);

      analitica.eventosConsulta = eventos;
      await tester.tap(find.byTooltip('Actualizar analítica'));
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(find.text('Mostrando 1–10 de 11'), findsOneWidget);
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

      await _seleccionarFlujo(tester, 'Unirse a un partido');
      await tester.scrollUntilVisible(
        find.byKey(const Key('analitica_evento_0')),
        400,
        scrollable: _scrollableAnalitica(),
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
      expect(
        tester.widget<Text>(find.byKey(const Key('analitica_Inicios'))).data,
        '3',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('analitica_Finalizados')))
            .data,
        '1',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('analitica_porcentaje'))).data,
        '33.3%',
      );
      expect(
        find.byKey(const Key('analitica_detalle_Sin finalizar')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('analitica_detalle_Sin finalizar')),
            )
            .data,
        '2',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('analitica_detalle_Intentos con error')),
            )
            .data,
        '2',
      );
      expect(find.text('regla_negocio'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('analitica_detalle_regla_negocio')),
            )
            .data,
        '2',
      );
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
      expect(
        tester.widget<Text>(find.byKey(const Key('analitica_porcentaje'))).data,
        'Sin datos',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('analitica_Inicios'))).data,
        '0',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('analitica_Finalizados')))
            .data,
        '0',
      );
    },
  );

  testWidgets(
    'selector cubre las 14 acciones y cuenta decisiones como finalizaciones',
    (tester) async {
      const acciones = {
        'Unirse a un partido': ['union_iniciada', 'partido_unido'],
        'Crear partido': ['creacion_iniciada', 'partido_creado'],
        'Buscar partidos': [
          'busqueda_iniciada',
          'busqueda_realizada',
          'busqueda_sin_resultados',
        ],
        'Crear cuenta': ['registro_iniciado', 'registro_completado'],
        'Iniciar sesión': ['login_iniciado', 'login_exitoso'],
        'Salir de un partido': ['salida_iniciada', 'salida_completada'],
        'Entrar en lista de espera': ['espera_iniciada', 'espera_confirmada'],
        'Reprogramar partido': [
          'reprogramacion_iniciada',
          'partido_reprogramado',
        ],
        'Responder reprogramación': [
          'reconfirmacion_iniciada',
          'reprogramacion_rechazada',
          'reprogramacion_aceptada',
        ],
        'Responder propuesta de equipos': [
          'respuesta_propuesta_iniciada',
          'propuesta_rechazada',
          'propuesta_aceptada',
        ],
        'Validar resultado del partido': [
          'validacion_resultado_iniciada',
          'resultado_disputado',
          'resultado_confirmado',
        ],
        'Editar partido': ['edicion_iniciada', 'partido_editado'],
        'Eliminar partido': ['eliminacion_iniciada', 'partido_eliminado'],
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
        final eventosEsperados = [
          ...acciones[accion]!,
          if (accion == 'Entrar en lista de espera') 'suplente_promovido',
        ];
        for (final nombre in eventosEsperados) {
          expect(find.text(nombre), findsOneWidget);
        }
        expect(
          tester.widget<Text>(find.byKey(const Key('analitica_Inicios'))).data,
          '1',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('analitica_Finalizados')))
              .data,
          '1',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('analitica_porcentaje')))
              .data,
          '100.0%',
        );
      }
      await _seleccionarFlujo(tester, 'Entrar en lista de espera');
      expect(find.text('Suplentes promovidos'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('analitica_detalle_Suplentes promovidos')),
            )
            .data,
        '1',
      );
    },
  );
}

Future<void> _seleccionarFlujo(WidgetTester tester, String accion) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('analitica_flujo')),
    300,
    scrollable: _scrollableAnalitica(),
  );
  await tester.tap(find.byKey(const Key('analitica_flujo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(accion).last);
  await tester.pumpAndSettle();
}

Finder _scrollableAnalitica() => find
    .descendant(
      of: find.byKey(const Key('analitica_lista')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _usarViewportAnaliticaAlto(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
