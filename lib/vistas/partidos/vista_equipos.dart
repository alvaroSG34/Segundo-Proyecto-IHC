import 'package:flutter/material.dart';

import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../tema/caja_mensaje.dart';

class VistaEquipos extends StatefulWidget {
  final ModeloPartido partido;
  final RepositorioPartidos repositorio;
  final String usuarioId;

  const VistaEquipos({
    super.key,
    required this.partido,
    required this.repositorio,
    required this.usuarioId,
  });

  @override
  State<VistaEquipos> createState() => _VistaEquiposState();
}

class _VistaEquiposState extends State<VistaEquipos> {
  late ModeloPartido _partido = widget.partido;
  List<ParticipantePartido> _participantes = [];
  PropuestaEquipos? _propuesta;
  final Map<String, String> _equipos = {};
  String? _capitanId;
  bool _cargando = true;
  bool _guardando = false;
  bool _editando = false;
  String? _error;

  bool get _puedeEditar =>
      _partido.soyOrganizador &&
      !_partido.fechaPasada &&
      _partido.estado == EstadoPartido.equipoCompleto;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final partidos = [
        ...await widget.repositorio.obtenerMisPartidos(),
        ...await widget.repositorio.obtenerPartidosUnidos(),
      ];
      final actuales = partidos.where((p) => p.id == widget.partido.id);
      if (actuales.isEmpty) {
        throw StateError('Este partido ya no está entre tus partidos.');
      }
      final participantes = await widget.repositorio.obtenerParticipantes(
        _partido.id,
      );
      final propuesta = await widget.repositorio.obtenerPropuesta(_partido.id);
      if (!mounted) return;
      setState(() {
        _partido = actuales.first;
        _participantes = participantes;
        _propuesta = propuesta;
        _equipos.clear();
        for (final p in participantes) {
          _equipos[p.id] = propuesta?.equipoB.contains(p.id) == true
              ? 'B'
              : 'A';
        }
        _capitanId = propuesta?.capitanRivalId;
        _editando = propuesta == null && _puedeEditar;
      });
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los equipos.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final propuesta = PropuestaEquipos(
        revision: '',
        equipoA: [
          for (final p in _participantes)
            if (_equipos[p.id] == 'A') p.id,
        ],
        equipoB: [
          for (final p in _participantes)
            if (_equipos[p.id] == 'B') p.id,
        ],
        capitanRivalId: _capitanId ?? '',
      );
      propuesta.validar(_participantes);
      await widget.repositorio.guardarPropuesta(_partido.id, propuesta);
      await _cargar();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _responder(bool acepta) async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repositorio.responderPropuesta(
        _partido.id,
        _propuesta!.revision,
        acepta,
      );
      await _cargar();
    } on StateError catch (e) {
      // Recargar evita seguir mostrando una propuesta que ya fue reemplazada.
      await _cargar();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _listaEquipo(String letra, List<String> ids) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo $letra', style: Theme.of(context).textTheme.titleMedium),
        for (final id in ids)
          ListTile(
            title: Text(
              _participantes
                      .where((p) => p.id == id)
                      .map((p) => p.nombre)
                      .firstOrNull ??
                  'Jugador',
            ),
            subtitle:
                id == _propuesta!.capitanRivalId ||
                    _participantes.any((p) => p.id == id && p.esOrganizador)
                ? const Text('Capitán')
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rivales = _participantes.where((p) => _equipos[p.id] == 'B').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos del partido')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _guardando ? () async {} : _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _partido.titulo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    CajaMensaje(texto: _error!),
                    TextButton(
                      onPressed: _guardando ? null : _cargar,
                      child: const Text('Volver a cargar'),
                    ),
                  ],
                  if (_editando) ...[
                    const Text(
                      'Reparte los jugadores y elige al capitán del Equipo B. Tú eres el capitán del Equipo A.',
                    ),
                    for (final p in _participantes)
                      ListTile(
                        title: Text(p.nombre),
                        subtitle: p.esOrganizador
                            ? const Text('Capitán del Equipo A')
                            : null,
                        trailing: DropdownButton<String>(
                          key: ValueKey('equipo_${p.id}'),
                          value: _equipos[p.id],
                          items: const [
                            DropdownMenuItem(
                              value: 'A',
                              child: Text('Equipo A'),
                            ),
                            DropdownMenuItem(
                              value: 'B',
                              child: Text('Equipo B'),
                            ),
                          ],
                          onChanged: p.esOrganizador || _guardando
                              ? null
                              : (valor) {
                                  setState(() {
                                    _equipos[p.id] = valor!;
                                    if (_capitanId == p.id && valor != 'B') {
                                      _capitanId = null;
                                    }
                                  });
                                },
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'capitan_${_capitanId ?? "ninguno"}_${rivales.length}',
                      ),
                      initialValue: _capitanId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Capitán rival',
                      ),
                      items: [
                        for (final p in rivales)
                          DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                      ],
                      onChanged: _guardando
                          ? null
                          : (valor) => setState(() => _capitanId = valor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      child: Text(
                        _guardando ? 'Enviando…' : 'Enviar propuesta',
                      ),
                    ),
                    if (_propuesta != null)
                      TextButton(
                        onPressed: _guardando
                            ? null
                            : () => setState(() => _editando = false),
                        child: const Text('Cancelar'),
                      ),
                  ] else if (_propuesta != null) ...[
                    Text('Propuesta: ${_propuesta!.estado.etiqueta}'),
                    const SizedBox(height: 16),
                    _listaEquipo('A', _propuesta!.equipoA),
                    _listaEquipo('B', _propuesta!.equipoB),
                    if (_puedeEditar)
                      OutlinedButton(
                        onPressed: _guardando
                            ? null
                            : () => setState(() => _editando = true),
                        child: const Text('Editar propuesta'),
                      ),
                    if (_propuesta!.estado == EstadoPropuesta.pendiente &&
                        _propuesta!.capitanRivalId == widget.usuarioId &&
                        !_partido.fechaPasada) ...[
                      ElevatedButton(
                        onPressed: _guardando ? null : () => _responder(true),
                        child: const Text('Aceptar'),
                      ),
                      OutlinedButton(
                        onPressed: _guardando ? null : () => _responder(false),
                        child: const Text('Rechazar'),
                      ),
                    ],
                  ] else ...[
                    const Text('Equipos por proponer'),
                    if (!_partido.fechaPasada && _partido.soyOrganizador)
                      const Text(
                        'Cierra la convocatoria para proponer los equipos.',
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
