import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';

/// Flujo entre dos estudiantes sobre una base compartida (requisitos #5 y #6):
/// Lorgio organiza, Diego y Ana se unen, y cada uno ve lo que le corresponde.
/// Usa el repositorio en memoria, con el mismo contrato que Supabase.
///
/// Ejecutar con:  flutter test test/flujo_partidos_test.dart
late RepositorioEnMemoria bd;

void comoLorgio() => bd.usarSesionDe('u-lorgio', 'Lorgio');
void comoDiego() => bd.usarSesionDe('u-diego', 'Diego');
void comoAna() => bd.usarSesionDe('u-ana', 'Ana');

ModeloPartido nuevoPartido({
  int cupos = 10,
  String fechaHora = '10/10/2099 · 19:00',
}) {
  return ModeloPartido(
    id: '',
    titulo: 'Futsal nocturno',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Coliseo Campus',
    fechaHora: fechaHora,
    cuposTotales: cupos,
    cuposOcupados: 1,
    organizadorNombre: 'Lorgio',
    soyOrganizador: true,
    estoyUnido: true,
  );
}

void main() {
  setUp(() => bd = RepositorioEnMemoria());

  test(
    'lo que crea un estudiante lo ven los demás, pero no él mismo en Explorar',
    () async {
      comoLorgio();
      final creado = await bd.crearPartido(nuevoPartido());
      expect(await bd.buscarPartidos(const FiltroPartidos()), isEmpty);

      comoDiego();
      final vistos = await bd.buscarPartidos(const FiltroPartidos());
      expect(vistos.single.id, creado.id);
      expect(vistos.single.soyOrganizador, isFalse);
      expect(vistos.single.puedeUnirse, isTrue);
    },
  );

  test('la unión se guarda y el organizador ve quién se unió', () async {
    comoLorgio();
    final creado = await bd.crearPartido(nuevoPartido());

    comoDiego();
    final unido = await bd.unirseAPartido(creado.id);
    expect(unido.cuposOcupados, 2);
    expect((await bd.obtenerPartidosUnidos()).single.id, creado.id);

    comoLorgio();
    expect((await bd.obtenerMisPartidos()).single.cuposOcupados, 2);
    expect((await bd.obtenerJugadoresInscritos())[creado.id], ['Diego']);
  });

  test('no se puede unir dos veces y los cupos no cambian', () async {
    comoLorgio();
    final creado = await bd.crearPartido(nuevoPartido());
    comoDiego();
    await bd.unirseAPartido(creado.id);

    await expectLater(
      bd.unirseAPartido(creado.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'motivo',
          'Ya formas parte de este equipo.',
        ),
      ),
    );
    comoLorgio();
    expect((await bd.obtenerMisPartidos()).single.cuposOcupados, 2);
  });

  test(
    'el último cupo completa el equipo y el siguiente es rechazado',
    () async {
      comoLorgio();
      final creado = await bd.crearPartido(nuevoPartido(cupos: 2));

      comoDiego();
      final unido = await bd.unirseAPartido(creado.id);
      expect(unido.estado, EstadoPartido.equipoCompleto);

      comoAna();
      await expectLater(
        bd.unirseAPartido(creado.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'motivo',
            'Convocatoria cerrada: el equipo ya está completo.',
          ),
        ),
      );
    },
  );

  test('no se puede unir a un partido cuya fecha ya pasó', () async {
    comoLorgio();
    final creado = await bd.crearPartido(
      nuevoPartido(fechaHora: '01/03/2024 · 18:00'),
    );

    comoDiego();
    await expectLater(
      bd.unirseAPartido(creado.id),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'motivo',
          'El partido ya se jugó: su fecha ya pasó.',
        ),
      ),
    );
  });

  test('solo el organizador puede editar o eliminar', () async {
    comoLorgio();
    final creado = await bd.crearPartido(nuevoPartido());

    comoDiego();
    expect(() => bd.eliminarPartido(creado.id), throwsStateError);
    expect(
      () => bd.editarPartido(creado.copyWith(titulo: 'Otro')),
      throwsStateError,
    );
  });

  test(
    'si el organizador elimina el partido desaparece para el jugador',
    () async {
      comoLorgio();
      final creado = await bd.crearPartido(nuevoPartido());
      comoDiego();
      await bd.unirseAPartido(creado.id);

      comoLorgio();
      await bd.eliminarPartido(creado.id);

      comoDiego();
      expect(await bd.obtenerPartidosUnidos(), isEmpty);
      expect(await bd.buscarPartidos(const FiltroPartidos()), isEmpty);
    },
  );
}
