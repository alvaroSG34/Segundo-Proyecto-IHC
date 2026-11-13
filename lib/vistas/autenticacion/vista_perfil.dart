import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modelos/modelo_partido.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/boton_accion.dart';
import '../../widgets/campo_clave.dart';

class VistaPerfil extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;

  const VistaPerfil({super.key, required this.servicioAuth});

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
                _seccionClave(),
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
