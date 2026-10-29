import '../modelos/evento_historial.dart';
import '../modelos/filtro_partidos.dart';
import '../modelos/modelo_partido.dart';

/// Operaciones sobre partidos e inscripciones en la base de datos compartida.
///
/// Todas actúan en nombre del usuario con sesión iniciada. Si una regla de
/// negocio rechaza la operación, se lanza [StateError] con el motivo (el mismo
/// texto que usa ModeloPartido), para que la interfaz lo muestre.
///
/// La implementación real es RepositorioSupabase; las pruebas usan una versión
/// en memoria con el mismo contrato.
abstract class RepositorioPartidos {
  /// Partidos que organiza el usuario actual (más recientes primero).
  Future<List<ModeloPartido>> obtenerMisPartidos();

  /// Partidos de otros estudiantes a los que el usuario actual se unió.
  Future<List<ModeloPartido>> obtenerPartidosUnidos();

  /// Quién se unió a los partidos que organiza o integra: id -> nombres.
  Future<Map<String, List<String>>> obtenerJugadoresInscritos();

  /// Partidos de otros estudiantes que cumplen [filtro] (requisito #6).
  /// [ahora] es la referencia para "hoy", "próximos 7 días" y fechas pasadas.
  Future<List<ModeloPartido>> buscarPartidos(
    FiltroPartidos filtro, {
    DateTime? ahora,
  });

  /// Lugares para el filtro: los sugeridos y los usados en partidos de otros.
  Future<List<String>> obtenerLugares();

  /// Crea un partido organizado por el usuario actual. Devuelve el partido con
  /// el id que le asignó la base de datos.
  Future<ModeloPartido> crearPartido(ModeloPartido nuevo);

  /// Guarda título, deporte, lugar, fecha y cupos (regla de edición de cupos).
  Future<ModeloPartido> editarPartido(ModeloPartido editado);

  Future<void> eliminarPartido(String partidoId);

  /// "Completar equipo" (organizador).
  Future<ModeloPartido> completarEquipo(String partidoId);

  /// "Agregar jugador" sin cuenta (organizador).
  Future<ModeloPartido> agregarJugadorSinCuenta(String partidoId);

  /// "Unirme al equipo" (requisito #5).
  Future<ModeloPartido> unirseAPartido(String partidoId);

  /// "Salir del partido": libera el cupo de quien se había unido (H3).
  Future<ModeloPartido> salirDelPartido(String partidoId);

  /// Historial de participación del estudiante (Clase 16 · Tarea 4).
  /// Devuelve los partidos en los que participó (organizados o unidos),
  /// ordenados con los más recientes primero.
  Future<List<EventoHistorial>> obtenerHistorial({DateTime? ahora});
}
