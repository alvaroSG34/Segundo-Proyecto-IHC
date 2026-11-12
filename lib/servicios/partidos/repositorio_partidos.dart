import '../../modelos/baja_tardia.dart';
import '../../modelos/evento_historial.dart';
import '../../modelos/filtro_partidos.dart';
import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../modelos/resultado_partido.dart';

/// Operaciones sobre partidos e inscripciones en la base de datos compartida.
///
/// Todas actúan en nombre del usuario con sesión iniciada. Si una regla de
/// negocio rechaza la operación, se lanza [StateError] con el motivo (el mismo
/// texto que usa ModeloPartido), para que la interfaz lo muestre.
///
/// La implementación real es RepositorioPartidosSupabase; las pruebas usan una versión
/// en memoria con el mismo contrato.
abstract class RepositorioPartidos {
  Future<List<ParticipantePartido>> obtenerParticipantes(String partidoId);
  Future<PropuestaEquipos?> obtenerPropuesta(String partidoId);
  Future<void> guardarPropuesta(String partidoId, PropuestaEquipos propuesta);
  Future<void> responderPropuesta(
    String partidoId,
    String revision,
    bool acepta,
  );
  Future<ResultadoValidadoPartido?> obtenerResultado(String partidoId);
  Future<void> registrarResultado(
    String partidoId,
    int marcadorEquipoA,
    int marcadorEquipoB,
  );
  Future<void> disputarResultado(
    String partidoId,
    String revision,
    String motivo,
  );
  Future<void> confirmarResultado(String partidoId, String revision);

  /// Partidos que organiza el usuario actual (más recientes primero).
  Future<List<ModeloPartido>> obtenerMisPartidos();

  /// Partidos de otros estudiantes a los que el usuario actual se unió.
  Future<List<ModeloPartido>> obtenerPartidosUnidos();

  /// Nombres en orden de espera para los partidos organizados por el usuario.
  Future<Map<String, List<String>>> obtenerSuplentes();

  /// Bajas realizadas dentro de las dos horas previas, visibles únicamente
  /// para quien organiza cada partido.
  Future<Map<String, List<BajaTardia>>> obtenerBajasTardias();

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

  /// Cambia fecha/hora o lugar y pide reconfirmación a los inscritos.
  Future<ModeloPartido> reprogramarPartido(
    String partidoId,
    DateTime nuevaFecha,
    String nuevaUbicacion,
    String motivo,
  );

  /// Un titular acepta la nueva fecha o libera su plaza.
  Future<ModeloPartido> responderReprogramacion(String partidoId, bool acepta);

  /// Cierra la convocatoria del partido sin ocupar ni crear cupos.
  Future<ModeloPartido> completarEquipo(String partidoId);

  Future<void> eliminarPartido(String partidoId);

  /// "Unirme al equipo" (requisito #5).
  Future<ModeloPartido> unirseAPartido(String partidoId);

  /// "Salir del partido": libera el cupo de quien se había unido (H3).
  Future<ModeloPartido> salirDelPartido(String partidoId);

  /// Se anota al final de la lista cuando el equipo está completo.
  Future<ModeloPartido> entrarEnEspera(String partidoId);

  /// Cancela la solicitud de suplente sin tocar los cupos del equipo.
  Future<ModeloPartido> salirDeEspera(String partidoId);

  /// Historial de participación del estudiante (Clase 16 · Tarea 4).
  /// Devuelve los partidos en los que participó (organizados o unidos),
  /// ordenados con los más recientes primero.
  Future<List<EventoHistorial>> obtenerHistorial({DateTime? ahora});
}
