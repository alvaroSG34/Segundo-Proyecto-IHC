import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/evento_historial.dart';
import '../../modelos/filtro_partidos.dart';
import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../modelos/resultado_partido.dart';
import 'repositorio_partidos.dart';

/// Repositorio sobre la base de datos compartida de Supabase (PostgreSQL).
///
/// - Lecturas y filtros: consultas a las tablas `partidos` e `inscripciones`.
/// - Cambios con reglas de negocio: funciones del servidor (`rpc`) definidas en
///   supabase/esquema.sql, que validan las reglas y bloquean la fila del
///   partido, así varios teléfonos no pueden romperlas al mismo tiempo.
class RepositorioPartidosSupabase implements RepositorioPartidos {
  static const String mensajeSinConexion =
      'No se pudo conectar con el servidor. Revisa tu conexión a internet.';

  final SupabaseClient _cliente;

  RepositorioPartidosSupabase(this._cliente);

  @override
  Future<List<ParticipantePartido>> obtenerParticipantes(String partidoId) =>
      _ejecutar(() async {
        final filas = await _cliente.rpc(
          'obtener_participantes_equipos',
          params: {'p_partido': partidoId},
        );
        return [
          for (final f in filas as List)
            ParticipantePartido(
              id: f['id'] as String,
              nombre: f['nombre'] as String,
              esOrganizador: f['es_organizador'] as bool,
            ),
        ];
      });

  @override
  Future<PropuestaEquipos?> obtenerPropuesta(String partidoId) =>
      _ejecutar(() async {
        final fila = await _cliente
            .from('propuestas_equipos')
            .select()
            .eq('partido_id', partidoId)
            .maybeSingle();
        return fila == null ? null : PropuestaEquipos.desdeFila(fila);
      });

  @override
  Future<void> guardarPropuesta(String partidoId, PropuestaEquipos propuesta) =>
      _ejecutar(() async {
        await _cliente.rpc(
          'guardar_propuesta_equipos',
          params: {
            'p_partido': partidoId,
            'p_equipo_a': propuesta.equipoA,
            'p_equipo_b': propuesta.equipoB,
            'p_capitan_rival': propuesta.capitanRivalId,
          },
        );
      });

  @override
  Future<void> responderPropuesta(
    String partidoId,
    String revision,
    bool acepta,
  ) => _ejecutar(() async {
    await _cliente.rpc(
      'responder_propuesta_equipos',
      params: {
        'p_partido': partidoId,
        'p_revision': revision,
        'p_acepta': acepta,
      },
    );
  });

  @override
  Future<ResultadoValidadoPartido?> obtenerResultado(String partidoId) =>
      _ejecutar(() async {
        final fila = await _cliente
            .from('resultados_partido')
            .select()
            .eq('partido_id', partidoId)
            .maybeSingle();
        if (fila == null) return null;
        final eventos = await _cliente
            .from('historial_resultados')
            .select()
            .eq('partido_id', partidoId)
            .order('creado_en', ascending: true);
        return ResultadoValidadoPartido.desdeFila(
          fila,
          historial: [
            for (final evento in eventos)
              EventoResultadoPartido.desdeFila(evento),
          ],
        );
      });

  @override
  Future<void> registrarResultado(
    String partidoId,
    int marcadorEquipoA,
    int marcadorEquipoB,
  ) => _ejecutar(() async {
    ResultadoValidadoPartido.validarMarcador(marcadorEquipoA, marcadorEquipoB);
    await _cliente.rpc(
      'registrar_resultado_partido',
      params: {
        'p_partido': partidoId,
        'p_marcador_a': marcadorEquipoA,
        'p_marcador_b': marcadorEquipoB,
      },
    );
  });

  @override
  Future<void> disputarResultado(
    String partidoId,
    String revision,
    String motivo,
  ) => _ejecutar(() async {
    await _cliente.rpc(
      'disputar_resultado_partido',
      params: {
        'p_partido': partidoId,
        'p_revision': revision,
        'p_motivo': motivo,
      },
    );
  });

  @override
  Future<void> confirmarResultado(String partidoId, String revision) =>
      _ejecutar(() async {
        await _cliente.rpc(
          'confirmar_resultado_partido',
          params: {'p_partido': partidoId, 'p_revision': revision},
        );
      });

  /// Traduce el filtro a las condiciones que se envían a la base de datos
  /// (todas se combinan con AND).
  /// Es una función pura para poder probar qué consulta se envía.
  static List<CondicionConsulta> condicionesConsulta(
    FiltroPartidos filtro,
    DateTime ahora,
  ) {
    String instante(DateTime fecha) => fecha.toUtc().toIso8601String();
    final intervalo = filtro.intervaloFechas(ahora);
    return [
      if (filtro.periodo != PeriodoPartidos.todos)
        (
          columna: 'fecha_inicio',
          operador: filtro.periodo == PeriodoPartidos.vencidos ? 'lt' : 'gte',
          valor: instante(ahora),
        ),
      // El nombre no se envía a la base: se compara sin tildes en la app
      // (ver FiltroPartidos.coincideTitulo), porque ILIKE distingue "Vóley" de "voley".
      if (filtro.deporte != null)
        (columna: 'disciplina', operador: 'eq', valor: filtro.deporte!),
      if (filtro.lugar != null)
        (
          columna: 'ubicacion',
          operador: 'ilike',
          valor: '%${_escaparComodines(filtro.lugar!)}%',
        ),
      if (intervalo != null) ...[
        (
          columna: 'fecha_inicio',
          operador: 'gte',
          valor: instante(intervalo.$1),
        ),
        (
          columna: 'fecha_inicio',
          operador: 'lt',
          valor: instante(intervalo.$2),
        ),
      ],
      // Misma regla que ModeloPartido.estaDisponible (#5): cupos abiertos,
      // quedan lugares y la fecha todavía no pasó.
      if (filtro.soloConCupos) ...[
        (columna: 'estado', operador: 'eq', valor: 'cuposAbiertos'),
        (columna: 'hay_cupos', operador: 'eq', valor: true),
        (columna: 'fecha_inicio', operador: 'gte', valor: instante(ahora)),
      ],
    ];
  }

  // Evita que % y _ escritos por el usuario actúen como comodines en ILIKE
  static String _escaparComodines(String texto) => texto
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  String get _usuarioId {
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) throw StateError('Debes iniciar sesión.');
    return usuario.id;
  }

  /// Ejecuta una operación y convierte los errores del servidor en
  /// [StateError] con un mensaje que la interfaz puede mostrar.
  Future<T> _ejecutar<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on StateError {
      rethrow;
    } on PostgrestException catch (e) {
      // Los "raise exception" de las funciones SQL llegan aquí con su mensaje
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error de Supabase: $e');
      throw StateError(mensajeSinConexion);
    }
  }

  /// Convierte una fila de `partidos` en el modelo, visto por el usuario actual.
  ModeloPartido _desdeFila(
    Map<String, dynamic> fila, {
    Set<String> inscritos = const {},
    Set<String> pendientes = const {},
    Set<String> aceptadas = const {},
    Map<String, int> posiciones = const {},
  }) {
    final id = fila['id'] as String;
    final soyOrganizador = fila['organizador_id'] == _usuarioId;
    final inicio = DateTime.parse(fila['fecha_inicio'] as String).toLocal();
    final disciplina = fila['disciplina'] as String;
    return ModeloPartido(
      id: id,
      titulo: fila['titulo'] as String,
      disciplina: disciplina,
      icono: disciplina,
      ubicacion: fila['ubicacion'] as String,
      fechaHora: ModeloPartido.formatearFechaHora(inicio),
      cuposTotales: fila['cupos_totales'] as int,
      cuposOcupados: fila['cupos_ocupados'] as int,
      organizadorNombre: fila['organizador_nombre'] as String,
      soyOrganizador: soyOrganizador,
      estoyUnido: soyOrganizador || inscritos.contains(id),
      posicionEspera: posiciones[id] ?? 0,
      estado:
          EstadoPartido.values.asNameMap()[fila['estado'] as String] ??
          EstadoPartido.cuposAbiertos,
      motivoReprogramacion: fila['reprogramacion_motivo'] as String?,
      fechaAnterior: fila['reprogramacion_fecha_anterior'] == null
          ? null
          : ModeloPartido.formatearFechaHora(
              DateTime.parse(fila['reprogramacion_fecha_anterior'] as String)
                  .toLocal(),
            ),
      ubicacionAnterior: fila['reprogramacion_ubicacion_anterior'] as String?,
      respuestasPendientes: fila['reconfirmaciones_pendientes'] as int? ?? 0,
      reconfirmacionPendiente: pendientes.contains(id),
      reconfirmacionAceptada: aceptadas.contains(id),
    );
  }

  String _instante(ModeloPartido partido) {
    final inicio = partido.fechaInicio;
    if (inicio == null) throw StateError('La fecha del partido no es válida.');
    return inicio.toUtc().toIso8601String();
  }

  /// Ids de los partidos a los que el usuario actual se unió.
  Future<Set<String>> _idsInscritos() async {
    final filas = await _cliente
        .from('inscripciones')
        .select('partido_id')
        .eq('jugador_id', _usuarioId);
    return {for (final f in filas) f['partido_id'] as String};
  }

  Future<Set<String>> _idsReconfirmacionesPendientes() async {
    final filas = await _cliente
        .from('inscripciones')
        .select('partido_id')
        .eq('jugador_id', _usuarioId)
        .eq('reconfirmacion_pendiente', true);
    return {for (final f in filas) f['partido_id'] as String};
  }

  Future<Set<String>> _idsReconfirmacionesAceptadas() async {
    final filas = await _cliente
        .from('inscripciones')
        .select('partido_id')
        .eq('jugador_id', _usuarioId)
        .eq('reconfirmacion_aceptada', true);
    return {for (final f in filas) f['partido_id'] as String};
  }

  /// Lee la cola completa en orden y calcula el turno del usuario actual.
  Future<Map<String, int>> _posicionesEnEspera() async {
    final filas = await _cliente
        .from('lista_espera')
        .select('partido_id, jugador_id')
        .order('id', ascending: true);
    final cantidades = <String, int>{};
    final posiciones = <String, int>{};
    for (final fila in filas) {
      final partidoId = fila['partido_id'] as String;
      final posicion = (cantidades[partidoId] ?? 0) + 1;
      cantidades[partidoId] = posicion;
      if (fila['jugador_id'] == _usuarioId) posiciones[partidoId] = posicion;
    }
    return posiciones;
  }

  /// Ejecuta una función del servidor que devuelve la fila del partido.
  Future<ModeloPartido> _llamar(
    String funcion,
    Map<String, dynamic> parametros, {
    bool unido = false,
  }) => _ejecutar(() async {
    final fila = await _cliente.rpc(funcion, params: parametros);
    final partido = _desdeFila(Map<String, dynamic>.from(fila as Map));
    return unido ? partido.copyWith(estoyUnido: true) : partido;
  });

  @override
  Future<List<ModeloPartido>> obtenerMisPartidos() => _ejecutar(() async {
    final filas = await _cliente
        .from('partidos')
        .select()
        .eq('organizador_id', _usuarioId)
        .order('creado_en', ascending: false);
    return [for (final f in filas) _desdeFila(f)];
  });

  @override
  Future<List<ModeloPartido>> obtenerPartidosUnidos() => _ejecutar(() async {
    final ids = await _idsInscritos();
    if (ids.isEmpty) return <ModeloPartido>[];
    final pendientes = await _idsReconfirmacionesPendientes();
    final aceptadas = await _idsReconfirmacionesAceptadas();
    final filas = await _cliente
        .from('partidos')
        .select()
        .inFilter('id', ids.toList())
        .order('fecha_inicio', ascending: true);
    return [
      for (final f in filas)
        _desdeFila(
          f,
          inscritos: ids,
          pendientes: pendientes,
          aceptadas: aceptadas,
        ),
    ];
  });

  @override
  Future<List<EventoHistorial>> obtenerHistorial({DateTime? ahora}) =>
      _ejecutar(() async {
        try {
          final filas = await _cliente.rpc('obtener_historial_usuario');
          return [
            for (final f in (filas as List))
              EventoHistorial.desdeFila(
                Map<String, dynamic>.from(f as Map),
                usuarioActualId: _usuarioId,
                ahora: ahora,
              ),
          ];
        } catch (_) {
          final mios = await _cliente
              .from('partidos')
              .select()
              .eq('organizador_id', _usuarioId);
          final ids = await _idsInscritos();
          final filasUnidos = ids.isEmpty
              ? <Map<String, dynamic>>[]
              : await _cliente
                    .from('partidos')
                    .select()
                    .inFilter('id', ids.toList());

          final todos = <EventoHistorial>[
            for (final f in mios)
              EventoHistorial.desdeFila(
                {...f, 'rol': 'organizador'},
                usuarioActualId: _usuarioId,
                ahora: ahora,
              ),
            for (final f in filasUnidos)
              EventoHistorial.desdeFila(
                {...f, 'rol': 'jugador'},
                usuarioActualId: _usuarioId,
                ahora: ahora,
              ),
          ];

          todos.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
          return todos;
        }
      });

  @override
  Future<Map<String, List<String>>> obtenerSuplentes() => _ejecutar(() async {
    final mios = await _cliente
        .from('partidos')
        .select('id')
        .eq('organizador_id', _usuarioId);
    if (mios.isEmpty) return <String, List<String>>{};
    final filas = await _cliente
        .from('lista_espera')
        .select('partido_id, jugador_nombre')
        .inFilter('partido_id', [for (final f in mios) f['id'] as String])
        .order('id', ascending: true);
    final resultado = <String, List<String>>{};
    for (final fila in filas) {
      resultado
          .putIfAbsent(fila['partido_id'] as String, () => [])
          .add(fila['jugador_nombre'] as String);
    }
    return resultado;
  });

  // Interfaz -> consulta -> base de datos (requisito #6): los filtros se
  // traducen a condiciones y las resuelve PostgreSQL en el servidor.
  @override
  Future<List<ModeloPartido>> buscarPartidos(
    FiltroPartidos filtro, {
    DateTime? ahora,
  }) => _ejecutar(() async {
    var consulta = _cliente
        .from('partidos')
        .select()
        .neq('organizador_id', _usuarioId);

    for (final c in condicionesConsulta(filtro, ahora ?? DateTime.now())) {
      consulta = switch (c.operador) {
        'eq' => consulta.eq(c.columna, c.valor),
        'ilike' => consulta.ilike(c.columna, c.valor as String),
        'gte' => consulta.gte(c.columna, c.valor),
        'lt' => consulta.lt(c.columna, c.valor),
        _ => throw ArgumentError('Operador no soportado: ${c.operador}'),
      };
    }

    final filas = await consulta.order(
      'fecha_inicio',
      ascending: filtro.periodo != PeriodoPartidos.vencidos,
    );
    final inscritos = await _idsInscritos();
    final pendientes = await _idsReconfirmacionesPendientes();
    final aceptadas = await _idsReconfirmacionesAceptadas();
    final posiciones = await _posicionesEnEspera();
    return [
      for (final f in filas)
        if (filtro.coincideTitulo(f['titulo'] as String))
          _desdeFila(
            f,
            inscritos: inscritos,
            pendientes: pendientes,
            aceptadas: aceptadas,
            posiciones: posiciones,
          ),
    ];
  });

  @override
  Future<List<String>> obtenerLugares() => _ejecutar(() async {
    final filas = await _cliente
        .from('partidos')
        .select('ubicacion')
        .neq('organizador_id', _usuarioId);
    final existentes = [for (final f in filas) f['ubicacion'] as String]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final vistos = <String>{};
    return [
      for (final lugar in [...FiltroPartidos.lugaresSugeridos, ...existentes])
        if (lugar.trim().isNotEmpty && vistos.add(lugar.trim().toLowerCase()))
          lugar.trim(),
    ];
  });

  @override
  Future<ModeloPartido> crearPartido(ModeloPartido nuevo) =>
      _ejecutar(() async {
        final fila = await _cliente
            .from('partidos')
            .insert({
              'organizador_id': _usuarioId,
              'organizador_nombre': nuevo.organizadorNombre,
              'titulo': nuevo.titulo,
              'disciplina': nuevo.disciplina,
              'ubicacion': nuevo.ubicacion,
              'fecha_inicio': _instante(nuevo),
              'cupos_totales': nuevo.cuposTotales,
              'cupos_ocupados': 1,
              'estado': EstadoPartido.cuposAbiertos.name,
            })
            .select()
            .single();
        return _desdeFila(fila);
      });

  @override
  Future<ModeloPartido> editarPartido(ModeloPartido editado) =>
      _llamar('editar_partido', {
        'p_partido': editado.id,
        'p_titulo': editado.titulo,
        'p_disciplina': editado.disciplina,
        'p_ubicacion': editado.ubicacion,
        'p_fecha_inicio': _instante(editado),
        'p_cupos_totales': editado.cuposTotales,
      });

  @override
  Future<ModeloPartido> reprogramarPartido(
    String partidoId,
    DateTime nuevaFecha,
    String nuevaUbicacion,
    String motivo,
  ) => _llamar('reprogramar_partido', {
    'p_partido': partidoId,
    'p_fecha_inicio': nuevaFecha.toUtc().toIso8601String(),
    'p_ubicacion': nuevaUbicacion,
    'p_motivo': motivo,
  });

  @override
  Future<ModeloPartido> responderReprogramacion(
    String partidoId,
    bool acepta,
  ) async {
    final partido = await _llamar('responder_reprogramacion', {
      'p_partido': partidoId,
      'p_acepta': acepta,
    });
    return partido.copyWith(
      estoyUnido: acepta,
      reconfirmacionPendiente: false,
      reconfirmacionAceptada: acepta,
    );
  }

  @override
  Future<ModeloPartido> completarEquipo(String partidoId) =>
      _llamar('completar_equipo', {'p_partido': partidoId});

  @override
  Future<void> eliminarPartido(String partidoId) => _ejecutar(() async {
    await _cliente.from('partidos').delete().eq('id', partidoId);
  });

  @override
  Future<ModeloPartido> unirseAPartido(String partidoId) =>
      _llamar('unirse_a_partido', {'p_partido': partidoId}, unido: true);

  @override
  Future<ModeloPartido> salirDelPartido(String partidoId) async {
    final salido = await _llamar('salir_del_partido', {'p_partido': partidoId});
    return salido.copyWith(estoyUnido: false);
  }

  @override
  Future<ModeloPartido> entrarEnEspera(String partidoId) => _ejecutar(() async {
    final fila = await _cliente.rpc(
      'entrar_lista_espera',
      params: {'p_partido': partidoId},
    );
    final posiciones = await _posicionesEnEspera();
    return _desdeFila(
      Map<String, dynamic>.from(fila as Map),
      posiciones: posiciones,
    );
  });

  @override
  Future<ModeloPartido> salirDeEspera(String partidoId) =>
      _llamar('salir_lista_espera', {'p_partido': partidoId});
}

/// Una condición de la consulta: columna, operador (eq, ilike, gte, lt) y valor.
typedef CondicionConsulta = ({String columna, String operador, Object valor});
