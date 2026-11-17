import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:unisport/tema/iconos_app.dart';

import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/tema_app.dart';

class VistaAnalitica extends StatefulWidget {
  final ServicioAnalitica servicioAnalitica;

  const VistaAnalitica({super.key, required this.servicioAnalitica});

  @override
  State<VistaAnalitica> createState() => _VistaAnaliticaState();
}

class _VistaAnaliticaState extends State<VistaAnalitica> {
  static const _eventosPorPagina = 10;
  final _eventosRecientesKey = GlobalKey();

  // Cada fila contiene inicio, error y las posibles finalizaciones.
  static const _flujos = {
    'Unirse a un partido': ['union_iniciada', 'union_fallida', 'partido_unido'],
    'Crear partido': [
      'creacion_iniciada',
      'creacion_fallida',
      'partido_creado',
    ],
    'Buscar partidos': [
      'busqueda_iniciada',
      'busqueda_fallida',
      'busqueda_realizada',
    ],
    'Crear cuenta': [
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
    'Salir de un partido': [
      'salida_iniciada',
      'salida_fallida',
      'salida_completada',
    ],
    'Entrar en lista de espera': [
      'espera_iniciada',
      'espera_fallida',
      'espera_confirmada',
    ],
    'Reprogramar partido': [
      'reprogramacion_iniciada',
      'reprogramacion_fallida',
      'partido_reprogramado',
    ],
    'Responder reprogramación': [
      'reconfirmacion_iniciada',
      'reconfirmacion_fallida',
      'reprogramacion_aceptada',
      'reprogramacion_rechazada',
    ],
    'Responder propuesta de equipos': [
      'respuesta_propuesta_iniciada',
      'respuesta_propuesta_fallida',
      'propuesta_aceptada',
      'propuesta_rechazada',
    ],
    'Validar resultado del partido': [
      'validacion_resultado_iniciada',
      'validacion_resultado_fallida',
      'resultado_confirmado',
      'resultado_disputado',
    ],
    'Editar partido': [
      'edicion_iniciada',
      'edicion_fallida',
      'partido_editado',
    ],
    'Eliminar partido': [
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
  int _paginaActual = 0;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _actualizar() => _cargar(desplazarAEventos: true);

  Future<void> _cargar({bool desplazarAEventos = false}) async {
    setState(() {
      _paginaActual = 0;
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
      if (desplazarAEventos) _desplazarAEventosRecientes();
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppBar(
              title: const Text('Analítica'),
              actions: [
                IconButton(
                  tooltip: 'Actualizar analítica',
                  onPressed: _cargando ? null : _actualizar,
                  icon: const Icon(LucideIcons.refreshCw),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _actualizar,
            child: ListView(
              key: const Key('analitica_lista'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Eventos de los flujos principales',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
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
                  _selectorFlujo(),
                  const SizedBox(height: 18),
                  _tarjetaResumen(),
                  const SizedBox(height: 24),
                  _eventosRecientes(),
                ],
              ],
            ),
          ),
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

  Widget _selectorFlujo() => DropdownButtonFormField<String>(
    key: const Key('analitica_flujo'),
    initialValue: _flujo,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Acción'),
    items: [
      for (final flujo in _flujos.keys)
        DropdownMenuItem(value: flujo, child: Text(flujo)),
    ],
    onChanged: (valor) {
      if (valor != null) {
        setState(() {
          _flujo = valor;
          _paginaActual = 0;
        });
      }
    },
  );

  Widget _tarjetaResumen() {
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
    final porcentaje = inicios == 0
        ? 'Sin datos'
        : '${(tasa * 100).toStringAsFixed(1)}%';

    return Container(
      key: const Key('analitica_resumen'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TemaApp.superficie,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen del flujo',
                style: TemaApp.titulo(tamano: 17, peso: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Rendimiento del flujo: $_flujo',
                style: const TextStyle(
                  color: TemaApp.textoSecundario,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _filaProgreso('Inicios', inicios, inicios == 0 ? 0 : 1),
          const SizedBox(height: 16),
          _filaProgreso('Finalizados', finales, tasa),
          const SizedBox(height: 18),
          _filaFinalizacion(porcentaje),
          const SizedBox(height: 14),
          _detallesResumen(datos, errores),
          if (_flujo == 'Entrar en lista de espera') ...[
            const SizedBox(height: 14),
            _filaDetalle(
              LucideIcons.users,
              'Suplentes promovidos',
              '${_eventos.where((e) => e.evento == EventosAnalitica.suplentePromovido).length}',
            ),
          ],
        ],
      ),
    );
  }

  void _cambiarPagina(int pagina) {
    setState(() => _paginaActual = pagina);
    _desplazarAEventosRecientes();
  }

  void _desplazarAEventosRecientes() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contexto = _eventosRecientesKey.currentContext;
      if (contexto != null) {
        Scrollable.ensureVisible(
          contexto,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
        );
      }
    });
  }

  Widget _filaProgreso(String titulo, int cantidad, double progreso) => Column(
    children: [
      Row(
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
            '$cantidad',
            key: Key('analitica_$titulo'),
            style: TemaApp.titulo(tamano: 16, peso: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: progreso,
          minHeight: 6,
          backgroundColor: TemaApp.verdeSuave,
          color: TemaApp.verdeDeportivo,
        ),
      ),
    ],
  );

  Widget _filaFinalizacion(String porcentaje) => Row(
    children: [
      const Text('Finalización', style: TextStyle(fontWeight: FontWeight.w600)),
      const Spacer(),
      Text(
        porcentaje,
        key: const Key('analitica_porcentaje'),
        style: const TextStyle(
          color: TemaApp.verdeOscuro,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ],
  );

  Widget _detallesResumen(
    Map<String, int> datos,
    Map<String, Set<String>> errores,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _filaDetalle(
        LucideIcons.circleDashed,
        'Sin finalizar',
        '${datos['pendientes']}',
      ),
      const SizedBox(height: 10),
      _filaDetalle(
        LucideIcons.triangleAlert,
        'Intentos con error',
        '${datos['errores']}',
      ),
      for (final error in errores.entries) ...[
        const SizedBox(height: 8),
        _filaDetalle(
          LucideIcons.list,
          error.key,
          '${error.value.length}',
          compactar: true,
        ),
      ],
    ],
  );

  Widget _filaDetalle(
    IconData icono,
    String etiqueta,
    String valor, {
    bool compactar = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icono, size: 20, color: TemaApp.textoSecundario),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          etiqueta,
          maxLines: compactar ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        valor,
        key: Key('analitica_detalle_$etiqueta'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _eventosRecientes() {
    final eventos = _eventos
        .where(
          (e) =>
              _flujos[_flujo]!.contains(e.evento) ||
              (_flujo == 'Buscar partidos' &&
                  e.evento == EventosAnalitica.busquedaSinResultados) ||
              (_flujo == 'Entrar en lista de espera' &&
                  e.evento == EventosAnalitica.suplentePromovido),
        )
        .toList(growable: false);

    if (eventos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No hay eventos para este flujo.')),
      );
    }

    final totalPaginas = (eventos.length / _eventosPorPagina).ceil();
    final pagina = _paginaActual.clamp(0, totalPaginas - 1).toInt();
    final inicio = pagina * _eventosPorPagina;
    final fin = (inicio + _eventosPorPagina).clamp(0, eventos.length).toInt();
    final eventosPagina = eventos.sublist(inicio, fin);

    return Column(
      key: _eventosRecientesKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Eventos recientes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        for (final (indice, evento) in eventosPagina.indexed)
          Container(
            key: Key('analitica_evento_${inicio + indice}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TemaApp.superficie,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evento.evento,
                  softWrap: true,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatearFecha(evento.fecha),
                  style: const TextStyle(
                    color: TemaApp.textoSecundario,
                    fontSize: 13,
                  ),
                ),
                const Divider(height: 22),
                const Text(
                  'Propiedades',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(evento.props),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'Mostrando ${inicio + 1}–$fin de ${eventos.length}',
            key: const Key('analitica_paginacion_rango'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TemaApp.textoSecundario,
              fontSize: 12,
            ),
          ),
        ),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 4),
          Text(
            'Página ${pagina + 1} de $totalPaginas',
            key: const Key('analitica_paginacion_pagina'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TemaApp.textoSecundario,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('analitica_paginacion_anterior'),
                  onPressed: pagina == 0
                      ? null
                      : () => _cambiarPagina(pagina - 1),
                  child: const Text('Anterior'),
                ),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('analitica_paginacion_siguiente'),
                  onPressed: pagina >= totalPaginas - 1
                      ? null
                      : () => _cambiarPagina(pagina + 1),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

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
