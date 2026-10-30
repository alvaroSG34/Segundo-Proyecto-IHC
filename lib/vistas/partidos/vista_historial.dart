import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/evento_historial.dart';
import '../../modelos/modelo_partido.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../tema/tema_app.dart';
import '../../widgets/tarjeta_historial.dart';
import 'vista_crear_partido.dart';
import 'vista_explorar_partidos.dart';
import '../autenticacion/vista_login.dart';

/// Ruta Privada: Historial de participación del estudiante (Clase 16 · Tarea 4).
///
/// Responde a la pregunta: ¿En qué partidos participó la persona?
///
/// Principios de interacción aplicados:
/// - Fitts: botón de navegación y acciones con área táctil >= 48 px.
/// - Hick: opciones de filtrado simplificadas (Todos / Como organizador / Como jugador)
///   sin saturar al usuario con controles dispersos.
/// - Carga cognitiva: tarjetas que muestran directamente qué pasó, fecha amigable
///   y resultado sin exigir recordar otras pantallas.
/// - Estado vacío orientador: guía al usuario a la acción siguiente si no tiene historial.
class VistaHistorial extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final DateTime? referenciaTemporal;

  const VistaHistorial({
    super.key,
    required this.servicioAuth,
    this.referenciaTemporal,
  });

  @override
  State<VistaHistorial> createState() => _VistaHistorialState();
}

class _VistaHistorialState extends State<VistaHistorial> {
  List<EventoHistorial> _eventos = [];
  bool _cargando = true;
  String _filtroRol = 'todos'; // 'todos' | 'organizador' | 'jugador'

  @override
  void initState() {
    super.initState();
    _verificarAccesoProtegido();
    _cargarHistorial();
  }

  void _verificarAccesoProtegido() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.servicioAuth.estaAutenticado) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VistaLogin(
              servicioAuth: widget.servicioAuth,
              mensajeRedireccion:
                  'Debes iniciar sesión para consultar tu historial.',
            ),
          ),
        );
      }
    });
  }

  Future<void> _cargarHistorial() async {
    if (!widget.servicioAuth.estaAutenticado) return;
    setState(() => _cargando = true);

    try {
      final eventos = await widget.servicioAuth.partidos.obtenerHistorial(
        ahora: widget.referenciaTemporal,
      );
      if (mounted) {
        setState(() {
          _eventos = eventos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el historial. Intenta nuevamente.'),
            backgroundColor: TemaApp.rojoAlerta,
          ),
        );
      }
    }
  }

  void _irAExplorar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VistaExplorarPartidos(servicioAuth: widget.servicioAuth),
      ),
    ).then((_) => _cargarHistorial());
  }

  Future<void> _irACrear() async {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) return;
    final nuevo = await Navigator.push<ModeloPartido>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaCrearPartido(organizadorNombre: usuario.nombre),
      ),
    );
    if (nuevo == null || !mounted) return;
    try {
      await widget.servicioAuth.partidos.crearPartido(nuevo);
      if (mounted) await _cargarHistorial();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final eventosFiltrados = _eventos.where((e) {
      if (_filtroRol == 'organizador') return e.rol == RolParticipacion.organizador;
      if (_filtroRol == 'jugador') return e.rol == RolParticipacion.jugador;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de participación'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Volver',
          // Ley de Fitts: objetivo táctil cómodo de 48 px
          iconSize: 22,
          padding: const EdgeInsets.all(12),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: RefreshIndicator(
            onRefresh: _cargarHistorial,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Resumen superior (Carga cognitiva)
                  _construirResumenTrayectoria(usuario.nombre),
                  const SizedBox(height: 16),

                  // Filtros estructurados (Ley de Hick: no competir en desorden)
                  _construirSelectorFiltros(),
                  const SizedBox(height: 18),

                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (eventosFiltrados.isEmpty)
                    _construirEstadoVacio()
                  else ...[
                    Text(
                      '${eventosFiltrados.length} ${eventosFiltrados.length == 1 ? "partido registrado" : "partidos registrados"} (más recientes primero)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: TemaApp.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...eventosFiltrados.map(
                      (e) => TarjetaHistorial(
                        evento: e,
                        referenciaTemporal: widget.referenciaTemporal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirResumenTrayectoria(String nombre) {
    final finalizados = _eventos.where((e) => e.yaDisputado).length;
    final organizados = _eventos.where((e) => e.rol == RolParticipacion.organizador).length;
    final unidos = _eventos.where((e) => e.rol == RolParticipacion.jugador).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: TemaApp.verdeSuave.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TemaApp.verdeDeportivo.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.history, color: TemaApp.verdeOscuro, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trayectoria deportiva · $nombre',
                  style: TemaApp.titulo(tamano: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _construirIndicador('Total', '${_eventos.length}')),
              Expanded(child: _construirIndicador('Disputados', '$finalizados')),
              Expanded(child: _construirIndicador('Organizados', '$organizados')),
              Expanded(child: _construirIndicador('Como jugador', '$unidos')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirIndicador(String label, String valor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: TemaApp.textoPrincipal,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: TemaApp.textoSecundario,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Ley de Hick: Tres opciones claras, mutuamente excluyentes, con igual peso visual
  Widget _construirSelectorFiltros() {
    return Row(
      children: [
        _construirBotonFiltro('Todos', 'todos'),
        const SizedBox(width: 8),
        _construirBotonFiltro('Organizados', 'organizador'),
        const SizedBox(width: 8),
        _construirBotonFiltro('Como jugador', 'jugador'),
      ],
    );
  }

  Widget _construirBotonFiltro(String texto, String clave) {
    final activo = _filtroRol == clave;
    return Expanded(
      child: GestureDetector(
        key: Key('filtro_$clave'),
        onTap: () => setState(() => _filtroRol = clave),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // Ley de Fitts: altura de 46 px para toque seguro
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: activo ? TemaApp.textoPrincipal : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activo ? TemaApp.textoPrincipal : TemaApp.borde,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.white : TemaApp.textoSecundario,
            ),
          ),
        ),
      ),
    );
  }

  /// Estado Vacío Orientador (Criterio 4 de la rúbrica):
  /// No solo avisa que está vacío, sino que orienta qué hacer después mediante
  /// un botón de acción principal (Call to Action).
  Widget _construirEstadoVacio() {
    final bool esFiltroEspecifico = _filtroRol != 'todos';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: TemaApp.tarjeta(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TemaApp.superficieSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.calendarX2,
              size: 28,
              color: TemaApp.textoSecundario,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            esFiltroEspecifico
                ? 'No tienes partidos en esta categoría'
                : 'Aún no tienes partidos en tu historial',
            textAlign: TextAlign.center,
            style: TemaApp.titulo(tamano: 16),
          ),
          const SizedBox(height: 8),
          Text(
            esFiltroEspecifico
                ? 'Prueba cambiando el filtro o súmate a nuevos partidos para enriquecer tu historial.'
                : 'Cuando organices un partido o te unas al equipo de otro estudiante, podrás consultar aquí toda tu trayectoria deportiva.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: TemaApp.textoSecundario, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Botón orientador principal (Fitts: >= 48 px de alto)
          ElevatedButton.icon(
            key: const Key('boton_orientador_explorar'),
            onPressed: _irAExplorar,
            icon: const Icon(LucideIcons.compass, size: 18),
            label: const Text('Explorar partidos disponibles'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TemaApp.verdeDeportivo,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
            ),
          ),
          if (!esFiltroEspecifico) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('boton_orientador_crear'),
              onPressed: _irACrear,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Crear un partido'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
