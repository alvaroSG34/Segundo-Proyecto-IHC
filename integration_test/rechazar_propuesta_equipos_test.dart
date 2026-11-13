import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'apoyo/analitica_e2e.dart';
import 'apoyo/resultado_partido_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Rechazar propuesta: capitán autorizado, persistencia y vista del organizador',
    (tester) async {
      validarCredencialesE2E();
      await verificarTracksAlTerminar(['respuesta_propuesta_iniciada']);
      final cliente = await inicializarSupabaseE2E();
      final partido = await prepararPartidoResultado(
        cliente,
        'rechazo-propuesta',
        equiposAceptados: false,
      );
      addTearDown(() => limpiarPartidoResultado(cliente, partido));

      await iniciarAplicacionSinSesion(tester, cliente);
      await iniciarSesionUI(tester, organizadorCorreo, organizadorClave);
      await abrirPartidoUI(tester, partido, proponerEquipos: true);

      // La propuesta se envía desde la interfaz, con el jugador en B y
      // designado como capitán rival (único autorizado para responder).
      await tocar(tester, find.byKey(ValueKey('equipo_${partido.capitanId}')));
      await tocar(tester, find.text('Equipo B').last);
      final selectorCapitan = find.byType(DropdownButtonFormField<String>);
      final opcion = tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: selectorCapitan,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .single;
      await tocar(tester, selectorCapitan);
      await tocar(tester, find.text((opcion.child as Text).data!).last);
      await tocar(tester, find.text('Enviar propuesta'));
      await esperar(tester, find.text('Propuesta: Pendiente'));
      expect(find.text('Aceptar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);

      final pendiente = await cliente
          .from('propuestas_equipos')
          .select('revision, estado, equipo_a, equipo_b, capitan_rival_id')
          .eq('partido_id', partido.id)
          .single()
          .timeout(limite);
      expect(pendiente['estado'], 'pendiente');
      expect(pendiente['capitan_rival_id'], partido.capitanId);

      await cambiarSesionUI(tester, capitanCorreo, capitanClave);
      await abrirPartidoUI(tester, partido);
      await esperar(tester, find.text('Propuesta: Pendiente'));
      await esperar(tester, find.text('Rechazar'));
      expect(cliente.auth.currentUser!.id, partido.capitanId);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Editar propuesta'), findsNothing);
      await tocar(tester, find.text('Rechazar'));
      await esperar(tester, find.text('Propuesta: Rechazada'));
      _comprobarRechazo();

      // Comprueba el dato real: la respuesta cambia el estado de la misma
      // revisión, sin alterar el reparto ni crear otra propuesta.
      final rechazada = await cliente
          .from('propuestas_equipos')
          .select('revision, estado, equipo_a, equipo_b, capitan_rival_id')
          .eq('partido_id', partido.id)
          .single()
          .timeout(limite);
      expect(rechazada, {...pendiente, 'estado': 'rechazada'});

      await recargarPartidoUI(tester, partido);
      await esperar(tester, find.text('Propuesta: Rechazada'));
      _comprobarRechazo();
      expect(find.text('Editar propuesta'), findsNothing);

      // Otra sesión debe observar el rechazo persistido y permitir al
      // organizador preparar una nueva propuesta.
      await cambiarSesionUI(tester, organizadorCorreo, organizadorClave);
      await abrirPartidoUI(tester, partido);
      await esperar(tester, find.text('Propuesta: Rechazada'));
      _comprobarRechazo();
      expect(find.text('Editar propuesta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

void _comprobarRechazo() {
  expect(find.text('Propuesta: Rechazada'), findsOneWidget);
  expect(find.text('Aceptar'), findsNothing);
  expect(find.text('Rechazar'), findsNothing);
  expect(find.text('Registrar marcador'), findsNothing);
}
