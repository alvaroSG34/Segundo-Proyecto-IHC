import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/filtro_partidos.dart';
import '../../modelos/modelo_partido.dart';
import '../../tema/iconos_deporte.dart';
import '../../tema/tema_app.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/tarjeta_partido.dart';

/// Formulario real para crear un partido.
/// 1 - CAPTURAR: la persona completa los datos (con vista previa en vivo).
/// 2 - CONSTRUIR: se arma un ModeloPartido y se devuelve con Navigator.pop.
/// (Guardar, Mostrar y Recuperar los hace VistaMisPartidos.)
class VistaCrearPartido extends StatefulWidget {
  final String organizadorNombre;
  final ModeloPartido? partidoAEditar;

  const VistaCrearPartido({
    super.key,
    required this.organizadorNombre,
    this.partidoAEditar,
  });

  @override
  State<VistaCrearPartido> createState() => _VistaCrearPartidoState();
}

class _VistaCrearPartidoState extends State<VistaCrearPartido> {
  bool get _esEdicion => widget.partidoAEditar != null;

  static const List<String> _disciplinas = ModeloPartido.disciplinas;
  static const int _cuposMin = 2;
  static const int _cuposMax = 30;

  // Atajos de hora (hora, minuto)
  static const List<TimeOfDay> _horasRapidas = [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
  ];

  final _formKey = GlobalKey<FormState>();
  final _claveSacudida = GlobalKey<SacudidaState>();
  final _tituloCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();

  String _disciplina = 'Futsal';
  int _cupos = 10;
  DateTime? _fecha;
  TimeOfDay? _hora;
  bool _intentoEnviar = false;

  void _refrescar() {
    if (mounted) setState(() {});
  }

  int get _cuposMinimo => _esEdicion
      ? (widget.partidoAEditar!.cuposOcupados > _cuposMin
          ? widget.partidoAEditar!.cuposOcupados
          : _cuposMin)
      : _cuposMin;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final p = widget.partidoAEditar!;
      _tituloCtrl.text = p.titulo;
      _ubicacionCtrl.text = p.ubicacion;
      _disciplina = p.disciplina;
      _cupos = p.cuposTotales;
      // Se conservan la fecha y la hora del partido (antes se reemplazaban
      // por hoy a las 19:00 y el partido se movía sin avisar)
      final inicio = p.fechaInicio;
      if (inicio != null) {
        _fecha = DateTime(inicio.year, inicio.month, inicio.day);
        _hora = TimeOfDay(hour: inicio.hour, minute: inicio.minute);
      }
    }
    // La vista previa se actualiza mientras se escribe
    _tituloCtrl.addListener(_refrescar);
    _ubicacionCtrl.addListener(_refrescar);
  }

  @override
  void dispose() {
    _tituloCtrl.removeListener(_refrescar);
    _ubicacionCtrl.removeListener(_refrescar);
    _tituloCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  String _formatoFecha(DateTime f) =>
      '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
  String _formatoHora(TimeOfDay h) => '${_dos(h.hour)}:${_dos(h.minute)}';

  String get _textoFecha =>
      _fecha == null ? 'Elegir fecha' : _formatoFecha(_fecha!);
  String get _textoHora => _hora == null ? 'Elegir hora' : _formatoHora(_hora!);

  DateTime get _hoy {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  DateTime get _proximoSabado {
    final dias = (DateTime.saturday - _hoy.weekday) % 7;
    return _hoy.add(Duration(days: dias == 0 ? 7 : dias));
  }

  bool _mismoDia(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _elegirFecha() async {
    final ultima = DateTime(_hoy.year + 1, 12, 31);
    final actual = _fecha;
    final elegida = await showDatePicker(
      context: context,
      initialDate:
          actual == null || actual.isBefore(_hoy) || actual.isAfter(ultima)
          ? _hoy
          : actual,
      firstDate: _hoy,
      lastDate: ultima,
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  // 2 - CONSTRUIR: valida y arma el objeto con lo que escribió la persona
  void _guardar() {
    setState(() => _intentoEnviar = true);
    final formularioValido = _formKey.currentState!.validate();
    if (!formularioValido || _fecha == null || _hora == null) {
      _claveSacudida.currentState?.sacudir();
      return;
    }

    final ModeloPartido partido;
    try {
      partido = _esEdicion
          // La regla de cupos recalcula el estado (ver conCuposTotales)
          ? widget.partidoAEditar!
                .conCuposTotales(_cupos)
                .copyWith(
                  titulo: _tituloCtrl.text.trim(),
                  disciplina: _disciplina,
                  icono: _disciplina,
                  ubicacion: _ubicacionCtrl.text.trim(),
                  fechaHora: '$_textoFecha · $_textoHora',
                )
          : ModeloPartido(
            id: 'p-${DateTime.now().millisecondsSinceEpoch}',
            titulo: _tituloCtrl.text.trim(),
            disciplina: _disciplina,
            icono: _disciplina, // el ícono visual se resuelve por disciplina (ver EstiloDeporte)
            ubicacion: _ubicacionCtrl.text.trim(),
            fechaHora: '$_textoFecha · $_textoHora',
            cuposTotales: _cupos,
            cuposOcupados: 1, // el organizador ya cuenta como jugador
            organizadorNombre: widget.organizadorNombre,
            soyOrganizador: true,
            estoyUnido: true,
          );
    } on StateError catch (e) {
      _claveSacudida.currentState?.sacudir();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: TemaApp.rojoAlerta,
        ),
      );
      return;
    }

    Navigator.pop(context, partido);
  }

  // Partido provisional con lo que se lleva escrito, solo para la vista previa
  ModeloPartido get _partidoVistaPrevia {
    final titulo = _tituloCtrl.text.trim();
    final lugar = _ubicacionCtrl.text.trim();
    return ModeloPartido(
      id: _esEdicion ? widget.partidoAEditar!.id : 'vista-previa',
      titulo: titulo.isEmpty ? 'Título del partido' : titulo,
      disciplina: _disciplina,
      icono: _disciplina,
      ubicacion: lugar.isEmpty ? 'Ubicación por definir' : lugar,
      fechaHora:
          '${_fecha == null ? 'Fecha por definir' : _formatoFecha(_fecha!)} · ${_hora == null ? 'Hora por definir' : _formatoHora(_hora!)}',
      cuposTotales: _cupos,
      cuposOcupados: _esEdicion ? widget.partidoAEditar!.cuposOcupados : 1,
      organizadorNombre: widget.organizadorNombre,
      soyOrganizador: true,
      estoyUnido: true,
      estado: _esEdicion
          ? widget.partidoAEditar!.estado
          : EstadoPartido.cuposAbiertos,
    );
  }

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: TemaApp.textoPrincipal,
      ),
    ),
  );

  Widget _chips({
    required List<String> opciones,
    required String seleccionada,
    required ValueChanged<String> alCambiar,
    bool conIconos = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: opciones.map((op) {
        final activo = op == seleccionada;
        return GestureDetector(
          onTap: () => alCambiar(op),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? TemaApp.verdeSuave : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: activo ? TemaApp.verdeDeportivo : TemaApp.borde,
                width: activo ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conIconos) ...[
                  Icon(
                    EstiloDeporte.de(op).icono,
                    size: 16,
                    color: activo
                        ? TemaApp.verdeOscuro
                        : TemaApp.textoSecundario,
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  op,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activo
                        ? TemaApp.verdeOscuro
                        : TemaApp.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _chipRapido({
    required String texto,
    required IconData icono,
    required bool activo,
    required VoidCallback alTocar,
  }) {
    return GestureDetector(
      onTap: alTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? TemaApp.azulSuave : TemaApp.superficieSuave,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? TemaApp.azulDeportivo : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              size: 14,
              color: activo ? TemaApp.azulDeportivo : TemaApp.textoSecundario,
            ),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo
                    ? const Color(0xFF075985)
                    : TemaApp.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoSelector({
    required IconData icono,
    required String texto,
    required bool tieneValor,
    required bool error,
    required VoidCallback alTocar,
  }) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: error ? TemaApp.rojoAlerta : TemaApp.borde,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: TemaApp.textoSecundario),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tieneValor
                      ? TemaApp.textoPrincipal
                      : TemaApp.textoSecundario,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonCupo(IconData icono, VoidCallback? alTocar) {
    return Material(
      color: alTocar == null ? TemaApp.superficieSuave : TemaApp.verdeSuave,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icono,
            size: 20,
            color: alTocar == null
                ? const Color(0xFFCBD5E1)
                : TemaApp.verdeOscuro,
          ),
        ),
      ),
    );
  }

  // Selector de cupos con +/- y una fila de círculos (el primero eres tú)
  // Jugadores ya inscritos: al crear, solo el organizador
  int get _ocupados => _esEdicion ? widget.partidoAEditar!.cuposOcupados : 1;

  // Motivo por el que no se pueden cambiar los cupos (equipo completo)
  String? get _motivoCuposBloqueados =>
      _esEdicion ? widget.partidoAEditar!.motivoBloqueoCambiarCupos : null;

  Widget _selectorCupos() {
    final bloqueado = _motivoCuposBloqueados != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: TemaApp.tarjeta(radio: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botonCupo(
                LucideIcons.minus,
                !bloqueado && _cupos > _cuposMinimo
                    ? () => setState(() => _cupos--)
                    : null,
              ),
              SizedBox(
                width: 110,
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (hijo, anim) =>
                          ScaleTransition(scale: anim, child: hijo),
                      child: Text(
                        '$_cupos',
                        key: ValueKey(_cupos),
                        style: TemaApp.titulo(tamano: 32),
                      ),
                    ),
                    const Text(
                      'jugadores',
                      style: TextStyle(
                        fontSize: 12,
                        color: TemaApp.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              _botonCupo(
                LucideIcons.plus,
                !bloqueado && _cupos < _cuposMax
                    ? () => setState(() => _cupos++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_cupos, (i) {
              final eresTu = i < _ocupados;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eresTu ? TemaApp.verdeDeportivo : Colors.transparent,
                  border: Border.all(
                    color: eresTu
                        ? TemaApp.verdeDeportivo
                        : const Color(0xFFCBD5E1),
                    width: 1.8,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            _esEdicion
                ? 'Ya hay $_ocupados inscritos · faltan '
                      '${(_cupos - _ocupados).clamp(0, _cuposMax)} por completar'
                : 'Tú ocupas 1 cupo · faltan ${_cupos - 1} por completar',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: TemaApp.textoSecundario,
            ),
          ),
          if (bloqueado) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.lock, size: 15, color: TemaApp.rojoAlerta),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _motivoCuposBloqueados!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TemaApp.rojoAlerta,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorFecha = _intentoEnviar && _fecha == null;
    final errorHora = _intentoEnviar && _hora == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar partido' : 'Crear partido'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Sacudida(
              key: _claveSacudida,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vista previa en vivo
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.eye,
                          size: 15,
                          color: TemaApp.textoSecundario,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Así se verá tu partido',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TemaApp.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TarjetaPartido(partido: _partidoVistaPrevia),
                    const SizedBox(height: 12),

                    _etiqueta('Título'),
                    TextFormField(
                      key: const Key('partido_titulo'),
                      controller: _tituloCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ej: Futsal 5 vs 5 nocturno',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Escribe un título';
                        if (t.length < 3) {
                          return 'Debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    _etiqueta('Disciplina'),
                    _chips(
                      opciones: _disciplinas,
                      seleccionada: _disciplina,
                      conIconos: true,
                      alCambiar: (v) => setState(() => _disciplina = v),
                    ),
                    const SizedBox(height: 20),

                    _etiqueta('Ubicación'),
                    TextFormField(
                      key: const Key('partido_ubicacion'),
                      controller: _ubicacionCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ej: Cancha 2 (Campus Central)',
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Escribe el lugar del partido'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    // Atajos de lugar (Issue #10); se puede escribir otro lugar
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final lugar in FiltroPartidos.lugaresSugeridos)
                          _chipRapido(
                            texto: lugar,
                            icono: LucideIcons.mapPin,
                            activo: _ubicacionCtrl.text.trim() == lugar,
                            alTocar: () => _ubicacionCtrl.text = lugar,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _etiqueta('Fecha'),
                              _campoSelector(
                                icono: LucideIcons.calendarDays,
                                texto: _textoFecha,
                                tieneValor: _fecha != null,
                                error: errorFecha,
                                alTocar: _elegirFecha,
                              ),
                              if (errorFecha)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 4),
                                  child: Text(
                                    'Elige una fecha',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TemaApp.rojoAlerta,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _etiqueta('Hora'),
                              _campoSelector(
                                icono: LucideIcons.clock,
                                texto: _textoHora,
                                tieneValor: _hora != null,
                                error: errorHora,
                                alTocar: _elegirHora,
                              ),
                              if (errorHora)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 4),
                                  child: Text(
                                    'Elige una hora',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: TemaApp.rojoAlerta,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Atajos de fecha y hora
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chipRapido(
                          texto: 'Hoy',
                          icono: LucideIcons.calendar,
                          activo: _mismoDia(_fecha, _hoy),
                          alTocar: () => setState(() => _fecha = _hoy),
                        ),
                        _chipRapido(
                          texto: 'Mañana',
                          icono: LucideIcons.calendar,
                          activo: _mismoDia(
                            _fecha,
                            _hoy.add(const Duration(days: 1)),
                          ),
                          alTocar: () => setState(
                            () => _fecha = _hoy.add(const Duration(days: 1)),
                          ),
                        ),
                        _chipRapido(
                          texto: 'Sábado',
                          icono: LucideIcons.calendar,
                          activo: _mismoDia(_fecha, _proximoSabado),
                          alTocar: () =>
                              setState(() => _fecha = _proximoSabado),
                        ),
                        for (final h in _horasRapidas)
                          _chipRapido(
                            texto: _formatoHora(h),
                            icono: LucideIcons.clock,
                            activo: _hora == h,
                            alTocar: () => setState(() => _hora = h),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _etiqueta('Cupos totales (incluyéndote)'),
                    _selectorCupos(),
                    const SizedBox(height: 8),
                    // Ayuda breve donde se decide (H10)
                    const Text(
                      'Los cupos incluyen al organizador. Después podrás '
                      '"Agregar jugador" para sumar a alguien sin cuenta o '
                      '"Completar equipo" para cerrar la convocatoria.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TemaApp.textoSecundario,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(LucideIcons.check, size: 19),
                      label: Text(
                        _esEdicion ? 'Guardar cambios' : 'Guardar partido',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
