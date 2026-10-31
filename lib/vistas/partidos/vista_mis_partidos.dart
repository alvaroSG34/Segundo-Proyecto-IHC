import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/modelo_partido.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/partidos/repositorio_partidos_supabase.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/partidos/controlador_explorar.dart';
import '../../tema/tema_app.dart';
import '../../widgets/tarjeta_partido.dart';
import 'vista_crear_partido.dart';
import 'vista_explorar_partidos.dart';
import 'vista_historial.dart';
import '../autenticacion/vista_login.dart';

/// Ruta Privada: Mis Partidos (Protegida)
/// Si un usuario sin sesión intenta acceder, se redirige inmediatamente a la pantalla de Login.
///
/// Cada acción se guarda en la base de datos compartida (Supabase), así los
/// cambios se ven desde cualquier dispositivo y se mantienen al recargar.
class VistaMisPartidos extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final RepositorioPartidos? repositorioPartidos;
  final ControladorExplorar controladorExplorar;

  const VistaMisPartidos({
    super.key,
    required this.servicioAuth,
    this.repositorioPartidos,
    required this.controladorExplorar,
  });

  @override
  State<VistaMisPartidos> createState() => _VistaMisPartidosState();
}

class _VistaMisPartidosState extends State<VistaMisPartidos> {
  late final RepositorioPartidos _repositorio =
      widget.repositorioPartidos ??
      RepositorioPartidosSupabase(Supabase.instance.client);

  List<ModeloPartido> _partidos = [];
  Map<String, List<String>> _jugadoresInscritos = {};
  bool _cargando = true;
  String _filtroActivo = 'todos';

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

    final datos = await _intentar(
      () async => (
        propios: await _repositorio.obtenerMisPartidos(),
        unidos: await _repositorio.obtenerPartidosUnidos(),
        inscritos: await _repositorio.obtenerJugadoresInscritos(),
      ),
    );
    if (!mounted) return;

    setState(() {
      if (datos != null) {
        _partidos = [...datos.propios, ...datos.unidos];
        _jugadoresInscritos = datos.inscritos;
      }
      _cargando = false;
    });
  }

  // Abre "Explorar partidos" y, al volver, recarga para mostrar las uniones nuevas
  Future<void> _explorarPartidos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VistaExplorarPartidos(
          repositorioPartidos: _repositorio,
          controladorExplorar: widget.controladorExplorar,
          servicioAuth: widget.servicioAuth,
        ),
      ),
    );
    if (mounted) await _cargarPartidos();
  }

  // Abre "Historial de participación" (Clase 16 · Tarea 4)
  Future<void> _abrirHistorial() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VistaHistorial(
          repositorioPartidos: _repositorio,
          controladorExplorar: widget.controladorExplorar,
          servicioAuth: widget.servicioAuth,
        ),
      ),
    );
    if (mounted) await _cargarPartidos();
  }

  // 1-4: CAPTURAR (formulario) -> CONSTRUIR -> GUARDAR -> MOSTRAR
  Future<void> _crearPartido() async {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) return;

    // 1 y 2: el formulario captura los datos y devuelve el ModeloPartido construido
    final nuevo = await Navigator.push<ModeloPartido>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaCrearPartido(organizadorNombre: usuario.nombre),
      ),
    );

    // Si la persona volvió atrás sin guardar, no se hace nada
    if (nuevo == null || !mounted) return;

    // 3: GUARDAR en la base de datos (devuelve el partido con su id)
    final guardado = await _intentar(() => _repositorio.crearPartido(nuevo));
    if (guardado == null || !mounted) return;

    // 4: MOSTRAR
    setState(() => _partidos = [guardado, ..._partidos]);
    _avisar('Partido "${guardado.titulo}" creado y guardado');
  }

  // ACCIÓN "COMPLETAR EQUIPO": la regla del modelo decide en pantalla y el
  // servidor la vuelve a aplicar al guardar
  Future<void> _completarEquipo(ModeloPartido partido) async {
    if (!partido.puedeCompletarEquipo) return;

    final actualizado = await _intentar(
      () => _repositorio.completarEquipo(partido.id),
    );
    if (actualizado == null || !mounted) return;

    _reemplazar(actualizado);
    _avisar('¡Equipo completo en "${partido.titulo}"!');
  }

  // ACCIÓN "EDITAR PARTIDO": abre el formulario con datos pre-cargados y actualiza
  Future<void> _editarPartido(ModeloPartido partido) async {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) return;

    final editado = await Navigator.push<ModeloPartido>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaCrearPartido(
          organizadorNombre: usuario.nombre,
          partidoAEditar: partido,
        ),
      ),
    );

    if (editado == null || !mounted) return;

    final guardado = await _intentar(() => _repositorio.editarPartido(editado));
    if (guardado == null || !mounted) return;

    _reemplazar(guardado);
    _avisar('Partido "${guardado.titulo}" actualizado');
  }

  // ACCIÓN "ELIMINAR PARTIDO": solicita confirmación previa antes de borrar
  Future<void> _eliminarPartido(ModeloPartido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar partido?', style: TemaApp.titulo(tamano: 20)),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${partido.titulo}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: TemaApp.textoSecundario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaApp.rojoAlerta,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final eliminado = await _intentar(() async {
      await _repositorio.eliminarPartido(partido.id);
      return true;
    });
    if (eliminado == null || !mounted) return;

    setState(() {
      _partidos = _partidos.where((p) => p.id != partido.id).toList();
    });
    _avisar('Partido "${partido.titulo}" eliminado');
  }

  // ACCIÓN "AGREGAR JUGADOR" (organizador). Aplica la restricción "un equipo
  // completo no permite agregar más jugadores": si está bloqueada, explica el
  // motivo; si no, el servidor suma el jugador.
  Future<void> _agregarJugador(ModeloPartido partido) async {
    if (!partido.puedeAgregarJugador) {
      _avisar(
        'No se puede agregar jugadores. '
        '${partido.motivoBloqueoAgregarJugador ?? "Convocatoria no disponible."}',
        error: true,
      );
      return;
    }

    final actualizado = await _intentar(
      () => _repositorio.agregarJugadorSinCuenta(partido.id),
    );
    if (actualizado == null || !mounted) return;

    _reemplazar(actualizado);
    final mensaje =
        'Jugador agregado (${actualizado.cuposOcupados}/${actualizado.cuposTotales}).';
    _avisar(
      actualizado.estado == EstadoPartido.equipoCompleto
          ? '$mensaje ¡Equipo completo!'
          : mensaje,
    );
  }

  // ACCIÓN "SALIR DEL PARTIDO" (H3): quien se había unido libera su cupo
  Future<void> _salirDelPartido(ModeloPartido partido) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Salir del partido?', style: TemaApp.titulo(tamano: 20)),
        content: Text(
          'Dejarás tu cupo en "${partido.titulo}" y otra persona podrá tomarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaApp.rojoAlerta,
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      await _repositorio.salirDelPartido(partido.id);
      if (!mounted) return;
      setState(
        () => _partidos = _partidos.where((p) => p.id != partido.id).toList(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saliste de "${partido.titulo}". Tu cupo quedó libre.'),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No puedes salir. ${e.message}'),
          backgroundColor: TemaApp.rojoAlerta,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cerrar sesión?', style: TemaApp.titulo(tamano: 20)),
        content: const Text('Volverás a la pantalla pública de UniSport.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: TemaApp.textoSecundario,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaApp.rojoAlerta,
              minimumSize: const Size(110, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await widget.servicioAuth.cerrarSesion();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final partidosFiltrados = _partidos.where((p) {
      if (_filtroActivo == 'organizados') return p.soyOrganizador;
      if (_filtroActivo == 'unido') return !p.soyOrganizador;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis partidos'),
        actions: [
          IconButton(
            key: const Key('icono_abrir_historial'),
            tooltip: 'Historial de participación',
            icon: const Icon(
              LucideIcons.history,
              color: TemaApp.textoPrincipal,
              size: 20,
            ),
            onPressed: _abrirHistorial,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(
              LucideIcons.logOut,
              color: TemaApp.rojoAlerta,
              size: 20,
            ),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      // Misma navegación principal que la portada (Clase 15, hallazgo #1 · H6)
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (indice) {
          if (indice == 0) _explorarPartidos();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.compass),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.calendarDays),
            label: 'Mis partidos',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearPartido,
        backgroundColor: TemaApp.verdeDeportivo,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Crear partido',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _construirBannerUsuario(
                  usuario.nombre,
                  usuario.correo,
                  usuario.carrera,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _explorarPartidos,
                  icon: const Icon(LucideIcons.compass, size: 18),
                  label: const Text('Explorar partidos para unirme'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('boton_abrir_historial'),
                  onPressed: _abrirHistorial,
                  icon: const Icon(LucideIcons.history, size: 18),
                  label: const Text('Ver historial de participación'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      48,
                    ), // Ley de Fitts: >= 48 px
                  ),
                ),
                const SizedBox(height: 24),
                _construirEncabezadoLista(partidosFiltrados.length),
                const SizedBox(height: 12),
                _construirFiltros(),
                const SizedBox(height: 16),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (partidosFiltrados.isEmpty)
                  _construirEstadoVacio()
                else
                  ...partidosFiltrados.map(
                    (p) => TarjetaPartido(
                      partido: p,
                      onCompletarEquipo: () => _completarEquipo(p),
                      onEditar: () => _editarPartido(p),
                      onAgregarJugador: () => _agregarJugador(p),
                      jugadoresUnidos: _jugadoresInscritos[p.id] ?? const [],
                      onEliminar: () => _eliminarPartido(p),
                      onSalir: () => _salirDelPartido(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Banner de usuario autenticado (requisito explícito del docente)
  Widget _construirBannerUsuario(String nombre, String correo, String carrera) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3316A34A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
              style: TemaApp.titulo(tamano: 20, color: TemaApp.verdeOscuro),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TemaApp.titulo(tamano: 17, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  '$correo · $carrera',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.circleDot, size: 11, color: Color(0xFFBBF7D0)),
                SizedBox(width: 5),
                Text(
                  'Activo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezadoLista(int cantidad) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Encuentros programados',
            style: TemaApp.titulo(tamano: 18),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: TemaApp.verdeSuave,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$cantidad',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: TemaApp.verdeOscuro,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirFiltros() {
    return Row(
      children: [
        _construirBotonFiltro('Todos (${_partidos.length})', 'todos'),
        const SizedBox(width: 8),
        _construirBotonFiltro('Creados por mí', 'organizados'),
        const SizedBox(width: 8),
        _construirBotonFiltro('Como jugador', 'unido'),
      ],
    );
  }

  Widget _construirBotonFiltro(String texto, String clave) {
    final activo = _filtroActivo == clave;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filtroActivo = clave),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? TemaApp.textoPrincipal : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo ? TemaApp.textoPrincipal : TemaApp.borde,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : TemaApp.textoSecundario,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: TemaApp.tarjeta(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TemaApp.verdeSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.calendarDays,
              size: 28,
              color: TemaApp.verdeOscuro,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No tienes partidos en esta categoría',
            textAlign: TextAlign.center,
            style: TemaApp.titulo(tamano: 15),
          ),
          const SizedBox(height: 4),
          Text(
            _filtroActivo == 'unido'
                ? 'Toca "Explorar partidos para unirme" para encontrar uno.'
                : 'Toca "Crear partido" para agregar uno.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: TemaApp.textoSecundario),
          ),
        ],
      ),
    );
  }
}
