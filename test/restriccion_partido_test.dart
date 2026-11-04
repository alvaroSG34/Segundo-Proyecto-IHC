import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';

void main() {
  group(
    'Restricción UniSport: Un equipo completo no permite agregar más jugadores',
    () {
      late ModeloPartido partidoAbierto;

      setUp(() {
        partidoAbierto = ModeloPartido(
          id: 'p-test-01',
          titulo: 'Futsal 5v5 Facultad',
          disciplina: 'Fútbol',
          icono: 'Fútbol',
          ubicacion: 'Cancha 1',
          fechaHora: 'Hoy · 19:00',
          cuposTotales: 10,
          cuposOcupados: 5,
          organizadorNombre: 'Diego Astete',
          soyOrganizador: false,
          estoyUnido: false,
          estado: EstadoPartido.cuposAbiertos,
        );
      });

      test('1. Un partido con cupos abiertos permite inscribirse', () {
        expect(partidoAbierto.puedeAgregarJugador, isTrue);
        expect(partidoAbierto.motivoBloqueoAgregarJugador, isNull);

        final actualizado = partidoAbierto.unirse();
        expect(actualizado.cuposOcupados, equals(6));
        expect(actualizado.estoyUnido, isTrue);
        expect(actualizado.estado, equals(EstadoPartido.cuposAbiertos));
      });

      test('2. Restricción: un partido en estado "Equipo completo" no permite agregar jugadores', () {
        final partidoCompleto = partidoAbierto.copyWith(
          estado: EstadoPartido.equipoCompleto,
          cuposOcupados: 10,
        );

        expect(partidoCompleto.puedeAgregarJugador, isFalse);
      });

      test('3. Explica claramente el motivo del bloqueo cuando el equipo está completo', () {
        final partidoCompleto = partidoAbierto.copyWith(
          estado: EstadoPartido.equipoCompleto,
          cuposOcupados: 10,
        );

        final motivo = partidoCompleto.motivoBloqueoAgregarJugador;
        expect(motivo, isNotNull);
        expect(motivo, contains('el equipo ya está completo'));
      });

      test('4. Intentar inscribirse en un equipo completo lanza StateError con la razón', () {
        final partidoCompleto = partidoAbierto.copyWith(
          estado: EstadoPartido.equipoCompleto,
          cuposOcupados: 10,
        );

        expect(
          () => partidoCompleto.unirse(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'mensaje',
              contains('el equipo ya está completo'),
            ),
          ),
        );
      });

      test('5. Al llenar el último cupo disponible el partido pasa automáticamente a equipo completo', () {
        final casiLleno = partidoAbierto.copyWith(cuposOcupados: 9);

        final lleno = casiLleno.unirse();
        expect(lleno.cuposOcupados, equals(10));
        expect(lleno.estado, equals(EstadoPartido.equipoCompleto));
        expect(lleno.puedeAgregarJugador, isFalse);
      });
    },
  );
}
