import 'package:unisport/modelos/modelo_usuario.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos.dart';
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
  RepositorioPartidos get partidos => repositorio;

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
  Future<void> cerrarSesion() async {
    _usuarioActual = null;
    notifyListeners();
  }
}
