import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';

// La portada ya no ofrece el botón privado: probar el acceso directo a la ruta.
void abrirRutaProtegidaE2E(WidgetTester tester) {
  final portada = find.byType(VistaInicioPublico);
  final auth = tester.widget<VistaInicioPublico>(portada).servicioAuth;
  Navigator.of(tester.element(portada)).push(
    MaterialPageRoute<void>(
      builder: (_) => VistaMisPartidos(
        servicioAuth: auth,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
}

// Un observador separado permite comprobar los tracks incluso tras cerrar sesión.
Future<void> verificarTracksAlTerminar(List<String> inicios) async {
  const correo = String.fromEnvironment(
    'E2E_ORGANIZADOR_CORREO',
    defaultValue: String.fromEnvironment('E2E_CORREO'),
  );
  const clave = String.fromEnvironment(
    'E2E_ORGANIZADOR_CLAVE',
    defaultValue: String.fromEnvironment('E2E_CLAVE'),
  );
  expect(
    correo.isNotEmpty && clave.isNotEmpty,
    isTrue,
    reason: 'Indica E2E_ORGANIZADOR_CORREO y E2E_ORGANIZADOR_CLAVE para consultar la analítica.',
  );
  final cliente = SupabaseClient(
    ConfiguracionSupabase.url,
    ConfiguracionSupabase.clavePublica,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  const limite = Duration(seconds: 45);
  List<dynamic> antes = [];
  addTearDown(() async {
    try {
      final reloj = Stopwatch()..start();
      final comprobados = <String>{};
      do {
        final eventos =
            await cliente.rpc('obtener_eventos_analitica').timeout(limite)
                as List;
        for (final inicio in inicios) {
          final anteriores = {
            for (final e in antes)
              if (e['evento'] == inicio) e['props']['intento_id'],
          };
          final nuevos = {
            for (final e in eventos)
              if (e['evento'] == inicio &&
                  !anteriores.contains(e['props']['intento_id']))
                e['props']['intento_id'],
          };
          final finales = {
            for (final e in eventos)
              if (_finales[inicio]!.contains(e['evento']))
                e['props']['intento_id'],
          };
          if (nuevos.any((id) => id is String && finales.contains(id))) {
            comprobados.add(inicio);
          }
        }
        if (comprobados.length == inicios.length) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } while (reloj.elapsed < limite);
      expect(
        comprobados,
        containsAll(inicios),
        reason: 'Cada acción debe guardar inicio y finalización con el mismo intento_id.',
      );
    } finally {
      try {
        await cliente.auth.signOut().timeout(limite);
      } finally {
        await cliente.dispose();
      }
    }
  });
  await cliente.auth
      .signInWithPassword(email: correo.trim(), password: clave)
      .timeout(limite);
  antes =
      await cliente.rpc('obtener_eventos_analitica').timeout(limite) as List;
}

const _finales = {
  'union_iniciada': ['partido_unido'],
  'creacion_iniciada': ['partido_creado'],
  'busqueda_iniciada': ['busqueda_realizada'],
  'registro_iniciado': ['registro_completado'],
  'login_iniciado': ['login_exitoso'],
  'salida_iniciada': ['salida_completada'],
  'espera_iniciada': ['espera_confirmada'],
  'reprogramacion_iniciada': ['partido_reprogramado'],
  'reconfirmacion_iniciada': [
    'reprogramacion_aceptada',
    'reprogramacion_rechazada',
  ],
  'respuesta_propuesta_iniciada': ['propuesta_aceptada', 'propuesta_rechazada'],
  'validacion_resultado_iniciada': [
    'resultado_confirmado',
    'resultado_disputado',
  ],
  'edicion_iniciada': ['partido_editado'],
  'eliminacion_iniciada': ['partido_eliminado'],
  'recuperacion_iniciada': ['recuperacion_solicitada'],
};
