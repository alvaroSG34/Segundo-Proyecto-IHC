import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/configuracion_supabase.dart';
import 'servicios/autenticacion/servicio_autenticacion.dart';
import 'tema/tema_app.dart';
import 'vistas/inicio/vista_inicio_publico.dart';
import 'vistas/inicio/vista_principal_diferida.dart';
import 'vistas/autenticacion/vista_nueva_clave.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapUniSport());
}

class _BootstrapUniSport extends StatefulWidget {
  const _BootstrapUniSport();

  @override
  State<_BootstrapUniSport> createState() => _BootstrapUniSportState();
}

class _BootstrapUniSportState extends State<_BootstrapUniSport> {
  ServicioAutenticacion? _servicioAuth;
  bool _inicioFallido = false;

  @override
  void initState() {
    super.initState();
    unawaited(_inicializar());
  }

  Future<void> _inicializar() async {
    if (!ConfiguracionSupabase.estaConfigurada) return;

    try {
      await Supabase.initialize(
        url: ConfiguracionSupabase.url,
        publishableKey: ConfiguracionSupabase.clavePublica,
      );

      final servicioAuth = ServicioAutenticacionSupabase(
        Supabase.instance.client,
      );
      if (!mounted) return;

      setState(() => _servicioAuth = servicioAuth);
      unawaited(servicioAuth.inicializar());
    } catch (error) {
      debugPrint('No se pudo iniciar UniSport: $error');
      if (mounted) setState(() => _inicioFallido = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ConfiguracionSupabase.estaConfigurada) {
      return const _FaltaConfiguracion();
    }

    final servicioAuth = _servicioAuth;
    if (servicioAuth != null) {
      return UniSportApp(servicioAuth: servicioAuth);
    }

    if (_inicioFallido) {
      return MaterialApp(
        title: 'UniSport - IHC',
        debugShowCheckedModeBanner: false,
        theme: TemaApp.tema,
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se pudo iniciar UniSport. Comprueba tu conexión e inténtalo de nuevo.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'UniSport - IHC',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.tema,
      home: const VistaInicioPublico(estaPreparando: true),
    );
  }
}

class UniSportApp extends StatelessWidget {
  final ServicioAutenticacion servicioAuth;

  const UniSportApp({super.key, required this.servicioAuth});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: servicioAuth,
      builder: (context, _) {
        return MaterialApp(
          // Reiniciar la navegación al entrar o salir de una cuenta.
          key: ValueKey(servicioAuth.usuarioActual?.id),
          title: 'UniSport - IHC',
          debugShowCheckedModeBanner: false,
          theme: TemaApp.tema,
          // Si el servicio está cargando la sesión, mostrar pantalla de carga
          home: servicioAuth.estaCargando
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : servicioAuth.estaRecuperandoContrasena
              ? VistaNuevaClave(servicioAuth: servicioAuth)
              // Si había una sesión guardada, mostrar el menú principal
              : (servicioAuth.estaAutenticado
                    ? VistaPrincipalDiferida(servicioAuth: servicioAuth)
                    : VistaInicioPublico(servicioAuth: servicioAuth)),
        );
      },
    );
  }
}

/// Se muestra si la app se ejecuta sin los datos de conexión a Supabase.
class _FaltaConfiguracion extends StatelessWidget {
  const _FaltaConfiguracion();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: TemaApp.tema,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Falta configurar la conexión a Supabase.\n\n'
              'Escribe la URL y la clave pública (Publishable key) del '
              'proyecto en '
              'lib/config/configuracion_supabase.dart, o ejecuta:\n\n'
              'flutter run --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
