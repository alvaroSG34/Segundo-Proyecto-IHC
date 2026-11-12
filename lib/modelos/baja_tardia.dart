class BajaTardia {
  final String partidoId;
  final String jugadorNombre;
  final DateTime fecha;

  const BajaTardia({
    required this.partidoId,
    required this.jugadorNombre,
    required this.fecha,
  });

  factory BajaTardia.desdeJson(Map<String, dynamic> json) => BajaTardia(
    partidoId: json['partido_id'] as String,
    jugadorNombre: json['jugador_nombre'] as String,
    fecha: DateTime.parse(json['fecha'] as String).toLocal(),
  );
}
