import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

void main() {
  testWidgets('carga suplentes y permite reintentar si falla esa consulta', (
    tester,
  ) async {
    final repo = _RepositorioControlado();
    final auth = ServicioAutenticacionFalso(repo);
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    repo.sembrar(
      'u-diego',
      _partido(
        'con-suplentes',
        'Partido con suplentes',
      ).copyWith(cuposTotales: 2),
    );
    repo.usarSesionDe('titular', 'Titular');
    await repo.unirseAPartido('con-suplentes');
    repo.usarSesionDe('suplente', 'Suplente');
    await repo.entrarEnEspera('con-suplentes');
    repo.usarSesionDe('u-diego', 'Diego');

    repo.fallarSuplentes = true;
    await _abrir(tester, auth, repo);
    expect(find.text('Error al cargar suplentes.'), findsOneWidget);
    expect(find.byKey(const Key('mis_partidos_error')), findsOneWidget);
    expect(find.byKey(const Key('mis_partidos_vacio')), findsNothing);

    repo.fallarSuplentes = false;
    final reintentar = find.byKey(const Key('mis_partidos_reintentar'));
    await _visible(tester, reintentar);
    await tester.tap(reintentar);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mis_partidos_error')), findsNothing);
    final tarjeta = tester.widget<TarjetaMisPartidos>(
      find.byType(TarjetaMisPartidos),
    );
    expect(tarjeta.partido.id, 'con-suplentes');
    await tester.tap(
      find.byKey(const Key('mis_partidos_detalle_con-suplentes')),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Suplente'), findsOneWidget);
  });

  testWidgets('el detalle conserva las acciones del organizador', (
    tester,
  ) async {
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    auth.repositorio.sembrar(
      'u-diego',
      _partido('detalle-organizador', 'Partido organizado'),
    );
    await _abrir(tester, auth, auth.repositorio);
    await tester.tap(
      find.byKey(const Key('mis_partidos_detalle_detalle-organizador')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalles del partido'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar inscripciones'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Reprogramar'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar partido'), findsOneWidget);
  });

  testWidgets('el detalle conserva la acción de salir para un jugador', (
    tester,
  ) async {
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    auth.repositorio.sembrar(
      'u-lorgio',
      _partido('detalle-jugador', 'Partido inscrito'),
    );
    await auth.repositorio.unirseAPartido('detalle-jugador');
    await _abrir(tester, auth, auth.repositorio);
    await tester.tap(find.bySemanticsLabel('Como jugador'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('mis_partidos_detalle_detalle-jugador')),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Salir del partido'), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('tarjeta de resumen cabe en una pantalla móvil estrecha', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    auth.repositorio.sembrar(
      'u-diego',
      _partido('estrecho', 'Partido de prueba con nombre largo'),
    );
    await _abrir(tester, auth, auth.repositorio);
    expect(find.byType(TarjetaMisPartidos), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'vacío en las tres categorías conserva orientación, selección y accesibilidad',
    (tester) async {
      final semantica = tester.ensureSemantics();
      try {
        final auth = ServicioAutenticacionFalso();
        await auth.iniciarSesion('diego@unisport.edu', '123456');
        await _abrir(tester, auth, auth.repositorio);
        for (final filtro in [
          ('todos', 'Todos'),
          ('organizados', 'Creados por mí'),
          ('unido', 'Como jugador'),
        ]) {
          await _visible(tester, _filtro(filtro.$1));
          final datos = tester
              .getSemantics(_filtro(filtro.$1))
              .getSemanticsData();
          expect(datos.label, filtro.$2);
          expect(datos.flagsCollection.isButton, isTrue);
          _area(tester, _filtro(filtro.$1));
          await tester.tap(find.bySemanticsLabel(filtro.$2));
          await tester.pumpAndSettle();
          for (final clave in ['todos', 'organizados', 'unido']) {
            expect(
              tester
                  .getSemantics(_filtro(clave))
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected
                  .toBoolOrNull(),
              clave == filtro.$1,
            );
          }
          expect(find.byKey(const Key('mis_partidos_vacio')), findsOneWidget);
          expect(find.text('No tienes partidos próximos'), findsOneWidget);
          expect(
            find.text(
              filtro.$1 == 'unido'
                  ? 'Toca "Explorar partidos para unirme" para encontrar uno.'
                  : filtro.$1 == 'organizados'
                  ? 'Toca "Crear partido" para agregar uno.'
                  : 'Cambia la categoría o crea un partido para comenzar.',
            ),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const Key('mis_partidos_cantidad_total')),
                )
                .data,
            'Todos (0)',
          );
          expect(
            tester.getSemantics(_filtro('todos')).getSemanticsData().value,
            '0 partidos',
          );
          expect(find.byType(TarjetaPartido), findsNothing);
        }
        for (final accion in ['Explorar', 'Crear partido']) {
          final control = find.bySemanticsLabel(RegExp('^$accion'));
          final visual = accion == 'Crear partido'
              ? find.byKey(const Key('mis_partidos_crear'))
              : find.byType(NavigationDestination).first;
          await _visible(tester, visual);
          expect(control, findsOneWidget);
          expect(
            tester
                .getSemantics(control)
                .getSemanticsData()
                .flagsCollection
                .isButton,
            isTrue,
          );
          _area(tester, visual);
        }
      } finally {
        semantica.dispose();
      }
    },
  );

  testWidgets(
    'error no se presenta como vacío y reintentar conserva el filtro',
    (tester) async {
      final semantica = tester.ensureSemantics();
      try {
        final repo = _RepositorioControlado();
        final auth = ServicioAutenticacionFalso(repo);
        await auth.iniciarSesion('diego@unisport.edu', '123456');
        repo.sembrar('u-diego', _partido('propio', 'Organizado'));
        repo.sembrar('u-lorgio', _partido('jugador', 'Inscrito'));
        await repo.unirseAPartido('jugador');
        repo.fallar = true;
        await _abrir(tester, auth, repo);
        expect(find.text('Error de carga de prueba.'), findsOneWidget);
        expect(find.byKey(const Key('mis_partidos_error')), findsOneWidget);
        expect(find.byKey(const Key('mis_partidos_vacio')), findsNothing);
        expect(find.byType(TarjetaMisPartidos), findsNothing);
        await tester.tap(find.bySemanticsLabel('Como jugador'));
        await tester.pumpAndSettle();
        final reintentar = find.byKey(const Key('mis_partidos_reintentar'));
        await _visible(tester, reintentar);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Reintentar'))
              .getSemanticsData()
              .flagsCollection
              .isButton,
          isTrue,
        );
        _area(tester, reintentar);
        repo.fallar = false;
        repo.pendiente = Completer<List<ModeloPartido>>();
        await tester.tap(reintentar);
        await tester.pump();
        expect(find.byKey(const Key('mis_partidos_cargando')), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(const Key('mis_partidos_cargando')))
              .getSemanticsData()
              .label,
          'Cargando mis partidos',
        );
        for (final clave in ['todos', 'organizados', 'unido']) {
          final datos = tester.widget<Semantics>(_filtro(clave)).properties;
          expect(datos.enabled, isFalse);
          expect(datos.selected, clave == 'unido');
        }
        expect(find.byKey(const Key('mis_partidos_vacio')), findsNothing);
        expect(find.byKey(const Key('mis_partidos_error')), findsNothing);
        repo.pendiente!.complete(await repo.propios());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('mis_partidos_cargando')), findsNothing);
        expect(find.byKey(const Key('mis_partidos_error')), findsNothing);
        expect(find.byKey(const Key('mis_partidos_vacio')), findsNothing);
        expect(
          tester
              .getSemantics(_filtro('unido'))
              .getSemanticsData()
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isTrue,
        );
        final tarjeta = tester.widget<TarjetaMisPartidos>(
          find.byType(TarjetaMisPartidos),
        );
        expect(tarjeta.partido.id, 'jugador');
        expect(tarjeta.partido.soyOrganizador, isFalse);
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('mis_partidos_cantidad_total')),
              )
              .data,
          'Todos (2)',
        );
      } finally {
        semantica.dispose();
      }
    },
  );
}

class _RepositorioControlado extends RepositorioEnMemoria {
  bool fallar = false;
  bool fallarSuplentes = false;

  @override
  Future<Map<String, List<String>>> obtenerSuplentes() async {
    if (fallarSuplentes) throw StateError('Error al cargar suplentes.');
    return super.obtenerSuplentes();
  }

  Completer<List<ModeloPartido>>? pendiente;
  Future<List<ModeloPartido>> propios() => super.obtenerMisPartidos();
  @override
  Future<List<ModeloPartido>> obtenerMisPartidos() async {
    if (fallar) throw StateError('Error de carga de prueba.');
    if (pendiente != null) return pendiente!.future;
    return propios();
  }
}

ModeloPartido _partido(String id, String titulo) => ModeloPartido(
  id: id,
  titulo: titulo,
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Cancha de prueba',
  fechaHora: '10/10/2099 · 19:00',
  cuposTotales: 10,
  cuposOcupados: 1,
  organizadorNombre: 'Estudiante',
);
Finder _filtro(String clave) => find.byKey(Key('mis_partidos_filtro_$clave'));
Future<void> _abrir(
  WidgetTester tester,
  ServicioAutenticacionFalso auth,
  RepositorioEnMemoria repo,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VistaMisPartidos(
        servicioAuth: auth,
        repositorioPartidos: repo,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
}

void _area(WidgetTester tester, Finder control) {
  final area = tester.getSize(control);
  expect(area.width, greaterThanOrEqualTo(48));
  expect(area.height, greaterThanOrEqualTo(48));
}
