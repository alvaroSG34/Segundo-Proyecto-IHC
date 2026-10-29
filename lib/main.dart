import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/configuracion_supabase.dart';
import 'servicios/servicio_autenticacion.dart';
import 'tema/tema_app.dart';
import 'vistas/vista_inicio_publico.dart';
import 'vistas/vista_principal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!ConfiguracionSupabase.estaConfigurada) {
    runApp(const _FaltaConfiguracion());
    return;
  }

  // Conexión con la base de datos compartida (Supabase)
  await Supabase.initialize(
    url: ConfiguracionSupabase.url,
    publishableKey: ConfiguracionSupabase.clavePublica,
  );

  // Recuperar la sesión guardada en el dispositivo, si existe
  final servicioAuth = ServicioAutenticacionSupabase(Supabase.instance.client);
  await servicioAuth.inicializar();

  runApp(UniSportApp(servicioAuth: servicioAuth));
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
              // Si había una sesión guardada, mostrar el menú principal
              : (servicioAuth.estaAutenticado
                    ? VistaPrincipal(servicioAuth: servicioAuth)
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
