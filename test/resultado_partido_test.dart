import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/propuesta_equipos.dart';
import 'package:unisport/modelos/resultado_partido.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';

import 'apoyo/repositorio_en_memoria.dart';

Future<RepositorioEnMemoria> preparar() async {
  final repo = RepositorioEnMemoria(
    usuarioId: 'organizador',
    usuarioNombre: 'Organizador',
  );
  await repo.crearPartido(
    ModeloPartido(
      id: '',
      titulo: 'Final universitaria',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Cancha central',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 2,
      cuposOcupados: 1,
      organizadorNombre: 'Organizador',
    ),
  );
  repo.usarSesionDe('capitan', 'Capitán rival');
  await repo.unirseAPartido('m-1');
  repo.usarSesionDe('organizador', 'Organizador');
  await repo.guardarPropuesta(
    'm-1',
    PropuestaEquipos(
      revision: '',
      equipoA: const ['organizador'],
      equipoB: const ['capitan'],
      capitanRivalId: 'capitan',
    ),
  );
  final propuesta = (await repo.obtenerPropuesta('m-1'))!;
  repo.usarSesionDe('capitan', 'Capitán rival');
  await repo.responderPropuesta('m-1', propuesta.revision, true);
  repo.usarSesionDe('organizador', 'Organizador');
  final partido = (await repo.obtenerMisPartidos()).single;
  repo.sembrar(
    'organizador',
    partido.copyWith(fechaHora: '01/01/2020 · 19:00'),
  );
  return repo;
}

void main() {
  test(
    'registrar, disputar, corregir y confirmar conserva todo el historial',
    () async {
      final repo = await preparar();

      await repo.registrarResultado('m-1', 2, 1);
      final inicial = (await repo.obtenerResultado('m-1'))!;
      expect(inicial.estado, EstadoResultadoPartido.pendiente);
      expect(inicial.esDefinitivo, isFalse);

      repo.usarSesionDe('capitan', 'Capitán rival');
      await repo.disputarResultado(
        'm-1',
        inicial.revision,
        'El segundo gol no fue válido.',
      );
      final disputado = (await repo.obtenerResultado('m-1'))!;
      expect(disputado.estado, EstadoResultadoPartido.disputado);
      expect(disputado.motivoDisputa, 'El segundo gol no fue válido.');

      repo.usarSesionDe('organizador', 'Organizador');
      await repo.registrarResultado('m-1', 1, 1);
      final corregido = (await repo.obtenerResultado('m-1'))!;
      expect(corregido.estado, EstadoResultadoPartido.pendiente);
      expect(corregido.revision, isNot(inicial.revision));

      repo.usarSesionDe('capitan', 'Capitán rival');
      await expectLater(
        repo.confirmarResultado('m-1', inicial.revision),
        throwsStateError,
      );
      await repo.confirmarResultado('m-1', corregido.revision);
      final definitivo = (await repo.obtenerResultado('m-1'))!;
      expect(definitivo.estado, EstadoResultadoPartido.confirmado);
      expect(definitivo.esDefinitivo, isTrue);
      expect(definitivo.marcador, '1 - 1');
      expect(definitivo.historial.map((evento) => evento.accion), [
        AccionResultadoPartido.registrado,
        AccionResultadoPartido.disputado,
        AccionResultadoPartido.corregido,
        AccionResultadoPartido.confirmado,
      ]);
    },
  );

  test('solo los actores correctos operan y lo confirmado no cambia', () async {
    final repo = await preparar();
    repo.usarSesionDe('capitan', 'Capitán rival');
    await expectLater(repo.registrarResultado('m-1', 1, 0), throwsStateError);

    repo.usarSesionDe('organizador', 'Organizador');
    await repo.registrarResultado('m-1', 1, 0);
    final pendiente = (await repo.obtenerResultado('m-1'))!;
    await expectLater(
      repo.confirmarResultado('m-1', pendiente.revision),
      throwsStateError,
    );

    repo.usarSesionDe('capitan', 'Capitán rival');
    await expectLater(
      repo.disputarResultado('m-1', pendiente.revision, '   '),
      throwsStateError,
    );
    await repo.confirmarResultado('m-1', pendiente.revision);

    repo.usarSesionDe('organizador', 'Organizador');
    await expectLater(repo.registrarResultado('m-1', 3, 0), throwsStateError);
    expect((await repo.obtenerResultado('m-1'))!.marcador, '1 - 0');

    repo.usarSesionDe('ajeno', 'Ajeno');
    await expectLater(repo.obtenerResultado('m-1'), throwsStateError);
  });

  testWidgets('la pantalla completa disputa, corrección y confirmación', (
    tester,
  ) async {
    final repo = await preparar();

    Future<void> abrirComo(String id, String nombre) async {
      repo.usarSesionDe(id, nombre);
      await tester.pumpWidget(const SizedBox());
      final partido = id == 'organizador'
          ? (await repo.obtenerMisPartidos()).single
          : (await repo.obtenerPartidosUnidos()).single;
      await tester.pumpWidget(
        MaterialApp(
          home: VistaEquipos(
            partido: partido,
            repositorio: repo,
            usuarioId: id,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await abrirComo('organizador', 'Organizador');
    await tester.enterText(
      find.byKey(const ValueKey('marcador_equipo_a')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('marcador_equipo_b')),
      '1',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar marcador'));
    await tester.pumpAndSettle();
    expect(find.text('Este resultado aún no es definitivo.'), findsOneWidget);

    await abrirComo('capitan', 'Capitán rival');
    await tester.tap(find.text('Disputar resultado'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'El segundo gol no fue válido.',
    );
    await tester.tap(find.text('Enviar disputa'));
    await tester.pumpAndSettle();
    expect(
      find.text('Motivo de la disputa: El segundo gol no fue válido.'),
      findsOneWidget,
    );

    await abrirComo('organizador', 'Organizador');
    await tester.enterText(
      find.byKey(const ValueKey('marcador_equipo_a')),
      '1',
    );
    await tester.ensureVisible(find.text('Enviar corrección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar corrección'));
    await tester.pumpAndSettle();
    expect(find.text('Estado: Pendiente de confirmación'), findsOneWidget);

    await abrirComo('capitan', 'Capitán rival');
    await tester.ensureVisible(find.text('Confirmar resultado'));
    await tester.pumpAndSettle();
    // Se informa de la consecuencia antes de confirmar el marcador.
    expect(
      find.text('Al confirmar, el resultado será definitivo.'),
      findsOneWidget,
    );
    expect(find.text('Disputar resultado'), findsOneWidget);
    await tester.tap(find.text('Confirmar resultado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Resultado definitivo'), findsOneWidget);
    expect(find.text('Marcador registrado'), findsOneWidget);
    expect(find.text('Marcador disputado'), findsOneWidget);
    expect(find.text('Marcador corregido'), findsOneWidget);
    expect(find.text('Resultado confirmado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
