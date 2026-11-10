import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'apoyo/resultado_partido_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Resultado E2E: proponer, aceptar, registrar, disputar, corregir, confirmar y recargar',
    (tester) async {
      validarCredencialesE2E();
      final cliente = await inicializarSupabaseE2E();
      final partido = await prepararPartidoResultado(
        cliente,
        'flujo',
        equiposAceptados: false,
      );
      addTearDown(() => limpiarPartidoResultado(cliente, partido));

      await iniciarAplicacionSinSesion(tester, cliente);

      debugPrint('Resultado E2E · 1/7: el organizador propone los equipos');
      await iniciarSesionUI(tester, organizadorCorreo, organizadorClave);
      await abrirPartidoUI(tester, partido, proponerEquipos: true);
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(ValueKey('equipo_${partido.organizadorId}')),
            )
            .onChanged,
        isNull,
        reason: 'El organizador conserva su lugar en el Equipo A.',
      );
      await tocar(tester, find.byKey(ValueKey('equipo_${partido.capitanId}')));
      await tocar(tester, find.text('Equipo B').last);
      final selectorCapitan = find.byType(DropdownButtonFormField<String>);
      final opcionCapitan = tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: selectorCapitan,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .single;
      final nombreCapitan = (opcionCapitan.child as Text).data!;
      await tocar(tester, selectorCapitan);
      await tocar(tester, find.text(nombreCapitan).last);
      await tocar(tester, find.text('Enviar propuesta'));
      await esperar(tester, find.text('Propuesta: Pendiente'));
      expect(find.text('Aceptar'), findsNothing);
      expect(find.text('Registrar marcador'), findsNothing);

      debugPrint('Resultado E2E · 2/7: el capitán rival acepta los equipos');
      await cambiarSesionUI(tester, capitanCorreo, capitanClave);
      await abrirPartidoUI(tester, partido);
      await esperar(tester, find.text('Aceptar'));
      expect(find.text('Rechazar'), findsOneWidget);
      expect(find.text('Editar propuesta'), findsNothing);
      await tocar(tester, find.text('Aceptar'));
      await esperar(tester, find.text('Propuesta: Aceptada'));
      expect(find.text('Aceptar'), findsNothing);

      debugPrint('Resultado E2E · 3/7: el organizador registra el marcador');
      await cambiarSesionUI(tester, organizadorCorreo, organizadorClave);
      await abrirPartidoUI(tester, partido);
      await esperarPartidoTerminado(tester, partido);
      await recargarPartidoUI(tester, partido);
      await escribir(
        tester,
        find.byKey(const ValueKey('marcador_equipo_a')),
        '2',
      );
      await escribir(
        tester,
        find.byKey(const ValueKey('marcador_equipo_b')),
        '1',
      );
      await tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Registrar marcador'),
      );
      await esperar(tester, find.text('Estado: Pendiente de confirmación'));
      expect(find.text('Este resultado aún no es definitivo.'), findsOneWidget);

      debugPrint('Resultado E2E · 4/7: el capitán disputa con un motivo');
      await cambiarSesionUI(tester, capitanCorreo, capitanClave);
      await abrirPartidoUI(tester, partido);
      await tocar(tester, find.text('Disputar resultado'));
      await esperar(tester, find.text('Disputar marcador'));
      await escribir(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'El segundo gol no fue válido.',
      );
      await tocar(tester, find.text('Enviar disputa'));
      await esperar(tester, find.text('Estado: Disputado'));
      expect(
        find.text('Motivo de la disputa: El segundo gol no fue válido.'),
        findsOneWidget,
      );

      debugPrint('Resultado E2E · 5/7: el organizador corrige el marcador');
      await cambiarSesionUI(tester, organizadorCorreo, organizadorClave);
      await abrirPartidoUI(tester, partido);
      await esperar(tester, find.text('Corregir marcador'));
      await escribir(
        tester,
        find.byKey(const ValueKey('marcador_equipo_a')),
        '1',
      );
      await escribir(
        tester,
        find.byKey(const ValueKey('marcador_equipo_b')),
        '1',
      );
      await tocar(tester, find.text('Enviar corrección'));
      await esperar(tester, find.text('Estado: Pendiente de confirmación'));
      expect(find.text('Equipo A 1 - 1 Equipo B'), findsOneWidget);

      debugPrint('Resultado E2E · 6/7: el capitán confirma la corrección');
      await cambiarSesionUI(tester, capitanCorreo, capitanClave);
      await abrirPartidoUI(tester, partido);
      await tocar(tester, find.text('Confirmar resultado'));
      await esperar(tester, find.text('Estado: Confirmado'));
      expect(find.textContaining('Resultado definitivo'), findsOneWidget);

      debugPrint('Resultado E2E · 7/7: recarga e historial persistido');
      await recargarPartidoUI(tester, partido);
      expect(find.text('Estado: Confirmado'), findsOneWidget);
      expect(find.text('Marcador registrado'), findsOneWidget);
      expect(find.text('Marcador disputado'), findsOneWidget);
      expect(find.text('Marcador corregido'), findsOneWidget);
      expect(find.text('Resultado confirmado'), findsOneWidget);
      expect(find.text('Equipo A 1 - 1 Equipo B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
