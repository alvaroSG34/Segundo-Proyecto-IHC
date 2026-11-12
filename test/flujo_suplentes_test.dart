import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';

ModeloPartido partidoDePrueba() => ModeloPartido(
  id: 'partido-1',
  titulo: 'Futsal del jueves',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Cancha 1',
  fechaHora: '10/11/2099 · 19:00',
  cuposTotales: 2,
  cuposOcupados: 1,
  organizadorNombre: 'Organizador',
);

void main() {
  test(
    'sale un titular y entra el primer suplente; el siguiente avanza',
    () async {
      final repo = RepositorioEnMemoria(
        usuarioId: 'org',
        usuarioNombre: 'Organizador',
      );
      repo.sembrar('org', partidoDePrueba());

      repo.usarSesionDe('ana', 'Ana');
      final lleno = await repo.unirseAPartido('partido-1');
      expect(lleno.cuposOcupados, 2);
      expect(lleno.estado, EstadoPartido.equipoCompleto);

      repo.usarSesionDe('beto', 'Beto');
      final primerSuplente = await repo.entrarEnEspera('partido-1');
      expect(primerSuplente.posicionEspera, 1);
      expect(primerSuplente.cuposOcupados, 2);
      await expectLater(repo.unirseAPartido('partido-1'), throwsStateError);
      await expectLater(repo.entrarEnEspera('partido-1'), throwsStateError);

      repo.usarSesionDe('carla', 'Carla');
      expect((await repo.entrarEnEspera('partido-1')).posicionEspera, 2);

      repo.usarSesionDe('ana', 'Ana');
      final despuesDeSalir = await repo.salirDelPartido('partido-1');
      expect(despuesDeSalir.cuposOcupados, 2);
      expect(despuesDeSalir.estado, EstadoPartido.equipoCompleto);

      repo.usarSesionDe('beto', 'Beto');
      final ascendido = (await repo.buscarPartidos(const FiltroPartidos()))
          .single;
      expect(ascendido.estoyUnido, isTrue);
      expect(ascendido.estoyEnEspera, isFalse);

      repo.usarSesionDe('carla', 'Carla');
      expect(
        (await repo.buscarPartidos(const FiltroPartidos()))
            .single
            .posicionEspera,
        1,
      );

      repo.usarSesionDe('org', 'Organizador');
      expect(await repo.obtenerSuplentes(), {
        'partido-1': ['Carla'],
      });
      expect(await repo.obtenerBajasTardias(), isEmpty);
      expect(
        (await repo.obtenerParticipantes('partido-1'))
            .where((p) => !p.esOrganizador)
            .map((p) => p.nombre),
        ['Beto'],
      );
    },
  );

  test('una salida dentro de dos horas queda como baja tardía', () async {
    final repo = RepositorioEnMemoria(
      usuarioId: 'org',
      usuarioNombre: 'Organizador',
    );
    final inicio = DateTime.now().add(const Duration(hours: 1));
    repo.sembrar(
      'org',
      partidoDePrueba().copyWith(
        fechaHora: ModeloPartido.formatearFechaHora(inicio),
      ),
    );

    repo.usarSesionDe('ana', 'Ana');
    await repo.unirseAPartido('partido-1');
    await repo.salirDelPartido('partido-1');
    expect(await repo.obtenerBajasTardias(), isEmpty);

    repo.usarSesionDe('org', 'Organizador');
    final bajas = await repo.obtenerBajasTardias();
    expect(bajas['partido-1'], hasLength(1));
    expect(bajas['partido-1']!.single.jugadorNombre, 'Ana');
  });

  test('el límite exacto de dos horas no es baja tardía', () {
    final ahora = DateTime(2099, 11, 10, 17);
    final partido = partidoDePrueba();
    expect(partido.esBajaTardia(ahora: ahora), isFalse);
    expect(
      partido
          .copyWith(fechaHora: '10/11/2099 · 18:59')
          .esBajaTardia(ahora: ahora),
      isTrue,
    );
    expect(
      partido
          .copyWith(fechaHora: '10/11/2099 · 19:01')
          .esBajaTardia(ahora: ahora),
      isFalse,
    );
  });

  test('cancelar espera respeta el orden y no ocupa un cupo', () async {
    final repo = RepositorioEnMemoria(
      usuarioId: 'org',
      usuarioNombre: 'Organizador',
    );
    repo.sembrar('org', partidoDePrueba());
    repo.usarSesionDe('ana', 'Ana');
    await repo.unirseAPartido('partido-1');
    repo.usarSesionDe('beto', 'Beto');
    await repo.entrarEnEspera('partido-1');
    repo.usarSesionDe('carla', 'Carla');
    await repo.entrarEnEspera('partido-1');

    repo.usarSesionDe('beto', 'Beto');
    expect((await repo.salirDeEspera('partido-1')).estoyEnEspera, isFalse);
    await expectLater(repo.salirDeEspera('partido-1'), throwsStateError);

    repo.usarSesionDe('carla', 'Carla');
    expect(
      (await repo.buscarPartidos(const FiltroPartidos())).single.posicionEspera,
      1,
    );

    repo.usarSesionDe('ana', 'Ana');
    await repo.salirDelPartido('partido-1');
    repo.usarSesionDe('carla', 'Carla');
    expect(
      (await repo.buscarPartidos(const FiltroPartidos())).single.estoyUnido,
      isTrue,
    );
  });

  test('sin suplentes, salir deja un cupo libre', () async {
    final repo = RepositorioEnMemoria(
      usuarioId: 'org',
      usuarioNombre: 'Organizador',
    );
    repo.sembrar('org', partidoDePrueba());
    repo.usarSesionDe('ana', 'Ana');
    await repo.unirseAPartido('partido-1');
    final abierto = await repo.salirDelPartido('partido-1');
    expect(abierto.cuposOcupados, 1);
    expect(abierto.estado, EstadoPartido.cuposAbiertos);
    expect(abierto.puedeEntrarEnEspera, isFalse);
  });

  test(
    'sin suplentes, salir deja el cupo libre y conserva cierre manual',
    () async {
      final repo = RepositorioEnMemoria(
        usuarioId: 'org',
        usuarioNombre: 'Organizador',
      );
      repo.sembrar(
        'org',
        partidoDePrueba().copyWith(cuposTotales: 6, cuposOcupados: 1),
      );
      repo.usarSesionDe('ana', 'Ana');
      await repo.unirseAPartido('partido-1');
      repo.usarSesionDe('org', 'Organizador');
      await repo.completarEquipo('partido-1');

      repo.usarSesionDe('ana', 'Ana');
      final cerrado = await repo.salirDelPartido('partido-1');

      expect(cerrado.cuposOcupados, 1);
      expect(cerrado.estado, EstadoPartido.equipoCompleto);
      expect(cerrado.puedeEntrarEnEspera, isTrue);
    },
  );
}
