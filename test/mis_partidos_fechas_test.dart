import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

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
    .widgetList<TarjetaPartido>(find.byType(TarjetaPartido))
    .map((tarjeta) => tarjeta.partido.id)
    .toList();

Future<void> tocar(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> elegirFecha(WidgetTester tester, String opcion) async {
  await tocar(tester, find.byKey(const Key('mis_partidos_periodo')));
  await tester.tap(find.text(opcion).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('todos mezcla los roles y ordena próximos antes de pasados', (
    tester,
  ) async {
    await abrir(tester, await preparar());
    expect(ids(tester), [
      'ahora',
      'proximo',
      'medio',
      'lejano',
      'pasado-reciente',
      'pasado-antiguo',
    ]);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('mis_partidos_cantidad_visible')))
          .data,
      '6',
    );
    await elegirFecha(tester, 'Próximos');
    expect(ids(tester), ['ahora', 'proximo', 'medio', 'lejano']);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('mis_partidos_cantidad_visible')))
          .data,
      '4',
    );
    await elegirFecha(tester, 'Pasados');
    expect(ids(tester), ['pasado-reciente', 'pasado-antiguo']);
    await elegirFecha(tester, 'Todas las fechas');
    expect(ids(tester), [
      'ahora',
      'proximo',
      'medio',
      'lejano',
      'pasado-reciente',
      'pasado-antiguo',
    ]);
  });

  testWidgets(
    'fecha se combina con el rol y se conserva al volver de Explorar',
    (tester) async {
      final auth = await preparar();
      await abrir(tester, auth);
      await elegirFecha(tester, 'Próximos');
      await tocar(tester, find.byKey(const Key('mis_partidos_filtro_unido')));
      expect(ids(tester), ['ahora', 'medio']);
      await elegirFecha(tester, 'Pasados');
      expect(ids(tester), ['pasado-reciente']);
      await tocar(
        tester,
        find.byKey(const Key('mis_partidos_filtro_organizados')),
      );
      expect(ids(tester), ['pasado-antiguo']);
      await tocar(tester, find.text('Explorar'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ids(tester), ['pasado-antiguo']);
      expect(
        tester
            .widget<DropdownButtonFormField<PeriodoPartidos>>(
              find.byKey(const Key('mis_partidos_periodo')),
            )
            .initialValue,
        PeriodoPartidos.vencidos,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vacío por fecha orienta y no provoca desbordamientos a 320 px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await abrir(tester, auth);
    await elegirFecha(tester, 'Pasados');
    expect(find.text('No tienes partidos pasados'), findsOneWidget);
    expect(
      find.text('Prueba otra fecha o cambia la categoría.'),
      findsOneWidget,
    );
    expect(ids(tester), isEmpty);
    await elegirFecha(tester, 'Próximos');
    expect(find.text('No tienes partidos próximos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
