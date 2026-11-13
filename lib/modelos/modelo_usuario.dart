/// Datos públicos de un estudiante (tabla `perfiles` en Supabase).
///
/// La contraseña no forma parte del modelo: la guarda Supabase Auth, cifrada,
/// y la app nunca la almacena.
class ModeloUsuario {
  final String id;
  final String nombre;
  final String correo;
  final String carrera;
  final String deporteFavorito;

  ModeloUsuario({
    required this.id,
    required this.nombre,
    required this.correo,
    this.carrera = 'Ingeniería',
    this.deporteFavorito = 'Futsal',
  });

  /// Construye el usuario a partir de una fila de la tabla `perfiles`.
  factory ModeloUsuario.desdePerfil(Map<String, dynamic> fila) {
    return ModeloUsuario(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      correo: fila['correo'] as String,
      carrera: fila['carrera'] as String? ?? 'Ingeniería',
      deporteFavorito: fila['deporte_favorito'] as String? ?? 'Futsal',
    );
  }

  ModeloUsuario copiarCon({
    String? nombre,
    String? carrera,
    String? deporteFavorito,
  }) {
    return ModeloUsuario(
      id: id,
      nombre: nombre ?? this.nombre,
      correo: correo,
      carrera: carrera ?? this.carrera,
      deporteFavorito: deporteFavorito ?? this.deporteFavorito,
    );
  }
}
