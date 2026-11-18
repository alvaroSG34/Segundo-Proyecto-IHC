import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/evento_historial.dart';

void main() {
  final ahora = DateTime(2030, 4, 10, 12);

  Map<String, dynamic> fila({
    required DateTime fecha,
    int ocupados = 1,
    String estado = 'cuposAbiertos',
  }) => {
    'id': 'partido-1',
    'titulo': 'Partido de prueba',
    'disciplina': 'Futsal',
    'ubicacion': 'Cancha',
    'fecha_inicio': fecha.toIso8601String(),
    'organizador_id': 'organizador',
    'cupos_ocupados': ocupados,
    'cupos_totales': 4,
    'estado': estado,
  };

  test('clasifica las filas del historial por fecha, cupos y convocatoria', () {
    EventoHistorial evento(Map<String, dynamic> datos) =>
        EventoHistorial.desdeFila(
          datos,
          usuarioActualId: 'jugador',
          ahora: ahora,
        );

    expect(
      evento(fila(fecha: ahora.subtract(const Duration(days: 1)))).resultado,
      ResultadoPartido.finalizado,
    );
    expect(
      evento(fila(fecha: ahora.add(const Duration(days: 1)), ocupados: 4))
          .resultado,
      ResultadoPartido.equipoCompleto,
    );
    expect(
      evento(
        fila(
          fecha: ahora.add(const Duration(days: 1)),
          estado: 'equipoCompleto',
        ),
      ).resultado,
      ResultadoPartido.convocatoriaCerrada,
    );
    final abierto = evento(fila(fecha: ahora.add(const Duration(days: 1))));
    expect(abierto.resultado, ResultadoPartido.enConvocatoria);
    expect(abierto.rol, RolParticipacion.jugador);
    expect(abierto.organizadorNombre, 'Organizador');
    expect(abierto.fechaAmigable(ahora: ahora), 'Mañana · 12:00');
  });

  test('reconoce al organizador por identidad o por el rol de la fila', () {
    final datos = fila(fecha: ahora.add(const Duration(days: 2)));
    final porId = EventoHistorial.desdeFila(
      datos,
      usuarioActualId: 'organizador',
      ahora: ahora,
    );
    final porRol = EventoHistorial.desdeFila(
      {...datos, 'rol': 'organizador'},
      usuarioActualId: 'otro',
      ahora: ahora,
    );
    expect(porId.rol, RolParticipacion.organizador);
    expect(porRol.id, 'partido-1_organizador');
    expect(porId.fechaAmigable(ahora: ahora), porId.fechaHoraTexto);
  });
}
