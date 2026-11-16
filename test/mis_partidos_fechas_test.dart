import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_mis_partidos.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

final referencia = DateTime(2090, 11, 9, 12);

Future<ServicioAutenticacionFalso> preparar() async {
  final auth = ServicioAutenticacionFalso();
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  for (final caso in [
    ('lejano', '11/11/2090 · 19:00', true),
    ('pasado-antiguo', '01/11/2090 · 19:00', true),
    ('medio', '10/11/2090 · 19:00', false),
    ('pasado-reciente', '09/11/2090 · 11:59', false),
    ('proximo', '09/11/2090 · 13:00', true),
    ('ahora', '09/11/2090 · 12:00', false),
  ]) {
    auth.repositorio.sembrar(
      caso.$3 ? 'u-diego' : 'u-lorgio',
      ModeloPartido(
        id: caso.$1,
        titulo: 'Partido ${caso.$1}',
        disciplina: 'Futsal',
        icono: 'Futsal',
        ubicacion: 'Cancha',
        fechaHora: caso.$2,
        cuposTotales: 10,
        cuposOcupados: 1,
        organizadorNombre: 'Estudiante',
      ),
    );
    if (!caso.$3) await auth.repositorio.unirseAPartido(caso.$1);
  }
  return auth;
}

Future<void> abrir(WidgetTester tester, ServicioAutenticacionFalso auth) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VistaMisPartidos(
        servicioAuth: auth,
        repositorioPartidos: auth.repositorio,
        controladorExplorar: ControladorExplorar(),
        referenciaTemporal: referencia,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> ids(WidgetTester tester) => tester
    .widgetList<TarjetaMisPartidos>(find.byType(TarjetaMisPartidos))
    .map((tarjeta) => tarjeta.partido.id)
    .toList();

Future<void> tocar(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> elegirFecha(WidgetTester tester, String opcion) async {
  await tocar(tester, find.byKey(const Key('mis_partidos_abrir_filtros')));
  await tocar(tester, find.byKey(const Key('mis_partidos_filtro_fecha')));
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
  await tocar(tester, find.byKey(const Key('mis_partidos_aplicar_filtros')));
}

void main() {
  testWidgets(
    'inicia en creados próximos y filtra todos los roles y periodos',
    (tester) async {
      await abrir(tester, await preparar());
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('mis_partidos_filtro_organizados')),
            )
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
      expect(ids(tester), ['proximo', 'lejano']);

      await tocar(tester, find.byKey(const Key('mis_partidos_filtro_todos')));
      expect(ids(tester), ['ahora', 'proximo', 'medio', 'lejano']);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('mis_partidos_cantidad_total')))
            .data,
        'Todos (4)',
      );
      await elegirFecha(tester, 'Partidos pasados');
      expect(ids(tester), ['pasado-reciente', 'pasado-antiguo']);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('mis_partidos_titulo_lista')))
            .data,
        'Partidos pasados',
      );

      await elegirFecha(tester, 'Todas las fechas');
      expect(ids(tester), [
        'ahora',
        'proximo',
        'medio',
        'lejano',
        'pasado-reciente',
        'pasado-antiguo',
      ]);
    },
  );

  testWidgets('el deporte y el periodo se combinan con la categoría', (
    tester,
  ) async {
    final auth = await preparar();
    await abrir(tester, auth);
    await tocar(tester, find.byKey(const Key('mis_partidos_filtro_unido')));
    expect(ids(tester), ['ahora', 'medio']);
    await elegirFecha(tester, 'Partidos pasados');
    expect(ids(tester), ['pasado-reciente']);
    await tocar(
      tester,
      find.byKey(const Key('mis_partidos_filtro_organizados')),
    );
    expect(ids(tester), ['pasado-antiguo']);
    expect(ids(tester), ['pasado-antiguo']);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('mis_partidos_titulo_lista')))
          .data,
      'Partidos pasados',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el filtro de deporte se aplica y se puede quitar desde el chip',
    (tester) async {
      final auth = await preparar();
      auth.repositorio.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'basquet',
          titulo: 'Partido de básquet',
          disciplina: 'Básquetbol',
          icono: 'Básquetbol',
          ubicacion: 'Coliseo',
          fechaHora: '12/11/2090 · 19:00',
          cuposTotales: 10,
          cuposOcupados: 1,
          organizadorNombre: 'Estudiante',
        ),
      );
      await abrir(tester, auth);
      await tocar(tester, find.byKey(const Key('mis_partidos_abrir_filtros')));
      await tocar(tester, find.byKey(const Key('mis_partidos_filtro_deporte')));
      await tester.tap(find.text('Básquetbol').last);
      await tester.pumpAndSettle();
      await tocar(
        tester,
        find.byKey(const Key('mis_partidos_aplicar_filtros')),
      );
      expect(ids(tester), ['basquet']);
      expect(
        find.byKey(const Key('mis_partidos_chip_deporte')),
        findsOneWidget,
      );
      final borrarDeporte = find.byTooltip('Quitar filtro de deporte');
      await tocar(tester, borrarDeporte);
      expect(ids(tester), ['proximo', 'lejano', 'basquet']);
      expect(find.byKey(const Key('mis_partidos_chip_deporte')), findsNothing);
    },
  );

  testWidgets('aplicar confirma filtros y cerrar descarta cambios pendientes', (
    tester,
  ) async {
    await abrir(tester, await preparar());
    await tocar(tester, find.byKey(const Key('mis_partidos_abrir_filtros')));
    await tocar(tester, find.byKey(const Key('mis_partidos_filtro_fecha')));
    await tester.tap(find.text('Todas las fechas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Próximos partidos'), findsOneWidget);
    expect(ids(tester), ['proximo', 'lejano']);
    await elegirFecha(tester, 'Esta semana');
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.byKey(const Key('mis_partidos_chip_fecha')), findsOneWidget);
    expect(
      find.byKey(const Key('mis_partidos_filtros_cantidad')),
      findsOneWidget,
    );
  });

  testWidgets('limpiar filtros vuelve a creados y próximos', (tester) async {
    await abrir(tester, await preparar());
    await elegirFecha(tester, 'Todas las fechas');
    await tocar(tester, find.byKey(const Key('mis_partidos_abrir_filtros')));
    await tocar(tester, find.byKey(const Key('mis_partidos_limpiar_filtros')));
    await tocar(tester, find.byKey(const Key('mis_partidos_aplicar_filtros')));
    expect(find.text('Próximos partidos'), findsOneWidget);
    expect(ids(tester), ['proximo', 'lejano']);
  });

  test('filtro de semana usa lunes y domingo de la semana actual', () {
    final inicio = DateTime(2090, 11, 6, 0);
    final fin = DateTime(2090, 11, 12, 23, 59);
    const filtro = FiltroPartidos(fecha: FiltroFecha.estaSemana);
    expect(
      filtro.coincide(_partidoDePrueba('lunes', inicio), referencia),
      isTrue,
    );
    expect(
      filtro.coincide(_partidoDePrueba('domingo', fin), referencia),
      isTrue,
    );
    expect(
      filtro.coincide(
        _partidoDePrueba('fuera', DateTime(2090, 11, 13, 0)),
        referencia,
      ),
      isFalse,
    );
  });

  test('rango personalizado incluye ambos días completos', () {
    final filtro = FiltroPartidos(
      periodo: PeriodoPartidos.todos,
      fecha: FiltroFecha.rango,
      desde: DateTime(2090, 11, 10),
      hasta: DateTime(2090, 11, 11),
    );
    expect(
      filtro.coincide(
        _partidoDePrueba('inicio', DateTime(2090, 11, 10, 0)),
        referencia,
      ),
      isTrue,
    );
    expect(
      filtro.coincide(
        _partidoDePrueba('fin', DateTime(2090, 11, 11, 23, 59)),
        referencia,
      ),
      isTrue,
    );
    expect(
      filtro.coincide(
        _partidoDePrueba('fuera', DateTime(2090, 11, 12)),
        referencia,
      ),
      isFalse,
    );
  });

  testWidgets('vacío orienta en próximos y pasados a 320 px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await abrir(tester, auth);
    await elegirFecha(tester, 'Partidos pasados');
    expect(find.text('No tienes partidos pasados'), findsOneWidget);
    expect(
      find.text('Prueba otra fecha o cambia la categoría.'),
      findsOneWidget,
    );
    expect(ids(tester), isEmpty);
    await elegirFecha(tester, 'Próximos partidos');
    expect(find.text('No tienes partidos próximos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ModeloPartido _partidoDePrueba(String id, DateTime fecha) => ModeloPartido(
  id: id,
  titulo: id,
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Cancha',
  fechaHora: ModeloPartido.formatearFechaHora(fecha),
  cuposTotales: 10,
  cuposOcupados: 1,
  organizadorNombre: 'Estudiante',
);
