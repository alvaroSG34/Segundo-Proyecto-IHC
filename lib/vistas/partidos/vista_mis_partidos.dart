import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/tema/iconos_app.dart';

import '../../modelos/baja_tardia.dart';
import '../../modelos/modelo_partido.dart';
import '../../modelos/filtro_partidos.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/partidos/repositorio_partidos_supabase.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../servicios/partidos/controlador_explorar.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/tarjeta_mis_partidos.dart';
import '../../widgets/filtros_mis_partidos.dart';
import '../../widgets/barra_navegacion_partidos.dart';
import 'vista_crear_partido.dart';
import 'vista_reprogramar_partido.dart';
import 'vista_detalle_partido.dart';
import '../autenticacion/vista_login.dart';

/// Ruta Privada: Mis Partidos (Protegida)
/// Si un usuario sin sesión intenta acceder, se redirige inmediatamente a la pantalla de Login.
///
/// Cada acción se guarda en la base de datos compartida (Supabase), así los
/// cambios se ven desde cualquier dispositivo y se mantienen al recargar.
class VistaMisPartidos extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final RepositorioPartidos? repositorioPartidos;
  final ServicioAnalitica? servicioAnalitica;
  final ControladorExplorar controladorExplorar;
  final DateTime? referenciaTemporal;

  const VistaMisPartidos({
    super.key,
    required this.servicioAuth,
    this.repositorioPartidos,
    this.servicioAnalitica,
    required this.controladorExplorar,
    this.referenciaTemporal,
  });

  @override
  State<VistaMisPartidos> createState() => _VistaMisPartidosState();
}

class _VistaMisPartidosState extends State<VistaMisPartidos> {
  late final RepositorioPartidos _repositorio =
      widget.repositorioPartidos ??
      RepositorioPartidosSupabase(Supabase.instance.client);
  late final _analitica =
      widget.servicioAnalitica ??
      crearAnalitica(widget.repositorioPartidos == null);

  List<ModeloPartido> _partidos = [];
  Map<String, List<String>> _suplentes = {};
  Map<String, List<BajaTardia>> _bajasTardias = {};
  bool _cargando = true;
  String? _errorCarga;
  int _consulta = 0;
  String _filtroActivo = 'organizados';
  FiltroPartidos _filtros = const FiltroPartidos(
    periodo: PeriodoPartidos.proximos,
  );

  @override
  void initState() {
    super.initState();
    _verificarAccesoProtegido();
    _cargarPartidos();
  }

  // Verificación de Ruta Privada Protegida
  void _verificarAccesoProtegido() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.servicioAuth.estaAutenticado) {
        // Redirección inmediata al Login por falta de sesión
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VistaLogin(
              servicioAuth: widget.servicioAuth,
              mensajeRedireccion:
                  'Debes iniciar sesión para acceder a "Mis Partidos".',
            ),
          ),
        );
      }
    });
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? TemaApp.rojoAlerta : null,
      ),
    );
  }

  /// Ejecuta una operación en la base de datos. Si una regla la rechaza o no
  /// hay conexión, muestra el motivo y devuelve null.
  Future<T?> _intentar<T>(Future<T> Function() operacion) async {
    try {
      return await operacion();
    } on StateError catch (e) {
      if (mounted) _avisar(e.message, error: true);
      return null;
    }
  }

  void _reemplazar(ModeloPartido actualizado) {
    setState(() {
      _partidos = [
        for (final p in _partidos) p.id == actualizado.id ? actualizado : p,
      ];
    });
  }

  // 5 - RECUPERAR: lee de la base de datos los partidos que organizo y los de
  // otros estudiantes a los que me uní.
  Future<void> _cargarPartidos() async {
    if (widget.servicioAuth.usuarioActual == null) return;

    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final propios = await _repositorio.obtenerMisPartidos();
      final unidos = await _repositorio.obtenerPartidosUnidos();
      final suplentes = await _repositorio.obtenerSuplentes();
      final bajasTardias = await _repositorio.obtenerBajasTardias();
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _partidos = [...propios, ...unidos];
        _suplentes = suplentes;
        _bajasTardias = bajasTardias;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        _errorCarga = error is StateError
            ? error.message
            : 'No se pudieron cargar tus partidos. Intenta nuevamente.';
      });
    }
  }

  Future<void> _crearPartido() async {
    final guardado = await VistaCrearPartido.abrirYGuardar(
      context,
      organizadorNombre: widget.servicioAuth.usuarioActual?.nombre,
      repositorio: _repositorio,
      servicioAnalitica: _analitica,
    );
    if (guardado == null || !mounted) return;
    setState(() => _partidos = [guardado, ..._partidos]);
    _avisar('Partido "${guardado.titulo}" creado y guardado');
  }

  // ACCIÓN "EDITAR PARTIDO": abre el formulario con datos pre-cargados y actualiza
  Future<void> _editarPartido(ModeloPartido partido) async {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) return;

    final guardado = await Navigator.push<ModeloPartido>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaCrearPartido(
          organizadorNombre: usuario.nombre,
          partidoAEditar: partido,
          guardarPartido: _repositorio.editarPartido,
          servicioAnalitica: _analitica,
        ),
      ),
    );

    if (guardado == null || !mounted) return;

    _reemplazar(guardado);
    _avisar('Partido "${guardado.titulo}" actualizado');
  }

  Future<void> _abrirDetalle(ModeloPartido partido) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaDetallePartido(
          partido: partido,
          repositorio: _repositorio,
          usuarioId: widget.servicioAuth.usuarioActual!.id,
          servicioAnalitica: _analitica,
          onEditar: partido.soyOrganizador
              ? () => _editarPartido(partido)
              : null,
          onCompletarEquipo: partido.puedeCompletarEquipo
              ? () => _completarEquipo(partido)
              : null,
          onReprogramar: partido.puedeReprogramar
              ? () => _reprogramarPartido(partido)
              : null,
          onReconfirmar: partido.reconfirmacionPendiente
              ? () => _responderReprogramacion(partido, true)
              : null,
          onRetirarseReprogramacion: partido.reconfirmacionPendiente
              ? () => _responderReprogramacion(partido, false)
              : null,
          suplentes: partido.soyOrganizador
              ? _suplentes[partido.id] ?? const []
              : null,
          bajasTardias: partido.soyOrganizador
              ? _bajasTardias[partido.id] ?? const []
              : null,
          onEliminar: partido.soyOrganizador
              ? () => _eliminarPartido(partido)
              : null,
          onSalir: !partido.soyOrganizador && partido.puedeSalir
              ? () => _salirDelPartido(partido)
              : null,
          recargarPartido: () => _buscarPartidoActual(partido.id),
        ),
      ),
    );
    if (mounted) await _cargarPartidos();
  }

  Future<ModeloPartido?> _buscarPartidoActual(String id) async {
    final partidos = [
      ...await _repositorio.obtenerMisPartidos(),
      ...await _repositorio.obtenerPartidosUnidos(),
    ];
    for (final partido in partidos) {
      if (partido.id == id) return partido;
    }
    return null;
  }

  Future<void> _abrirFiltros() async {
    final nuevos = await mostrarFiltrosMisPartidos(context, _filtros);
    if (nuevos == null || !mounted) return;
    setState(() => _filtros = nuevos);
  }

  void _quitarFiltroDeporte() =>
      setState(() => _filtros = _filtros.copiarCon(quitarDeporte: true));

  void _quitarFiltroFecha() => setState(
    () =>
        _filtros = const FiltroPartidos(periodo: PeriodoPartidos.proximos)
            .copiarCon(deporte: _filtros.deporte),
  );

  Future<void> _completarEquipo(ModeloPartido partido) async {
    final cerrado = await _intentar(
      () => _repositorio.completarEquipo(partido.id),
    );
    if (cerrado == null || !mounted) return;
    _reemplazar(cerrado);
    _avisar(
      'Convocatoria cerrada: ${cerrado.cuposOcupados}/${cerrado.cuposTotales} cupos ocupados.',
    );
  }

  Future<void> _reprogramarPartido(ModeloPartido partido) async {
    final guardado = await Navigator.push<ModeloPartido>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaReprogramarPartido(
          partido: partido,
          repositorio: _repositorio,
          servicioAnalitica: _analitica,
        ),
      ),
    );
    if (guardado == null || !mounted) return;
    await _cargarPartidos();
    if (mounted) _avisar('Partido reprogramado. El equipo puede reconfirmar.');
  }

  Future<void> _responderReprogramacion(
    ModeloPartido partido,
    bool acepta,
  ) async {
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(_analitica, EventosAnalitica.reconfirmacionIniciada, props);
    if (!acepta) {
      final confirmar = await confirmarAccion(
        context,
        titulo: '¿Retirarte del partido?',
        mensaje: 'Liberarás tu plaza. Si hay suplentes, entrará el primero.',
        textoConfirmar: 'Sí, retirarme',
      );
      if (confirmar != true || !mounted) return;
    }
    final resultado = await _intentar(
      () => _repositorio.responderReprogramacion(partido.id, acepta),
    );
    if (resultado == null) {
      registrarEvento(_analitica, EventosAnalitica.reconfirmacionFallida, {
        ...props,
        'codigo_error': 'servicio_partidos',
      });
      return;
    }
    registrarEvento(
      _analitica,
      acepta
          ? EventosAnalitica.reprogramacionAceptada
          : EventosAnalitica.reprogramacionRechazada,
      props,
    );
    if (!mounted) return;
    await _cargarPartidos();
    if (mounted) {
      _avisar(
        acepta ? 'Tu plaza quedó confirmada.' : 'Te retiraste del partido.',
      );
    }
  }

  // ACCIÓN "ELIMINAR PARTIDO": solicita confirmación previa antes de borrar
  Future<void> _eliminarPartido(ModeloPartido partido) async {
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(_analitica, EventosAnalitica.eliminacionIniciada, props);
    final confirmar = await confirmarAccion(
      context,
      titulo: '¿Eliminar partido?',
      mensaje:
          'Se eliminará "${partido.titulo}", sus inscripciones, suplentes y resultados. Esta acción no se puede deshacer.',
      textoConfirmar: 'Eliminar',
    );

    if (confirmar != true || !mounted) return;

    final eliminado = await _intentar(() async {
      await _repositorio.eliminarPartido(partido.id);
      registrarEvento(_analitica, EventosAnalitica.partidoEliminado, props);
      return true;
    });
    if (eliminado == null) {
      registrarEvento(_analitica, EventosAnalitica.eliminacionFallida, {
        ...props,
        'codigo_error': 'servicio_partidos',
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _partidos = _partidos.where((p) => p.id != partido.id).toList();
    });
    _avisar('Partido "${partido.titulo}" eliminado');
  }

  // ACCIÓN "SALIR DEL PARTIDO" (H3): quien se había unido libera su cupo
  Future<void> _salirDelPartido(ModeloPartido partido) async {
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(_analitica, EventosAnalitica.salidaIniciada, props);
    final ahora = widget.referenciaTemporal ?? DateTime.now();
    final bajaTardia = partido.esBajaTardia(ahora: ahora);
    final confirmar = await confirmarAccion(
      context,
      titulo: '¿Salir del partido?',
      mensaje: bajaTardia
          ? 'Faltan menos de 2 horas para "${partido.titulo}". Saldrás del equipo y la baja tardía será visible para el organizador.'
          : 'Dejarás tu cupo en "${partido.titulo}" y otra persona podrá tomarlo.',
      textoConfirmar: 'Sí, salir',
    );
    if (confirmar != true || !mounted) return;

    try {
      final salido = await _repositorio.salirDelPartido(partido.id);
      final resultado = {...props};
      final anticipacion = anticipacionSalida(partido.fechaInicio, ahora);
      if (anticipacion != null) resultado['anticipacion'] = anticipacion;
      registrarEvento(_analitica, EventosAnalitica.salidaCompletada, resultado);
      if (!mounted) return;
      setState(
        () => _partidos = _partidos.where((p) => p.id != partido.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bajaTardia
                ? 'Baja tardía registrada en "${partido.titulo}".'
                : salido.estaLleno
                ? 'Saliste de "${partido.titulo}". Entró el primer suplente.'
                : 'Saliste de "${partido.titulo}". Tu cupo quedó libre.',
          ),
        ),
      );
      await _cargarPartidos();
    } catch (e) {
      registrarEvento(_analitica, EventosAnalitica.salidaFallida, {
        ...props,
        'codigo_error': 'servicio_partidos',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puedes salir. ${e is StateError ? e.message : 'Intenta nuevamente.'}',
          ),
          backgroundColor: TemaApp.rojoAlerta,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ahora = widget.referenciaTemporal ?? DateTime.now();
    final partidosFiltrados =
        _partidos.where((p) {
          if (_filtroActivo == 'organizados' && !p.soyOrganizador) return false;
          if (_filtroActivo == 'unido' && p.soyOrganizador) return false;
          return _filtros.coincide(p, ahora);
        }).toList()..sort((a, b) {
          final fechaA = a.fechaInicio;
          final fechaB = b.fechaInicio;
          // Las fechas desconocidas quedan al final de "Todas las fechas".
          if (fechaA == null) return fechaB == null ? a.id.compareTo(b.id) : 1;
          if (fechaB == null) return -1;
          final pasadoA = fechaA.isBefore(ahora);
          final pasadoB = fechaB.isBefore(ahora);
          if (pasadoA != pasadoB) return pasadoA ? 1 : -1;
          final orden = pasadoA
              ? fechaB.compareTo(fechaA)
              : fechaA.compareTo(fechaB);
          return orden == 0 ? a.id.compareTo(b.id) : orden;
        });

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) => AppBar(
                title: const Text('Mis partidos'),
                actions: [
                  if (constraints.maxWidth < 390)
                    IconButton(
                      key: const Key('mis_partidos_crear'),
                      tooltip: 'Crear partido',
                      onPressed: _crearPartido,
                      icon: const Icon(LucideIcons.plus),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: TemaApp.verdeDeportivo,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.icon(
                        key: const Key('mis_partidos_crear'),
                        onPressed: _crearPartido,
                        icon: const Icon(LucideIcons.plus, size: 19),
                        label: const Text('Crear partido'),
                        style: FilledButton.styleFrom(
                          backgroundColor: TemaApp.verdeDeportivo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Misma navegación principal que la portada (Clase 15, hallazgo #1 · H6)
      bottomNavigationBar: BarraNavegacionPartidos(
        selectedIndex: 1,
        servicioAuth: widget.servicioAuth,
        repositorioPartidos: _repositorio,
        servicioAnalitica: _analitica,
        controladorExplorar: widget.controladorExplorar,
        referenciaTemporal: widget.referenciaTemporal,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _construirFiltros(),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _tituloPeriodo,
                        key: const Key('mis_partidos_titulo_lista'),
                        style: TemaApp.titulo(tamano: 20),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('mis_partidos_abrir_filtros'),
                      onPressed: _cargando ? null : _abrirFiltros,
                      icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                      label: const Text('Filtros'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    if (_cantidadFiltrosActivos > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: const Key('mis_partidos_filtros_cantidad'),
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: TemaApp.azulDeportivo,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_cantidadFiltrosActivos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_hayFiltrosVisibles) ...[
                  const SizedBox(height: 10),
                  _construirChipsFiltros(),
                ],
                const SizedBox(height: 14),
                if (_cargando)
                  Semantics(
                    key: const Key('mis_partidos_cargando'),
                    container: true,
                    label: 'Cargando mis partidos',
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_errorCarga != null)
                  Column(
                    key: const Key('mis_partidos_error'),
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: CajaMensaje(texto: _errorCarga!),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        key: const Key('mis_partidos_reintentar'),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.standard,
                          minimumSize: const Size(48, 52),
                        ),
                        onPressed: _cargarPartidos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                else if (partidosFiltrados.isEmpty)
                  _construirEstadoVacio()
                else
                  ...partidosFiltrados.map(
                    (p) => TarjetaMisPartidos(
                      partido: p,
                      alVerDetalle: () => _abrirDetalle(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _tituloPeriodo => switch (_filtros.periodo) {
    PeriodoPartidos.proximos => 'Próximos partidos',
    PeriodoPartidos.vencidos => 'Partidos pasados',
    PeriodoPartidos.todos => 'Todos los partidos',
  };

  int get _cantidadTodos => _partidos
      .where(
        (p) =>
            _filtros.coincide(p, widget.referenciaTemporal ?? DateTime.now()),
      )
      .length;

  bool get _hayFiltrosVisibles =>
      _filtros.deporte != null ||
      _filtros.fecha != FiltroFecha.cualquiera ||
      _filtros.periodo != PeriodoPartidos.proximos;

  int get _cantidadFiltrosActivos =>
      (_filtros.deporte == null ? 0 : 1) +
      (_filtros.fecha != FiltroFecha.cualquiera ||
              _filtros.periodo != PeriodoPartidos.proximos
          ? 1
          : 0);

  Widget _construirChipsFiltros() => Wrap(
    spacing: 8,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (_filtros.deporte case final deporte?)
        InputChip(
          key: const Key('mis_partidos_chip_deporte'),
          avatar: const Icon(LucideIcons.trophy, size: 15),
          label: Text(deporte),
          deleteIcon: const Icon(LucideIcons.x, size: 16),
          deleteButtonTooltipMessage: 'Quitar filtro de deporte',
          onDeleted: _quitarFiltroDeporte,
        ),
      if (_filtros.fecha != FiltroFecha.cualquiera ||
          _filtros.periodo != PeriodoPartidos.proximos)
        InputChip(
          key: const Key('mis_partidos_chip_fecha'),
          avatar: const Icon(LucideIcons.calendarDays, size: 15),
          label: Text(_etiquetaFiltroFecha),
          deleteIcon: const Icon(LucideIcons.x, size: 16),
          deleteButtonTooltipMessage: 'Quitar filtro de fecha',
          onDeleted: _quitarFiltroFecha,
        ),
      if (_cantidadFiltrosActivos > 1)
        TextButton(
          key: const Key('mis_partidos_limpiar_todos'),
          onPressed: () => setState(
            () => _filtros = const FiltroPartidos(
              periodo: PeriodoPartidos.proximos,
            ),
          ),
          child: const Text('Limpiar filtros'),
        ),
    ],
  );

  String get _etiquetaFiltroFecha {
    if (_filtros.fecha == FiltroFecha.hoy) return 'Hoy';
    if (_filtros.fecha == FiltroFecha.estaSemana) return 'Esta semana';
    if (_filtros.fecha == FiltroFecha.proximos7Dias) return 'Próximos 7 días';
    if (_filtros.fecha == FiltroFecha.rango &&
        _filtros.desde != null &&
        _filtros.hasta != null) {
      final desde = _filtros.desde!;
      final hasta = _filtros.hasta!;
      return 'Fecha: ${desde.day}/${desde.month} – ${hasta.day}/${hasta.month}';
    }
    return switch (_filtros.periodo) {
      PeriodoPartidos.todos => 'Todas las fechas',
      PeriodoPartidos.proximos => 'Próximos partidos',
      PeriodoPartidos.vencidos => 'Partidos pasados',
    };
  }

  Widget _construirFiltros() {
    return Row(
      children: [
        _construirBotonFiltro('Creados por mí', 'organizados'),
        const SizedBox(width: 8),
        _construirBotonFiltro('Como jugador', 'unido'),
        const SizedBox(width: 8),
        _construirBotonFiltro(
          'Todos${_cargando ? '' : ' ($_cantidadTodos)'}',
          'todos',
        ),
      ],
    );
  }

  Widget _construirBotonFiltro(String texto, String clave) {
    final activo = _filtroActivo == clave;
    final habilitado = !_cargando;
    final nombre = clave == 'todos' ? 'Todos' : texto;
    final disponible = !_cargando && _errorCarga == null;
    return Expanded(
      child: Semantics(
        key: Key('mis_partidos_filtro_$clave'),
        container: true,
        label: nombre,
        value: clave == 'todos'
            ? disponible
                  ? '$_cantidadTodos partidos'
                  : 'No disponible'
            : null,
        button: true,
        selected: activo,
        enabled: habilitado,
        excludeSemantics: true,
        onTap: habilitado ? () => setState(() => _filtroActivo = clave) : null,
        child: ChoiceChip(
          selected: activo,
          onSelected: habilitado
              ? (_) => setState(() => _filtroActivo = clave)
              : null,
          showCheckmark: false,
          backgroundColor: Colors.white,
          selectedColor: TemaApp.textoPrincipal,
          side: BorderSide(
            color: activo ? TemaApp.textoPrincipal : TemaApp.borde,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          label: SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                clave == 'todos'
                    ? disponible
                          ? 'Todos ($_cantidadTodos)'
                          : 'Todos (—)'
                    : texto,
                key: clave == 'todos'
                    ? const Key('mis_partidos_cantidad_total')
                    : null,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : TemaApp.textoSecundario,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Container(
      key: const Key('mis_partidos_vacio'),
      padding: const EdgeInsets.all(24),
      decoration: TemaApp.tarjeta(),
      child: Column(
        children: [
          const Icon(
            LucideIcons.calendarDays,
            size: 28,
            color: TemaApp.textoSecundario,
          ),
          const SizedBox(height: 10),
          Text(
            _filtros.deporte != null || _filtros.fecha != FiltroFecha.cualquiera
                ? 'No hay partidos con estos filtros'
                : _filtros.periodo == PeriodoPartidos.todos
                ? 'No tienes partidos en esta categoría'
                : _filtros.periodo == PeriodoPartidos.proximos
                ? 'No tienes partidos próximos'
                : 'No tienes partidos pasados',
            textAlign: TextAlign.center,
            style: TemaApp.titulo(tamano: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _filtros.deporte != null || _filtros.fecha != FiltroFecha.cualquiera
                ? 'Prueba ajustar o limpiar los filtros.'
                : _filtros.periodo == PeriodoPartidos.vencidos
                ? 'Prueba otra fecha o cambia la categoría.'
                : _filtroActivo == 'unido'
                ? 'Toca "Explorar partidos para unirme" para encontrar uno.'
                : _filtroActivo == 'organizados'
                ? 'Toca "Crear partido" para agregar uno.'
                : 'Cambia la categoría o crea un partido para comenzar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: TemaApp.textoSecundario),
          ),
        ],
      ),
    );
  }
}
