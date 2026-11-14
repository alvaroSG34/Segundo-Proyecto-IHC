import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/boton_accion.dart';
import '../../widgets/campo_clave.dart';
import 'vista_registro.dart';
import 'vista_recuperar_clave.dart';
import '../inicio/vista_principal.dart';

/// Formulario de inicio de sesión de UniSport
class VistaLogin extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final ServicioAnalitica? servicioAnalitica;
  final String? mensajeRedireccion;

  const VistaLogin({
    super.key,
    required this.servicioAuth,
    this.servicioAnalitica,
    this.mensajeRedireccion,
  });

  @override
  State<VistaLogin> createState() => _VistaLoginState();
}

class _VistaLoginState extends State<VistaLogin> {
  late final _analitica =
      widget.servicioAnalitica ??
      crearAnalitica(widget.servicioAuth is ServicioAutenticacionSupabase);
  final _intentoId = crearIntentoId();

  void _registrar(String evento, [String? codigoError]) {
    final props = {'intento_id': _intentoId};
    if (codigoError != null) props['codigo_error'] = codigoError;
    registrarEvento(_analitica, evento, props);
  }

  final _claveFormulario = GlobalKey<FormState>();
  final _claveSacudida = GlobalKey<SacudidaState>();
  final _controladorCorreo = TextEditingController();
  final _controladorContrasena = TextEditingController();

  EstadoBoton _estadoBoton = EstadoBoton.normal;
  String? _mensajeError;

  bool get _correoValido =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
          .hasMatch(_controladorCorreo.text.trim());

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _registrar(EventosAnalitica.loginIniciado);
    _controladorCorreo.addListener(_refrescar);
  }

  @override
  void dispose() {
    _controladorCorreo.removeListener(_refrescar);
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    super.dispose();
  }

  Future<void> _ejecutarLogin() async {
    if (_estadoBoton != EstadoBoton.normal) return;
    setState(() => _mensajeError = null);

    if (!_claveFormulario.currentState!.validate()) {
      _registrar(EventosAnalitica.loginFallido, 'validacion_formulario');
      _claveSacudida.currentState?.sacudir();
      return;
    }

    setState(() => _estadoBoton = EstadoBoton.cargando);

    String? error;
    try {
      error = await widget.servicioAuth.iniciarSesion(
        _controladorCorreo.text,
        _controladorContrasena.text,
      );
    } catch (_) {
      error = 'No se pudo iniciar sesion. Intenta nuevamente.';
    }
    if (error == null) {
      _registrar(EventosAnalitica.loginExitoso);
    } else {
      _registrar(EventosAnalitica.loginFallido, 'servicio_autenticacion');
    }

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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => VistaPrincipal(
          servicioAuth: widget.servicioAuth,
          servicioAnalitica: _analitica,
        ),
      ),
      (ruta) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
                    // Alerta natural si fue redirigido por protección de ruta
                    if (widget.mensajeRedireccion != null) ...[
                      Aparecer(
                        child: CajaMensaje(
                          texto: widget.mensajeRedireccion!,
                          tipo: TipoMensaje.info,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Aparecer(
                      indice: 0,
                      child: Text(
                        'Bienvenido de vuelta',
                        style: TemaApp.titulo(tamano: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Aparecer(
                      indice: 1,
                      child: Text(
                        'Ingresa tus credenciales para acceder a tus partidos.',
                        style: TextStyle(
                          fontSize: 14,
                          color: TemaApp.textoSecundario,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Campo correo (con check en vivo cuando el formato es válido)
                    Aparecer(
                      indice: 2,
                      child: TextFormField(
                        key: const Key('login_correo'),
                        controller: _controladorCorreo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'ejemplo@unisport.edu',
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
                            return 'Ingresa tu correo institucional';
                          }
                          if (!valor.contains('@')) {
                            return 'Formato de correo no válido';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Campo contraseña (pelotitas animadas)
                    Aparecer(
                      indice: 3,
                      child: CampoClave(
                        key: const Key('login_clave'),
                        controller: _controladorContrasena,
                        etiqueta: 'Contraseña',
                        onSubmitted: _ejecutarLogin,
                        validator: (valor) {
                          if (valor == null || valor.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          if (valor.length < 6) {
                            return 'La contraseña debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.standard,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VistaRecuperarClave(
                                servicioAuth: widget.servicioAuth,
                                servicioAnalitica: _analitica,
                              ),
                            ),
                          );
                        },
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),

                    if (_mensajeError != null) ...[
                      const SizedBox(height: 8),
                      CajaMensaje(texto: _mensajeError!),
                    ],

                    const SizedBox(height: 24),

                    Aparecer(
                      indice: 4,
                      child: BotonAccion(
                        key: const Key('login_enviar'),
                        texto: 'Entrar a UniSport',
                        estado: _estadoBoton,
                        onPressed: _ejecutarLogin,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Aparecer(
                      indice: 5,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            '¿Aún no tienes cuenta? ',
                            style: TextStyle(color: TemaApp.textoSecundario),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.standard,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VistaRegistro(
                                    servicioAuth: widget.servicioAuth,
                                    servicioAnalitica: _analitica,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Regístrate aquí',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: TemaApp.verdeOscuro,
                              ),
                            ),
                          ),
                        ],
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
