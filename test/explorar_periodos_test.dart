import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/tema/tema_app.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

final ahora = DateTime(2030, 5, 15, 12);

ModeloPartido partido(String id, DateTime fecha) => ModeloPartido(
  id: id,
  titulo: 'Futsal $id',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Coliseo Campus',
  fechaHora: ModeloPartido.formatearFechaHora(fecha),
  cuposTotales: 10,
  cuposOcupados: 2,
  organizadorNombre: 'Lorgio',
);

void main() {
  late ServicioAutenticacionFalso auth;
  late ControladorExplorar controlador;

  setUp(() async {
    auth = ServicioAutenticacionFalso();
    controlador = ControladorExplorar();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
  });

  Widget pantalla() => MaterialApp(
    theme: TemaApp.tema,
    home: VistaExplorarPartidos(
      servicioAuth: auth,
      repositorioPartidos: auth.repositorio,
      controladorExplorar: controlador,
      referenciaTemporal: ahora,
    ),
  );

  Future<void> tocar(WidgetTester tester, String key) async {
    final boton = find.byKey(Key(key));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  void ampliar(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('categorías muestran solo sus partidos y respetan el orden', (
    tester,
  ) async {
    ampliar(tester);
    for (final (id, minutos) in [
      ('lejano', 120),
      ('viejo', -120),
      ('cercano', 0),
      ('reciente', -1),
    ]) {
      auth.repositorio.sembrar(
        'u-lorgio',
        partido(id, ahora.add(Duration(minutes: minutos))),
      );
    }
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();
    expect(find.text('2 partidos encontrados'), findsOneWidget);
    expect(
      tester
          .widgetList<TarjetaPartido>(find.byType(TarjetaPartido))
          .map((w) => w.partido.id),
      ['cercano', 'lejano'],
    );
    await tocar(tester, 'explorar_vencidos');
    expect(
      tester
          .widgetList<TarjetaPartido>(find.byType(TarjetaPartido))
          .map((w) => w.partido.id),
      ['reciente', 'viejo'],
    );
    expect(
      find.text('Ordenados del más reciente al más antiguo'),
      findsOneWidget,
    );
  });

  testWidgets(
    'cambiar a vencidos quita cupos y conserva búsqueda, filtros y categoría al volver',
    (tester) async {
      ampliar(tester);
      controlador.actualizarFiltro(
        const FiltroPartidos(
          periodo: PeriodoPartidos.proximos,
          texto: 'Futsal',
          deporte: 'Futsal',
          lugar: 'Coliseo Campus',
          fecha: FiltroFecha.hoy,
          soloConCupos: true,
        ),
      );
      await tester.pumpWidget(pantalla());
      await tester.pumpAndSettle();
      await tocar(tester, 'explorar_vencidos');
      expect(controlador.filtro.soloConCupos, isFalse);
      expect(controlador.filtro.texto, 'Futsal');
      expect(controlador.filtro.deporte, 'Futsal');
      expect(controlador.filtro.lugar, 'Coliseo Campus');
      expect(controlador.filtro.fecha, FiltroFecha.hoy);
      await tocar(tester, 'explorar_mostrar_filtros');
      expect(find.text('Disponible solo en partidos próximos'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(pantalla());
      await tester.pumpAndSettle();
      expect(controlador.filtro.periodo, PeriodoPartidos.vencidos);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Futsal',
      );
      expect(find.text('Deporte: Futsal'), findsOneWidget);
      expect(
        find.byKey(const Key('explorar_filtros_desplegados')),
        findsNothing,
      );
      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();
      expect(controlador.filtro.periodo, PeriodoPartidos.vencidos);
      expect(controlador.filtro.estaActivo, isFalse);
      expect(find.text('No hay partidos vencidos'), findsOneWidget);
      await tocar(tester, 'explorar_proximos');
      expect(controlador.filtro.soloConCupos, isFalse);
      await tocar(tester, 'explorar_mostrar_filtros');
      await tocar(tester, 'explorar_con_cupos');
      expect(controlador.filtro.soloConCupos, isTrue);
    },
  );

  testWidgets('estados vacíos corresponden a la categoría seleccionada', (
    tester,
  ) async {
    await tester.pumpWidget(pantalla());
    await tester.pumpAndSettle();
    expect(find.text('No hay partidos próximos'), findsOneWidget);
    await tocar(tester, 'explorar_vencidos');
    expect(find.text('No hay partidos vencidos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'rugby');
    await tester.pumpAndSettle();
    expect(
      find.text('Ningún partido coincide con tu búsqueda'),
      findsOneWidget,
    );
    expect(find.text('No hay partidos vencidos'), findsNothing);
  });

  for (final ancho in [320.0, 1280.0]) {
    testWidgets(
      'diseño accesible y sin desbordamientos a $ancho px con filtros largos',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(ancho, 1400);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        controlador.actualizarFiltro(
          const FiltroPartidos(
            periodo: PeriodoPartidos.proximos,
            lugar: 'Coliseo universitario del campus principal, cancha de entrenamiento',
          ),
        );
        final semantica = tester.ensureSemantics();
        try {
          await tester.pumpWidget(pantalla());
          await tester.pumpAndSettle();
          final busqueda = tester.getRect(
            find.byKey(const Key('explorar_busqueda')),
          );
          final filtros = tester.getRect(
            find.byKey(const Key('explorar_mostrar_filtros')),
          );
          if (ancho == 320) {
            expect(filtros.top, greaterThan(busqueda.bottom));
          } else {
            expect(filtros.left, greaterThan(busqueda.right));
          }
          for (final key in [
            'explorar_mostrar_filtros',
            'explorar_proximos',
            'explorar_vencidos',
          ]) {
            final finder = find.byKey(Key(key));
            final size = tester.getSize(finder);
            expect(size.height, greaterThanOrEqualTo(48));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(
              tester
                  .getSemantics(finder)
                  .getSemanticsData()
                  .flagsCollection
                  .isButton,
              isTrue,
            );
          }
          await tocar(tester, 'explorar_mostrar_filtros');
          expect(find.text('Deporte'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantica.dispose();
        }
      },
    );
  }
}
