import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/modelo_partido.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/boton_accion.dart';
import '../../widgets/campo_clave.dart';
import '../inicio/vista_inicio_publico.dart';

class VistaPerfil extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final Future<String?> Function(Uint8List)? guardarArchivo;
  final ServicioAnalitica? servicioAnalitica;

  const VistaPerfil({
    super.key,
    required this.servicioAuth,
    this.guardarArchivo,
    this.servicioAnalitica,
  });

  @override
  State<VistaPerfil> createState() => _VistaPerfilState();
}

class _VistaPerfilState extends State<VistaPerfil> {
  final _formularioPerfil = GlobalKey<FormState>();
  final _formularioClave = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _carrera;
  final _claveActual = TextEditingController();
  final _claveNueva = TextEditingController();
  final _confirmarClave = TextEditingController();
  late String _deporte;
  bool _guardandoPerfil = false;
  bool _guardandoClave = false;
  bool _cargandoDatos = false;
  bool _guardandoArchivo = false;
  bool _eliminandoCuenta = false;
  late final _analitica =
      widget.servicioAnalitica ??
      crearAnalitica(widget.servicioAuth is ServicioAutenticacionSupabase);
  String? _mensajePerfil;
  String? _errorPerfil;
  String? _mensajeClave;
  String? _errorClave;

  @override
  void initState() {
    super.initState();
    final usuario = widget.servicioAuth.usuarioActual!;
    _nombre = TextEditingController(text: usuario.nombre);
    _carrera = TextEditingController(text: usuario.carrera);
    _deporte = ModeloPartido.disciplinas.contains(usuario.deporteFavorito)
        ? usuario.deporteFavorito
        : 'Otro';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _carrera.dispose();
    _claveActual.dispose();
    _claveNueva.dispose();
    _confirmarClave.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    if (_guardandoPerfil || !_formularioPerfil.currentState!.validate()) return;
    setState(() {
      _guardandoPerfil = true;
      _mensajePerfil = null;
      _errorPerfil = null;
    });
    final error = await widget.servicioAuth.actualizarPerfil(
      nombre: _nombre.text,
      carrera: _carrera.text,
      deporteFavorito: _deporte,
    );
    if (!mounted) return;
    setState(() {
      _guardandoPerfil = false;
      if (error == null) {
        _mensajePerfil = 'Perfil actualizado correctamente.';
      } else {
        _errorPerfil = error;
      }
    });
  }

  Future<void> _cambiarClave() async {
    if (_guardandoClave || !_formularioClave.currentState!.validate()) return;
    setState(() {
      _guardandoClave = true;
      _mensajeClave = null;
      _errorClave = null;
    });
    final error = await widget.servicioAuth.cambiarContrasena(
      contrasenaActual: _claveActual.text,
      contrasenaNueva: _claveNueva.text,
    );
    if (!mounted) return;
    setState(() {
      _guardandoClave = false;
      if (error == null) {
        _claveActual.clear();
        _claveNueva.clear();
        _confirmarClave.clear();
        _formularioClave.currentState!.reset();
        _mensajeClave = 'Contraseña actualizada correctamente.';
      } else {
        _errorClave = error;
      }
    });
  }

  Future<void> _verMisDatos() async {
    if (_cargandoDatos) return;
    setState(() => _cargandoDatos = true);
    try {
      final datos = await widget.servicioAuth.obtenerMisDatos();
      final json = const JsonEncoder.withIndent('  ').convert(datos);
      if (!mounted) return;
      setState(() => _cargandoDatos = false);
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: const Text('Mis datos'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: SelectableText(json)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogo),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              key: const Key('descargar_mis_datos'),
              onPressed: () => _descargarDatos(json, dialogo),
              child: const Text('Descargar JSON'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar tus datos. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  Future<void> _descargarDatos(String json, BuildContext dialogo) async {
    if (_guardandoArchivo) return;
    _guardandoArchivo = true;
    try {
      final bytes = Uint8List.fromList(utf8.encode(json));
      final ruta = widget.guardarArchivo != null
          ? await widget.guardarArchivo!(bytes)
          : await FileSaver.instance.saveAs(
              name: 'unisport-mis-datos',
              bytes: bytes,
              fileExtension: 'json',
              mimeType: MimeType.json,
            );
      if (!mounted || ruta == null) return;
      if (dialogo.mounted) Navigator.pop(dialogo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos guardados correctamente.')),
      );
    } catch (_) {
      if (!mounted) return;
      if (dialogo.mounted) Navigator.pop(dialogo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron guardar tus datos. Inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      _guardandoArchivo = false;
    }
  }

  Future<void> _eliminarCuenta() async {
    final intentoId = crearIntentoId();
    unawaited(
      registrarEvento(_analitica, EventosAnalitica.cuentaEliminacionIniciada, {
        'intento_id': intentoId,
      }),
    );
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const SingleChildScrollView(
          child: Text(
            'Se eliminarán tu cuenta y tu perfil. Ya no podrás iniciar sesión.\n\n'
            'Se cancelarán los partidos futuros que organizas. En los partidos '
            'en los que participas, el primer suplente ocupará tu lugar o '
            'quedará un cupo libre.\n\n'
            'Los resultados confirmados se conservarán sin identificarte. '
            'Esta acción no se puede deshacer.',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogo, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('confirmar_eliminar_cuenta'),
                  onPressed: () => Navigator.pop(dialogo, true),
                  child: const Text(
                    'Eliminar cuenta',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _eliminandoCuenta = true);
    final error = await widget.servicioAuth.eliminarCuenta(
      intentoId: intentoId,
    );
    if (error != null) {
      unawaited(
        registrarEvento(_analitica, EventosAnalitica.cuentaEliminacionFallida, {
          'intento_id': intentoId,
          'codigo_error':
              error.contains('resultado confirmado en un partido futuro')
              ? 'bloqueo'
              : 'error',
        }),
      );
    }
    if (!mounted) return;
    setState(() => _eliminandoCuenta = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => VistaInicioPublico(servicioAuth: widget.servicioAuth),
      ),
      (ruta) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) {
      return const Scaffold(body: Center(child: Text('Sesión no disponible.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cabecera(usuario.nombre, usuario.correo),
                const SizedBox(height: 20),
                _seccionPerfil(usuario.correo),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const Key('ver_mis_datos'),
                  onPressed: _cargandoDatos ? null : _verMisDatos,
                  icon: const Icon(LucideIcons.fileJson),
                  label: Text(
                    _cargandoDatos
                        ? 'Cargando datos...'
                        : 'Ver y descargar mis datos',
                  ),
                ),
                const SizedBox(height: 20),
                _seccionClave(),
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const Key('eliminar_cuenta'),
                  onPressed: _eliminandoCuenta ? null : _eliminarCuenta,
                  child: Text(
                    _eliminandoCuenta
                        ? 'Eliminando cuenta...'
                        : 'Eliminar cuenta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabecera(String nombre, String correo) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF0BAA60), Color(0xFF10786F)]),
      borderRadius: BorderRadius.all(Radius.circular(22)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          child: Text(
            nombre.isEmpty ? 'U' : nombre[0].toUpperCase(),
            style: const TextStyle(
              color: TemaApp.verdeOscuro,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(correo, style: const TextStyle(color: Color(0xFFE0F2EA))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _seccionPerfil(String correo) => Container(
    padding: const EdgeInsets.all(20),
    decoration: TemaApp.tarjeta(),
    child: Form(
      key: _formularioPerfil,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Datos personales', style: TemaApp.titulo(tamano: 19)),
          const SizedBox(height: 6),
          const Text(
            'Actualiza la información que se muestra en UniSport.',
            style: TextStyle(color: TemaApp.textoSecundario),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('perfil_nombre'),
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre y apellido',
              prefixIcon: Icon(LucideIcons.user),
            ),
            validator: (valor) => valor == null || valor.trim().length < 2
                ? 'Ingresa tu nombre'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: correo,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Correo de la cuenta',
              prefixIcon: Icon(LucideIcons.mail),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('perfil_carrera'),
            controller: _carrera,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Carrera o facultad',
              prefixIcon: Icon(LucideIcons.graduationCap),
            ),
            validator: (valor) => valor == null || valor.trim().isEmpty
                ? 'Ingresa tu carrera'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('perfil_deporte'),
            initialValue: _deporte,
            decoration: const InputDecoration(
              labelText: 'Deporte principal',
              prefixIcon: Icon(LucideIcons.medal),
            ),
            items: [
              for (final deporte in ModeloPartido.disciplinas)
                DropdownMenuItem(value: deporte, child: Text(deporte)),
            ],
            onChanged: _guardandoPerfil
                ? null
                : (valor) => setState(() => _deporte = valor!),
          ),
          if (_errorPerfil != null) ...[
            const SizedBox(height: 14),
            CajaMensaje(texto: _errorPerfil!),
          ],
          if (_mensajePerfil != null) ...[
            const SizedBox(height: 14),
            CajaMensaje(texto: _mensajePerfil!, tipo: TipoMensaje.exito),
          ],
          const SizedBox(height: 18),
          BotonAccion(
            key: const Key('perfil_guardar'),
            texto: 'Guardar perfil',
            estado: _guardandoPerfil
                ? EstadoBoton.cargando
                : EstadoBoton.normal,
            onPressed: _guardarPerfil,
          ),
        ],
      ),
    ),
  );

  Widget _seccionClave() => Container(
    padding: const EdgeInsets.all(20),
    decoration: TemaApp.tarjeta(),
    child: Form(
      key: _formularioClave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cambiar contraseña', style: TemaApp.titulo(tamano: 19)),
          const SizedBox(height: 6),
          const Text(
            'Confirma tu contraseña actual y elige una nueva.',
            style: TextStyle(color: TemaApp.textoSecundario),
          ),
          const SizedBox(height: 18),
          CampoClave(
            key: const Key('perfil_clave_actual'),
            controller: _claveActual,
            etiqueta: 'Contraseña actual',
            validator: (valor) => valor == null || valor.isEmpty
                ? 'Ingresa tu contraseña actual'
                : null,
          ),
          const SizedBox(height: 14),
          CampoClave(
            key: const Key('perfil_clave_nueva'),
            controller: _claveNueva,
            etiqueta: 'Nueva contraseña',
            validator: (valor) => valor == null || valor.length < 6
                ? 'Usa al menos 6 caracteres'
                : valor == _claveActual.text
                ? 'La nueva contraseña debe ser diferente'
                : null,
          ),
          const SizedBox(height: 14),
          CampoClave(
            key: const Key('perfil_clave_confirmar'),
            controller: _confirmarClave,
            etiqueta: 'Confirmar nueva contraseña',
            onSubmitted: _cambiarClave,
            validator: (valor) => valor != _claveNueva.text
                ? 'Las contraseñas no coinciden'
                : null,
          ),
          if (_errorClave != null) ...[
            const SizedBox(height: 14),
            CajaMensaje(texto: _errorClave!),
          ],
          if (_mensajeClave != null) ...[
            const SizedBox(height: 14),
            CajaMensaje(texto: _mensajeClave!, tipo: TipoMensaje.exito),
          ],
          const SizedBox(height: 18),
          BotonAccion(
            key: const Key('perfil_cambiar_clave'),
            texto: 'Cambiar contraseña',
            estado: _guardandoClave ? EstadoBoton.cargando : EstadoBoton.normal,
            onPressed: _cambiarClave,
          ),
        ],
      ),
    ),
  );
}
