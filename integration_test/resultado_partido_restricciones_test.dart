import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apoyo/resultado_partido_e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Resultado E2E: permisos, duplicados y resultado definitivo', (
    tester,
  ) async {
    validarCredencialesE2E();
    final cliente = await inicializarSupabaseE2E();
    final partido = await prepararPartidoResultado(cliente, 'restricciones');
    addTearDown(() => limpiarPartidoResultado(cliente, partido));

    await iniciarAplicacionSinSesion(tester, cliente);

    debugPrint('Restricciones E2E · 1/4: registro del organizador');
    await iniciarSesionUI(tester, organizadorCorreo, organizadorClave);
    await abrirPartidoUI(tester, partido);
    await esperarPartidoTerminado(tester, partido);
    await escribir(
      tester,
      find.byKey(const ValueKey('marcador_equipo_a')),
      '3',
    );
    await escribir(
      tester,
      find.byKey(const ValueKey('marcador_equipo_b')),
      '0',
    );
      await tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Registrar marcador'),
      );
    await esperar(tester, find.text('Estado: Pendiente de confirmación'));

    final resultadoPendiente = await cliente
        .from('resultados_partido')
        .select('revision')
        .eq('partido_id', partido.id)
        .single()
        .timeout(limite);
    final revision = resultadoPendiente['revision'] as String;

    debugPrint('Restricciones E2E · 2/4: actores incorrectos bloqueados');
    expect(find.text('Confirmar resultado'), findsNothing);
    await expectLater(
      cliente.rpc(
        'confirmar_resultado_partido',
        params: {'p_partido': partido.id, 'p_revision': revision},
      ),
      throwsA(isA<PostgrestException>()),
    );

    await cambiarSesionUI(tester, capitanCorreo, capitanClave);
    await abrirPartidoUI(tester, partido);
    expect(
      find.byKey(const ValueKey('marcador_equipo_a')),
      findsNothing,
      reason: 'El capitán no debe recibir el formulario del organizador.',
    );
    await expectLater(
      cliente.rpc(
        'registrar_resultado_partido',
        params: {'p_partido': partido.id, 'p_marcador_a': 9, 'p_marcador_b': 0},
      ),
      throwsA(isA<PostgrestException>()),
    );

    debugPrint('Restricciones E2E · 3/4: respuesta única del capitán');
    await tocar(tester, find.text('Confirmar resultado'));
    await esperar(tester, find.text('Estado: Confirmado'));
    await expectLater(
      cliente.rpc(
        'confirmar_resultado_partido',
        params: {'p_partido': partido.id, 'p_revision': revision},
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(find.text('Confirmar resultado'), findsNothing);
    expect(find.text('Disputar resultado'), findsNothing);

    debugPrint('Restricciones E2E · 4/4: definitivo después de recargar');
    await cambiarSesionUI(tester, organizadorCorreo, organizadorClave);
    await abrirPartidoUI(tester, partido);
    expect(find.text('Corregir marcador'), findsNothing);
    await expectLater(
      cliente.rpc(
        'registrar_resultado_partido',
        params: {'p_partido': partido.id, 'p_marcador_a': 4, 'p_marcador_b': 0},
      ),
      throwsA(isA<PostgrestException>()),
    );
    await recargarPartidoUI(tester, partido);
    expect(find.text('Estado: Confirmado'), findsOneWidget);
    expect(find.text('Equipo A 3 - 0 Equipo B'), findsOneWidget);
    expect(find.text('Marcador registrado'), findsOneWidget);
    expect(find.text('Resultado confirmado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
