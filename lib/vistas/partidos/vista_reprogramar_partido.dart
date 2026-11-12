import 'package:flutter/material.dart';

import '../../modelos/modelo_partido.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../tema/tema_app.dart';

/// Formulario separado para que cambiar la fecha no pase por Editar partido.
class VistaReprogramarPartido extends StatefulWidget {
  final ModeloPartido partido;
  final RepositorioPartidos repositorio;
  final ServicioAnalitica servicioAnalitica;

  const VistaReprogramarPartido({
    super.key,
    required this.partido,
    required this.repositorio,
    this.servicioAnalitica = const ServicioAnaliticaNula(),
  });

  @override
  State<VistaReprogramarPartido> createState() =>
      _VistaReprogramarPartidoState();
}

class _VistaReprogramarPartidoState extends State<VistaReprogramarPartido> {
  final _intentoId = crearIntentoId();
  final _formulario = GlobalKey<FormState>();
  late final _lugar = TextEditingController(text: widget.partido.ubicacion);
  final _motivo = TextEditingController();
  late DateTime _fecha = widget.partido.fechaInicio ?? DateTime.now();
  bool _guardando = false;
  String? _error;

  void _registrar(String evento, [String? codigo]) {
    registrarEvento(widget.servicioAnalitica, evento, {
      'intento_id': _intentoId,
      'codigo_error': ?codigo,
    });
  }

  @override
  void initState() {
    super.initState();
    _registrar(EventosAnalitica.reprogramacionIniciada);
  }

  @override
  void dispose() {
    _lugar.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final primerDia = DateTime(hoy.year, hoy.month, hoy.day);
    final ultimoDia = DateTime(
      _fecha.year > hoy.year + 2 ? _fecha.year + 1 : hoy.year + 2,
      12,
      31,
    );
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha.isBefore(primerDia) ? primerDia : _fecha,
      firstDate: primerDia,
      lastDate: ultimoDia,
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        elegida.year,
        elegida.month,
        elegida.day,
        _fecha.hour,
        _fecha.minute,
      );
    });
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        elegida.hour,
        elegida.minute,
      );
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formulario.currentState!.validate()) {
      _registrar(
        EventosAnalitica.reprogramacionFallida,
        'validacion_formulario',
      );
      return;
    }
    if (!_fecha.isAfter(DateTime.now())) {
      _registrar(EventosAnalitica.reprogramacionFallida, 'regla_negocio');
      setState(() => _error = 'La nueva fecha debe ser futura.');
      return;
    }
    if (widget.partido.fechaInicio != null &&
        _fecha.isAtSameMomentAs(widget.partido.fechaInicio!) &&
        _lugar.text.trim() == widget.partido.ubicacion) {
      _registrar(EventosAnalitica.reprogramacionFallida, 'regla_negocio');
      setState(() => _error = 'Cambia la fecha, la hora o el lugar.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final guardado = await widget.repositorio.reprogramarPartido(
        widget.partido.id,
        _fecha,
        _lugar.text.trim(),
        _motivo.text.trim(),
      );
      registrarEvento(
        widget.servicioAnalitica,
        EventosAnalitica.partidoReprogramado,
        {'intento_id': _intentoId},
      );
      if (mounted) {
        Navigator.pop(context, guardado);
      }
    } on StateError catch (error) {
      _registrar(EventosAnalitica.reprogramacionFallida, 'servicio_partidos');
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      _registrar(EventosAnalitica.reprogramacionFallida, 'servicio_partidos');
      if (mounted) {
        setState(() => _error = 'No se pudo reprogramar el partido.');
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Reprogramar partido')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formulario,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.partido.titulo,
                    style: TemaApp.titulo(tamano: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Los titulares conservarán su plaza hasta que acepten '
                    'la nueva fecha o se retiren.',
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('reprogramar_fecha'),
                    onPressed: _guardando ? null : _elegirFecha,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year}',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('reprogramar_hora'),
                    onPressed: _guardando ? null : _elegirHora,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      'Hora: ${TimeOfDay.fromDateTime(_fecha).format(context)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('reprogramar_lugar'),
                    controller: _lugar,
                    enabled: !_guardando,
                    decoration: const InputDecoration(labelText: 'Nuevo lugar'),
                    validator: (texto) => texto == null || texto.trim().isEmpty
                        ? 'Indica el lugar'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('reprogramar_motivo'),
                    controller: _motivo,
                    enabled: !_guardando,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del cambio',
                    ),
                    validator: (texto) => texto == null || texto.trim().isEmpty
                        ? 'Explica el motivo a los jugadores'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: TemaApp.rojoAlerta),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('reprogramar_guardar'),
                    onPressed: _guardando ? null : _guardar,
                    child: Text(
                      _guardando
                          ? 'Guardando...'
                          : 'Guardar y avisar al equipo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
