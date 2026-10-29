import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../servicios/servicio_autenticacion.dart';
import '../tema/caja_mensaje.dart';
import '../tema/iconos_deporte.dart';
import '../tema/tema_app.dart';
import '../widgets/animaciones.dart';
import '../widgets/boton_accion.dart';
import '../widgets/campo_clave.dart';
import 'vista_login.dart';
import 'vista_principal.dart';

/// Formulario de registro simple para nuevos estudiantes universitarios
class VistaRegistro extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;

  const VistaRegistro({super.key, required this.servicioAuth});

  @override
  State<VistaRegistro> createState() => _VistaRegistroState();
}

class _VistaRegistroState extends State<VistaRegistro> {
  final _claveFormulario = GlobalKey<FormState>();
  final _claveSacudida = GlobalKey<SacudidaState>();
  final _controladorNombre = TextEditingController();
  final _controladorCorreo = TextEditingController();
  final _controladorContrasena = TextEditingController();
  final _controladorCarrera = TextEditingController();

  String _deporteSeleccionado = 'Futsal';
  EstadoBoton _estadoBoton = EstadoBoton.normal;
  String? _mensajeError;

  static const List<String> _deportes = ['Futsal', 'Básquetbol', 'Voleibol'];

  bool get _correoValido =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_controladorCorreo.text.trim());

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controladorCorreo.addListener(_refrescar);
  }

  @override
  void dispose() {
    _controladorCorreo.removeListener(_refrescar);
    _controladorNombre.dispose();
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    _controladorCarrera.dispose();
    super.dispose();
  }

  Future<void> _ejecutarRegistro() async {
    setState(() => _mensajeError = null);

    if (!_claveFormulario.currentState!.validate()) {
      _claveSacudida.currentState?.sacudir();
      return;
    }

    setState(() => _estadoBoton = EstadoBoton.cargando);

    final error = await widget.servicioAuth.registrarUsuario(
      nombre: _controladorNombre.text,
      correo: _controladorCorreo.text,
      contrasena: _controladorContrasena.text,
      carrera: _controladorCarrera.text,
      deporteFavorito: _deporteSeleccionado,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _estadoBoton = EstadoBoton.normal;
        _mensajeError = error;
      });
      _claveSacudida.currentState?.sacudir();
      return;
    }

    setState(() => _estadoBoton = EstadoBoton.exito);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // Redirigir a la ruta privada protegida
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => VistaPrincipal(servicioAuth: widget.servicioAuth),
      ),
      (ruta) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de estudiante')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Sacudida(
              key: _claveSacudida,
              child: Form(
                key: _claveFormulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Aparecer(
                      indice: 0,
                      child: Text(
                        'Únete a UniSport',
                        style: TemaApp.titulo(tamano: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Aparecer(
                      indice: 1,
                      child: Text(
                        'Completa tus datos básicos para comenzar a jugar.',
                        style: TextStyle(
                          fontSize: 14,
                          color: TemaApp.textoSecundario,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Nombre
                    Aparecer(
                      indice: 2,
                      child: TextFormField(
                        controller: _controladorNombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y apellido',
                          prefixIcon: Icon(LucideIcons.user),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Ingresa tu nombre';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Correo (con check en vivo)
                    Aparecer(
                      indice: 3,
                      child: TextFormField(
                        controller: _controladorCorreo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo institucional (@uagrm.edu / @unisport.edu)',
                          prefixIcon: const Icon(LucideIcons.mail),
                          suffixIcon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (hijo, anim) =>
                                ScaleTransition(scale: anim, child: hijo),
                            child: _correoValido
                                ? const Icon(
                                    LucideIcons.circleCheck,
                                    key: ValueKey('ok'),
                                    color: TemaApp.verdeDeportivo,
                                  )
                                : const SizedBox.shrink(key: ValueKey('vacio')),
                          ),
                        ),
                        validator: (valor) {
                          if (valor == null || valor.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!valor.contains('@')) {
                            return 'Correo no válido';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Carrera
                    Aparecer(
                      indice: 4,
                      child: TextFormField(
                        controller: _controladorCarrera,
                        decoration: const InputDecoration(
                          labelText: 'Carrera o facultad',
                          prefixIcon: Icon(LucideIcons.graduationCap),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contraseña (pelotitas animadas)
                    Aparecer(
                      indice: 5,
                      child: CampoClave(
                        controller: _controladorContrasena,
                        etiqueta: 'Contraseña (mínimo 6 caracteres)',
                        onSubmitted: _ejecutarRegistro,
                        validator: (valor) {
                          if (valor == null || valor.isEmpty) {
                            return 'Define una contraseña';
                          }
                          if (valor.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Deporte principal
                    Aparecer(
                      indice: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deporte principal',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: TemaApp.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: _deportes
                                .map(_construirOpcionDeporte)
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    if (_mensajeError != null) ...[
                      const SizedBox(height: 16),
                      CajaMensaje(texto: _mensajeError!),
                    ],

                    const SizedBox(height: 26),

                    Aparecer(
                      indice: 7,
                      child: BotonAccion(
                        texto: 'Crear cuenta e ingresar',
                        estado: _estadoBoton,
                        onPressed: _ejecutarRegistro,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes cuenta? ',
                          style: TextStyle(color: TemaApp.textoSecundario),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VistaLogin(
                                  servicioAuth: widget.servicioAuth,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Inicia sesión',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: TemaApp.verdeOscuro,
                            ),
                          ),
                        ),
                      ],
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

  Widget _construirOpcionDeporte(String deporte) {
    final seleccionado = _deporteSeleccionado == deporte;
    final estilo = EstiloDeporte.de(deporte);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: () => setState(() => _deporteSeleccionado = deporte),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: seleccionado ? TemaApp.verdeSuave : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: seleccionado ? TemaApp.verdeDeportivo : TemaApp.borde,
                width: seleccionado ? 1.8 : 1.2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  estilo.icono,
                  size: 24,
                  color: seleccionado
                      ? TemaApp.verdeOscuro
                      : TemaApp.textoSecundario,
                ),
                const SizedBox(height: 6),
                Text(
                  deporte,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: seleccionado
                        ? TemaApp.verdeOscuro
                        : TemaApp.textoPrincipal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
