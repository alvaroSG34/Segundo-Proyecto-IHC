import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/partidos/repositorio_partidos.dart';
import '../../servicios/partidos/repositorio_partidos_supabase.dart';
import '../../servicios/partidos/controlador_explorar.dart';
import '../../tema/tema_app.dart';
import '../partidos/vista_crear_partido.dart';
import '../partidos/vista_explorar_partidos.dart';
import '../partidos/vista_historial.dart';
import 'vista_inicio_publico.dart';
import '../partidos/vista_mis_partidos.dart';

class VistaPrincipal extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final RepositorioPartidos? repositorioPartidos;

  const VistaPrincipal({
    super.key,
    required this.servicioAuth,
    this.repositorioPartidos,
  });

  @override
  State<VistaPrincipal> createState() => _VistaPrincipalState();
}

class _VistaPrincipalState extends State<VistaPrincipal> {
  late final RepositorioPartidos _repositorio =
      widget.repositorioPartidos ??
      RepositorioPartidosSupabase(Supabase.instance.client);

  // Vive mientras el menú esté abierto y se comparte con sus pantallas.
  final _controladorExplorar = ControladorExplorar();

  Future<void> _crearPartido(BuildContext context) async {
    final creado = await VistaCrearPartido.abrirYGuardar(
      context,
      organizadorNombre: widget.servicioAuth.usuarioActual?.nombre,
      repositorio: _repositorio,
    );
    if (creado == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Partido creado y guardado correctamente.')),
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    try {
      await widget.servicioAuth.cerrarSesion();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => VistaInicioPublico(servicioAuth: widget.servicioAuth),
        ),
        (ruta) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    }
  }

  Widget _boton(
    String texto,
    Color color,
    VoidCallback alPresionar, {
    Color colorTexto = Colors.white,
  }) {
    return ElevatedButton(
      onPressed: alPresionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: colorTexto,
        minimumSize: Size.zero,
        padding: const EdgeInsets.all(12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colorTexto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.servicioAuth.usuarioActual;
    if (usuario == null) {
      return VistaInicioPublico(servicioAuth: widget.servicioAuth);
    }

    return Scaffold(
      backgroundColor: TemaApp.fondo,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0BAA60), Color(0xFF10786F)],
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Text(
                            usuario.nombre.isEmpty
                                ? 'U'
                                : usuario.nombre[0].toUpperCase(),
                            style: const TextStyle(
                              color: TemaApp.verdeOscuro,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                usuario.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${usuario.correo} · ${usuario.carrera}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFE0F2EA),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '● Activo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¿Qué deseas hacer?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: TemaApp.textoPrincipal,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _boton(
                        'Crear\nPartido',
                        const Color(0xFF26C99A),
                        () => _crearPartido(context),
                        colorTexto: const Color(0xFF062D29),
                      ),
                      _boton('Mis\nPartidos', const Color(0xFF0077A8), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VistaMisPartidos(
                              repositorioPartidos: _repositorio,
                              controladorExplorar: _controladorExplorar,
                              servicioAuth: widget.servicioAuth,
                            ),
                          ),
                        );
                      }),
                      _boton('Explorar', const Color(0xFFF59E0B), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VistaExplorarPartidos(
                              repositorioPartidos: _repositorio,
                              controladorExplorar: _controladorExplorar,
                              servicioAuth: widget.servicioAuth,
                            ),
                          ),
                        );
                      }, colorTexto: const Color(0xFF301C00)),
                      _boton('Historial', const Color(0xFF7C3AED), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VistaHistorial(
                              repositorioPartidos: _repositorio,
                              controladorExplorar: _controladorExplorar,
                              servicioAuth: widget.servicioAuth,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _cerrarSesion(context),
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('CERRAR SESIÓN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TemaApp.rojoAlerta,
                        backgroundColor: TemaApp.superficie,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        side: const BorderSide(color: TemaApp.borde),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
