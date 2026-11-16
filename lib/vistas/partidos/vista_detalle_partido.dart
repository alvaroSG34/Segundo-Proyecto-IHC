import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/baja_tardia.dart';
import '../../modelos/modelo_partido.dart';
import '../../modelos/propuesta_equipos.dart';
import '../../modelos/resultado_partido.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../tema/iconos_deporte.dart';
import '../../tema/tema_app.dart';
import 'vista_equipos.dart';

class VistaDetallePartido extends StatefulWidget {
  final ModeloPartido partido;
  final RepositorioPartidos repositorio;
  final String usuarioId;
  final ServicioAnalitica servicioAnalitica;
  final Future<void> Function()? onUnirse, onEntrarEnEspera, onSalirDeEspera;
  final Future<void> Function()? onReconfirmar,
      onRetirarseReprogramacion,
      onSalir;
  final Future<void> Function()? onEditar, onReprogramar;
  final Future<void> Function()? onCompletarEquipo, onEliminar;
  final List<String>? suplentes;
  final List<BajaTardia>? bajasTardias;
  final Future<ModeloPartido?> Function()? recargarPartido;

  const VistaDetallePartido({
    super.key,
    required this.partido,
    required this.repositorio,
    required this.usuarioId,
    this.servicioAnalitica = const ServicioAnaliticaNula(),
    this.onUnirse,
    this.onEntrarEnEspera,
    this.onSalirDeEspera,
    this.onReconfirmar,
    this.onRetirarseReprogramacion,
    this.onSalir,
    this.onEditar,
    this.onReprogramar,
    this.onCompletarEquipo,
    this.onEliminar,
    this.suplentes,
    this.bajasTardias,
    this.recargarPartido,
  });

  @override
  State<VistaDetallePartido> createState() => _VistaDetallePartidoState();
}

class _VistaDetallePartidoState extends State<VistaDetallePartido> {
  final _tarjetaResultadoKey = GlobalKey();
  late ModeloPartido partido = widget.partido;
  List<ParticipantePartido> participantes = [];
  PropuestaEquipos? propuesta;
  ResultadoValidadoPartido? resultado;
  final _marcadorA = TextEditingController();
  final _marcadorB = TextEditingController();
  bool cargando = true;
  bool ejecutandoAccion = false;
  bool guardandoResultado = false;
  String? error;
  String? errorResultado;

  bool get puedeGestionar => partido.soyOrganizador || partido.estoyUnido;
  bool get capitan => propuesta?.capitanRivalId == widget.usuarioId;
  bool get propuestaPendiente =>
      propuesta?.estado == EstadoPropuesta.pendiente && capitan;
  bool get resultadoPendiente =>
      resultado?.estado == EstadoResultadoPartido.pendiente && capitan;
  bool get puedeRegistrarResultado =>
      partido.soyOrganizador &&
      partido.fechaPasada &&
      (resultado == null ||
          resultado!.estado == EstadoResultadoPartido.disputado);
  bool get mostrarTarjetaResultado =>
      puedeGestionar && propuesta?.estado == EstadoPropuesta.aceptada;
  bool get puedeAbrirEquipos =>
      puedeGestionar &&
      (propuesta != null ||
          (partido.soyOrganizador &&
              !partido.fechaPasada &&
              partido.estado == EstadoPartido.equipoCompleto));

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    _marcadorA.dispose();
    _marcadorB.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });
    try {
      final ps = puedeGestionar
          ? await widget.repositorio.obtenerParticipantes(partido.id)
          : <ParticipantePartido>[];
      final prop = puedeGestionar
          ? await widget.repositorio.obtenerPropuesta(partido.id)
          : null;
      final res =
          puedeGestionar &&
              prop?.estado == EstadoPropuesta.aceptada &&
              partido.fechaPasada
          ? await widget.repositorio.obtenerResultado(partido.id)
          : null;
      if (!mounted) return;
      setState(() {
        participantes = ps;
        propuesta = prop;
        resultado = res;
        if (res != null) {
          _marcadorA.text = '${res.marcadorEquipoA}';
          _marcadorB.text = '${res.marcadorEquipoB}';
        } else {
          _marcadorA.clear();
          _marcadorB.clear();
        }
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e is StateError
            ? e.message
            : 'No se pudo cargar la información del partido.';
        cargando = false;
      });
    }
  }

  Future<void> actualizar() async {
    final p = await widget.recargarPartido?.call();
    if (p == null && widget.recargarPartido != null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (p != null && mounted) setState(() => partido = p);
    await cargar();
  }

  Future<void> ejecutar(Future<void> Function()? accion) async {
    if (accion == null || ejecutandoAccion) return;
    setState(() => ejecutandoAccion = true);
    try {
      await accion();
      if (mounted) await actualizar();
    } finally {
      if (mounted) setState(() => ejecutandoAccion = false);
    }
  }

  Future<void> abrirEquipos() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => VistaEquipos(
          partido: partido,
          repositorio: widget.repositorio,
          servicioAnalitica: widget.servicioAnalitica,
          usuarioId: widget.usuarioId,
        ),
      ),
    );
    if (mounted) await actualizar();
  }

  Future<void> irAlResultado() async {
    final contexto = _tarjetaResultadoKey.currentContext;
    if (contexto == null) return;
    await Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: .1,
    );
  }

  Future<void> registrarResultado() async {
    if (guardandoResultado) return;
    final marcadorA = int.tryParse(_marcadorA.text.trim());
    final marcadorB = int.tryParse(_marcadorB.text.trim());
    if (marcadorA == null || marcadorB == null) {
      setState(() => errorResultado = 'Ingresa ambos valores del marcador.');
      return;
    }
    setState(() {
      guardandoResultado = true;
      errorResultado = null;
    });
    try {
      await widget.repositorio.registrarResultado(
        partido.id,
        marcadorA,
        marcadorB,
      );
      await actualizar();
    } on StateError catch (e) {
      if (mounted) setState(() => errorResultado = e.message);
    } finally {
      if (mounted) setState(() => guardandoResultado = false);
    }
  }

  Map<String, String> iniciarValidacionResultado() {
    final props = {'intento_id': crearIntentoId()};
    registrarEvento(
      widget.servicioAnalitica,
      EventosAnalitica.validacionResultadoIniciada,
      props,
    );
    return props;
  }

  Future<void> disputarResultado() async {
    if (guardandoResultado || resultado == null) return;
    final props = iniciarValidacionResultado();
    var motivoEscrito = '';
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disputar marcador'),
        content: TextField(
          autofocus: true,
          maxLength: 300,
          onChanged: (valor) => motivoEscrito = valor,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Explica qué debe corregirse',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, motivoEscrito),
            child: const Text('Enviar disputa'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;
    await actuarSobreResultado(
      EventosAnalitica.resultadoDisputado,
      () => widget.repositorio.disputarResultado(
        partido.id,
        resultado!.revision,
        motivo,
      ),
      props,
    );
  }

  Future<void> confirmarResultado() async {
    final resultadoActual = resultado;
    if (guardandoResultado || resultadoActual == null) return;
    await actuarSobreResultado(
      EventosAnalitica.resultadoConfirmado,
      () => widget.repositorio.confirmarResultado(
        partido.id,
        resultadoActual.revision,
      ),
      iniciarValidacionResultado(),
    );
  }

  Future<void> actuarSobreResultado(
    String evento,
    Future<void> Function() accion,
    Map<String, String> props,
  ) async {
    if (guardandoResultado) return;
    setState(() {
      guardandoResultado = true;
      errorResultado = null;
    });
    try {
      await accion();
      registrarEvento(widget.servicioAnalitica, evento, props);
      await actualizar();
    } on StateError catch (e) {
      registrarEvento(
        widget.servicioAnalitica,
        EventosAnalitica.validacionResultadoFallida,
        {...props, 'codigo_error': 'servicio_partidos'},
      );
      await cargar();
      if (mounted) setState(() => errorResultado = e.message);
    } finally {
      if (mounted) setState(() => guardandoResultado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progreso = partido.cuposTotales <= 0
        ? 0.0
        : (partido.cuposOcupados / partido.cuposTotales).clamp(0.0, 1.0);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            key: const Key('detalle_encabezado'),
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppBar(
              title: const Text('Detalles del partido'),
              actions: [
                if (tieneSecundarias)
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    onSelected: secundaria,
                    itemBuilder: (_) => [
                      if (widget.onEditar != null)
                        const PopupMenuItem(
                          value: 'editar',
                          child: Text('Editar'),
                        ),
                      if (widget.onReprogramar != null)
                        const PopupMenuItem(
                          value: 'reprogramar',
                          child: Text('Reprogramar'),
                        ),
                      if (widget.onCompletarEquipo != null)
                        const PopupMenuItem(
                          value: 'cerrar',
                          child: Text('Cerrar inscripciones'),
                        ),
                      if (puedeAbrirEquipos)
                        PopupMenuItem(
                          value: 'equipos',
                          child: Text(
                            propuesta == null
                                ? 'Proponer equipos'
                                : 'Ver equipos',
                          ),
                        ),
                      if (widget.onRetirarseReprogramacion != null)
                        const PopupMenuItem(
                          value: 'retirarme',
                          child: Text('Retirarme de la nueva fecha'),
                        ),
                      if (widget.onSalirDeEspera != null)
                        const PopupMenuItem(
                          value: 'espera',
                          child: Text('Cancelar espera'),
                        ),
                      if (widget.onSalir != null)
                        const PopupMenuItem(
                          value: 'salir',
                          child: Text('Salir del partido'),
                        ),
                      if (widget.onEliminar != null)
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Text(
                            'Eliminar partido',
                            style: TextStyle(color: TemaApp.rojoAlerta),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          key: const Key('detalle_contenido'),
          constraints: const BoxConstraints(maxWidth: 480),
          child: cargando
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: actualizar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (partido.motivoReprogramacion != null)
                        aviso(
                          'Partido reprogramado',
                          partido.reconfirmacionPendiente
                              ? 'La fecha o ubicación cambiaron. Confirma tu asistencia para conservar tu plaza.'
                              : 'La fecha o ubicación cambiaron. ${partido.motivoReprogramacion}',
                          LucideIcons.calendarSync,
                          TemaApp.amarilloSuave,
                          TemaApp.naranjaAviso,
                        ),
                      tarjeta(),
                      const SizedBox(height: 14),
                      participacion(progreso),
                      const SizedBox(height: 14),
                      seccionParticipantes(),
                      const SizedBox(height: 12),
                      seccionEquipos(),
                      if (mostrarTarjetaResultado) ...[
                        const SizedBox(height: 14),
                        tarjetaResultado(),
                      ],
                      if (partido.soyOrganizador &&
                          ((widget.suplentes?.isNotEmpty ?? false) ||
                              (widget.bajasTardias?.isNotEmpty ?? false))) ...[
                        const SizedBox(height: 12),
                        seccionSeguimiento(),
                      ],
                      if (partido.estoyEnEspera)
                        aviso(
                          'Estás en lista de espera',
                          'Tu posición es ${partido.posicionEspera}. Entrarás automáticamente si se libera un cupo.',
                          LucideIcons.clock3,
                          TemaApp.amarilloSuave,
                          TemaApp.naranjaAviso,
                        ),
                      if (propuestaPendiente)
                        aviso(
                          'Propuesta pendiente',
                          'El organizador espera tu respuesta como capitán rival.',
                          LucideIcons.info,
                          TemaApp.azulSuave,
                          TemaApp.azulDeportivo,
                        ),
                      if (resultadoPendiente)
                        aviso(
                          'Resultado pendiente',
                          'Revisa el marcador y confírmalo o disputa el resultado.',
                          LucideIcons.info,
                          TemaApp.naranjaSuave,
                          TemaApp.naranjaAviso,
                        ),
                      const SizedBox(height: 18),
                      accionPrincipal(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  bool get tieneSecundarias =>
      widget.onEditar != null ||
      widget.onReprogramar != null ||
      widget.onCompletarEquipo != null ||
      puedeAbrirEquipos ||
      widget.onRetirarseReprogramacion != null ||
      widget.onSalirDeEspera != null ||
      widget.onSalir != null ||
      widget.onEliminar != null;

  String get accionTexto {
    if (partido.reconfirmacionPendiente && widget.onReconfirmar != null) {
      return 'Confirmar asistencia';
    }
    if (propuestaPendiente) return 'Responder propuesta';
    if (resultadoPendiente) return 'Revisar resultado';
    if (partido.soyOrganizador) {
      if (puedeAbrirEquipos) {
        return propuesta == null ? 'Gestionar equipos' : 'Ver equipos';
      }
      if (widget.onCompletarEquipo != null) return 'Cerrar inscripciones';
      if (widget.onEditar != null) return 'Editar partido';
      return '';
    }
    if (partido.estoyEnEspera && widget.onSalirDeEspera != null) {
      return 'Cancelar espera';
    }
    if (partido.estoyUnido && widget.onSalir != null) {
      return 'Salir del partido';
    }
    if (widget.onUnirse != null) return 'Unirme al partido';
    if (widget.onEntrarEnEspera != null) return 'Entrar en lista de espera';
    return '';
  }

  Future<void> Function()? get accionCallback {
    if (partido.reconfirmacionPendiente && widget.onReconfirmar != null) {
      return widget.onReconfirmar;
    }
    if (resultadoPendiente) return irAlResultado;
    if (propuestaPendiente) return abrirEquipos;
    if (partido.soyOrganizador) {
      if (puedeAbrirEquipos) return abrirEquipos;
      if (widget.onCompletarEquipo != null) return widget.onCompletarEquipo;
      if (widget.onEditar != null) return widget.onEditar;
    }
    if (partido.estoyEnEspera && widget.onSalirDeEspera != null) {
      return widget.onSalirDeEspera;
    }
    if (partido.estoyUnido && widget.onSalir != null) return widget.onSalir;
    return widget.onUnirse ?? widget.onEntrarEnEspera;
  }

  Widget accionPrincipal() {
    final callback = accionCallback;
    if (accionTexto.isEmpty || callback == null) {
      return Text(
        partido.motivoRechazoUnirse ??
            partido.motivoRechazoSalir ??
            'No hay acciones disponibles para este estado.',
        style: const TextStyle(color: TemaApp.textoSecundario),
      );
    }
    return FilledButton.icon(
      onPressed: ejecutandoAccion ? null : () => ejecutar(callback),
      icon: ejecutandoAccion
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.arrowRight),
      label: Text(ejecutandoAccion ? 'Procesando…' : accionTexto),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> secundaria(String s) async {
    switch (s) {
      case 'editar':
        await ejecutar(widget.onEditar);
        break;
      case 'reprogramar':
        await ejecutar(widget.onReprogramar);
        break;
      case 'cerrar':
        await ejecutar(widget.onCompletarEquipo);
        break;
      case 'equipos':
        await abrirEquipos();
        break;
      case 'retirarme':
        await ejecutar(widget.onRetirarseReprogramacion);
        break;
      case 'espera':
        await ejecutar(widget.onSalirDeEspera);
        break;
      case 'salir':
        await ejecutar(widget.onSalir);
        break;
      case 'eliminar':
        await ejecutar(widget.onEliminar);
        break;
    }
  }

  Widget tarjeta() => Container(
    padding: const EdgeInsets.all(20),
    decoration: TemaApp.tarjeta(radio: 24),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InsigniaDeporte(disciplina: partido.disciplina, tamano: 68),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(partido.titulo, style: TemaApp.titulo(tamano: 23)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(
                        partido.disciplina,
                        TemaApp.verdeSuave,
                        TemaApp.verdeOscuro,
                      ),
                      chip(
                        partido.etiquetaEstado,
                        partido.estaLleno
                            ? TemaApp.verdeSuave
                            : TemaApp.naranjaSuave,
                        partido.estaLleno
                            ? TemaApp.verdeOscuro
                            : TemaApp.naranjaAviso,
                      ),
                      if (partido.soyOrganizador)
                        chip(
                          'Organizador',
                          TemaApp.azulSuave,
                          TemaApp.azulDeportivo,
                        ),
                      if (partido.estoyUnido)
                        chip(
                          partido.reconfirmacionPendiente
                              ? 'Reconfirmación pendiente'
                              : 'Inscrito',
                          TemaApp.azulSuave,
                          TemaApp.azulDeportivo,
                        ),
                      if (partido.estoyEnEspera)
                        chip(
                          'Suplente #${partido.posicionEspera}',
                          TemaApp.naranjaSuave,
                          TemaApp.naranjaAviso,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        dato(LucideIcons.calendarDays, partido.fechaHora),
        dato(LucideIcons.mapPin, partido.ubicacion),
        dato(
          LucideIcons.userRound,
          'Organiza: ${partido.soyOrganizador ? 'Tú' : partido.organizadorNombre}',
        ),
      ],
    ),
  );

  Widget participacion(double value) => Container(
    padding: const EdgeInsets.all(18),
    decoration: TemaApp.tarjeta(radio: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text('Participación', style: TemaApp.titulo(tamano: 21)),
            chip(
              partido.estaLleno ? 'Sin cupos libres' : 'Cupos abiertos',
              partido.estaLleno ? TemaApp.verdeSuave : TemaApp.naranjaSuave,
              partido.estaLleno ? TemaApp.verdeOscuro : TemaApp.naranjaAviso,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '${partido.cuposOcupados} de ${partido.cuposTotales} jugadores',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${partido.cuposRestantes.clamp(0, partido.cuposTotales)} libres',
              style: const TextStyle(
                color: TemaApp.naranjaAviso,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            color: partido.estaLleno
                ? TemaApp.verdeDeportivo
                : TemaApp.naranjaAviso,
            backgroundColor: TemaApp.borde,
          ),
        ),
      ],
    ),
  );

  Widget seccionParticipantes() => seccion(
    LucideIcons.users,
    'Participantes (${partido.cuposOcupados})',
    participantes.isEmpty
        ? (puedeGestionar
              ? 'No hay participantes para mostrar'
              : partido.estoyEnEspera
              ? 'Estás en lista de espera'
              : 'Acceso restringido')
        : 'Consultar jugadores inscritos',
    participantes.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                puedeGestionar
                    ? 'No hay participantes disponibles.'
                    : 'Solo organizador e inscritos pueden ver la lista.',
              ),
            ),
          ]
        : participantes
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: TemaApp.azulSuave,
                      child: Text(
                        p.nombre.isEmpty ? '?' : p.nombre[0].toUpperCase(),
                      ),
                    ),
                    title: Text(p.nombre),
                    trailing: p.esOrganizador
                        ? const Text(
                            'Organizador',
                            style: TextStyle(color: TemaApp.textoSecundario),
                          )
                        : null,
                  ),
                ),
              )
              .toList(),
  );

  Widget seccionEquipos() {
    final p = propuesta;
    final nombres = {for (final x in participantes) x.id: x.nombre};
    final children = <Widget>[];
    if (p == null) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text('La distribución de equipos todavía no está definida.'),
        ),
      );
    } else {
      children.add(equipo('Equipo A', p.equipoA, nombres));
      children.add(const SizedBox(height: 8));
      children.add(equipo('Equipo B', p.equipoB, nombres));
    }
    if (puedeAbrirEquipos) {
      children.add(
        OutlinedButton.icon(
          onPressed: abrirEquipos,
          icon: const Icon(LucideIcons.externalLink),
          label: Text(
            p == null ? 'Gestionar equipos' : 'Abrir gestión de equipos',
          ),
        ),
      );
    }
    return seccion(
      LucideIcons.shieldCheck,
      'Equipos',
      p?.estado.etiqueta ?? 'Por definir',
      children,
    );
  }

  Widget tarjetaResultado() {
    final resultadoActual = resultado;
    final estado = resultadoActual?.estado;
    final estadoColor = switch (estado) {
      EstadoResultadoPartido.confirmado => TemaApp.verdeOscuro,
      EstadoResultadoPartido.disputado => TemaApp.naranjaAviso,
      EstadoResultadoPartido.pendiente => TemaApp.azulDeportivo,
      null => TemaApp.textoSecundario,
    };
    final estadoFondo = switch (estado) {
      EstadoResultadoPartido.confirmado => TemaApp.verdeSuave,
      EstadoResultadoPartido.disputado => TemaApp.naranjaSuave,
      EstadoResultadoPartido.pendiente => TemaApp.azulSuave,
      null => TemaApp.superficieSuave,
    };
    final puedeResponder =
        estado == EstadoResultadoPartido.pendiente && capitan;

    return Container(
      key: _tarjetaResultadoKey,
      padding: const EdgeInsets.all(18),
      decoration: TemaApp.tarjeta(radio: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text('Resultado del partido', style: TemaApp.titulo(tamano: 20)),
              if (estado != null)
                chip(estado.etiqueta, estadoFondo, estadoColor),
            ],
          ),
          const SizedBox(height: 16),
          if (resultadoActual != null)
            Row(
              children: [
                Expanded(
                  child: _marcadorEquipo(
                    'Equipo A',
                    resultadoActual.marcadorEquipoA,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–', style: TemaApp.titulo(tamano: 25)),
                ),
                Expanded(
                  child: _marcadorEquipo(
                    'Equipo B',
                    resultadoActual.marcadorEquipoB,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(LucideIcons.info, color: TemaApp.azulDeportivo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    partido.fechaPasada
                        ? 'El organizador todavía no registró el marcador.'
                        : 'El marcador podrá registrarse cuando termine el partido.',
                    style: const TextStyle(color: TemaApp.textoSecundario),
                  ),
                ),
              ],
            ),
          if (resultadoActual?.motivoDisputa case final motivo?) ...[
            const SizedBox(height: 12),
            _mensajeResultado(
              'Motivo de disputa: $motivo',
              TemaApp.naranjaSuave,
              TemaApp.naranjaAviso,
            ),
          ],
          if (estado == EstadoResultadoPartido.confirmado) ...[
            const SizedBox(height: 12),
            _mensajeResultado(
              'Resultado definitivo, confirmado por el capitán rival.',
              TemaApp.verdeSuave,
              TemaApp.verdeOscuro,
            ),
          ],
          if (resultadoActual != null &&
              !resultadoActual.esDefinitivo &&
              !puedeResponder) ...[
            const SizedBox(height: 10),
            Text(
              estado == EstadoResultadoPartido.disputado
                  ? partido.soyOrganizador
                        ? 'El marcador fue disputado. Corrígelo y envía una nueva versión.'
                        : 'El marcador fue disputado y está pendiente de corrección del organizador.'
                  : 'Pendiente de respuesta del capitán rival.',
              style: TextStyle(color: TemaApp.textoSecundario),
            ),
          ],
          if (puedeRegistrarResultado) ...[
            const SizedBox(height: 16),
            Text(
              resultadoActual == null
                  ? 'Registrar marcador'
                  : 'Corregir marcador',
              style: TemaApp.titulo(tamano: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('detalle_marcador_equipo_a'),
                    controller: _marcadorA,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Equipo A'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–'),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('detalle_marcador_equipo_b'),
                    controller: _marcadorB,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Equipo B'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: guardandoResultado ? null : registrarResultado,
              icon: guardandoResultado
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send),
              label: Text(
                guardandoResultado
                    ? 'Guardando…'
                    : resultadoActual == null
                    ? 'Registrar marcador'
                    : 'Enviar corrección',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          if (puedeResponder) ...[
            const SizedBox(height: 10),
            const Text('Al confirmar, el resultado será definitivo.'),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: guardandoResultado ? null : confirmarResultado,
              icon: guardandoResultado
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.circleCheck),
              label: const Text('Confirmar resultado'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: guardandoResultado ? null : disputarResultado,
              icon: const Icon(LucideIcons.messageCircle),
              label: const Text('Disputar resultado'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          if (errorResultado != null) ...[
            const SizedBox(height: 12),
            _mensajeResultado(
              errorResultado!,
              TemaApp.rojoSuave,
              TemaApp.rojoAlerta,
            ),
          ],
          if (resultadoActual != null &&
              resultadoActual.historial.isNotEmpty) ...[
            const Divider(height: 28),
            Text('Historial', style: TemaApp.titulo(tamano: 16)),
            const SizedBox(height: 6),
            for (final evento in resultadoActual.historial)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  LucideIcons.history,
                  color: TemaApp.textoSecundario,
                ),
                title: Text(evento.accion.etiqueta),
                subtitle: Text(
                  '${evento.marcadorEquipoA} - ${evento.marcadorEquipoB} · ${evento.actorNombre}'
                  '${evento.motivo == null ? '' : '\n${evento.motivo}'}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _marcadorEquipo(String equipo, int marcador) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: TemaApp.superficieSuave,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(equipo, style: const TextStyle(color: TemaApp.textoSecundario)),
        const SizedBox(height: 4),
        Text('$marcador', style: TemaApp.titulo(tamano: 28)),
      ],
    ),
  );

  Widget _mensajeResultado(String texto, Color fondo, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget seccionSeguimiento() {
    final suplentes = widget.suplentes ?? const <String>[];
    final bajas = widget.bajasTardias ?? const <BajaTardia>[];
    final hijos = <Widget>[
      for (var i = 0; i < suplentes.length; i++)
        ListTile(
          dense: true,
          leading: CircleAvatar(child: Text((i + 1).toString())),
          title: Text(suplentes[i]),
          subtitle: const Text('Lista de espera'),
        ),
      for (final baja in bajas)
        ListTile(
          dense: true,
          leading: const Icon(
            LucideIcons.triangleAlert,
            color: TemaApp.rojoAlerta,
          ),
          title: Text(baja.jugadorNombre),
          subtitle: Text('Baja tardía · ${baja.fecha.toLocal()}'),
        ),
    ];
    return seccion(
      LucideIcons.clipboardList,
      'Seguimiento',
      'Suplentes y bajas tardías',
      hijos,
    );
  }

  Widget equipo(String nombre, List<String> ids, Map<String, String> nombres) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TemaApp.superficieSuave,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$nombre · ${ids.length} jugadores',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(ids.map((id) => nombres[id] ?? 'Jugador').join(', ')),
          ],
        ),
      );

  Widget seccion(
    IconData icono,
    String titulo,
    String subtitulo,
    List<Widget> children,
  ) => Card(
    elevation: 0,
    color: TemaApp.superficie,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: TemaApp.borde),
    ),
    child: ExpansionTile(
      initiallyExpanded: false,
      leading: Icon(icono, color: TemaApp.textoSecundario, size: 28),
      title: Text(titulo, style: TemaApp.titulo(tamano: 17)),
      subtitle: Text(subtitulo),
      children: children,
    ),
  );

  Widget aviso(
    String titulo,
    String mensaje,
    IconData icono,
    Color fondo,
    Color color,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: fondo,
      border: Border.all(color: color.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 4),
              Text(mensaje),
            ],
          ),
        ),
      ],
    ),
  );

  Widget dato(IconData icono, String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icono, color: TemaApp.textoSecundario),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: TemaApp.textoSecundario),
          ),
        ),
      ],
    ),
  );

  Widget chip(String texto, Color fondo, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      texto,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}
