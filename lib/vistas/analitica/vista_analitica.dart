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
              'Eventos del flujo “Unirme al equipo”',
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
            else
              _tabla(),
          ],
        ),
      ),
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
          for (final evento in _eventos)
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
