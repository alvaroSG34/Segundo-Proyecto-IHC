import 'package:material_ui/material_ui.dart';
import 'package:unisport/tema/iconos_app.dart';

import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';

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

  List<ParticipantePartido> _jugadoresEquipo(String letra) =>
      _participantes.where((p) => _equipos[p.id] == letra).toList();

  void _moverJugador(ParticipantePartido participante, String equipoDestino) {
    if (participante.esOrganizador || _guardando) return;
    setState(() {
      _equipos[participante.id] = equipoDestino;
      if (equipoDestino == 'A' && _capitanId == participante.id) {
        _capitanId = null;
      }
    });
  }

  Widget _tarjetaEquipo(String letra, {bool editable = false}) {
    final jugadores = _jugadoresEquipo(letra);
    final esEquipoA = letra == 'A';
    final colorEquipo = esEquipoA ? TemaApp.verdeOscuro : TemaApp.azulDeportivo;
    final fondoEquipo = esEquipoA ? TemaApp.verdeSuave : TemaApp.azulSuave;

    return Container(
      decoration: BoxDecoration(
        color: TemaApp.superficie,
        border: Border.all(color: TemaApp.borde),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            color: fondoEquipo,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Equipo $letra',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: TemaApp.textoPrincipal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${jugadores.length} ${jugadores.length == 1 ? 'jugador' : 'jugadores'}',
                  style: const TextStyle(color: TemaApp.textoSecundario),
                ),
              ],
            ),
          ),
          if (jugadores.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mueve aquí a los jugadores que formarán este equipo.',
                style: TextStyle(color: TemaApp.textoSecundario),
              ),
            )
          else
            for (var i = 0; i < jugadores.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              _filaJugador(
                jugadores[i],
                equipo: letra,
                colorEquipo: colorEquipo,
                editable: editable,
              ),
            ],
        ],
      ),
    );
  }

  Widget _filaJugador(
    ParticipantePartido participante, {
    required String equipo,
    required Color colorEquipo,
    required bool editable,
  }) {
    final esCapitan = participante.esOrganizador
        ? equipo == 'A'
        : participante.id == _capitanId;
    final destino = equipo == 'A' ? 'B' : 'A';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(LucideIcons.userRound, color: colorEquipo, size: 20),
      title: Text(
        participante.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: esCapitan
          ? Text(participante.esOrganizador ? 'Capitán (tú)' : 'Capitán')
          : null,
      trailing: editable && !participante.esOrganizador
          ? IconButton(
              key: ValueKey('mover_jugador_${participante.id}_$destino'),
              tooltip: 'Mover a Equipo $destino',
              onPressed: _guardando
                  ? null
                  : () => _moverJugador(participante, destino),
              iconSize: 18,
              icon: Icon(
                equipo == 'A' ? LucideIcons.arrowRight : LucideIcons.arrowLeft,
              ),
            )
          : null,
    );
  }

  Widget _selectorCapitan(List<ParticipantePartido> rivales) =>
      DropdownButtonFormField<String>(
        key: ValueKey('capitan_${_capitanId ?? "ninguno"}_${rivales.length}'),
        initialValue: _capitanId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Capitán del Equipo B',
          prefixIcon: Icon(LucideIcons.crown),
        ),
        hint: Text(
          rivales.isEmpty
              ? 'Mueve al menos un jugador al Equipo B'
              : 'Selecciona al capitán',
        ),
        items: [
          for (final p in rivales)
            DropdownMenuItem(value: p.id, child: Text(p.nombre)),
        ],
        onChanged: _guardando
            ? null
            : (valor) => setState(() => _capitanId = valor),
      );

  Widget _estadoPropuesta() {
    final estado = _propuesta!.estado;
    final aceptada = estado == EstadoPropuesta.aceptada;
    final color = aceptada ? TemaApp.verdeOscuro : TemaApp.naranjaAviso;
    final fondo = aceptada ? TemaApp.verdeSuave : TemaApp.naranjaSuave;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            aceptada ? LucideIcons.circleCheck : LucideIcons.clock3,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            'Propuesta: ${estado.etiqueta}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _mensajeEquiposPorProponer() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: TemaApp.azulSuave,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TemaApp.azulDeportivo.withValues(alpha: .2)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, color: TemaApp.azulDeportivo),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Los equipos todavía no están definidos.',
            style: TextStyle(color: TemaApp.textoPrincipal),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rivales = _participantes.where((p) => _equipos[p.id] == 'B').toList();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppBar(title: const Text('Equipos del partido')),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _cargando
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
                      const SizedBox(height: 6),
                      Text(
                        _editando
                            ? 'Reparte los jugadores y elige al capitán del Equipo B. Tú eres el capitán del Equipo A.'
                            : 'Distribución y estado de los equipos del partido.',
                        style: const TextStyle(color: TemaApp.textoSecundario),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        CajaMensaje(texto: _error!),
                        TextButton(
                          onPressed: _guardando ? null : _cargar,
                          child: const Text('Volver a cargar'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_editando) ...[
                        _tarjetaEquipo('A', editable: true),
                        const SizedBox(height: 14),
                        _tarjetaEquipo('B', editable: true),
                        const SizedBox(height: 14),
                        _selectorCapitan(rivales),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('enviar_propuesta_equipos'),
                          onPressed: _guardando ? null : _guardar,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                          ),
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
                        _estadoPropuesta(),
                        const SizedBox(height: 14),
                        _tarjetaEquipo('A'),
                        const SizedBox(height: 14),
                        _tarjetaEquipo('B'),
                        if (_puedeEditar)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: OutlinedButton.icon(
                              onPressed: _guardando
                                  ? null
                                  : () => setState(() => _editando = true),
                              icon: const Icon(LucideIcons.pencil),
                              label: const Text('Editar propuesta'),
                            ),
                          ),
                        if (_propuesta!.estado == EstadoPropuesta.pendiente &&
                            _propuesta!.capitanRivalId == widget.usuarioId &&
                            !_partido.fechaPasada) ...[
                          ElevatedButton(
                            onPressed: _guardando
                                ? null
                                : () => _responder(true),
                            child: const Text('Aceptar'),
                          ),
                          OutlinedButton(
                            onPressed: _guardando
                                ? null
                                : () => _responder(false),
                            child: const Text('Rechazar'),
                          ),
                        ],
                      ] else ...[
                        _mensajeEquiposPorProponer(),
                        if (!_partido.fechaPasada && _partido.soyOrganizador)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Cierra la convocatoria para proponer los equipos.',
                              style: TextStyle(color: TemaApp.textoSecundario),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
