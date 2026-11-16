import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/filtro_partidos.dart';
import '../modelos/modelo_partido.dart';
import '../tema/tema_app.dart';

/// Hoja de filtros de «Mis partidos». Aplica cambios solo al confirmar.
class FiltrosMisPartidos extends StatefulWidget {
  final FiltroPartidos inicial;

  const FiltrosMisPartidos({super.key, required this.inicial});

  @override
  State<FiltrosMisPartidos> createState() => _FiltrosMisPartidosState();
}

enum _FechaMisPartidos { todas, proximos, pasados, hoy, estaSemana, rango }

class _FiltrosMisPartidosState extends State<FiltrosMisPartidos> {
  late String? _deporte = widget.inicial.deporte;
  late _FechaMisPartidos _fecha = _fechaDe(widget.inicial);
  late DateTime? _desde = widget.inicial.desde;
  late DateTime? _hasta = widget.inicial.hasta;

  _FechaMisPartidos _fechaDe(FiltroPartidos filtro) {
    if (filtro.fecha == FiltroFecha.hoy) return _FechaMisPartidos.hoy;
    if (filtro.fecha == FiltroFecha.estaSemana) {
      return _FechaMisPartidos.estaSemana;
    }
    if (filtro.fecha == FiltroFecha.rango) return _FechaMisPartidos.rango;
    return switch (filtro.periodo) {
      PeriodoPartidos.todos => _FechaMisPartidos.todas,
      PeriodoPartidos.proximos => _FechaMisPartidos.proximos,
      PeriodoPartidos.vencidos => _FechaMisPartidos.pasados,
    };
  }

  String get _etiquetaRango {
    if (_desde == null || _hasta == null) return 'Rango de fechas';
    return '${_dia(_desde!)} – ${_dia(_hasta!)}';
  }

  String _dia(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';

  Future<bool> _elegirRango() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
      initialDateRange: _desde != null && _hasta != null
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
      helpText: 'Elige el rango de fechas',
    );
    if (rango == null || !mounted) return false;
    setState(() {
      _fecha = _FechaMisPartidos.rango;
      _desde = rango.start;
      _hasta = rango.end;
    });
    return true;
  }

  Future<void> _elegirRangoDesdeSelector() async {
    final fechaAnterior = _fecha;
    final elegido = await _elegirRango();
    if (!mounted || elegido) return;
    // Si se cancela el selector, revierte la opción que DropdownButton
    // seleccionó internamente.
    setState(() => _fecha = fechaAnterior);
  }

  FiltroPartidos _construirFiltro() {
    final periodo = switch (_fecha) {
      _FechaMisPartidos.todas ||
      _FechaMisPartidos.rango => PeriodoPartidos.todos,
      _FechaMisPartidos.proximos ||
      _FechaMisPartidos.hoy ||
      _FechaMisPartidos.estaSemana => PeriodoPartidos.proximos,
      _FechaMisPartidos.pasados => PeriodoPartidos.vencidos,
    };
    final fecha = switch (_fecha) {
      _FechaMisPartidos.hoy => FiltroFecha.hoy,
      _FechaMisPartidos.estaSemana => FiltroFecha.estaSemana,
      _FechaMisPartidos.rango => FiltroFecha.rango,
      _ => FiltroFecha.cualquiera,
    };
    return FiltroPartidos(
      deporte: _deporte,
      periodo: periodo,
      fecha: fecha,
      desde: _fecha == _FechaMisPartidos.rango ? _desde : null,
      hasta: _fecha == _FechaMisPartidos.rango ? _hasta : null,
    );
  }

  void _limpiar() => setState(() {
    _deporte = null;
    _fecha = _FechaMisPartidos.proximos;
    _desde = null;
    _hasta = null;
  });

  void _aplicar() => Navigator.pop(context, _construirFiltro());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtrar partidos',
                        style: TemaApp.titulo(tamano: 20),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar filtros',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Deporte'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  key: const Key('mis_partidos_filtro_deporte'),
                  initialValue: _deporte,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los deportes'),
                    ),
                    for (final deporte in ModeloPartido.disciplinas)
                      DropdownMenuItem<String?>(
                        value: deporte,
                        child: Text(deporte),
                      ),
                  ],
                  onChanged: (valor) => setState(() => _deporte = valor),
                ),
                const SizedBox(height: 16),
                const Text('Fecha'),
                const SizedBox(height: 6),
                KeyedSubtree(
                  key: const Key('mis_partidos_filtro_fecha'),
                  child: DropdownButtonFormField<_FechaMisPartidos>(
                    key: ValueKey(_fecha),
                    initialValue: _fecha,
                    isExpanded: true,
                    items: [
                      for (final fecha in _FechaMisPartidos.values)
                        DropdownMenuItem(
                          value: fecha,
                          child: Text(switch (fecha) {
                            _FechaMisPartidos.todas => 'Todas las fechas',
                            _FechaMisPartidos.proximos => 'Próximos partidos',
                            _FechaMisPartidos.pasados => 'Partidos pasados',
                            _FechaMisPartidos.hoy => 'Hoy',
                            _FechaMisPartidos.estaSemana => 'Esta semana',
                            _FechaMisPartidos.rango => 'Elegir rango…',
                          }),
                        ),
                    ],
                    onChanged: (valor) async {
                      if (valor == null) return;
                      if (valor == _FechaMisPartidos.rango) {
                        await _elegirRangoDesdeSelector();
                      } else {
                        setState(() => _fecha = valor);
                      }
                    },
                  ),
                ),
                if (_fecha == _FechaMisPartidos.rango) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('mis_partidos_cambiar_rango'),
                      onPressed: _elegirRango,
                      icon: const Icon(LucideIcons.calendarDays, size: 17),
                      label: Text(
                        _desde == null || _hasta == null
                            ? 'Elegir rango de fechas'
                            : 'Rango: $_etiquetaRango · Cambiar',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('mis_partidos_limpiar_filtros'),
                        onPressed: _limpiar,
                        child: const Text('Limpiar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('mis_partidos_aplicar_filtros'),
                        onPressed: _aplicar,
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<FiltroPartidos?> mostrarFiltrosMisPartidos(
  BuildContext context,
  FiltroPartidos inicial,
) => showModalBottomSheet<FiltroPartidos>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: TemaApp.superficie,
  builder: (_) => FiltrosMisPartidos(inicial: inicial),
);
