import 'package:unisport/modelos/modelo_usuario.dart';
import 'package:unisport/servicios/autenticacion/servicio_autenticacion.dart';

import 'repositorio_en_memoria.dart';

/// Autenticación en memoria para las pruebas (sin Supabase ni internet).
/// Trae las mismas cuentas de prueba del README.
class ServicioAutenticacionFalso extends ServicioAutenticacion {
  final RepositorioEnMemoria repositorio;
  final Map<String, ({String contrasena, ModeloUsuario usuario})> _cuentas = {
    'lorgio@unisport.edu': (
      contrasena: '123456',
      usuario: ModeloUsuario(
        id: 'u-lorgio',
        nombre: 'Lorgio',
        correo: 'lorgio@unisport.edu',
      ),
    ),
    'diego@unisport.edu': (
      contrasena: '123456',
      usuario: ModeloUsuario(
        id: 'u-diego',
        nombre: 'Diego',
        correo: 'diego@unisport.edu',
      ),
    ),
  };

  ModeloUsuario? _usuarioActual;

  ServicioAutenticacionFalso([RepositorioEnMemoria? repositorio])
    : repositorio = repositorio ?? RepositorioEnMemoria();

  @override
  ModeloUsuario? get usuarioActual => _usuarioActual;

  @override
  bool get estaCargando => false;

  @override
  Future<void> inicializar() async {}

  @override
  Future<String?> iniciarSesion(String correo, String contrasena) async {
    final cuenta = _cuentas[correo.trim().toLowerCase()];
    if (cuenta == null || cuenta.contrasena != contrasena.trim()) {
      return 'Correo o contraseña incorrectos. Verifica tus credenciales.';
    }
    _usuarioActual = cuenta.usuario;
    repositorio.usarSesionDe(cuenta.usuario.id, cuenta.usuario.nombre);
    notifyListeners();
    return null;
  }

  @override
  Future<String?> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String carrera,
    required String deporteFavorito,
  }) async {
    final clave = correo.trim().toLowerCase();
    if (_cuentas.containsKey(clave)) {
      return 'Este correo ya se encuentra registrado.';
    }
    final usuario = ModeloUsuario(
      id: 'u-${_cuentas.length + 1}',
      nombre: nombre,
      correo: clave,
      carrera: carrera,
      deporteFavorito: deporteFavorito,
    );
    _cuentas[clave] = (contrasena: contrasena, usuario: usuario);
    return iniciarSesion(clave, contrasena);
  }

  @override
  Future<String?> recuperarContrasena(String correo) async => null;

  @override
  Future<Map<String, dynamic>> obtenerMisDatos() async {
    final usuario = _usuarioActual;
    if (usuario == null) throw StateError('Debes iniciar sesión.');
    return {
      'perfil': {
        'id': usuario.id,
        'nombre': usuario.nombre,
        'correo': usuario.correo,
        'carrera': usuario.carrera,
        'deporte_favorito': usuario.deporteFavorito,
      },
      'partidos_organizados': [],
      'inscripciones': [],
      'lista_de_espera': [],
      'bajas_tardias': [],
      'acciones_en_resultados': [],
    };
  }

  @override
  Future<String?> actualizarPerfil({
    required String nombre,
    required String carrera,
    required String deporteFavorito,
  }) async {
    final actual = _usuarioActual;
    if (actual == null) return 'Debes iniciar sesión para editar tu perfil.';
    final actualizado = actual.copiarCon(
      nombre: nombre.trim(),
      carrera: carrera.trim(),
      deporteFavorito: deporteFavorito,
    );
    final clave = actual.correo.toLowerCase();
    final cuenta = _cuentas[clave]!;
    _cuentas[clave] = (contrasena: cuenta.contrasena, usuario: actualizado);
    _usuarioActual = actualizado;
    notifyListeners();
    return null;
  }

  @override
  Future<String?> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final actual = _usuarioActual;
    if (actual == null) {
      return 'Debes iniciar sesión para cambiar tu contraseña.';
    }
    final clave = actual.correo.toLowerCase();
    final cuenta = _cuentas[clave]!;
    if (cuenta.contrasena != contrasenaActual) {
      return 'La contraseña actual es incorrecta.';
    }
    _cuentas[clave] = (contrasena: contrasenaNueva, usuario: cuenta.usuario);
    return null;
  }

  @override
  Future<String?> guardarContrasenaRecuperada(String contrasenaNueva) async {
    final actual = _usuarioActual;
    if (actual == null) {
      return 'El enlace de recuperación no es válido o ya venció.';
    }
    final clave = actual.correo.toLowerCase();
    _cuentas[clave] = (
      contrasena: contrasenaNueva,
      usuario: _cuentas[clave]!.usuario,
    );
    return null;
  }

  @override
  void finalizarRecuperacionContrasena() {}

  @override
  Future<String?> eliminarCuenta({String? intentoId}) async {
    final usuario = _usuarioActual;
    if (usuario == null) return 'Debes iniciar sesión.';
    _cuentas.remove(usuario.correo.toLowerCase());
    await cerrarSesion();
    return null;
  }

  @override
  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    notifyListeners();
  }
}
