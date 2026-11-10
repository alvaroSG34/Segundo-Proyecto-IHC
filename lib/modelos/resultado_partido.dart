enum EstadoResultadoPartido {
  pendiente('Pendiente de confirmación'),
  disputado('Disputado'),
  confirmado('Confirmado');

  final String etiqueta;
  const EstadoResultadoPartido(this.etiqueta);
}

enum AccionResultadoPartido {
  registrado('Marcador registrado'),
  disputado('Marcador disputado'),
  corregido('Marcador corregido'),
  confirmado('Resultado confirmado');

  final String etiqueta;
  const AccionResultadoPartido(this.etiqueta);
}

class EventoResultadoPartido {
  final AccionResultadoPartido accion;
  final int marcadorEquipoA;
  final int marcadorEquipoB;
  final String? motivo;
  final String actorNombre;
  final DateTime fecha;

  const EventoResultadoPartido({
    required this.accion,
    required this.marcadorEquipoA,
    required this.marcadorEquipoB,
    required this.actorNombre,
    required this.fecha,
    this.motivo,
  });

  factory EventoResultadoPartido.desdeFila(Map<String, dynamic> fila) =>
      EventoResultadoPartido(
        accion: AccionResultadoPartido.values.byName(fila['accion'] as String),
        marcadorEquipoA: fila['marcador_equipo_a'] as int,
        marcadorEquipoB: fila['marcador_equipo_b'] as int,
        motivo: fila['motivo'] as String?,
        actorNombre: fila['actor_nombre'] as String,
        fecha: DateTime.parse(fila['creado_en'] as String).toLocal(),
      );
}

class ResultadoValidadoPartido {
  final String revision;
  final int marcadorEquipoA;
  final int marcadorEquipoB;
  final EstadoResultadoPartido estado;
  final String? motivoDisputa;
  final List<EventoResultadoPartido> historial;

  ResultadoValidadoPartido({
    required this.revision,
    required this.marcadorEquipoA,
    required this.marcadorEquipoB,
    required this.estado,
    this.motivoDisputa,
    List<EventoResultadoPartido> historial = const [],
  }) : historial = List.unmodifiable(historial);

  bool get esDefinitivo => estado == EstadoResultadoPartido.confirmado;

  String get marcador => '$marcadorEquipoA - $marcadorEquipoB';

  factory ResultadoValidadoPartido.desdeFila(
    Map<String, dynamic> fila, {
    List<EventoResultadoPartido> historial = const [],
  }) => ResultadoValidadoPartido(
    revision: fila['revision'] as String,
    marcadorEquipoA: fila['marcador_equipo_a'] as int,
    marcadorEquipoB: fila['marcador_equipo_b'] as int,
    estado: EstadoResultadoPartido.values.byName(fila['estado'] as String),
    motivoDisputa: fila['motivo_disputa'] as String?,
    historial: historial,
  );

  static void validarMarcador(int equipoA, int equipoB) {
    if (equipoA < 0 || equipoB < 0) {
      throw StateError('El marcador no puede tener valores negativos.');
    }
    if (equipoA > 999 || equipoB > 999) {
      throw StateError('Cada valor del marcador debe ser menor a 1000.');
    }
  }
}
