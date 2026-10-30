import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/filtro_partidos.dart';
import '../../modelos/modelo_usuario.dart';
import '../partidos/repositorio_partidos.dart';
import '../partidos/repositorio_partidos_supabase.dart';

/// Sesión del estudiante y acceso a los datos.
///
/// Las pantallas solo conocen esta clase: la implementación real usa Supabase
/// (cuentas y base de datos compartidas entre dispositivos); las pruebas usan
/// una versión en memoria.
abstract class ServicioAutenticacion extends ChangeNotifier {
  ModeloUsuario? get usuarioActual;
  bool get estaAutenticado => usuarioActual != null;
  bool get estaCargando;

  /// Búsqueda y filtros de Explorar: se conservan al salir y volver a la
  /// pantalla durante la sesión (H7). Se reinicia al cerrar sesión.
  FiltroPartidos filtroExplorar = const FiltroPartidos();

  /// Partidos e inscripciones del usuario con sesión.
  RepositorioPartidos get partidos;

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

  Future<void> cerrarSesion();
}

/// Autenticación con Supabase Auth: las cuentas viven en el servidor y las
/// contraseñas se guardan cifradas. La sesión la conserva supabase_flutter
/// en el dispositivo, así la app abre directamente en "Mis partidos".
class ServicioAutenticacionSupabase extends ServicioAutenticacion {
  final SupabaseClient _cliente;
  late final RepositorioPartidos _partidos = RepositorioPartidosSupabase(_cliente);

  ModeloUsuario? _usuarioActual;
  bool _estaCargando = true;

  ServicioAutenticacionSupabase(this._cliente);

  @override
  ModeloUsuario? get usuarioActual => _usuarioActual;

  @override
  bool get estaCargando => _estaCargando;

  @override
  RepositorioPartidos get partidos => _partidos;

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
    return RepositorioPartidosSupabase.mensajeSinConexion;
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
      await _cliente.auth.resetPasswordForEmail(correo.trim().toLowerCase());
      return null;
    } catch (e) {
      return _mensajeDe(e);
    }
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _cliente.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
    _usuarioActual = null;
    filtroExplorar = const FiltroPartidos();
    notifyListeners();
  }
}
