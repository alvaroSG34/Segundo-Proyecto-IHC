import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/autenticacion/servicio_autenticacion.dart';

/// Prueba de integración contra la base de datos REAL de Supabase:
/// dos estudiantes en "dispositivos" distintos (dos clientes) comparten datos.
///
/// No corre con `flutter test` normal. Para ejecutarla (requiere internet y el
/// esquema supabase/esquema.sql aplicado):
///
///   flutter test test/supabase_integracion_test.dart --dart-define=PRUEBAS_SUPABASE=true
///
/// Crea dos cuentas de prueba nuevas en cada ejecución (prueba-...@unisport.edu).
const bool activada = bool.fromEnvironment('PRUEBAS_SUPABASE');

void main() {
  final motivoOmitida = !activada
      ? 'Se ejecuta con --dart-define=PRUEBAS_SUPABASE=true'
      : !ConfiguracionSupabase.estaConfigurada
      ? 'Falta la URL o la clave en lib/config/configuracion_supabase.dart'
      : null;

  test(
    'dos dispositivos comparten partidos y la regla de unión se aplica en el servidor',
    () async {
      SupabaseClient nuevoCliente() => SupabaseClient(
        ConfiguracionSupabase.url,
        ConfiguracionSupabase.clavePublica,
        // Cliente aparte (como otro teléfono) sin almacenamiento persistente
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final marca = DateTime.now().millisecondsSinceEpoch;

      // Dispositivo 1: organizador
      final organizador = ServicioAutenticacionSupabase(nuevoCliente());
      expect(
        await organizador.registrarUsuario(
          nombre: 'Organizador $marca',
          correo: 'prueba-$marca-org@unisport.edu',
          contrasena: '123456',
          carrera: 'Sistemas',
          deporteFavorito: 'Futsal',
        ),
        isNull,
        reason: 'En Supabase: Authentication > Sign In / Providers > Email, '
            'desactiva "Confirm email"',
      );

      // Dispositivo 2: jugador
      final jugador = ServicioAutenticacionSupabase(nuevoCliente());
      expect(
        await jugador.registrarUsuario(
          nombre: 'Jugador $marca',
          correo: 'prueba-$marca-jug@unisport.edu',
          contrasena: '123456',
          carrera: 'Sistemas',
          deporteFavorito: 'Futsal',
        ),
        isNull,
      );

      final titulo = 'Prueba integración $marca';
      final creado = await organizador.partidos.crearPartido(
        ModeloPartido(
          id: '',
          titulo: titulo,
          disciplina: 'Futsal',
          icono: 'Futsal',
          ubicacion: 'Coliseo Campus',
          fechaHora: '10/10/2099 · 19:00',
          cuposTotales: 2,
          cuposOcupados: 1,
          organizadorNombre: 'Organizador $marca',
        ),
      );

      try {
        // El jugador lo encuentra desde su dispositivo con la búsqueda
        final encontrados = await jugador.partidos.buscarPartidos(
          FiltroPartidos(texto: titulo, soloConCupos: true),
        );
        expect(encontrados.single.id, creado.id);
        expect(encontrados.single.puedeUnirse, isTrue);

        // Se une: ocupa el último cupo y el servidor completa el equipo
        final unido = await jugador.partidos.unirseAPartido(creado.id);
        expect(unido.cuposOcupados, 2);
        expect(unido.estado, EstadoPartido.equipoCompleto);

        // El servidor rechaza unirse dos veces
        await expectLater(
          jugador.partidos.unirseAPartido(creado.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'motivo',
              'Ya formas parte de este equipo.',
            ),
          ),
        );

        // El organizador ve, desde su dispositivo, quién se unió
        final inscritos = await organizador.partidos
            .obtenerJugadoresInscritos();
        expect(inscritos[creado.id], ['Jugador $marca']);

        // RLS: el jugador no puede eliminar un partido ajeno
        await jugador.partidos.eliminarPartido(creado.id);
        expect(
          (await organizador.partidos.obtenerMisPartidos()).map((p) => p.id),
          contains(creado.id),
        );
      } finally {
        await organizador.partidos.eliminarPartido(creado.id);
        await organizador.cerrarSesion();
        await jugador.cerrarSesion();
      }
    },
    skip: motivoOmitida,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
