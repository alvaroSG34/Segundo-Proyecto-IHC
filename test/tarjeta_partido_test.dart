import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

/// Pruebas de la interfaz: la acción "Agregar jugador" y su bloqueo
/// cuando el equipo está completo, y la acción "Unirme al equipo" con el
/// motivo de cada rechazo (Issue #4).
///
/// Ejecutar con:  flutter test test/tarjeta_partido_test.dart
ModeloPartido crearPartido({
  EstadoPartido estado = EstadoPartido.cuposAbiertos,
  bool soyOrganizador = true,
  bool estoyUnido = true,
  String fechaHora = '10/10/2099 · 19:00',
}) {
  return ModeloPartido(
    id: 'p-1',
    titulo: 'Futsal nocturno',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Cancha 2',
    fechaHora: fechaHora,
    cuposTotales: 10,
    cuposOcupados: estado == EstadoPartido.equipoCompleto ? 10 : 3,
    organizadorNombre: 'Lorgio',
    soyOrganizador: soyOrganizador,
    estoyUnido: estoyUnido,
    estado: estado,
  );
}

Widget envolver(Widget hijo) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo)));

void main() {
  testWidgets('con cupos abiertos se puede agregar un jugador y no hay aviso de bloqueo', (
    tester,
  ) async {
    var llamadas = 0;
    await tester.pumpWidget(
      envolver(
        TarjetaPartido(
          partido: crearPartido(),
          onAgregarJugador: () => llamadas++,
          onCompletarEquipo: () {},
        ),
      ),
    );

    await tester.tap(find.text('Agregar jugador'));

    expect(llamadas, 1);
    expect(find.textContaining('No puedes agregar más jugadores'), findsNothing);
  });

  testWidgets('con el equipo completo la interfaz explica por qué no se pueden agregar jugadores', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        TarjetaPartido(
          partido: crearPartido(estado: EstadoPartido.equipoCompleto),
          onAgregarJugador: () {},
          onCompletarEquipo: () {},
        ),
      ),
    );

    expect(find.textContaining('No puedes agregar más jugadores'), findsOneWidget);
    expect(find.textContaining('el equipo ya está completo'), findsOneWidget);
    // El botón "Completar equipo" ya no se ofrece
    expect(find.text('Completar equipo'), findsNothing);
  });

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
        envolver(TarjetaPartido(
          partido: crearPartido(soyOrganizador: false, estoyUnido: true),
          jugadoresUnidos: const ['Diego', 'Ana'],
        )),
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
        envolver(TarjetaPartido(
          partido: crearPartido(soyOrganizador: false, estoyUnido: false),
          jugadoresUnidos: const ['Diego', 'Ana'],
        )),
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
        envolver(TarjetaPartido(partido: crearPartido(), jugadoresUnidos: const [])),
      );

      await tester.tap(find.text('Ver jugadores inscritos (0)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no se unió nadie desde Explorar.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('50 nombres no agrandan la tarjeta y la lista permite desplazarse', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(envolver(TarjetaPartido(
      partido: crearPartido(),
      jugadoresUnidos: const ['Jugador 1'],
    )));
    final altura = tester.getSize(find.byType(TarjetaPartido)).height;

    await tester.pumpWidget(envolver(TarjetaPartido(
      partido: crearPartido(),
      jugadoresUnidos: List.generate(50, (i) => 'Jugador ${i + 1}'),
    )));
    expect(tester.getSize(find.byType(TarjetaPartido)).height, altura);
    await tester.tap(find.text('Ver jugadores inscritos (50)'));
    await tester.pumpAndSettle();
    expect(find.text('Jugadores inscritos (50)'), findsOneWidget);
    expect(find.text('Jugador 1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Jugador 50'), 250,
      scrollable: find.descendant(of: find.byType(AlertDialog), matching: find.byType(Scrollable)));
    expect(find.text('Jugador 50').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Clase 16 · Fitts: editar y eliminar fáciles de alcanzar', () {
    testWidgets('son botones con texto de al menos 48 px de alto', (tester) async {
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
