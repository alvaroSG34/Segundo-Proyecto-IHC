import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

/// Pruebas de la interfaz de unión al partido y las listas de inscritos.
///
/// Ejecutar con:  flutter test test/tarjeta_partido_test.dart
ModeloPartido crearPartido({
  EstadoPartido estado = EstadoPartido.cuposAbiertos,
  bool soyOrganizador = true,
  bool estoyUnido = true,
  String fechaHora = '10/10/2099 · 19:00',
  int? cuposOcupados,
}) {
  return ModeloPartido(
    id: 'p-1',
    titulo: 'Futsal nocturno',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Cancha 2',
    fechaHora: fechaHora,
    cuposTotales: 10,
    cuposOcupados:
        cuposOcupados ?? (estado == EstadoPartido.equipoCompleto ? 10 : 3),
    organizadorNombre: 'Lorgio',
    soyOrganizador: soyOrganizador,
    estoyUnido: estoyUnido,
    estado: estado,
  );
}

Widget envolver(Widget hijo) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: hijo)),
);

void main() {
  testWidgets('un titular pendiente conserva su plaza y puede responder', (
    tester,
  ) async {
    var acepto = 0;
    var retiro = 0;
    final partido = crearPartido(soyOrganizador: false, estoyUnido: true)
        .copyWith(
          motivoReprogramacion: 'La cancha cambió',
          fechaAnterior: '10/10/2099 · 19:00',
          reconfirmacionPendiente: true,
        );
    await tester.pumpWidget(
      envolver(
        TarjetaPartido(
          partido: partido,
          onReconfirmar: () => acepto++,
          onRetirarseReprogramacion: () => retiro++,
          onSalir: () {},
        ),
      ),
    );
    expect(find.textContaining('Conservas tu plaza'), findsOneWidget);
    expect(find.text('Salir del partido'), findsNothing);
    await tester.tap(find.text('Confirmar mi asistencia'));
    await tester.tap(find.text('Retirarme'));
    expect(acepto, 1);
    expect(retiro, 1);
  });

  testWidgets(
    'el organizador espera las respuestas antes de reprogramar otra vez',
    (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido().copyWith(
              motivoReprogramacion: 'Cambio de cancha',
              respuestasPendientes: 2,
            ),
            onReprogramar: () {},
          ),
        ),
      );
      expect(find.text('Faltan 2 respuestas.'), findsOneWidget);
      expect(find.text('Reprogramar partido'), findsNothing);
    },
  );

  testWidgets(
    'la tarjeta del organizador no ofrece acciones para ocupar cupos',
    (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            onEditar: () {},
            onEliminar: () {},
          ),
        ),
      );

      expect(find.text('Agregar jugador'), findsNothing);
      expect(find.text('Completar equipo'), findsNothing);
      expect(
        find.textContaining('No puedes agregar más jugadores'),
        findsNothing,
      );
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    },
  );

  testWidgets('un partido completo no muestra acciones para ocupar cupos', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        TarjetaPartido(
          partido: crearPartido(estado: EstadoPartido.equipoCompleto),
        ),
      ),
    );

    expect(find.text('Agregar jugador'), findsNothing);
    expect(find.text('Completar equipo'), findsNothing);
    expect(
      find.textContaining('No puedes agregar más jugadores'),
      findsNothing,
    );
  });

  testWidgets('el organizador ve la acción que cierra sin ocupar cupos', (
    tester,
  ) async {
    var llamadas = 0;
    await tester.pumpWidget(
      envolver(
        TarjetaPartido(
          partido: crearPartido(),
          onCompletarEquipo: () => llamadas++,
        ),
      ),
    );

    expect(find.text('Completar equipo'), findsOneWidget);
    expect(
      find.text('Cierra las inscripciones sin añadir jugadores.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Completar equipo'));
    expect(llamadas, 1);
  });

  testWidgets(
    'un cierre con cupos libres se etiqueta como convocatoria cerrada',
    (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(
              estado: EstadoPartido.equipoCompleto,
              cuposOcupados: 3,
            ),
          ),
        ),
      );

      expect(find.text('Convocatoria cerrada'), findsOneWidget);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.text('Faltan 7'), findsOneWidget);
      expect(find.text('Equipo completo'), findsNothing);
    },
  );

  group('Unirme al equipo (Issue #4)', () {
    testWidgets('con cupos abiertos aparece el botón y avisa al tocarlo', (
      tester,
    ) async {
      var llamadas = 0;
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(soyOrganizador: false, estoyUnido: false),
            onUnirse: () => llamadas++,
          ),
        ),
      );

      expect(find.text('Organiza: Lorgio'), findsOneWidget);
      await tester.tap(find.text('Unirme al equipo'));

      expect(llamadas, 1);
      expect(find.textContaining('No puedes unirte'), findsNothing);
    });

    testWidgets('con el equipo completo no hay botón y se explica el motivo', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(
              estado: EstadoPartido.equipoCompleto,
              soyOrganizador: false,
              estoyUnido: false,
            ),
            onUnirse: () {},
          ),
        ),
      );

      expect(find.text('Unirme al equipo'), findsNothing);
      expect(
        find.text(
          'No puedes unirte. Convocatoria cerrada: el equipo ya está completo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('si ya forma parte del equipo no hay botón y se indica', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(soyOrganizador: false, estoyUnido: true),
            onUnirse: () {},
          ),
        ),
      );

      expect(find.text('Unirme al equipo'), findsNothing);
      expect(find.text('Ya formas parte de este equipo.'), findsOneWidget);
    });

    testWidgets('si la fecha ya pasó no hay botón y se explica el motivo', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(
              soyOrganizador: false,
              estoyUnido: false,
              fechaHora: '01/03/2024 · 18:00',
            ),
            onUnirse: () {},
          ),
        ),
      );

      expect(find.text('Unirme al equipo'), findsNothing);
      expect(
        find.text('No puedes unirte. El partido ya se jugó: su fecha ya pasó.'),
        findsOneWidget,
      );
    });
  });

  group('Organizador ve quién se unió (Issue #8)', () {
    testWidgets('un jugador inscrito también ve los nombres', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(soyOrganizador: false, estoyUnido: true),
            jugadoresUnidos: const ['Diego', 'Ana'],
          ),
        ),
      );

      expect(find.text('Diego'), findsNothing);
      await tester.tap(find.text('Ver jugadores inscritos (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Diego'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Agregar jugador'), findsNothing);
      expect(find.text('Completar equipo'), findsNothing);
    });

    testWidgets('quien no se unió no ve los nombres', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(soyOrganizador: false, estoyUnido: false),
            jugadoresUnidos: const ['Diego', 'Ana'],
          ),
        ),
      );

      expect(find.textContaining('Ver jugadores inscritos'), findsNothing);
    });

    testWidgets('muestra los nombres de quienes se unieron', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            jugadoresUnidos: const ['Diego', 'Ana'],
          ),
        ),
      );

      await tester.tap(find.text('Ver jugadores inscritos (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Jugadores inscritos (2)'), findsOneWidget);
      expect(find.text('Diego'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('avisa cuando todavía no se unió nadie', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(partido: crearPartido(), jugadoresUnidos: const []),
        ),
      );

      await tester.tap(find.text('Ver jugadores inscritos (0)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no se unió nadie desde Explorar.'),
        findsOneWidget,
      );
    });
  });

  group('Lista de suplentes', () {
    testWidgets('un equipo completo ofrece entrar como suplente', (
      tester,
    ) async {
      var entradas = 0;
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(
              estado: EstadoPartido.equipoCompleto,
              soyOrganizador: false,
              estoyUnido: false,
            ),
            onEntrarEnEspera: () => entradas++,
          ),
        ),
      );

      final boton = find.widgetWithText(OutlinedButton, 'Entrar como suplente');
      expect(boton, findsOneWidget);
      expect(find.text('Unirme al equipo'), findsNothing);
      expect(tester.getSize(boton).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      expect(entradas, 1);
    });

    testWidgets('el suplente ve su turno y puede cancelar', (tester) async {
      var cancelaciones = 0;
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(
              estado: EstadoPartido.equipoCompleto,
              soyOrganizador: false,
              estoyUnido: false,
            ).copyWith(posicionEspera: 2),
            onSalirDeEspera: () => cancelaciones++,
          ),
        ),
      );

      expect(find.textContaining('Turno 2'), findsOneWidget);
      final boton = find.widgetWithText(OutlinedButton, 'Cancelar espera');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      expect(cancelaciones, 1);
    });

    testWidgets('el organizador ve el orden de suplentes', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(estado: EstadoPartido.equipoCompleto),
            suplentes: const ['Beto', 'Carla'],
          ),
        ),
      );

      final boton = find.text('Ver suplentes (2)');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Carla'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  testWidgets(
    '50 nombres no agrandan la tarjeta y la lista permite desplazarse',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            jugadoresUnidos: const ['Jugador 1'],
          ),
        ),
      );
      final altura = tester.getSize(find.byType(TarjetaPartido)).height;

      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            jugadoresUnidos: List.generate(50, (i) => 'Jugador ${i + 1}'),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TarjetaPartido)).height, altura);
      await tester.tap(find.text('Ver jugadores inscritos (50)'));
      await tester.pumpAndSettle();
      expect(find.text('Jugadores inscritos (50)'), findsOneWidget);
      expect(find.text('Jugador 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Jugador 50'),
        250,
        scrollable: find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Jugador 50').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('Clase 16 · Fitts: editar y eliminar fáciles de alcanzar', () {
    testWidgets('son botones con texto de al menos 48 px de alto', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            onEditar: () {},
            onEliminar: () {},
          ),
        ),
      );

      final editar = find.widgetWithText(OutlinedButton, 'Editar');
      final eliminar = find.widgetWithText(TextButton, 'Eliminar');
      expect(editar, findsOneWidget);
      expect(eliminar, findsOneWidget);
      expect(tester.getSize(editar).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(eliminar).height, greaterThanOrEqualTo(48));
    });

    testWidgets('eliminar queda separado de editar', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            onEditar: () {},
            onEliminar: () {},
          ),
        ),
      );

      final finEditar = tester
          .getRect(find.widgetWithText(OutlinedButton, 'Editar'))
          .right;
      final inicioEliminar = tester
          .getRect(find.widgetWithText(TextButton, 'Eliminar'))
          .left;
      expect(inicioEliminar - finEditar, greaterThanOrEqualTo(16));
    });

    testWidgets('cada botón ejecuta su propia acción', (tester) async {
      var editados = 0;
      var eliminados = 0;
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(),
            onEditar: () => editados++,
            onEliminar: () => eliminados++,
          ),
        ),
      );

      await tester.tap(find.text('Editar'));
      expect(editados, 1);
      expect(eliminados, 0);

      await tester.tap(find.text('Eliminar'));
      expect(eliminados, 1);
    });

    testWidgets('también están con el equipo completo', (tester) async {
      await tester.pumpWidget(
        envolver(
          TarjetaPartido(
            partido: crearPartido(estado: EstadoPartido.equipoCompleto),
            onEditar: () {},
            onEliminar: () {},
          ),
        ),
      );

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });
  });
}
