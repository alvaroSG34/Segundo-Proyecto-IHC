import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/propuesta_equipos.dart';
import 'package:unisport/servicios/autenticacion/servicio_autenticacion.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';

// Ejecutar con:
// flutter test test/eliminar_cuenta_supabase_test.dart --dart-define=PRUEBAS_SUPABASE=true
void main() {
  const activada = bool.fromEnvironment('PRUEBAS_SUPABASE');
  final omitir = !activada || !ConfiguracionSupabase.estaConfigurada;

  test(
    'eliminar cuentas promueve al suplente y cancela el partido',
    () async {
      SupabaseClient clienteNuevo() => SupabaseClient(
        ConfiguracionSupabase.url,
        ConfiguracionSupabase.clavePublica,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );

      final marca = DateTime.now().microsecondsSinceEpoch;
      final clientes = [clienteNuevo(), clienteNuevo(), clienteNuevo()];
      final servicios = clientes
          .map(ServicioAutenticacionSupabase.new)
          .toList();
      final repositorios = clientes
          .map(RepositorioPartidosSupabase.new)
          .toList();
      final correos = [
        'org',
        'jug',
        'sup',
      ].map((rol) => 'eliminar-$marca-$rol@unisport.edu').toList();
      const clave = 'Prueba123456!';

      try {
        for (var i = 0; i < servicios.length; i++) {
          final error = await servicios[i].registrarUsuario(
            nombre: [
              'Organizador prueba',
              'Jugador prueba',
              'Suplente prueba',
            ][i],
            correo: correos[i],
            contrasena: clave,
            carrera: 'Sistemas',
            deporteFavorito: 'Futsal',
          );
          expect(
            error,
            isNull,
            reason: 'No se pudo crear la cuenta de prueba $i',
          );
        }

        final suplenteId = clientes[2].auth.currentUser!.id;
        final partido = await repositorios[0].crearPartido(
          ModeloPartido(
            id: '',
            titulo: 'Eliminar cuenta $marca',
            disciplina: 'Futsal',
            icono: 'Futsal',
            ubicacion: 'Cancha de prueba',
            fechaHora: '10/10/2099 · 19:00',
            cuposTotales: 2,
            cuposOcupados: 1,
            organizadorNombre: 'Organizador prueba',
          ),
        );
        await repositorios[1].unirseAPartido(partido.id);
        await expectLater(
          repositorios[1].unirseAPartido(partido.id),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'mensaje',
              'Ya formas parte de este equipo.',
            ),
          ),
        );
        await repositorios[2].entrarEnEspera(partido.id);

        final intento = crearIntentoId();
        await ServicioAnaliticaSupabase(clientes[1]).track(
          EventosAnalitica.cuentaEliminacionIniciada,
          {'intento_id': intento},
        );
        expect(await servicios[1].eliminarCuenta(intentoId: intento), isNull);
        final eventos = await ServicioAnaliticaSupabase(clientes[0])
            .obtenerEventos();
        final eventosDelIntento = eventos
            .where((e) => e.props['intento_id'] == intento)
            .toList();
        expect(
          eventosDelIntento.map((e) => e.evento),
          containsAll([
            EventosAnalitica.cuentaEliminacionIniciada,
            EventosAnalitica.cuentaEliminacionCompletada,
          ]),
        );
        for (final evento in eventosDelIntento) {
          expect(evento.props.keys, ['intento_id']);
        }

        expect(servicios[1].estaAutenticado, isFalse);
        expect(await servicios[1].iniciarSesion(correos[1], clave), isNotNull);
        final inscritos = await clientes[0]
            .from('inscripciones')
            .select('jugador_id')
            .eq('partido_id', partido.id);
        expect(inscritos, hasLength(1));
        expect(inscritos.single['jugador_id'], suplenteId);
        final actualizado = await clientes[0]
            .from('partidos')
            .select('cupos_ocupados')
            .eq('id', partido.id)
            .single();
        expect(actualizado['cupos_ocupados'], 2);

        expect(await servicios[0].eliminarCuenta(), isNull);
        expect(await servicios[0].iniciarSesion(correos[0], clave), isNotNull);
        final partidos = await clientes[2]
            .from('partidos')
            .select('id')
            .eq('id', partido.id);
        expect(partidos, isEmpty);
      } finally {
        // Solo se eliminan las cuentas creadas por esta ejecución.
        for (final servicio in servicios) {
          if (servicio.estaAutenticado) {
            final error = await servicio.eliminarCuenta();
            if (error != null) {
              // Informar si una cuenta de prueba requiere limpieza manual.
              // ignore: avoid_print
              print('No se pudo eliminar una cuenta de prueba: $error');
            }
          }
          servicio.dispose();
        }
        for (final cliente in clientes) {
          await cliente.dispose();
        }
      }
    },
    skip: omitir
        ? 'Requiere PRUEBAS_SUPABASE=true y configuración de Supabase'
        : null,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'conserva un resultado confirmado al eliminar al capitán',
    () async {
      SupabaseClient clienteNuevo() => SupabaseClient(
        ConfiguracionSupabase.url,
        ConfiguracionSupabase.clavePublica,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final clientes = [clienteNuevo(), clienteNuevo()];
      final auth = clientes.map(ServicioAutenticacionSupabase.new).toList();
      final repos = clientes.map(RepositorioPartidosSupabase.new).toList();
      final marca = DateTime.now().microsecondsSinceEpoch;
      const clave = 'Prueba123456!';
      String? partidoId;
      try {
        for (var i = 0; i < auth.length; i++) {
          expect(
            await auth[i].registrarUsuario(
              nombre: i == 0 ? 'Organizador de prueba' : 'Capitán de prueba',
              correo: 'resultado-$marca-$i@unisport.edu',
              contrasena: clave,
              carrera: 'Sistemas',
              deporteFavorito: 'Futsal',
            ),
            isNull,
          );
        }
        final organizadorId = clientes[0].auth.currentUser!.id;
        final capitanId = clientes[1].auth.currentUser!.id;
        final fecha = DateTime.now().toUtc().add(const Duration(seconds: 45));
        final partido = await clientes[0]
            .from('partidos')
            .insert({
              'organizador_id': organizadorId,
              'organizador_nombre': 'Organizador de prueba',
              'titulo': 'Resultado de prueba $marca',
              'disciplina': 'Futsal',
              'ubicacion': 'Cancha de prueba',
              'fecha_inicio': fecha.toIso8601String(),
              'cupos_totales': 2,
              'cupos_ocupados': 1,
              'estado': 'cuposAbiertos',
            })
            .select('id')
            .single();
        partidoId = partido['id'] as String;
        await repos[1].unirseAPartido(partidoId);
        await repos[0].guardarPropuesta(
          partidoId,
          PropuestaEquipos(
            revision: '',
            equipoA: [organizadorId],
            equipoB: [capitanId],
            capitanRivalId: capitanId,
          ),
        );
        final propuesta = (await repos[1].obtenerPropuesta(partidoId))!;
        await repos[1].responderPropuesta(partidoId, propuesta.revision, true);

        // Las reglas solo permiten registrar resultados cuando ya comenzó.
        final espera =
            fecha.difference(DateTime.now().toUtc()) +
            const Duration(seconds: 3);
        if (espera > Duration.zero) await Future<void>.delayed(espera);
        await repos[0].registrarResultado(partidoId, 2, 1);
        final pendiente = (await repos[1].obtenerResultado(partidoId))!;
        await repos[1].confirmarResultado(partidoId, pendiente.revision);
        expect(await auth[1].eliminarCuenta(), isNull);
        expect(
          await auth[1].iniciarSesion('resultado-$marca-1@unisport.edu', clave),
          isNotNull,
        );
        final resultado = (await repos[0].obtenerResultado(partidoId))!;
        expect(resultado.esDefinitivo, isTrue);
        expect(resultado.marcador, '2 - 1');
        final reparto = await clientes[0]
            .from('propuestas_equipos')
            .select('capitan_rival_id, equipo_a, equipo_b')
            .eq('partido_id', partidoId)
            .single();
        expect(reparto['capitan_rival_id'], isNull);
        expect(reparto['equipo_b'], isNot(contains(capitanId)));
        final historial = await clientes[0]
            .from('historial_resultados')
            .select('actor_id, actor_nombre')
            .eq('partido_id', partidoId);
        expect(historial.any((fila) => fila['actor_id'] == capitanId), isFalse);
        expect(
          historial.any((fila) => fila['actor_nombre'] == 'Capitán de prueba'),
          isFalse,
        );
      } finally {
        // El organizador conserva permiso para limpiar este partido de prueba.
        if (partidoId != null && auth[0].estaAutenticado) {
          try {
            await repos[0].eliminarPartido(partidoId);
          } catch (error) {
            // ignore: avoid_print
            print('No se pudo limpiar el partido de prueba $partidoId: $error');
          }
        }
        for (final servicio in auth) {
          if (servicio.estaAutenticado) {
            final error = await servicio.eliminarCuenta();
            if (error != null) {
              // ignore: avoid_print
              print('No se pudo eliminar una cuenta de prueba: $error');
            }
          }
          servicio.dispose();
        }
        for (final cliente in clientes) {
          await cliente.dispose();
        }
      }
    },
    skip: omitir
        ? 'Requiere PRUEBAS_SUPABASE=true y configuración de Supabase'
        : null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
