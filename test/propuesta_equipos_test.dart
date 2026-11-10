import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/propuesta_equipos.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';

import 'apoyo/repositorio_en_memoria.dart';

ModeloPartido partido({int cupos = 2}) => ModeloPartido(
  id: 'p',
  titulo: 'Partido de prueba',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Cancha',
  fechaHora: '10/10/2099 · 19:00',
  cuposTotales: cupos,
  cuposOcupados: 1,
  organizadorNombre: 'Alex',
);

PropuestaEquipos propuesta({
  List<String> a = const ['org'],
  List<String> b = const ['jug'],
  String capitan = 'jug',
}) => PropuestaEquipos(
  revision: '',
  equipoA: a,
  equipoB: b,
  capitanRivalId: capitan,
);

Future<RepositorioEnMemoria> preparar({int cupos = 2}) async {
  final repo = RepositorioEnMemoria(usuarioId: 'org', usuarioNombre: 'Alex');
  await repo.crearPartido(partido(cupos: cupos));
  // crearPartido asigna m-1.
  repo.usarSesionDe('jug', 'Alex');
  await repo.unirseAPartido('m-1');
  repo.usarSesionDe('org', 'Alex');
  return repo;
}

void main() {
  test(
    'dos cuentas consultan, rechazan, reenvían y aceptan el reparto',
    () async {
      final repo = await preparar();
      final participantes = await repo.obtenerParticipantes('m-1');
      expect(participantes.map((p) => p.id), ['org', 'jug']);
      expect(participantes.map((p) => p.nombre), ['Alex', 'Alex']);
      await repo.guardarPropuesta('m-1', propuesta());
      final primera = (await repo.obtenerPropuesta('m-1'))!;
      await expectLater(
        repo.responderPropuesta('m-1', primera.revision, true),
        throwsStateError,
      );
      repo.usarSesionDe('jug', 'Alex');
      await repo.responderPropuesta('m-1', primera.revision, false);
      expect(
        (await repo.obtenerPropuesta('m-1'))!.estado,
        EstadoPropuesta.rechazada,
      );
      await expectLater(
        repo.responderPropuesta('m-1', primera.revision, true),
        throwsStateError,
      );
      repo.usarSesionDe('org', 'Alex');
      await repo.guardarPropuesta('m-1', propuesta());
      final segunda = (await repo.obtenerPropuesta('m-1'))!;
      expect(segunda.estado, EstadoPropuesta.pendiente);
      repo.usarSesionDe('jug', 'Alex');
      await expectLater(
        repo.responderPropuesta('m-1', primera.revision, true),
        throwsStateError,
      );
      await repo.responderPropuesta('m-1', segunda.revision, true);
      repo.usarSesionDe('org', 'Alex');
      expect(
        (await repo.obtenerPropuesta('m-1'))!.estado,
        EstadoPropuesta.aceptada,
      );
      repo.usarSesionDe('ajeno', 'Otro');
      await expectLater(repo.obtenerPropuesta('m-1'), throwsStateError);
      await expectLater(
        repo.guardarPropuesta('m-1', propuesta()),
        throwsStateError,
      );
      await expectLater(
        repo.responderPropuesta('m-1', segunda.revision, true),
        throwsStateError,
      );
    },
  );

  test('rechaza equipos inválidos y convocatoria abierta', () async {
    final repo = await preparar(cupos: 5);
    await expectLater(
      repo.guardarPropuesta('m-1', propuesta()),
      throwsStateError,
    );
    await repo.completarEquipo('m-1');
    for (final invalida in [
      propuesta(a: ['org', 'jug']),
      propuesta(b: []),
      propuesta(a: [], b: ['jug']),
      propuesta(b: ['ajeno']),
      propuesta(a: ['jug'], b: ['org'], capitan: 'org'),
      propuesta(capitan: 'org'),
    ]) {
      await expectLater(
        repo.guardarPropuesta('m-1', invalida),
        throwsStateError,
      );
    }
    await repo.guardarPropuesta('m-1', propuesta());
  });

  for (final suplente in [false, true]) {
    test('salida invalida propuesta, con suplente: $suplente', () async {
      final repo = await preparar();
      await repo.guardarPropuesta('m-1', propuesta());
      if (suplente) {
        repo.usarSesionDe('sup', 'Suplente');
        await repo.entrarEnEspera('m-1');
      }
      repo.usarSesionDe('jug', 'Alex');
      await repo.salirDelPartido('m-1');
      repo.usarSesionDe('org', 'Alex');
      expect(await repo.obtenerPropuesta('m-1'), isNull);
      expect(
        (await repo.obtenerParticipantes('m-1')).map((p) => p.id),
        suplente ? ['org', 'sup'] : ['org'],
      );
    });
  }

  test('reprogramación y retiro posterior invalidan la propuesta', () async {
    final repo = await preparar(cupos: 5);
    await repo.completarEquipo('m-1');
    await repo.guardarPropuesta('m-1', propuesta());
    await repo.reprogramarPartido(
      'm-1',
      DateTime(2099, 11, 10, 19),
      'Cancha 2',
      'Cambio',
    );
    expect(await repo.obtenerPropuesta('m-1'), isNull);
    await repo.guardarPropuesta('m-1', propuesta());
    repo.usarSesionDe('jug', 'Alex');
    await repo.responderReprogramacion('m-1', false);
    repo.usarSesionDe('org', 'Alex');
    expect(await repo.obtenerPropuesta('m-1'), isNull);
  });

  test('partido iniciado impide proponer y responder', () async {
    final repo = await preparar();
    await repo.guardarPropuesta('m-1', propuesta());
    final enviada = (await repo.obtenerPropuesta('m-1'))!;
    final actual = (await repo.obtenerMisPartidos()).single;
    repo.sembrar('org', actual.copyWith(fechaHora: '01/01/2000 · 12:00'));
    await expectLater(
      repo.guardarPropuesta('m-1', propuesta()),
      throwsStateError,
    );
    repo.usarSesionDe('jug', 'Alex');
    await expectLater(
      repo.responderPropuesta('m-1', enviada.revision, true),
      throwsStateError,
    );
  });

  testWidgets('organizador reparte y capitán rival acepta desde la pantalla', (
    tester,
  ) async {
    final repo = await preparar();
    final actual = (await repo.obtenerMisPartidos()).single;
    await tester.pumpWidget(
      MaterialApp(
        home: VistaEquipos(
          partido: actual,
          repositorio: repo,
          usuarioId: 'org',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aceptar'), findsNothing);
    final organizador = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('equipo_org')),
    );
    expect(organizador.onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('equipo_jug')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipo B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar propuesta'));
    await tester.tap(find.text('Enviar propuesta'));
    await tester.pumpAndSettle();
    expect(find.text('Propuesta: Pendiente'), findsOneWidget);
    expect(find.text('Editar propuesta'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
    repo.usarSesionDe('jug', 'Alex');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: VistaEquipos(
          partido: (await repo.obtenerPartidosUnidos()).single,
          repositorio: repo,
          usuarioId: 'jug',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar propuesta'), findsNothing);
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Propuesta: Aceptada'), findsOneWidget);
    expect(find.text('Aceptar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
