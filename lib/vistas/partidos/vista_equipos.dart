import 'package:flutter/material.dart';

import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../modelos/resultado_partido.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/caja_mensaje.dart';

class VistaEquipos extends StatefulWidget {
  final ModeloPartido partido;
  final RepositorioPartidos repositorio;
  final String usuarioId;
  final ServicioAnalitica servicioAnalitica;

  const VistaEquipos({
    super.key,
    required this.partido,
    required this.repositorio,
    required this.usuarioId,
    this.servicioAnalitica = const ServicioAnaliticaNula(),
  });

  @override
  State<VistaEquipos> createState() => _VistaEquiposState();
}

class _VistaEquiposState extends State<VistaEquipos> {
  late ModeloPartido _partido = widget.partido;
  List<ParticipantePartido> _participantes = [];
  PropuestaEquipos? _propuesta;
  ResultadoValidadoPartido? _resultado;
  final Map<String, String> _equipos = {};
  final _marcadorA = TextEditingController();
  final _marcadorB = TextEditingController();
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

  @override
  void dispose() {
    _marcadorA.dispose();
    _marcadorB.dispose();
    super.dispose();
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
      final resultado = propuesta?.estado == EstadoPropuesta.aceptada
          ? await widget.repositorio.obtenerResultado(_partido.id)
          : null;
      if (!mounted) return;
      setState(() {
        _partido = actuales.first;
        _participantes = participantes;
        _propuesta = propuesta;
        _resultado = resultado;
        _equipos.clear();
        for (final p in participantes) {
          _equipos[p.id] = propuesta?.equipoB.contains(p.id) == true
              ? 'B'
              : 'A';
        }
        _capitanId = propuesta?.capitanRivalId;
        _editando = propuesta == null && _puedeEditar;
        if (resultado != null) {
          _marcadorA.text = '${resultado.marcadorEquipoA}';
          _marcadorB.text = '${resultado.marcadorEquipoB}';
        }
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
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(
      widget.servicioAnalitica,
      EventosAnalitica.respuestaPropuestaIniciada,
      props,
    );
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
      registrarEvento(
        widget.servicioAnalitica,
        acepta
            ? EventosAnalitica.propuestaAceptada
            : EventosAnalitica.propuestaRechazada,
        props,
      );
      await _cargar();
    } on StateError catch (e) {
      registrarEvento(
        widget.servicioAnalitica,
        EventosAnalitica.respuestaPropuestaFallida,
        {...props, 'codigo_error': 'servicio_partidos'},
      );
      // Recargar evita seguir mostrando una propuesta que ya fue reemplazada.
      await _cargar();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _registrarResultado() async {
    if (_guardando) return;
    final equipoA = int.tryParse(_marcadorA.text.trim());
    final equipoB = int.tryParse(_marcadorB.text.trim());
    if (equipoA == null || equipoB == null) {
      setState(() => _error = 'Ingresa dos valores enteros para el marcador.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repositorio.registrarResultado(
        _partido.id,
        equipoA,
        equipoB,
      );
      await _cargar();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _disputarResultado() async {
    if (_guardando) return;
    final props = _iniciarValidacionResultado();
    var motivoEscrito = '';
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disputar marcador'),
        content: TextField(
          autofocus: true,
          maxLength: 300,
          onChanged: (valor) => motivoEscrito = valor,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Explica qué debe corregirse',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motivoEscrito),
            child: const Text('Enviar disputa'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;
    await _actuarSobreResultado(
      EventosAnalitica.resultadoDisputado,
      () => widget.repositorio.disputarResultado(
        _partido.id,
        _resultado!.revision,
        motivo,
      ),
      props,
    );
  }

  Map<String, String> _iniciarValidacionResultado() {
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(
      widget.servicioAnalitica,
      EventosAnalitica.validacionResultadoIniciada,
      props,
    );
    return props;
  }

  Future<void> _confirmarResultado() async {
    if (_guardando) return;
    await _actuarSobreResultado(
      EventosAnalitica.resultadoConfirmado,
      () => widget.repositorio.confirmarResultado(
        _partido.id,
        _resultado!.revision,
      ),
      _iniciarValidacionResultado(),
    );
  }

  Future<void> _actuarSobreResultado(
    String evento,
    Future<void> Function() accion,
    Map<String, String> props,
  ) async {
    if (_guardando) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await accion();
      registrarEvento(widget.servicioAnalitica, evento, props);
      await _cargar();
    } on StateError catch (e) {
      registrarEvento(
        widget.servicioAnalitica,
        EventosAnalitica.validacionResultadoFallida,
        {...props, 'codigo_error': 'servicio_partidos'},
      );
      await _cargar();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _seccionResultado() {
    final resultado = _resultado;
    final esCapitan = _propuesta!.capitanRivalId == widget.usuarioId;
    final puedeRegistrar =
        _partido.soyOrganizador &&
        (resultado == null ||
            resultado.estado == EstadoResultadoPartido.disputado);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          'Resultado del partido',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (resultado == null)
          const Text('El organizador todavía no registró el marcador.')
        else ...[
          Text(
            'Equipo A ${resultado.marcador} Equipo B',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Estado: ${resultado.estado.etiqueta}'),
          if (resultado.motivoDisputa != null)
            CajaMensaje(
              texto: 'Motivo de la disputa: ${resultado.motivoDisputa}',
            ),
          if (resultado.esDefinitivo)
            const CajaMensaje(
              texto:
                  'Resultado definitivo: fue confirmado por el capitán rival.',
            )
          else
            const Text('Este resultado aún no es definitivo.'),
        ],
        if (puedeRegistrar) ...[
          const SizedBox(height: 16),
          Text(
            resultado == null ? 'Registrar marcador' : 'Corregir marcador',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('marcador_equipo_a'),
                  controller: _marcadorA,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Equipo A'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('-'),
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('marcador_equipo_b'),
                  controller: _marcadorB,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Equipo B'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _guardando ? null : _registrarResultado,
            child: Text(
              resultado == null ? 'Registrar marcador' : 'Enviar corrección',
            ),
          ),
        ],
        if (resultado?.estado == EstadoResultadoPartido.pendiente &&
            esCapitan) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _guardando ? null : _confirmarResultado,
            child: const Text('Confirmar resultado'),
          ),
          OutlinedButton(
            onPressed: _guardando ? null : _disputarResultado,
            child: const Text('Disputar resultado'),
          ),
        ],
        if (resultado != null && resultado.historial.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Historial', style: Theme.of(context).textTheme.titleMedium),
          for (final evento in resultado.historial)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(evento.accion.etiqueta),
              subtitle: Text(
                '${evento.marcadorEquipoA} - ${evento.marcadorEquipoB} · ${evento.actorNombre}'
                '${evento.motivo == null ? '' : '\n${evento.motivo}'}',
              ),
            ),
        ],
      ],
    );
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
                    if (_propuesta!.estado == EstadoPropuesta.aceptada &&
                        _partido.fechaPasada)
                      _seccionResultado(),
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
