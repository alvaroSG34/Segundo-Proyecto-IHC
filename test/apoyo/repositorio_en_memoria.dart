import 'package:unisport/modelos/evento_historial.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos.dart';

/// Repositorio en memoria para las pruebas: mismo contrato que
/// RepositorioPartidosSupabase y mismas reglas (las del modelo), sin internet.
/// Simula una base compartida por varios usuarios: [usuarioId] es quien
/// tiene la sesión en ese momento.
class RepositorioEnMemoria implements RepositorioPartidos {
  String usuarioId;
  String usuarioNombre;

  RepositorioEnMemoria({this.usuarioId = '', this.usuarioNombre = ''});

  final Map<String, _Fila> _partidos = {};
  final List<({String partidoId, String jugadorId, String nombre})>
  _inscripciones = [];
  final List<({String partidoId, String jugadorId, String nombre})> _suplentes =
      [];
  int _siguienteId = 1;

  /// Cambia el usuario con sesión (como si otra persona abriera la app).
  void usarSesionDe(String id, String nombre) {
    usuarioId = id;
    usuarioNombre = nombre;
  }

  /// Agrega un partido de [organizadorId] directamente (datos de prueba).
  ModeloPartido sembrar(String organizadorId, ModeloPartido partido) {
    final id = partido.id.isEmpty ? 'm-${_siguienteId++}' : partido.id;
    _partidos[id] = _Fila(
      organizadorId,
      partido.copyWith(
        id: id,
        soyOrganizador: false,
        estoyUnido: false,
        posicionEspera: 0,
      ),
      _siguienteId++,
    );
    return _visto(_partidos[id]!);
  }

  bool _inscrito(String partidoId) => _inscripciones.any(
    (i) => i.partidoId == partidoId && i.jugadorId == usuarioId,
  );

  int _posicionEspera(String partidoId) {
    var posicion = 0;
    for (final suplente in _suplentes) {
      if (suplente.partidoId != partidoId) continue;
      posicion++;
      if (suplente.jugadorId == usuarioId) return posicion;
    }
    return 0;
  }

  ModeloPartido _visto(_Fila fila) {
    final soyOrganizador = fila.organizadorId == usuarioId;
    return fila.partido.copyWith(
      soyOrganizador: soyOrganizador,
      estoyUnido: soyOrganizador || _inscrito(fila.partido.id),
      posicionEspera: _posicionEspera(fila.partido.id),
    );
  }

  _Fila _buscar(String id) {
    final fila = _partidos[id];
    if (fila == null) throw StateError('Este partido ya no existe.');
    return fila;
  }

  _Fila _delOrganizador(String id, String mensaje) {
    final fila = _buscar(id);
    if (fila.organizadorId != usuarioId) throw StateError(mensaje);
    return fila;
  }

  ModeloPartido _guardar(_Fila fila, ModeloPartido nuevo) {
    fila.partido = nuevo.copyWith(
      soyOrganizador: false,
      estoyUnido: false,
      posicionEspera: 0,
    );
    return _visto(fila);
  }

  @override
  Future<List<ModeloPartido>> obtenerMisPartidos() async {
    final propias =
        _partidos.values.where((f) => f.organizadorId == usuarioId).toList()
          ..sort((a, b) => b.orden.compareTo(a.orden));
    return [for (final f in propias) _visto(f)];
  }

  @override
  Future<List<ModeloPartido>> obtenerPartidosUnidos() async => [
    for (final f in _partidos.values)
      if (f.organizadorId != usuarioId && _inscrito(f.partido.id)) _visto(f),
  ];

  @override
  Future<List<EventoHistorial>> obtenerHistorial({DateTime? ahora}) async {
    final referencia = ahora ?? DateTime.now();
    final participados = <EventoHistorial>[];

    for (final f in _partidos.values) {
      final esOrg = f.organizadorId == usuarioId;
      final estaIns = _inscrito(f.partido.id);

      if (esOrg || estaIns) {
        final partidoVisto = _visto(f);
        participados.add(
          EventoHistorial.desdePartido(partidoVisto, ahora: referencia),
        );
      }
    }

    participados.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    return participados;
  }

  @override
  Future<Map<String, List<String>>> obtenerJugadoresInscritos() async {
    final resultado = <String, List<String>>{};
    for (final i in _inscripciones) {
      if (_partidos[i.partidoId]?.organizadorId == usuarioId ||
          _inscrito(i.partidoId)) {
        resultado.putIfAbsent(i.partidoId, () => []).add(i.nombre);
      }
    }
    return resultado;
  }

  @override
  Future<Map<String, List<String>>> obtenerSuplentes() async {
    final resultado = <String, List<String>>{};
    for (final suplente in _suplentes) {
      if (_partidos[suplente.partidoId]?.organizadorId == usuarioId) {
        resultado
            .putIfAbsent(suplente.partidoId, () => [])
            .add(suplente.nombre);
      }
    }
    return resultado;
  }

  @override
  Future<List<ModeloPartido>> buscarPartidos(
    FiltroPartidos filtro, {
    DateTime? ahora,
  }) async {
    final referencia = ahora ?? DateTime.now();
    final resultado = [
      for (final f in _partidos.values)
        if (f.organizadorId != usuarioId &&
            filtro.coincide(f.partido, referencia))
          _visto(f),
    ];
    resultado.sort((a, b) => a.fechaInicio!.compareTo(b.fechaInicio!));
    return resultado;
  }

  @override
  Future<List<String>> obtenerLugares() async {
    final existentes = [
      for (final f in _partidos.values)
        if (f.organizadorId != usuarioId) f.partido.ubicacion,
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final vistos = <String>{};
    return [
      for (final lugar in [...FiltroPartidos.lugaresSugeridos, ...existentes])
        if (vistos.add(lugar.toLowerCase())) lugar,
    ];
  }

  @override
  Future<ModeloPartido> crearPartido(ModeloPartido nuevo) async {
    final id = 'm-${_siguienteId++}';
    final fila = _Fila(
      usuarioId,
      nuevo.copyWith(
        id: id,
        organizadorNombre: usuarioNombre,
        cuposOcupados: 1,
        estado: EstadoPartido.cuposAbiertos,
      ),
      _siguienteId++,
    );
    _partidos[id] = fila;
    return _visto(fila);
  }

  @override
  Future<ModeloPartido> editarPartido(ModeloPartido editado) async {
    final fila = _delOrganizador(
      editado.id,
      'Solo el organizador puede editar el partido.',
    );
    final conCupos = fila.partido.conCuposTotales(editado.cuposTotales);
    return _guardar(
      fila,
      conCupos.copyWith(
        titulo: editado.titulo,
        disciplina: editado.disciplina,
        icono: editado.disciplina,
        ubicacion: editado.ubicacion,
        fechaHora: editado.fechaHora,
      ),
    );
  }

  @override
  Future<ModeloPartido> completarEquipo(String partidoId) async {
    final fila = _buscar(partidoId);
    return _guardar(fila, _visto(fila).completarEquipo());
  }

  @override
  Future<void> eliminarPartido(String partidoId) async {
    _delOrganizador(partidoId, 'Solo el organizador puede eliminarlo.');
    _partidos.remove(partidoId);
    _inscripciones.removeWhere((i) => i.partidoId == partidoId);
    _suplentes.removeWhere((i) => i.partidoId == partidoId);
  }

  @override
  Future<ModeloPartido> unirseAPartido(String partidoId) async {
    final fila = _buscar(partidoId);
    final unido = _visto(fila).unirse(); // lanza StateError con el motivo
    _inscripciones.add((
      partidoId: partidoId,
      jugadorId: usuarioId,
      nombre: usuarioNombre,
    ));
    return _guardar(fila, unido);
  }

  @override
  Future<ModeloPartido> salirDelPartido(String partidoId) async {
    final fila = _buscar(partidoId);
    final salido = _visto(fila).salir(); // lanza StateError con el motivo
    _inscripciones.removeWhere(
      (i) => i.partidoId == partidoId && i.jugadorId == usuarioId,
    );
    final indice = _suplentes.indexWhere((i) => i.partidoId == partidoId);
    if (indice < 0) return _guardar(fila, salido);

    final primero = _suplentes.removeAt(indice);
    _inscripciones.add((
      partidoId: partidoId,
      jugadorId: primero.jugadorId,
      nombre: primero.nombre,
    ));
    return _guardar(
      fila,
      salido.copyWith(
        cuposOcupados: fila.partido.cuposOcupados,
        estado: EstadoPartido.equipoCompleto,
      ),
    );
  }

  @override
  Future<ModeloPartido> entrarEnEspera(String partidoId) async {
    final fila = _buscar(partidoId);
    final partido = _visto(fila);
    if (!partido.puedeEntrarEnEspera) {
      throw StateError(
        partido.estoyEnEspera
            ? 'Ya estás en la lista de suplentes.'
            : partido.motivoRechazoUnirse ??
                  'El equipo todavía tiene cupos: puedes unirte directamente.',
      );
    }
    _suplentes.add((
      partidoId: partidoId,
      jugadorId: usuarioId,
      nombre: usuarioNombre,
    ));
    return _visto(fila);
  }

  @override
  Future<ModeloPartido> salirDeEspera(String partidoId) async {
    final fila = _buscar(partidoId);
    final indice = _suplentes.indexWhere(
      (i) => i.partidoId == partidoId && i.jugadorId == usuarioId,
    );
    if (indice < 0) throw StateError('No estás en la lista de suplentes.');
    _suplentes.removeAt(indice);
    return _visto(fila);
  }
}

class _Fila {
  final String organizadorId;
  ModeloPartido partido;
  final int orden;

  _Fila(this.organizadorId, this.partido, this.orden);
}
