import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/vistas/autenticacion/vista_perfil.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

void main() {
  testWidgets('edita el perfil y cambia la contraseña de la sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repositorio = RepositorioEnMemoria();
    final auth = ServicioAutenticacionFalso(repositorio);
    expect(await auth.iniciarSesion('diego@unisport.edu', '123456'), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: VistaPrincipal(
          servicioAuth: auth,
          repositorioPartidos: repositorio,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('abrir_perfil')), findsOneWidget);
    await tester.tap(find.byKey(const Key('abrir_perfil')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(VistaPerfil), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('perfil_nombre')),
      'Diego actualizado',
    );
    await tester.enterText(
      find.byKey(const Key('perfil_carrera')),
      'Ingeniería Informática',
    );
    await tester.tap(find.byKey(const Key('perfil_deporte')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tenis').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('perfil_guardar')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Perfil actualizado correctamente.'), findsOneWidget);
    expect(auth.usuarioActual!.nombre, 'Diego actualizado');
    expect(auth.usuarioActual!.carrera, 'Ingeniería Informática');
    expect(auth.usuarioActual!.deporteFavorito, 'Tenis');

    await _escribirClave(tester, 'perfil_clave_actual', '123456');
    await _escribirClave(tester, 'perfil_clave_nueva', 'nueva789');
    await _escribirClave(tester, 'perfil_clave_confirmar', 'nueva789');
    final cambiar = find.byKey(const Key('perfil_cambiar_clave'));
    await tester.ensureVisible(cambiar);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cambiar);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Contraseña actualizada correctamente.'), findsOneWidget);
    await auth.cerrarSesion();
    expect(await auth.iniciarSesion('diego@unisport.edu', '123456'), isNotNull);
    expect(await auth.iniciarSesion('diego@unisport.edu', 'nueva789'), isNull);
  });
}

Future<void> _escribirClave(
  WidgetTester tester,
  String clave,
  String valor,
) async {
  final contenedor = find.byKey(Key(clave));
  await tester.ensureVisible(contenedor);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(
    find.descendant(of: contenedor, matching: find.byType(EditableText)),
    valor,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}
