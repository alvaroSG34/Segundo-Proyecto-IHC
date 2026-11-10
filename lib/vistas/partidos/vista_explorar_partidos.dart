import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../servicios/partidos/controlador_explorar.dart';
import '../../modelos/filtro_partidos.dart';
import '../../modelos/modelo_partido.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/partidos/repositorio_partidos_supabase.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/panel_filtros.dart';
import '../../widgets/tarjeta_partido.dart';

/// Explorar partidos organizados por otros estudiantes, buscarlos, filtrarlos
/// (requisito #6) y unirse a ellos (requisito #5).
class VistaExplorarPartidos extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final RepositorioPartidos? repositorioPartidos;
  final ControladorExplorar controladorExplorar;
  final DateTime? referenciaTemporal;

  const VistaExplorarPartidos({
    super.key,
    required this.servicioAuth,
    this.repositorioPartidos,
    required this.controladorExplorar,
    this.referenciaTemporal,
  });

  @override
  State<VistaExplorarPartidos> createState() => _VistaExplorarPartidosState();
}

class _VistaExplorarPartidosState extends State<VistaExplorarPartidos> {
  late final RepositorioPartidos _repositorio =
      widget.repositorioPartidos ??
      RepositorioPartidosSupabase(Supabase.instance.client);

  List<ModeloPartido> _partidos = [];
  List<String> _lugares = FiltroPartidos.lugaresSugeridos;
  FiltroPartidos get _filtro => widget.controladorExplorar.filtro;
  bool _cargando = true;

  // Evita que una consulta lenta pise el resultado de una más reciente
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // Interfaz -> consulta -> base de datos: cada cambio de filtro vuelve a
  // pedir los partidos a la base de datos de Supabase con buscarPartidos.
  Future<void> _cargar() async {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) return;

    final numero = ++_consulta;
    setState(() => _cargando = true);
    final List<ModeloPartido> partidos;
    final List<String> lugares;
    try {
      partidos = await _repositorio.buscarPartidos(
        _filtro,
        ahora: widget.referenciaTemporal,
      );
      lugares = await _repositorio.obtenerLugares();
    } on StateError catch (e) {
      if (!mounted || numero != _consulta) return;
      setState(() => _cargando = false);
      _avisar(e.message, error: true);
      return;
    }
    if (!mounted || numero != _consulta) return;
    setState(() {
      _partidos = partidos;
      _lugares = lugares;
      _cargando = false;
    });
  }

  void _cambiarFiltro(FiltroPartidos nuevo) {
    setState(() => widget.controladorExplorar.actualizarFiltro(nuevo));
    _cargar();
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? TemaApp.rojoAlerta : null,
      ),
    );
  }

  // ACCIÓN "UNIRME AL EQUIPO": la regla del modelo decide; si rechaza, se explica el motivo
  Future<void> _unirse(ModeloPartido partido) async {
    final motivo = partido.motivoRechazoUnirse;
    if (motivo != null) {
      _avisar('No puedes unirte. $motivo', error: true);
      return;
    }

    // H3/H5: confirmar antes de ocupar un cupo
    final confirmar = await confirmarAccion(
      context,
      titulo: '¿Unirte al equipo?',
      mensaje:
          'Ocuparás un cupo en "${partido.titulo}" '
          '(${partido.cuposOcupados}/${partido.cuposTotales}).',
      textoConfirmar: 'Sí, unirme',
      estiloBotonCancelar: TextButton.styleFrom(
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(48, 48),
      ),
      estiloConfirmar: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(48, 48),
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      // El servidor vuelve a aplicar la regla sobre el dato guardado
      final unido = await _repositorio.unirseAPartido(partido.id);
      if (!mounted) return;

      setState(() {
        _partidos = [for (final p in _partidos) p.id == partido.id ? unido : p];
      });

      final completo = unido.estado == EstadoPartido.equipoCompleto;
      _avisar(
        '¡Te uniste a "${unido.titulo}"! '
        '(${unido.cuposOcupados}/${unido.cuposTotales})'
        '${completo ? ' El equipo quedó completo.' : ''}',
      );
      await _cargar();
    } on StateError catch (e) {
      // El dato guardado cambió (por ejemplo, otro ocupó el último cupo)
      if (!mounted) return;
      _avisar('No puedes unirte. ${e.message}', error: true);
      await _cargar();
    }
  }

  // ACCIÓN "SALIR DEL PARTIDO" (H3): pide confirmación y libera el cupo
  Future<void> _salir(ModeloPartido partido) async {
    final confirmar = await confirmarAccion(
      context,
      titulo: '¿Salir del partido?',
      mensaje:
          'Dejarás tu cupo en "${partido.titulo}" y otra persona podrá tomarlo.',
      textoConfirmar: 'Sí, salir',
      estiloConfirmar: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.standard,
        backgroundColor: TemaApp.rojoAlerta,
        minimumSize: const Size(120, 48),
      ),
      estiloBotonCancelar: TextButton.styleFrom(
        visualDensity: VisualDensity.standard,
        minimumSize: const Size(120, 48),
      ),
    );
    if (confirmar != true || !mounted) return;

    try {
      final salido = await _repositorio.salirDelPartido(partido.id);
      if (!mounted) return;
      setState(() {
        _partidos = [
          for (final p in _partidos) p.id == partido.id ? salido : p,
        ];
      });
      _avisar(
        salido.estaLleno
            ? 'Saliste de "${salido.titulo}". Entró el primer suplente.'
            : 'Saliste de "${salido.titulo}". Tu cupo quedó libre.',
      );
      await _cargar();
    } on StateError catch (e) {
      if (!mounted) return;
      _avisar('No puedes salir. ${e.message}', error: true);
      await _cargar();
    }
  }

  Future<void> _responderReprogramacion(
    ModeloPartido partido,
    bool acepta,
  ) async {
    if (!acepta) {
      final confirmar = await confirmarAccion(
        context,
        titulo: '¿Retirarte del partido?',
        mensaje: 'Liberarás tu plaza. Si hay suplentes, entrará el primero.',
        textoConfirmar: 'Sí, retirarme',
      );
      if (confirmar != true || !mounted) return;
    }
    try {
      await _repositorio.responderReprogramacion(partido.id, acepta);
      if (!mounted) return;
      await _cargar();
      if (mounted) {
        _avisar(
          acepta ? 'Tu plaza quedó confirmada.' : 'Te retiraste del partido.',
        );
      }
    } on StateError catch (error) {
      if (!mounted) return;
      _avisar(error.message, error: true);
      await _cargar();
    }
  }

  Future<void> _entrarEnEspera(ModeloPartido partido) async {
    try {
      final actualizado = await _repositorio.entrarEnEspera(partido.id);
      if (!mounted) return;
      _avisar(
        'Estás en la lista de suplentes. Turno ${actualizado.posicionEspera}.',
      );
      await _cargar();
    } on StateError catch (e) {
      if (!mounted) return;
      _avisar(e.message, error: true);
      await _cargar();
    }
  }

  Future<void> _salirDeEspera(ModeloPartido partido) async {
    try {
      await _repositorio.salirDeEspera(partido.id);
      if (!mounted) return;
      _avisar('Saliste de la lista de suplentes.');
      await _cargar();
    } on StateError catch (e) {
      if (!mounted) return;
      _avisar(e.message, error: true);
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorar partidos')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: TemaApp.verdeDeportivo,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Encuentra tu próximo partido o consulta los que ya pasaron',
                  style: TextStyle(
                    fontSize: 13,
                    color: TemaApp.textoSecundario,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                PanelFiltros(
                  filtro: _filtro,
                  lugares: _lugares,
                  alCambiar: _cambiarFiltro,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _botonPeriodo(PeriodoPartidos.proximos)),
                    const SizedBox(width: 10),
                    Expanded(child: _botonPeriodo(PeriodoPartidos.vencidos)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _filtro.periodo == PeriodoPartidos.vencidos
                      ? 'Partidos vencidos'
                      : 'Partidos próximos',
                  style: TemaApp.titulo(tamano: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  _filtro.periodo == PeriodoPartidos.vencidos
                      ? 'Ordenados del más reciente al más antiguo'
                      : 'Ordenados por fecha más cercana',
                  style: const TextStyle(
                    fontSize: 13,
                    color: TemaApp.textoSecundario,
                  ),
                ),
                const SizedBox(height: 14),
                if (!_cargando)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _partidos.length == 1
                          ? '1 partido encontrado'
                          : '${_partidos.length} partidos encontrados',
                      key: const Key('explorar_cantidad'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TemaApp.textoSecundario,
                      ),
                    ),
                  ),
                if (_cargando)
                  Semantics(
                    key: const Key('explorar_cargando'),
                    label: 'Cargando partidos',
                    liveRegion: true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_partidos.isEmpty && _filtro.estaActivo)
                  MensajeSinResultados(
                    alQuitarFiltros: () => _cambiarFiltro(_filtro.limpiar()),
                  )
                else if (_partidos.isEmpty)
                  _construirEstadoVacio()
                else ...[
                  ..._partidos.map(
                    (partido) => TarjetaPartido(
                      partido: partido,
                      onUnirse: () => _unirse(partido),
                      onSalir: () => _salir(partido),
                      onReconfirmar: partido.reconfirmacionPendiente
                          ? () => _responderReprogramacion(partido, true)
                          : null,
                      onRetirarseReprogramacion: partido.reconfirmacionPendiente
                          ? () => _responderReprogramacion(partido, false)
                          : null,
                      onEntrarEnEspera: () => _entrarEnEspera(partido),
                      onSalirDeEspera: () => _salirDeEspera(partido),
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

  Widget _construirEstadoVacio() {
    final vencidos = _filtro.periodo == PeriodoPartidos.vencidos;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: TemaApp.tarjeta(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TemaApp.azulSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.compass,
              size: 28,
              color: TemaApp.azulDeportivo,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            vencidos ? 'No hay partidos vencidos' : 'No hay partidos próximos',
            textAlign: TextAlign.center,
            style: TemaApp.titulo(tamano: 15),
          ),
          const SizedBox(height: 4),
          Text(
            vencidos
                ? 'Aquí aparecerán los partidos de otros estudiantes cuya fecha ya pasó.'
                : 'Cuando alguien cree un próximo partido, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: TemaApp.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonPeriodo(PeriodoPartidos periodo) {
    final seleccionado = _filtro.periodo == periodo;
    final vencidos = periodo == PeriodoPartidos.vencidos;
    return Semantics(
      selected: seleccionado,
      child: OutlinedButton(
        key: Key(vencidos ? 'explorar_vencidos' : 'explorar_proximos'),
        onPressed: () {
          if (!seleccionado) {
            _cambiarFiltro(_filtro.copiarCon(periodo: periodo));
          }
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          backgroundColor: seleccionado
              ? TemaApp.verdeDeportivo
              : TemaApp.superficie,
          foregroundColor: seleccionado
              ? Colors.white
              : TemaApp.textoSecundario,
          side: BorderSide(
            color: seleccionado ? TemaApp.verdeDeportivo : TemaApp.borde,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              vencidos ? LucideIcons.clock : LucideIcons.calendarDays,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                vencidos ? 'Partidos vencidos' : 'Partidos próximos',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
