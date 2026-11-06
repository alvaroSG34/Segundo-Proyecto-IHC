import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/filtro_partidos.dart';
import '../modelos/modelo_partido.dart';
import '../tema/tema_app.dart';

/// Búsqueda y filtros de "Explorar partidos" (Issue #10, requisito #6).
/// No consulta datos: avisa cada cambio con [alCambiar] y la pantalla vuelve
/// a pedir los partidos a la base de datos.
class PanelFiltros extends StatefulWidget {
  final FiltroPartidos filtro;
  final List<String> lugares;
  final ValueChanged<FiltroPartidos> alCambiar;

  const PanelFiltros({
    super.key,
    required this.filtro,
    required this.lugares,
    required this.alCambiar,
  });

  @override
  State<PanelFiltros> createState() => _PanelFiltrosState();
}

class _PanelFiltrosState extends State<PanelFiltros> {
  bool _mostrarFiltros = false;
  late final TextEditingController _busqueda = TextEditingController(
    text: widget.filtro.texto,
  );

  FiltroPartidos get _filtro => widget.filtro;

  @override
  void didUpdateWidget(PanelFiltros anterior) {
    super.didUpdateWidget(anterior);
    // Si la búsqueda se quitó desde los filtros activos, se limpia el campo
    if (_filtro.texto != _busqueda.text) _busqueda.text = _filtro.texto;
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _cambiar(FiltroPartidos nuevo) => widget.alCambiar(nuevo);

  static String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String get _textoFecha => switch (_filtro.fecha) {
    FiltroFecha.rango when _filtro.desde != null && _filtro.hasta != null =>
      _filtro.desde == _filtro.hasta
          ? _dia(_filtro.desde!)
          : '${_dia(_filtro.desde!)} – ${_dia(_filtro.hasta!)}',
    _ => _filtro.fecha.etiqueta,
  };

  /// Hoja inferior con opciones. Devuelve null si se cierra sin elegir.
  Future<T?> _elegir<T>(String titulo, List<(T, String)> opciones, T actual) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: TemaApp.superficie,
      builder: (contexto) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(titulo, style: TemaApp.titulo(tamano: 17)),
            ),
            for (final (valor, etiqueta) in opciones)
              ListTile(
                title: Text(etiqueta),
                trailing: valor == actual
                    ? const Icon(
                        LucideIcons.check,
                        color: TemaApp.verdeDeportivo,
                      )
                    : null,
                onTap: () => Navigator.pop(contexto, valor),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirDeporte() async {
    final elegido = await _elegir<String>('Deporte', [
      ('', 'Todos los deportes'),
      for (final d in ModeloPartido.disciplinas) (d, d),
    ], _filtro.deporte ?? '');
    if (elegido == null) return;
    _cambiar(
      elegido.isEmpty
          ? _filtro.copiarCon(quitarDeporte: true)
          : _filtro.copiarCon(deporte: elegido),
    );
  }

  Future<void> _elegirLugar() async {
    final elegido = await _elegir<String>('Zona o lugar', [
      ('', 'Todos los lugares'),
      for (final l in widget.lugares) (l, l),
    ], _filtro.lugar ?? '');
    if (elegido == null) return;
    _cambiar(
      elegido.isEmpty
          ? _filtro.copiarCon(quitarLugar: true)
          : _filtro.copiarCon(lugar: elegido),
    );
  }

  Future<void> _elegirFecha() async {
    final elegida = await _elegir<FiltroFecha>('Fecha', [
      for (final f in FiltroFecha.values)
        (f, f == FiltroFecha.rango ? 'Rango de fechas…' : f.etiqueta),
    ], _filtro.fecha);
    if (elegida == null || !mounted) return;
    if (elegida != FiltroFecha.rango) {
      _cambiar(_filtro.copiarCon(fecha: elegida));
      return;
    }
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
      initialDateRange: _filtro.desde != null && _filtro.hasta != null
          ? DateTimeRange(start: _filtro.desde!, end: _filtro.hasta!)
          : null,
      helpText: 'Elige el rango de fechas',
    );
    if (rango == null) return;
    _cambiar(
      _filtro.copiarCon(
        fecha: FiltroFecha.rango,
        desde: rango.start,
        hasta: rango.end,
      ),
    );
  }

  /// Filtros activos: etiqueta y cómo quitarlo.
  List<(String, FiltroPartidos)> get _activos => [
    if (_filtro.tieneTexto)
      ('Nombre: "${_filtro.texto.trim()}"', _filtro.copiarCon(texto: '')),
    if (_filtro.deporte != null)
      ('Deporte: ${_filtro.deporte}', _filtro.copiarCon(quitarDeporte: true)),
    if (_filtro.fecha != FiltroFecha.cualquiera)
      ('Fecha: $_textoFecha', _filtro.copiarCon(fecha: FiltroFecha.cualquiera)),
    if (_filtro.lugar != null)
      ('Lugar: ${_filtro.lugar}', _filtro.copiarCon(quitarLugar: true)),
    if (_filtro.soloConCupos)
      ('Con cupos', _filtro.copiarCon(soloConCupos: false)),
  ];

  @override
  Widget build(BuildContext context) {
    final activos = _activos;
    final vencidos = _filtro.periodo == PeriodoPartidos.vencidos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final busqueda = _construirBusqueda();
            final boton = Semantics(
              expanded: _mostrarFiltros,
              child: OutlinedButton(
                key: const Key('explorar_mostrar_filtros'),
                onPressed: () =>
                    setState(() => _mostrarFiltros = !_mostrarFiltros),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.slidersHorizontal, size: 18),
                    const SizedBox(width: 6),
                    const Text('Filtros'),
                    const SizedBox(width: 4),
                    Icon(
                      _mostrarFiltros
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                    ),
                  ],
                ),
              ),
            );
            if (constraints.maxWidth < 400) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  busqueda,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: boton),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: busqueda),
                const SizedBox(width: 10),
                boton,
              ],
            );
          },
        ),
        if (_mostrarFiltros) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('explorar_filtros_desplegados'),
            padding: const EdgeInsets.all(12),
            decoration: TemaApp.tarjeta(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BotonFiltro(
                      key: const Key('explorar_deporte'),
                      icono: LucideIcons.trophy,
                      texto: _filtro.deporte ?? 'Deporte',
                      activo: _filtro.deporte != null,
                      alTocar: _elegirDeporte,
                    ),
                    _BotonFiltro(
                      icono: LucideIcons.calendarDays,
                      texto: _filtro.fecha == FiltroFecha.cualquiera
                          ? 'Fecha'
                          : _textoFecha,
                      activo: _filtro.fecha != FiltroFecha.cualquiera,
                      alTocar: _elegirFecha,
                    ),
                    _BotonFiltro(
                      icono: LucideIcons.mapPin,
                      texto: _filtro.lugar ?? 'Lugar',
                      activo: _filtro.lugar != null,
                      alTocar: _elegirLugar,
                    ),
                    _BotonFiltro(
                      key: const Key('explorar_con_cupos'),
                      icono: LucideIcons.users,
                      texto: 'Con cupos',
                      activo: _filtro.soloConCupos,
                      conFlecha: false,
                      alTocar: vencidos
                          ? null
                          : () => _cambiar(
                              _filtro.copiarCon(
                                soloConCupos: !_filtro.soloConCupos,
                              ),
                            ),
                    ),
                  ],
                ),
                if (vencidos) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Disponible solo en partidos próximos',
                    style: TextStyle(
                      fontSize: 12,
                      color: TemaApp.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (activos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros activos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: TemaApp.textoSecundario,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _cambiar(_filtro.limpiar()),
                child: const Text('Limpiar todo'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (etiqueta, sinEste) in activos)
                InputChip(
                  label: Text(etiqueta),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TemaApp.verdeOscuro,
                  ),
                  backgroundColor: TemaApp.verdeSuave,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  deleteIconColor: TemaApp.verdeOscuro,
                  deleteButtonTooltipMessage: 'Quitar filtro',
                  onDeleted: () => _cambiar(sinEste),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _construirBusqueda() => TextField(
    key: const Key('explorar_busqueda'),
    controller: _busqueda,
    textInputAction: TextInputAction.search,
    onChanged: (texto) => _cambiar(_filtro.copiarCon(texto: texto)),
    decoration: InputDecoration(
      labelText: 'Buscar partido por nombre',
      prefixIcon: const Icon(LucideIcons.search, size: 20),
      suffixIcon: _busqueda.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Borrar búsqueda',
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => _cambiar(_filtro.copiarCon(texto: '')),
            ),
    ),
  );
}

class _BotonFiltro extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final bool conFlecha;
  final VoidCallback? alTocar;

  const _BotonFiltro({
    super.key,
    required this.icono,
    required this.texto,
    required this.activo,
    required this.alTocar,
    this.conFlecha = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? TemaApp.verdeOscuro : TemaApp.textoSecundario;
    return Semantics(
      label: texto,
      button: true,
      selected: activo,
      enabled: alTocar != null,
      excludeSemantics: true,
      onTap: alTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Material(
          color: alTocar == null
              ? TemaApp.superficieSuave
              : activo
              ? TemaApp.verdeSuave
              : TemaApp.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: activo ? TemaApp.verdeDeportivo : TemaApp.borde,
              width: activo ? 1.5 : 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 15, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (conFlecha) ...[
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronDown, size: 15, color: color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensaje cuando ningún partido coincide con la búsqueda y los filtros.
class MensajeSinResultados extends StatelessWidget {
  final VoidCallback alQuitarFiltros;

  const MensajeSinResultados({super.key, required this.alQuitarFiltros});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: TemaApp.tarjeta(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TemaApp.naranjaSuave,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              LucideIcons.searchX,
              size: 28,
              color: TemaApp.naranjaAviso,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ningún partido coincide con tu búsqueda',
            textAlign: TextAlign.center,
            style: TemaApp.titulo(tamano: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba con otro nombre o quita algunos filtros para ver más partidos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: TemaApp.textoSecundario),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: alQuitarFiltros,
            icon: const Icon(LucideIcons.filterX, size: 17),
            label: const Text('Quitar filtros'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.standard,
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }
}
