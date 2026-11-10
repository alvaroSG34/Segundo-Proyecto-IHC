class ParticipantePartido {
  final String id;
  final String nombre;
  final bool esOrganizador;

  const ParticipantePartido({
    required this.id,
    required this.nombre,
    this.esOrganizador = false,
  });
}

enum EstadoPropuesta {
  pendiente('Pendiente'),
  aceptada('Aceptada'),
  rechazada('Rechazada');

  final String etiqueta;
  const EstadoPropuesta(this.etiqueta);
}

class PropuestaEquipos {
  /// Cambia en cada envío para no responder una versión anterior del reparto.
  final String revision;
  final List<String> equipoA;
  final List<String> equipoB;
  final String capitanRivalId;
  final EstadoPropuesta estado;

  PropuestaEquipos({
    required this.revision,
    required List<String> equipoA,
    required List<String> equipoB,
    required this.capitanRivalId,
    this.estado = EstadoPropuesta.pendiente,
  }) : equipoA = List.unmodifiable(equipoA),
       equipoB = List.unmodifiable(equipoB);

  factory PropuestaEquipos.desdeFila(Map<String, dynamic> fila) =>
      PropuestaEquipos(
        revision: fila['revision'] as String,
        equipoA: List<String>.from(fila['equipo_a'] as List),
        equipoB: List<String>.from(fila['equipo_b'] as List),
        capitanRivalId: fila['capitan_rival_id'] as String,
        estado: EstadoPropuesta.values.byName(fila['estado'] as String),
      );

  void validar(List<ParticipantePartido> participantes) {
    final organizador = participantes.singleWhere((p) => p.esOrganizador);
    final todos = [...equipoA, ...equipoB];
    final ids = participantes.map((p) => p.id).toSet();
    if (equipoB.isEmpty ||
        !equipoA.contains(organizador.id) ||
        capitanRivalId == organizador.id ||
        !equipoB.contains(capitanRivalId) ||
        todos.length != ids.length ||
        todos.toSet().length != todos.length ||
        !todos.toSet().containsAll(ids)) {
      throw StateError(
        'Asigna a todos una sola vez, deja al organizador en A y elige un capitán del B.',
      );
    }
  }
}
