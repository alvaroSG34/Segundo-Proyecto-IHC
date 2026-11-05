/// Estado de convocatoria de un partido.
enum EstadoPartido {
  cuposAbiertos('Cupos abiertos'),
  equipoCompleto('Equipo completo');

  final String etiqueta;
  const EstadoPartido(this.etiqueta);
}

class ModeloPartido {
  /// Deportes disponibles (formulario de creación y filtro de búsqueda).
  static const List<String> disciplinas = [
    'Futsal',
    'Fútbol',
    'Básquetbol',
    'Voleibol',
    'Tenis',
    'Otro',
  ];

  final String id;
  final String titulo;
  final String disciplina;
  final String icono;
  final String ubicacion;
  final String fechaHora;
  final int cuposTotales;
  final int cuposOcupados;
  final String organizadorNombre;
  final bool soyOrganizador;
  final bool estoyUnido;

  /// Cero significa que el usuario no está en la lista de suplentes.
  final int posicionEspera;
  final EstadoPartido estado;
  final String? motivoReprogramacion;
  final String? fechaAnterior;
  final String? ubicacionAnterior;
  final int respuestasPendientes;
  final bool reconfirmacionPendiente;
  final bool reconfirmacionAceptada;

  ModeloPartido({
    required this.id,
    required this.titulo,
    required this.disciplina,
    required this.icono,
    required this.ubicacion,
    required this.fechaHora,
    required this.cuposTotales,
    required this.cuposOcupados,
    required this.organizadorNombre,
    this.soyOrganizador = false,
    this.estoyUnido = false,
    this.posicionEspera = 0,
    this.estado = EstadoPartido.cuposAbiertos,
    this.motivoReprogramacion,
    this.fechaAnterior,
    this.ubicacionAnterior,
    this.respuestasPendientes = 0,
    this.reconfirmacionPendiente = false,
    this.reconfirmacionAceptada = false,
  });

  int get cuposRestantes => cuposTotales - cuposOcupados;
  bool get estaLleno => cuposRestantes <= 0;
  bool get estoyEnEspera => posicionEspera > 0;

  bool get puedeReprogramar =>
      soyOrganizador && !fechaPasada && respuestasPendientes == 0;

  /// Solo alguien ajeno al equipo puede pedir un lugar cuando está lleno.
  bool get puedeEntrarEnEspera =>
      !soyOrganizador &&
      !estoyUnido &&
      !estoyEnEspera &&
      !fechaPasada &&
      estado == EstadoPartido.equipoCompleto;

  /// Fecha y hora reales del partido, a partir del texto "dd/mm/aaaa · hh:mm"
  /// que guarda el formulario. Es null si el texto no tiene ese formato.
  DateTime? get fechaInicio => interpretarFechaHora(fechaHora);

  /// ¿La fecha del partido ya pasó? (Issue #7)
  bool get fechaPasada {
    final fecha = fechaInicio;
    return fecha != null && fecha.isBefore(DateTime.now());
  }

  /// Un partido está disponible si alguien podría unirse: tiene cupos abiertos
  /// y su fecha todavía no pasó. Lo usa también el filtro "con cupos" (#6).
  bool get estaDisponible => puedeAgregarJugador && !fechaPasada;

  static final RegExp _formatoFechaHora = RegExp(
    r'(\d{1,2})/(\d{1,2})/(\d{4})\D+(\d{1,2}):(\d{2})',
  );

  /// Convierte una fecha real en el texto "dd/mm/aaaa · hh:mm" que muestran
  /// las pantallas (la base de datos guarda la fecha real).
  static String formatearFechaHora(DateTime fecha) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} · '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  /// Convierte "dd/mm/aaaa · hh:mm" en una fecha real.
  static DateTime? interpretarFechaHora(String texto) {
    final m = _formatoFechaHora.firstMatch(texto);
    if (m == null) return null;
    int parte(int i) => int.parse(m.group(i)!);
    return DateTime(parte(3), parte(2), parte(1), parte(4), parte(5));
  }

  // ---------------------------------------------------------------------------
  // REGLA DE RESTRICCIÓN (UNISPORT)
  //   "Un equipo completo no permite agregar más jugadores"
  //   Cuando una acción esté bloqueada, la interfaz debe explicar claramente el motivo.
  // ---------------------------------------------------------------------------

  /// ¿Se puede agregar un jugador a este partido ahora mismo?
  bool get puedeAgregarJugador =>
      estado == EstadoPartido.cuposAbiertos && !estaLleno;

  /// El organizador puede cerrar una convocatoria con cupos todavía libres.
  bool get puedeCompletarEquipo =>
      soyOrganizador &&
      estado == EstadoPartido.cuposAbiertos &&
      !estaLleno &&
      !fechaPasada;

  /// Etiqueta visible que diferencia un cierre manual de un equipo lleno.
  String get etiquetaEstado =>
      estado == EstadoPartido.equipoCompleto && !estaLleno
      ? 'Convocatoria cerrada'
      : estado.etiqueta;

  /// Cierra la convocatoria sin crear inscripciones ni ocupar cupos.
  ModeloPartido completarEquipo() {
    if (!soyOrganizador) {
      throw StateError('Solo el organizador puede cerrar la convocatoria.');
    }
    if (fechaPasada) {
      throw StateError('El partido ya se jugó: su fecha ya pasó.');
    }
    if (estado == EstadoPartido.equipoCompleto) {
      throw StateError('La convocatoria ya está cerrada.');
    }
    if (estaLleno) {
      throw StateError('El equipo ya está completo.');
    }
    return copyWith(estado: EstadoPartido.equipoCompleto);
  }

  /// Motivo claro por el cual está bloqueada la acción de agregar jugadores.
  /// Si la acción está permitida, devuelve null.
  String? get motivoBloqueoAgregarJugador {
    if (estado == EstadoPartido.equipoCompleto) {
      return estaLleno
          ? 'Convocatoria cerrada: el equipo ya está completo.'
          : 'Convocatoria cerrada por el organizador.';
    }
    if (estaLleno) {
      return 'Cupos agotados: se alcanzó el límite máximo de jugadores.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // REGLA DE UNIÓN AL PARTIDO (Issue #2, historia #1)
  //   Un estudiante puede unirse si:
  //   - no forma parte del equipo (el organizador ya cuenta como jugador), y
  //   - el partido tiene cupos abiertos, y
  //   - la fecha del partido todavía no pasó (Issue #7, historia #5).
  //   Al ocupar el último cupo, el partido pasa a "Equipo completo".
  // ---------------------------------------------------------------------------

  /// ¿Puede el usuario actual unirse a este partido?
  bool get puedeUnirse => motivoRechazoUnirse == null;

  /// Motivo por el que se rechaza la unión, o null si está permitida.
  String? get motivoRechazoUnirse {
    if (soyOrganizador || estoyUnido) {
      return 'Ya formas parte de este equipo.';
    }
    if (estoyEnEspera) {
      return 'Ya estás en la lista de suplentes.';
    }
    if (fechaPasada) {
      return 'El partido ya se jugó: su fecha ya pasó.';
    }
    return motivoBloqueoAgregarJugador;
  }

  /// Acción "Unirme al equipo". Devuelve una copia con un cupo más ocupado y
  /// el usuario marcado como unido. Lanza [StateError] con el motivo si la
  /// regla lo rechaza; en ese caso el partido no cambia.
  ModeloPartido unirse() {
    final motivo = motivoRechazoUnirse;
    if (motivo != null) throw StateError(motivo);
    final nuevosOcupados = cuposOcupados + 1;
    return copyWith(
      cuposOcupados: nuevosOcupados,
      estoyUnido: true,
      estado: nuevosOcupados >= cuposTotales
          ? EstadoPartido.equipoCompleto
          : estado,
    );
  }

  // ---------------------------------------------------------------------------
  // REGLA DE SALIDA DEL PARTIDO (H3 Control y libertad)
  //   Quien se unió puede retirarse mientras el partido no haya pasado. El
  //   organizador no sale de su propio partido (lo elimina). Al salir de un
  //   equipo que se llenó por inscripciones se libera el cupo y vuelve a abrirse;
  //   un cierre manual se conserva aunque quede un cupo libre.
  // ---------------------------------------------------------------------------

  /// Motivo por el que no puede salir, o null si la salida está permitida.
  String? get motivoRechazoSalir {
    if (soyOrganizador) {
      return 'El organizador no puede salir de su propio partido: elimínalo si ya no se realizará.';
    }
    if (!estoyUnido) return 'No formas parte de este equipo.';
    if (fechaPasada) return 'El partido ya se jugó: su fecha ya pasó.';
    return null;
  }

  bool get puedeSalir => motivoRechazoSalir == null;

  /// Acción "Salir del partido". Devuelve una copia con un cupo menos ocupado.
  /// Lanza [StateError] con el motivo si la regla lo rechaza.
  ModeloPartido salir() {
    final motivo = motivoRechazoSalir;
    if (motivo != null) throw StateError(motivo);
    return copyWith(
      cuposOcupados: cuposOcupados - 1,
      estoyUnido: false,
      estado: estado == EstadoPartido.equipoCompleto && !estaLleno
          ? EstadoPartido.equipoCompleto
          : EstadoPartido.cuposAbiertos,
    );
  }

  // ---------------------------------------------------------------------------
  // REGLA DE EDICIÓN DE CUPOS
  //   - Con el equipo completo no se pueden cambiar los cupos: subirlos sería
  //     agregar jugadores, y "un equipo completo no permite agregar más".
  //   - No se puede dejar menos cupos que jugadores ya inscritos.
  //   - Si los cupos quedan iguales a los inscritos, el partido pasa solo a
  //     "Equipo completo" (igual que al ocuparse el último cupo).
  // ---------------------------------------------------------------------------

  /// ¿Se pueden cambiar los cupos totales al editar?
  bool get puedeCambiarCupos => estado == EstadoPartido.cuposAbiertos;

  /// Motivo por el que no se pueden cambiar los cupos, o null si se puede.
  String? get motivoBloqueoCambiarCupos => puedeCambiarCupos
      ? null
      : 'El equipo ya está completo: no se pueden cambiar los cupos.';

  /// Edición de cupos: devuelve una copia con [nuevos] cupos totales y el
  /// estado recalculado. Lanza [StateError] si la regla no lo permite.
  ModeloPartido conCuposTotales(int nuevos) {
    if (nuevos == cuposTotales) return this;
    final motivo = motivoBloqueoCambiarCupos;
    if (motivo != null) throw StateError(motivo);
    if (nuevos < cuposOcupados) {
      throw StateError(
        'No puedes dejar menos cupos ($nuevos) que jugadores inscritos '
        '($cuposOcupados).',
      );
    }
    return copyWith(
      cuposTotales: nuevos,
      estado: nuevos <= cuposOcupados
          ? EstadoPartido.equipoCompleto
          : EstadoPartido.cuposAbiertos,
    );
  }

  /// Genera una copia inmutable con campos modificados para el flujo de edición.
  ModeloPartido copyWith({
    String? id,
    String? titulo,
    String? disciplina,
    String? icono,
    String? ubicacion,
    String? fechaHora,
    int? cuposTotales,
    int? cuposOcupados,
    String? organizadorNombre,
    bool? soyOrganizador,
    bool? estoyUnido,
    int? posicionEspera,
    EstadoPartido? estado,
    String? motivoReprogramacion,
    String? fechaAnterior,
    String? ubicacionAnterior,
    int? respuestasPendientes,
    bool? reconfirmacionPendiente,
    bool? reconfirmacionAceptada,
  }) {
    return ModeloPartido(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      disciplina: disciplina ?? this.disciplina,
      icono: icono ?? this.icono,
      ubicacion: ubicacion ?? this.ubicacion,
      fechaHora: fechaHora ?? this.fechaHora,
      cuposTotales: cuposTotales ?? this.cuposTotales,
      cuposOcupados: cuposOcupados ?? this.cuposOcupados,
      organizadorNombre: organizadorNombre ?? this.organizadorNombre,
      soyOrganizador: soyOrganizador ?? this.soyOrganizador,
      estoyUnido: estoyUnido ?? this.estoyUnido,
      posicionEspera: posicionEspera ?? this.posicionEspera,
      estado: estado ?? this.estado,
      motivoReprogramacion: motivoReprogramacion ?? this.motivoReprogramacion,
      fechaAnterior: fechaAnterior ?? this.fechaAnterior,
      ubicacionAnterior: ubicacionAnterior ?? this.ubicacionAnterior,
      respuestasPendientes: respuestasPendientes ?? this.respuestasPendientes,
      reconfirmacionPendiente:
          reconfirmacionPendiente ?? this.reconfirmacionPendiente,
      reconfirmacionAceptada:
          reconfirmacionAceptada ?? this.reconfirmacionAceptada,
    );
  }

  /// Convierte el partido en un Map para poder guardarlo como texto JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'disciplina': disciplina,
    'icono': icono,
    'ubicacion': ubicacion,
    'fechaHora': fechaHora,
    'cuposTotales': cuposTotales,
    'cuposOcupados': cuposOcupados,
    'organizadorNombre': organizadorNombre,
    'soyOrganizador': soyOrganizador,
    'estoyUnido': estoyUnido,
    'posicionEspera': posicionEspera,
    'estado': estado.name,
    'motivoReprogramacion': motivoReprogramacion,
    'fechaAnterior': fechaAnterior,
    'ubicacionAnterior': ubicacionAnterior,
    'respuestasPendientes': respuestasPendientes,
    'reconfirmacionPendiente': reconfirmacionPendiente,
    'reconfirmacionAceptada': reconfirmacionAceptada,
  };

  /// Reconstruye un partido a partir de un Map leído del almacenamiento.
  /// Si el estado guardado falta o no se reconoce, queda en "Cupos abiertos".
  factory ModeloPartido.fromJson(Map<String, dynamic> json) => ModeloPartido(
    id: json['id'] as String,
    titulo: json['titulo'] as String,
    disciplina: json['disciplina'] as String,
    icono: json['icono'] as String,
    ubicacion: json['ubicacion'] as String,
    fechaHora: json['fechaHora'] as String,
    cuposTotales: json['cuposTotales'] as int,
    cuposOcupados: json['cuposOcupados'] as int,
    organizadorNombre: json['organizadorNombre'] as String,
    soyOrganizador: json['soyOrganizador'] as bool? ?? false,
    estoyUnido: json['estoyUnido'] as bool? ?? false,
    posicionEspera: json['posicionEspera'] as int? ?? 0,
    estado:
        EstadoPartido.values.asNameMap()[json['estado'] as String?] ??
        EstadoPartido.cuposAbiertos,
    motivoReprogramacion: json['motivoReprogramacion'] as String?,
    fechaAnterior: json['fechaAnterior'] as String?,
    ubicacionAnterior: json['ubicacionAnterior'] as String?,
    respuestasPendientes: json['respuestasPendientes'] as int? ?? 0,
    reconfirmacionPendiente: json['reconfirmacionPendiente'] as bool? ?? false,
    reconfirmacionAceptada: json['reconfirmacionAceptada'] as bool? ?? false,
  );
}
