import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/main.dart';
import 'package:unisport/vistas/autenticacion/vista_nueva_clave.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

class _AuthRecuperacion extends ServicioAutenticacionFalso {
  bool recuperando = true;

  @override
  bool get estaRecuperandoContrasena => recuperando;

  @override
  void finalizarRecuperacionContrasena() {
    recuperando = false;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'el enlace permite definir una contraseña sin conocer la actual',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = _AuthRecuperacion();
      expect(await auth.iniciarSesion('diego@unisport.edu', '123456'), isNull);

      await tester.pumpWidget(UniSportApp(servicioAuth: auth));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(VistaNuevaClave), findsOneWidget);
      expect(find.textContaining('No necesitas recordar'), findsOneWidget);

      await _escribir(tester, 'recuperacion_clave_nueva', 'recuperada789');
      await _escribir(tester, 'recuperacion_clave_confirmar', 'recuperada789');
      await tester.tap(find.byKey(const Key('recuperacion_guardar_clave')));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Contraseña actualizada'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recuperacion_continuar')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(VistaPrincipal), findsOneWidget);

      await auth.cerrarSesion();
      expect(
        await auth.iniciarSesion('diego@unisport.edu', '123456'),
        isNotNull,
      );
      expect(
        await auth.iniciarSesion('diego@unisport.edu', 'recuperada789'),
        isNull,
      );
    },
  );
}

Future<void> _escribir(WidgetTester tester, String clave, String valor) async {
  final campo = find.byKey(Key(clave));
  await tester.enterText(
    find.descendant(of: campo, matching: find.byType(EditableText)),
    valor,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}
