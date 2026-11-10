import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';

void main() {
  ModeloPartido partidoFuturo(int cupos) => ModeloPartido(
    id: '',
    titulo: 'Partido de futsal',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Cancha A',
    fechaHora: ModeloPartido.formatearFechaHora(
      DateTime.now().add(const Duration(days: 5)),
    ),
    cuposTotales: cupos,
    cuposOcupados: 1,
    organizadorNombre: 'Organizador',
  );

  test(
    'reprogramar conserva plazas y promueve al primer suplente al retirarse',
    () async {
      final repo = RepositorioEnMemoria();
      repo.usarSesionDe('organizador', 'Organizador');
      final partido = await repo.crearPartido(partidoFuturo(3));
      repo.usarSesionDe('ana', 'Ana');
      await repo.unirseAPartido(partido.id);
      repo.usarSesionDe('beto', 'Beto');
      await repo.unirseAPartido(partido.id);
      repo.usarSesionDe('carla', 'Carla');
      await repo.entrarEnEspera(partido.id);

      final fechaNueva = DateTime.now().add(const Duration(days: 8));
      repo.usarSesionDe('organizador', 'Organizador');
      final cambiado = await repo.reprogramarPartido(
        partido.id,
        fechaNueva,
        'Cancha B',
        'La cancha A no está disponible',
      );
      expect(cambiado.cuposOcupados, 3);
      expect(cambiado.respuestasPendientes, 2);
      expect(cambiado.fechaAnterior, partido.fechaHora);
      expect(cambiado.ubicacionAnterior, 'Cancha A');
      await expectLater(
        repo.reprogramarPartido(
          partido.id,
          fechaNueva,
          'Cancha C',
          'Otro cambio',
        ),
        throwsStateError,
      );

      repo.usarSesionDe('ana', 'Ana');
      expect(
        (await repo.obtenerPartidosUnidos()).single.reconfirmacionPendiente,
        isTrue,
      );
      await repo.responderReprogramacion(partido.id, true);
      expect(
        (await repo.obtenerPartidosUnidos()).single.reconfirmacionAceptada,
        isTrue,
      );
      await expectLater(
        repo.responderReprogramacion(partido.id, true),
        throwsStateError,
      );

      repo.usarSesionDe('beto', 'Beto');
      await repo.responderReprogramacion(partido.id, false);
      expect(await repo.obtenerPartidosUnidos(), isEmpty);
      repo.usarSesionDe('carla', 'Carla');
      final promovido = (await repo.obtenerPartidosUnidos()).single;
      expect(promovido.cuposOcupados, 3);
      expect(promovido.reconfirmacionPendiente, isTrue);
      await repo.responderReprogramacion(partido.id, true);

      repo.usarSesionDe('organizador', 'Organizador');
      final finalPartido = (await repo.obtenerMisPartidos()).single;
      expect(finalPartido.respuestasPendientes, 0);
      expect(finalPartido.cuposOcupados, 3);
      expect(finalPartido.estaLleno, isTrue);
      expect(
        (await repo.obtenerParticipantes(partido.id))
            .where((p) => !p.esOrganizador)
            .map((p) => p.nombre),
        ['Ana', 'Carla'],
      );
      expect(await repo.obtenerSuplentes(), isEmpty);
    },
  );

  test(
    'sin suplente, retirarse libera un cupo y termina la reconfirmación',
    () async {
      final repo = RepositorioEnMemoria();
      repo.usarSesionDe('organizador', 'Organizador');
      final partido = await repo.crearPartido(partidoFuturo(2));
      repo.usarSesionDe('ana', 'Ana');
      await repo.unirseAPartido(partido.id);
      repo.usarSesionDe('organizador', 'Organizador');
      await repo.reprogramarPartido(
        partido.id,
        DateTime.now().add(const Duration(days: 9)),
        'Cancha B',
        'Cambio de horario',
      );
      repo.usarSesionDe('ana', 'Ana');
      await repo.responderReprogramacion(partido.id, false);
      repo.usarSesionDe('organizador', 'Organizador');
      final resultado = (await repo.obtenerMisPartidos()).single;
      expect(resultado.cuposOcupados, 1);
      expect(resultado.respuestasPendientes, 0);
      expect(resultado.estado, EstadoPartido.cuposAbiertos);
    },
  );
}
