import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';

ModeloPartido crearPartido({
  bool soyOrganizador = true,
  bool estoyUnido = true,
  EstadoPartido estado = EstadoPartido.cuposAbiertos,
  int cuposTotales = 10,
  int cuposOcupados = 3,
}) {
  return ModeloPartido(
    id: 'p-1',
    titulo: 'Futsal nocturno',
    disciplina: 'Futsal',
    icono: 'Futsal',
    ubicacion: 'Cancha 2',
    fechaHora: '10/10/2099 · 19:00',
    cuposTotales: cuposTotales,
    cuposOcupados: cuposOcupados,
    organizadorNombre: 'Lorgio',
    soyOrganizador: soyOrganizador,
    estoyUnido: estoyUnido,
    estado: estado,
  );
}

void main() {
  group('Estado del partido según las inscripciones', () {
    test('un partido nuevo nace con los cupos abiertos', () {
      final partido = crearPartido();

      expect(partido.estado, EstadoPartido.cuposAbiertos);
    });

    test('la inscripción que ocupa el último cupo completa el equipo', () {
      final partido = crearPartido(
        soyOrganizador: false,
        estoyUnido: false,
        cuposTotales: 4,
        cuposOcupados: 3,
      );

      final unido = partido.unirse();

      expect(unido.estado, EstadoPartido.equipoCompleto);
      expect(unido.cuposOcupados, 4);
      expect(unido.cuposRestantes, 0);
      expect(unido.estaLleno, isTrue);
      expect(unido.estoyUnido, isTrue);
      expect(partido.cuposOcupados, 3, reason: 'El original es inmutable.');
    });

    test('no se permite una inscripción después de completar el equipo', () {
      final completo = crearPartido(
        soyOrganizador: false,
        estoyUnido: false,
        estado: EstadoPartido.equipoCompleto,
        cuposTotales: 3,
        cuposOcupados: 3,
      );

      expect(() => completo.unirse(), throwsStateError);
    });

    test('el organizador cierra la convocatoria sin llenar cupos', () {
      final partido = crearPartido(cuposTotales: 10, cuposOcupados: 3);

      final cerrado = partido.completarEquipo();

      expect(cerrado.estado, EstadoPartido.equipoCompleto);
      expect(cerrado.cuposOcupados, 3);
      expect(cerrado.cuposTotales, 10);
      expect(cerrado.puedeUnirse, isFalse);
      expect(cerrado.etiquetaEstado, 'Convocatoria cerrada');
      expect(partido.estado, EstadoPartido.cuposAbiertos);
      expect(partido.cuposOcupados, 3);
    });

    test('solo el organizador puede cerrar una convocatoria abierta', () {
      final partido = crearPartido(soyOrganizador: false);

      expect(partido.puedeCompletarEquipo, isFalse);
      expect(() => partido.completarEquipo(), throwsStateError);
    });

    test('un retiro no reabre una convocatoria cerrada manualmente', () {
      final cerrado = crearPartido(
        soyOrganizador: false,
        estoyUnido: true,
        estado: EstadoPartido.equipoCompleto,
        cuposTotales: 10,
        cuposOcupados: 3,
      );

      final salido = cerrado.salir();

      expect(salido.cuposOcupados, 2);
      expect(salido.estado, EstadoPartido.equipoCompleto);
      expect(salido.etiquetaEstado, 'Convocatoria cerrada');
    });
  });

  group('Conservar las inscripciones después de recargar', () {
    test('el último cupo y el estado completo quedan guardados', () async {
      final repositorio = RepositorioEnMemoria(
        usuarioId: 'u-lorgio',
        usuarioNombre: 'Lorgio',
      );
      final creado = await repositorio.crearPartido(
        crearPartido(cuposTotales: 2, cuposOcupados: 1),
      );

      repositorio.usarSesionDe('u-diego', 'Diego');
      await repositorio.unirseAPartido(creado.id);

      repositorio.usarSesionDe('u-lorgio', 'Lorgio');
      final recuperado = (await repositorio.obtenerMisPartidos()).single;
      expect(recuperado.estado, EstadoPartido.equipoCompleto);
      expect(recuperado.cuposOcupados, recuperado.cuposTotales);
      expect(
        (await repositorio.obtenerParticipantes(creado.id))
            .where((p) => !p.esOrganizador)
            .map((p) => p.nombre),
        ['Diego'],
      );
    });

    test(
      'cerrar convocatoria no añade jugadores ni modifica los cupos',
      () async {
        final repositorio = RepositorioEnMemoria(
          usuarioId: 'u-lorgio',
          usuarioNombre: 'Lorgio',
        );
        final creado = await repositorio.crearPartido(
          crearPartido(cuposTotales: 10, cuposOcupados: 1),
        );

        final cerrado = await repositorio.completarEquipo(creado.id);

        expect(cerrado.estado, EstadoPartido.equipoCompleto);
        expect(cerrado.cuposOcupados, 1);
        expect(
          (await repositorio.obtenerParticipantes(creado.id))
              .where((p) => !p.esOrganizador),
          isEmpty,
        );
        await expectLater(
          repositorio.unirseAPartido(creado.id),
          throwsStateError,
        );
      },
    );

    test('la fecha real se convierte al texto de pantalla y de vuelta', () {
      final fecha = DateTime(2099, 6, 15, 9, 30);

      final texto = ModeloPartido.formatearFechaHora(fecha);

      expect(texto, '15/06/2099 · 09:30');
      expect(ModeloPartido.interpretarFechaHora(texto), fecha);
    });

    test('un partido guardado sin estado se recupera con cupos abiertos', () {
      final json = crearPartido().toJson()..remove('estado');

      final partido = ModeloPartido.fromJson(json);

      expect(partido.estado, EstadoPartido.cuposAbiertos);
    });
  });
}
