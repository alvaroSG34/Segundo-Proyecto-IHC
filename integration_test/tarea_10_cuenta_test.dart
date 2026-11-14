import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/autenticacion/servicio_autenticacion.dart';
import 'package:unisport/vistas/autenticacion/vista_perfil.dart';

class _AnaliticaPrueba implements ServicioAnalitica {
  final ServicioAnalitica servicio;
  String? intentoId;
  _AnaliticaPrueba(this.servicio);

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    if (evento == EventosAnalitica.cuentaEliminacionIniciada) {
      intentoId = props['intento_id'] as String?;
    }
    await servicio.track(evento, props);
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() => servicio.obtenerEventos();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const activada = bool.fromEnvironment('PRUEBAS_SUPABASE');
  testWidgets('descargar datos y eliminar cuenta con eventos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SupabaseClient clienteNuevo() => SupabaseClient(
      ConfiguracionSupabase.url,
      ConfiguracionSupabase.clavePublica,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final clientes = [clienteNuevo(), clienteNuevo()];
    final servicios = clientes.map(ServicioAutenticacionSupabase.new).toList();
    final marca = DateTime.now().microsecondsSinceEpoch;
    final correo = 'e2e-cuenta-$marca@unisport.edu';
    const clave = 'Prueba123456!';
    Future<void> esperar(Finder finder) async {
      for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(finder, findsOneWidget);
    }

    Uint8List? archivo;
    final analitica = _AnaliticaPrueba(ServicioAnaliticaSupabase(clientes[0]));
    try {
      for (var i = 0; i < servicios.length; i++) {
        final error = await servicios[i].registrarUsuario(
          nombre: 'Usuario de prueba',
          correo: i == 0 ? correo : 'e2e-observador-$marca@unisport.edu',
          contrasena: clave,
          carrera: 'Sistemas',
          deporteFavorito: 'Futsal',
        );
        expect(error, isNull);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: VistaPerfil(
            servicioAuth: servicios[0],
            servicioAnalitica: analitica,
            guardarArchivo: (bytes) async {
              archivo = bytes;
              return 'datos.json';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final verDatos = find.byKey(const Key('ver_mis_datos'));
      await tester.ensureVisible(verDatos);
      await tester.tap(verDatos);
      await esperar(find.byKey(const Key('descargar_mis_datos')));
      await tester.tap(find.byKey(const Key('descargar_mis_datos')));
      await tester.pumpAndSettle();
      expect(jsonDecode(utf8.decode(archivo!))['perfil']['correo'], correo);
      for (
        var i = 0;
        i < 40 && find.byType(AlertDialog).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(AlertDialog), findsNothing);

      final eliminar = find.byKey(const Key('eliminar_cuenta'));
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(eliminar);
      await tester.pumpAndSettle();
      await tester.tap(eliminar);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Esta acción no se puede deshacer'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirmar_eliminar_cuenta')));
      for (var i = 0; i < 80 && servicios[0].estaAutenticado; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(servicios[0].estaAutenticado, isFalse);
      expect(await servicios[0].iniciarSesion(correo, clave), isNotNull);
      final eventos = await ServicioAnaliticaSupabase(clientes[1])
          .obtenerEventos();
      final intento = analitica.intentoId;
      expect(intento, isNotNull);
      final propios = eventos
          .where((e) => e.props['intento_id'] == intento)
          .toList();
      expect(
        propios.map((e) => e.evento),
        containsAll([
          EventosAnalitica.cuentaEliminacionIniciada,
          EventosAnalitica.cuentaEliminacionCompletada,
        ]),
      );
      for (final evento in propios) {
        expect(evento.props.keys, ['intento_id']);
      }
    } finally {
      for (final servicio in servicios) {
        if (servicio.estaAutenticado) {
          final error = await servicio.eliminarCuenta();
          if (error != null) {
            debugPrint('No se pudo limpiar cuenta de prueba: $error');
          }
        }
        servicio.dispose();
      }
      for (final cliente in clientes) {
        await cliente.dispose();
      }
    }
  }, skip: !activada || !ConfiguracionSupabase.estaConfigurada);
}
