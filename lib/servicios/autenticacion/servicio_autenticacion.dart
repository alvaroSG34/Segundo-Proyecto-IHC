import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/modelo_usuario.dart';

/// Sesión y autenticación del estudiante.
///
/// Las pantallas dependen de este contrato de autenticación. La implementación
/// real usa Supabase Auth; las pruebas usan una versión en memoria.
abstract class ServicioAutenticacion extends ChangeNotifier {
  ModeloUsuario? get usuarioActual;
  bool get estaAutenticado => usuarioActual != null;
  bool get estaCargando;
  bool get estaRecuperandoContrasena => false;

  /// Recupera la sesión guardada (si el usuario no la cerró).
  Future<void> inicializar();

  /// Devuelve null si inició sesión, o el mensaje de error.
  Future<String?> iniciarSesion(String correo, String contrasena);

  /// Devuelve null si se registró e inició sesión, o el mensaje de error.
  Future<String?> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String carrera,
    required String deporteFavorito,
  });

  /// Devuelve null si se envió el correo de recuperación, o el error.
  Future<String?> recuperarContrasena(String correo);

  /// Actualiza los datos públicos de la cuenta con sesión iniciada.
  Future<String?> actualizarPerfil({
    required String nombre,
    required String carrera,
    required String deporteFavorito,
  });

  /// Cambia la contraseña después de verificar la contraseña actual.
  Future<String?> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  });

  /// Guarda una contraseña cuando la sesión proviene del enlace de recuperación.
  Future<String?> guardarContrasenaRecuperada(String contrasenaNueva);

  /// Cierra el modo de recuperación después de guardar la nueva contraseña.
  void finalizarRecuperacionContrasena();

  Future<void> cerrarSesion();
}

/// Autenticación con Supabase Auth: las cuentas viven en el servidor y las
/// contraseñas se guardan cifradas. La sesión la conserva supabase_flutter
/// en el dispositivo, así la app abre directamente en "Mis partidos".
class ServicioAutenticacionSupabase extends ServicioAutenticacion {
  final SupabaseClient _cliente;

  ModeloUsuario? _usuarioActual;
  bool _estaCargando = true;
  bool _estaRecuperandoContrasena = false;
  late final StreamSubscription<AuthState> _cambiosAutenticacion;

  ServicioAutenticacionSupabase(this._cliente) {
    _cambiosAutenticacion = _cliente.auth.onAuthStateChange.listen(
      (estado) async {
        if (estado.event != AuthChangeEvent.passwordRecovery) return;
        _estaRecuperandoContrasena = true;
        final usuario = estado.session?.user ?? _cliente.auth.currentUser;
        if (usuario != null) _usuarioActual = await _cargarPerfil(usuario);
        _estaCargando = false;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('No se pudo procesar el enlace de recuperación: $error');
      },
    );
  }

  @override
  ModeloUsuario? get usuarioActual => _usuarioActual;

  @override
  bool get estaCargando => _estaCargando;

  @override
  bool get estaRecuperandoContrasena => _estaRecuperandoContrasena;

  /// Lee el perfil del usuario con sesión desde la tabla `perfiles`.
  /// Si no se puede leer (por ejemplo, sin internet), usa los datos de la cuenta.
  Future<ModeloUsuario> _cargarPerfil(User usuario) async {
    try {
      final fila = await _cliente
          .from('perfiles')
          .select()
          .eq('id', usuario.id)
          .maybeSingle();
      if (fila != null) return ModeloUsuario.desdePerfil(fila);
    } catch (e) {
      debugPrint('No se pudo leer el perfil: $e');
    }
    final datos = usuario.userMetadata ?? const {};
    return ModeloUsuario(
      id: usuario.id,
      nombre: datos['nombre'] as String? ?? usuario.email ?? 'Estudiante',
      correo: usuario.email ?? '',
      carrera: datos['carrera'] as String? ?? 'Ingeniería',
      deporteFavorito: datos['deporte_favorito'] as String? ?? 'Futsal',
    );
  }

  @override
  Future<void> inicializar() async {
    _estaCargando = true;
    notifyListeners();

    final usuario = _cliente.auth.currentUser;
    _usuarioActual = usuario == null ? null : await _cargarPerfil(usuario);

    _estaCargando = false;
    notifyListeners();
  }

  /// Traduce los errores de Supabase Auth a mensajes para el estudiante.
  String _mensajeDe(Object error) {
    if (error is AuthException) {
      final mensaje = error.message.toLowerCase();
      if (mensaje.contains('invalid login credentials')) {
        return 'Correo o contraseña incorrectos. Verifica tus credenciales.';
      }
      if (mensaje.contains('already registered') ||
          mensaje.contains('already been registered')) {
        return 'Este correo ya se encuentra registrado.';
      }
      if (mensaje.contains('password')) {
        return 'La contraseña debe tener al menos 6 caracteres.';
      }
      if (mensaje.contains('email not confirmed')) {
        return 'Debes confirmar tu correo antes de iniciar sesión.';
      }
      return error.message;
    }
    debugPrint('Error de autenticación: $error');
    return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
  }

  @override
  Future<String?> iniciarSesion(String correo, String contrasena) async {
    try {
      final respuesta = await _cliente.auth.signInWithPassword(
        email: correo.trim().toLowerCase(),
        password: contrasena.trim(),
      );
      final usuario = respuesta.user;
      if (usuario == null) {
        return 'Correo o contraseña incorrectos. Verifica tus credenciales.';
      }
      _usuarioActual = await _cargarPerfil(usuario);
      notifyListeners();
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<String?> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String carrera,
    required String deporteFavorito,
  }) async {
    try {
      // El trigger de la base crea el perfil con estos datos
      final respuesta = await _cliente.auth.signUp(
        email: correo.trim().toLowerCase(),
        password: contrasena.trim(),
        data: {
          'nombre': nombre.trim(),
          'carrera': carrera.trim().isEmpty ? 'Ingeniería' : carrera.trim(),
          'deporte_favorito': deporteFavorito,
        },
      );
      final usuario = respuesta.user;
      if (usuario == null || respuesta.session == null) {
        // El proyecto exige confirmar el correo antes de entrar
        return 'Te enviamos un correo para confirmar la cuenta. '
            'Confírmala y luego inicia sesión.';
      }
      _usuarioActual = await _cargarPerfil(usuario);
      notifyListeners();
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<String?> recuperarContrasena(String correo) async {
    try {
      await _cliente.auth.resetPasswordForEmail(
        correo.trim().toLowerCase(),
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<String?> actualizarPerfil({
    required String nombre,
    required String carrera,
    required String deporteFavorito,
  }) async {
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) return 'Debes iniciar sesión para editar tu perfil.';
    final nombreLimpio = nombre.trim();
    final carreraLimpia = carrera.trim();
    if (nombreLimpio.isEmpty || carreraLimpia.isEmpty) {
      return 'Completa tu nombre y carrera.';
    }
    try {
      await _cliente
          .from('perfiles')
          .update({
            'nombre': nombreLimpio,
            'carrera': carreraLimpia,
            'deporte_favorito': deporteFavorito,
          })
          .eq('id', usuario.id);
      await _cliente.auth.updateUser(
        UserAttributes(
          data: {
            'nombre': nombreLimpio,
            'carrera': carreraLimpia,
            'deporte_favorito': deporteFavorito,
          },
        ),
      );
      _usuarioActual = await _cargarPerfil(
        _cliente.auth.currentUser ?? usuario,
      );
      notifyListeners();
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<String?> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final usuario = _cliente.auth.currentUser;
    final correo = usuario?.email;
    if (usuario == null || correo == null) {
      return 'Debes iniciar sesión para cambiar tu contraseña.';
    }
    try {
      await _cliente.auth.signInWithPassword(
        email: correo,
        password: contrasenaActual,
      );
      await _cliente.auth.updateUser(UserAttributes(password: contrasenaNueva));
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        return 'La contraseña actual es incorrecta.';
      }
      return _mensajeDe(e);
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<String?> guardarContrasenaRecuperada(String contrasenaNueva) async {
    if (!_estaRecuperandoContrasena || _cliente.auth.currentUser == null) {
      return 'El enlace de recuperación no es válido o ya venció.';
    }
    try {
      await _cliente.auth.updateUser(UserAttributes(password: contrasenaNueva));
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  void finalizarRecuperacionContrasena() {
    _estaRecuperandoContrasena = false;
    notifyListeners();
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _cliente.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
    _usuarioActual = null;
    _estaRecuperandoContrasena = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cambiosAutenticacion.cancel();
    super.dispose();
  }
}
