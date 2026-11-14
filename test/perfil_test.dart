import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/vistas/autenticacion/vista_perfil.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

class _AnaliticaCuenta implements ServicioAnalitica {
  final eventos = <(String, Map<String, dynamic>)>[];
  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    eventos.add((evento, Map.of(props)));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => [];
}

class _CuentaBloqueada extends ServicioAutenticacionFalso {
  @override
  Future<String?> eliminarCuenta({String? intentoId}) async =>
      'No se puede eliminar la cuenta: hay un resultado confirmado en un partido futuro.';
}

void main() {
  testWidgets('registrar inicio y bloqueo sin datos personales', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _CuentaBloqueada();
    final analitica = _AnaliticaCuenta();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(
        home: VistaPerfil(servicioAuth: auth, servicioAnalitica: analitica),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('eliminar_cuenta')));
    await tester.tap(find.byKey(const Key('eliminar_cuenta')));
    await tester.pumpAndSettle();
    expect(
      analitica.eventos.single.$1,
      EventosAnalitica.cuentaEliminacionIniciada,
    );
    await tester.tap(find.byKey(const Key('confirmar_eliminar_cuenta')));
    await tester.pumpAndSettle();
    expect(analitica.eventos.map((e) => e.$1), [
      EventosAnalitica.cuentaEliminacionIniciada,
      EventosAnalitica.cuentaEliminacionFallida,
    ]);
    expect(analitica.eventos.last.$2['codigo_error'], 'bloqueo');
    expect(
      analitica.eventos.first.$2['intento_id'],
      analitica.eventos.last.$2['intento_id'],
    );
    expect(analitica.eventos.toString(), isNot(contains('diego@unisport.edu')));
    expect(auth.estaAutenticado, isTrue);
  });

  testWidgets('cancelar y confirmar la eliminación de cuenta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(MaterialApp(home: VistaPerfil(servicioAuth: auth)));

    final boton = find.byKey(const Key('eliminar_cuenta'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Se cancelarán los partidos futuros'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(auth.estaAutenticado, isTrue);

    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmar_eliminar_cuenta')));
    await tester.pumpAndSettle();
    expect(auth.estaAutenticado, isFalse);
    expect(await auth.iniciarSesion('diego@unisport.edu', '123456'), isNotNull);
  });

  testWidgets('muestra y descarga los datos de la cuenta en JSON', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    Uint8List? archivo;
    await tester.pumpWidget(
      MaterialApp(
        home: VistaPerfil(
          servicioAuth: auth,
          guardarArchivo: (bytes) async {
            archivo = bytes;
            return 'mis-datos.json';
          },
        ),
      ),
    );

    final boton = find.byKey(const Key('ver_mis_datos'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    final texto = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(jsonDecode(texto)['perfil']['correo'], 'diego@unisport.edu');
    await tester.tap(find.byKey(const Key('descargar_mis_datos')));
    await tester.pump();
    expect(jsonDecode(utf8.decode(archivo!))['perfil']['nombre'], 'Diego');
    expect(jsonDecode(utf8.decode(archivo!))['lista_de_espera'], isEmpty);
  });

  testWidgets('informa si no se pueden cargar los datos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _AuthConError();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(MaterialApp(home: VistaPerfil(servicioAuth: auth)));
    final boton = find.byKey(const Key('ver_mis_datos'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudieron cargar tus datos. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(boton).onPressed, isNotNull);
  });

  testWidgets('informa si falla la descarga', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ServicioAutenticacionFalso();
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(
        home: VistaPerfil(
          servicioAuth: auth,
          guardarArchivo: (_) async => throw StateError('No se pudo guardar'),
        ),
      ),
    );
    final boton = find.byKey(const Key('ver_mis_datos'));
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('descargar_mis_datos')));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudieron guardar tus datos. Inténtalo de nuevo.'),
      findsOneWidget,
    );
  });

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

class _AuthConError extends ServicioAutenticacionFalso {
  @override
  Future<Map<String, dynamic>> obtenerMisDatos() async {
    throw StateError('Sin conexión');
  }
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
