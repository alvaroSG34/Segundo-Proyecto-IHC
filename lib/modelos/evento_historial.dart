import 'modelo_partido.dart';

/// Rol que desempeñó el usuario en el partido.
enum RolParticipacion {
  organizador('Organizador', 'Creaste la convocatoria'),
  jugador('Jugador', 'Te uniste al equipo');

  final String etiqueta;
  final String descripcion;
  const RolParticipacion(this.etiqueta, this.descripcion);
}

/// Estado o resultado del partido según la fecha y convocatoria.
enum ResultadoPartido {
  finalizado('Finalizado', 'Partido disputado'),
  enConvocatoria('Convocatoria abierta', 'Buscando jugadores'),
  convocatoriaCerrada('Convocatoria cerrada', 'Cerrada por el organizador'),
  equipoCompleto('Equipo completo', 'Todos los cupos están ocupados');

  final String etiqueta;
  final String detalle;
  const ResultadoPartido(this.etiqueta, this.detalle);
}

/// Representa una entrada en la trayectoria o historial de participación
/// del estudiante en UniSport (Clase 16).
///
/// Responde a las 4 preguntas esenciales:
/// - ¿Qué ocurrió? (rol y acción realizada: organizó o se unió).
/// - ¿Cuándo ocurrió? (fecha y hora del partido).
/// - ¿Cuál fue el resultado? (finalizado, completo o abierto).
/// - ¿Qué elemento estuvo involucrado? (partido, disciplina, cancha y cupos).
class EventoHistorial {
  final String id;
  final String partidoId;
  final String tituloPartido;
  final String disciplina;
  final String ubicacion;
  final DateTime fechaInicio;
  final String fechaHoraTexto;
  final RolParticipacion rol;
  final ResultadoPartido resultado;
  final int cuposOcupados;
  final int cuposTotales;
  final String organizadorNombre;

  const EventoHistorial({
    required this.id,
    required this.partidoId,
    required this.tituloPartido,
    required this.disciplina,
    required this.ubicacion,
    required this.fechaInicio,
    required this.fechaHoraTexto,
    required this.rol,
    required this.resultado,
    required this.cuposOcupados,
    required this.cuposTotales,
    required this.organizadorNombre,
  });

  /// Determina si el partido ya se disputó tomando como referencia [ahora].
  bool get yaDisputado => resultado == ResultadoPartido.finalizado;

  /// Retorna un texto amigable y de baja carga cognitiva para la fecha.
  String fechaAmigable({DateTime? ahora}) {
    final ref = ahora ?? DateTime.now();
    final inicio = fechaInicio;
    final esMismoDia =
        inicio.year == ref.year &&
        inicio.month == ref.month &&
        inicio.day == ref.day;
    final diferenciaDias = DateTime(
      inicio.year,
      inicio.month,
      inicio.day,
    ).difference(DateTime(ref.year, ref.month, ref.day)).inDays;

    final horaMinuto =
        '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';

    if (esMismoDia) {
      return 'Hoy · $horaMinuto';
    } else if (diferenciaDias == 1) {
      return 'Mañana · $horaMinuto';
    } else if (diferenciaDias == -1) {
      return 'Ayer · $horaMinuto';
    }
    return fechaHoraTexto;
  }

  /// Construye un evento a partir de un [ModeloPartido] y el contexto del usuario.
  factory EventoHistorial.desdePartido(
    ModeloPartido partido, {
    DateTime? ahora,
  }) {
    final ref = ahora ?? DateTime.now();
    final fecha = partido.fechaInicio ?? ref;
    final paso = fecha.isBefore(ref);

    final ResultadoPartido res;
    if (paso) {
      res = ResultadoPartido.finalizado;
    } else if (partido.estaLleno) {
      res = ResultadoPartido.equipoCompleto;
    } else if (partido.estado == EstadoPartido.equipoCompleto) {
      res = ResultadoPartido.convocatoriaCerrada;
    } else {
      res = ResultadoPartido.enConvocatoria;
    }

    final rol = partido.soyOrganizador
        ? RolParticipacion.organizador
        : RolParticipacion.jugador;

    return EventoHistorial(
      id: '${partido.id}_${rol.name}',
      partidoId: partido.id,
      tituloPartido: partido.titulo,
      disciplina: partido.disciplina,
      ubicacion: partido.ubicacion,
      fechaInicio: fecha,
      fechaHoraTexto: partido.fechaHora,
      rol: rol,
      resultado: res,
      cuposOcupados: partido.cuposOcupados,
      cuposTotales: partido.cuposTotales,
      organizadorNombre: partido.organizadorNombre,
    );
  }

  /// Construye un evento a partir de una fila devuelta por Supabase.
  factory EventoHistorial.desdeFila(
    Map<String, dynamic> fila, {
    required String usuarioActualId,
    DateTime? ahora,
  }) {
    final ref = ahora ?? DateTime.now();
    final inicio = DateTime.parse(fila['fecha_inicio'] as String).toLocal();
    final paso = inicio.isBefore(ref);
    final estadoStr = fila['estado'] as String? ?? 'cuposAbiertos';
    final cuposOcupados = fila['cupos_ocupados'] as int;
    final cuposTotales = fila['cupos_totales'] as int;

    final ResultadoPartido res;
    if (paso) {
      res = ResultadoPartido.finalizado;
    } else if (cuposOcupados >= cuposTotales) {
      res = ResultadoPartido.equipoCompleto;
    } else if (estadoStr == 'equipoCompleto') {
      res = ResultadoPartido.convocatoriaCerrada;
    } else {
      res = ResultadoPartido.enConvocatoria;
    }

    final esOrganizador =
        (fila['organizador_id'] as String?) == usuarioActualId ||
        (fila['rol'] as String?) == 'organizador';

    final rol = esOrganizador
        ? RolParticipacion.organizador
        : RolParticipacion.jugador;

    final disciplina = fila['disciplina'] as String;

    return EventoHistorial(
      id: '${fila['id']}_${rol.name}',
      partidoId: fila['id'] as String,
      tituloPartido: fila['titulo'] as String,
      disciplina: disciplina,
      ubicacion: fila['ubicacion'] as String,
      fechaInicio: inicio,
      fechaHoraTexto: ModeloPartido.formatearFechaHora(inicio),
      rol: rol,
      resultado: res,
      cuposOcupados: cuposOcupados,
      cuposTotales: cuposTotales,
      organizadorNombre: fila['organizador_nombre'] as String? ?? 'Organizador',
    );
  }
}
