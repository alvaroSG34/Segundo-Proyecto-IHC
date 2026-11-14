import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/tema_app.dart';

class VistaAnalitica extends StatefulWidget {
  final ServicioAnalitica servicioAnalitica;

  const VistaAnalitica({super.key, required this.servicioAnalitica});

  @override
  State<VistaAnalitica> createState() => _VistaAnaliticaState();
}

class _VistaAnaliticaState extends State<VistaAnalitica> {
  // Cada fila contiene inicio, error y las posibles finalizaciones.
  static const _flujos = {
    'Unirse': ['union_iniciada', 'union_fallida', 'partido_unido'],
    'Crear partido': [
      'creacion_iniciada',
      'creacion_fallida',
      'partido_creado',
    ],
    'Buscar': ['busqueda_iniciada', 'busqueda_fallida', 'busqueda_realizada'],
    'Registrarse': [
      'registro_iniciado',
      'registro_fallido',
      'registro_completado',
    ],
    'Iniciar sesión': ['login_iniciado', 'login_fallido', 'login_exitoso'],
    'Eliminar cuenta': [
      'cuenta_eliminacion_iniciada',
      'cuenta_eliminacion_fallida',
      'cuenta_eliminacion_completada',
    ],
    'Salir': ['salida_iniciada', 'salida_fallida', 'salida_completada'],
    'Entrar en espera': [
      'espera_iniciada',
      'espera_fallida',
      'espera_confirmada',
    ],
    'Reprogramar': [
      'reprogramacion_iniciada',
      'reprogramacion_fallida',
      'partido_reprogramado',
    ],
    'Reconfirmar': [
      'reconfirmacion_iniciada',
      'reconfirmacion_fallida',
      'reprogramacion_aceptada',
      'reprogramacion_rechazada',
    ],
    'Responder propuesta': [
      'respuesta_propuesta_iniciada',
      'respuesta_propuesta_fallida',
      'propuesta_aceptada',
      'propuesta_rechazada',
    ],
    'Validar resultado': [
      'validacion_resultado_iniciada',
      'validacion_resultado_fallida',
      'resultado_confirmado',
      'resultado_disputado',
    ],
    'Editar': ['edicion_iniciada', 'edicion_fallida', 'partido_editado'],
    'Eliminar': [
      'eliminacion_iniciada',
      'eliminacion_fallida',
      'partido_eliminado',
    ],
    'Recuperar contraseña': [
      'recuperacion_iniciada',
      'recuperacion_fallida',
      'recuperacion_solicitada',
    ],
  };
  String _flujo = 'Crear partido';
  List<EventoAnalitica> _eventos = const [];
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final eventos = await widget.servicioAnalitica.obtenerEventos();
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _cargando = false;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la analítica.';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica'),
        actions: [
          IconButton(
            tooltip: 'Actualizar analítica',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Eventos de los flujos principales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _estadoError()
            else if (_eventos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('No hay eventos registrados.')),
              )
            else ...[
              _embudo(),
              const SizedBox(height: 24),
              _tabla(),
            ],
          ],
        ),
      ),
    );
  }

  Set<String> _intentos(Iterable<String> nombres) => {
    for (final evento in _eventos)
      if (nombres.contains(evento.evento) &&
          evento.props['intento_id'] is String &&
          (evento.props['intento_id'] as String).isNotEmpty)
        evento.props['intento_id'] as String,
  };

  Map<String, int> _resumen(String flujo) {
    final eventos = _flujos[flujo]!;
    final inicios = _intentos([eventos[0]]);
    final finales = _intentos(eventos.skip(2)).intersection(inicios);
    return {
      'inicios': inicios.length,
      'finalizados': finales.length,
      'pendientes': inicios.length - finales.length,
      'errores': _intentos([eventos[1]]).intersection(inicios).length,
    };
  }

  Widget _embudo() {
    final datos = _resumen(_flujo);
    final inicios = datos['inicios']!;
    final finales = datos['finalizados']!;
    final tasa = inicios == 0 ? 0.0 : finales / inicios;
    final errores = <String, Set<String>>{};
    final iniciados = _intentos([_flujos[_flujo]![0]]);
    for (final evento in _eventos) {
      final id = evento.props['intento_id'];
      final codigo = evento.props['codigo_error'];
      if (evento.evento == _flujos[_flujo]![1] &&
          id is String &&
          iniciados.contains(id) &&
          codigo is String) {
        errores.putIfAbsent(codigo, () => <String>{}).add(id);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('analitica_flujo'),
          initialValue: _flujo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Acción'),
          items: [
            for (final flujo in _flujos.keys)
              DropdownMenuItem(value: flujo, child: Text(flujo)),
          ],
          onChanged: (valor) {
            if (valor != null) setState(() => _flujo = valor);
          },
        ),
        const SizedBox(height: 16),
        Text('Inicios: $inicios'),
        LinearProgressIndicator(value: inicios == 0 ? 0 : 1),
        const SizedBox(height: 12),
        Text('Finalizados: $finales'),
        LinearProgressIndicator(value: tasa),
        const SizedBox(height: 12),
        Text(
          inicios == 0
              ? 'Sin datos'
              : 'Finalización: ${(tasa * 100).toStringAsFixed(1)}%',
        ),
        Text('Sin finalizar: ${datos['pendientes']}'),
        Text('Intentos con error: ${datos['errores']}'),
        for (final error in errores.entries)
          Text('${error.key}: ${error.value.length}'),
        if (_flujo == 'Entrar en espera')
          Text(
            'Suplentes promovidos: ${_eventos.where((e) => e.evento == EventosAnalitica.suplentePromovido).length}',
          ),
      ],
    );
  }

  Widget _tabla() => Container(
    decoration: BoxDecoration(
      color: TemaApp.superficie,
      border: Border.all(color: TemaApp.borde),
      borderRadius: BorderRadius.circular(8),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(TemaApp.superficieSuave),
        columns: const [
          DataColumn(label: Text('evento')),
          DataColumn(label: Text('props')),
          DataColumn(label: Text('fecha')),
        ],
        rows: [
          for (final evento in _eventos.where(
            (e) =>
                _flujos[_flujo]!.contains(e.evento) ||
                (_flujo == 'Buscar' &&
                    e.evento == EventosAnalitica.busquedaSinResultados) ||
                (_flujo == 'Entrar en espera' &&
                    e.evento == EventosAnalitica.suplentePromovido),
          ))
            DataRow(
              cells: [
                DataCell(Text(evento.evento)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(jsonEncode(evento.props)),
                  ),
                ),
                DataCell(Text(_formatearFecha(evento.fecha))),
              ],
            ),
        ],
      ),
    ),
  );

  String _formatearFecha(DateTime fecha) {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _estadoError() => Column(
    children: [
      Text(_error!, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
    ],
  );
}
