import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';

/// Pruebas de la edición de partidos:
/// - la regla de cupos al editar (el equipo completo no admite más cupos), y
/// - que editar conserve la fecha y la hora del partido.
///
/// Ejecutar con:  flutter test test/edicion_partido_test.dart
ModeloPartido crearPartido({
  int cuposTotales = 10,
  int cuposOcupados = 4,
  EstadoPartido estado = EstadoPartido.cuposAbiertos,
  String fechaHora = '15/06/2099 · 09:30',
}) {
  return ModeloPartido(
    id: 'p-1',
    titulo: 'Futsal nocturno',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Coliseo Campus',
    fechaHora: fechaHora,
    cuposTotales: cuposTotales,
    cuposOcupados: cuposOcupados,
    organizadorNombre: 'Lorgio',
    soyOrganizador: true,
    estoyUnido: true,
    estado: estado,
  );
}

void main() {
  group('Regla de edición de cupos', () {
    test('con cupos abiertos se pueden subir los cupos y sigue abierto', () {
      final editado = crearPartido(cuposTotales: 10).conCuposTotales(12);

      expect(editado.cuposTotales, 12);
      expect(editado.estado, EstadoPartido.cuposAbiertos);
    });

    test('si los cupos quedan iguales a los inscritos, pasa a Equipo completo', () {
      final editado = crearPartido(
        cuposTotales: 10,
        cuposOcupados: 4,
      ).conCuposTotales(4);

      expect(editado.estado, EstadoPartido.equipoCompleto);
      expect(editado.puedeAgregarJugador, isFalse);
    });

    test('con el equipo completo no se pueden subir los cupos (rechazado)', () {
      final completo = crearPartido(
        cuposTotales: 10,
        cuposOcupados: 10,
        estado: EstadoPartido.equipoCompleto,
      );

      expect(completo.puedeCambiarCupos, isFalse);
      expect(
        completo.motivoBloqueoCambiarCupos,
        'El equipo ya está completo: no se pueden cambiar los cupos.',
      );
      expect(() => completo.conCuposTotales(12), throwsStateError);
    });

    test('un equipo completo se puede editar si no cambian los cupos', () {
      final completo = crearPartido(
        cuposTotales: 10,
        cuposOcupados: 10,
        estado: EstadoPartido.equipoCompleto,
      );

      expect(completo.conCuposTotales(10), same(completo));
    });

    test('no se puede dejar menos cupos que jugadores inscritos', () {
      expect(
        () => crearPartido(cuposOcupados: 4).conCuposTotales(3),
        throwsStateError,
      );
    });
  });

  group('Formulario de edición', () {
    Future<ModeloPartido?> editarYGuardar(
      WidgetTester tester,
      ModeloPartido partido, {
      Future<void> Function()? antesDeGuardar,
    }) async {
      ModeloPartido? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (contexto) => ElevatedButton(
              onPressed: () async {
                resultado = await Navigator.push<ModeloPartido>(
                  contexto,
                  MaterialPageRoute(
                    builder: (_) => VistaCrearPartido(
                      organizadorNombre: 'Lorgio',
                      partidoAEditar: partido,
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      if (antesDeGuardar != null) await antesDeGuardar();

      final guardar = find.text('Guardar cambios');
      await tester.ensureVisible(guardar);
      await tester.pumpAndSettle();
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('editar conserva la fecha y la hora del partido', (
      tester,
    ) async {
      final partido = crearPartido(fechaHora: '15/06/2099 · 09:30');

      final guardado = await editarYGuardar(
        tester,
        partido,
        antesDeGuardar: () async {
          expect(find.text('15/06/2099'), findsOneWidget);
          expect(find.text('09:30'), findsWidgets);
        },
      );

      expect(guardado, isNotNull);
      expect(guardado!.fechaHora, '15/06/2099 · 09:30');
    });

    testWidgets(
      'con el equipo completo los cupos están bloqueados y se explica el motivo',
      (tester) async {
        final completo = crearPartido(
          cuposTotales: 6,
          cuposOcupados: 6,
          estado: EstadoPartido.equipoCompleto,
        );

        final guardado = await editarYGuardar(
          tester,
          completo,
          antesDeGuardar: () async {
            expect(
              find.text(
                'El equipo ya está completo: no se pueden cambiar los cupos.',
              ),
              findsOneWidget,
            );
            // El botón "+" no hace nada: los cupos siguen en 6
            final mas = find.byIcon(LucideIcons.plus);
            await tester.ensureVisible(mas);
            await tester.tap(mas, warnIfMissed: false);
            await tester.pump();
          },
        );

        expect(guardado!.cuposTotales, 6);
        expect(guardado.estado, EstadoPartido.equipoCompleto);
      },
    );
  });
}
