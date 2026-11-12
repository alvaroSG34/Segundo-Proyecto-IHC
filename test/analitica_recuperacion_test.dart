import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/autenticacion/vista_recuperar_clave.dart';

import 'apoyo/servicio_autenticacion_falso.dart';

class _Analitica implements ServicioAnalitica {
  final eventos = <(String, Map<String, dynamic>)>[];
  bool fallar = false;
  Future<void>? pendiente;

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    if (fallar) throw StateError('Analitica no disponible');
    if (pendiente != null) await pendiente;
    eventos.add((evento, Map.of(props)));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => [];
}

class _Auth extends ServicioAutenticacionFalso {
  bool fallar = false;
  bool lanzar = false;
  Future<void>? pendiente;
  int solicitudes = 0;

  @override
  Future<String?> recuperarContrasena(String correo) async {
    solicitudes++;
    if (pendiente != null) await pendiente;
    if (lanzar) throw StateError('Contenido privado del servidor');
    return fallar ? 'Error privado del servidor' : null;
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  _Auth auth,
  _Analitica analitica, {
  bool desdeLogin = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: desdeLogin
          ? VistaLogin(servicioAuth: auth, servicioAnalitica: analitica)
          : VistaRecuperarClave(
              servicioAuth: auth,
              servicioAnalitica: analitica,
            ),
    ),
  );
  await tester.pumpAndSettle();
  if (desdeLogin) {
    final enlace = find.text('¿Olvidaste tu contraseña?');
    await tester.ensureVisible(enlace);
    await tester.tap(enlace);
    await tester.pumpAndSettle();
  }
}

Future<void> _correo(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('recuperar_correo')),
    'privado@unisport.edu',
  );
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<void> _enviar(WidgetTester tester, {bool esperar = true}) async {
  final boton = find.byKey(const Key('recuperar_enviar'));
  await tester.ensureVisible(boton);
  await tester.pump();
  await tester.tap(boton);
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _verificar(_Analitica analitica) {
  expect(analitica.eventos.last.$1, EventosAnalitica.recuperacionSolicitada);
  final id = analitica.eventos.last.$2['intento_id'];
  expect(
    analitica.eventos.any(
      (e) =>
          e.$1 == EventosAnalitica.recuperacionIniciada &&
          e.$2['intento_id'] == id,
    ),
    isTrue,
  );
  expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  expect(analitica.eventos.last.$2, {'intento_id': id});
}

void main() {
  testWidgets('desde login registra solo la solicitud aceptada sin correo', (
    tester,
  ) async {
    final auth = _Auth();
    final analitica = _Analitica();
    await _mostrar(tester, auth, analitica, desdeLogin: true);
    expect(
      analitica.eventos.where(
        (e) => [EventosAnalitica.recuperacionSolicitada].contains(e.$1),
      ),
      isEmpty,
    );
    await _correo(tester);
    await _enviar(tester);
    _verificar(analitica);
    expect(auth.solicitudes, 1);
    expect(find.text('¡Solicitud procesada!'), findsOneWidget);
    expect(auth.estaAutenticado, isFalse);
  });

  testWidgets('correo invalido no solicita recuperacion ni registra finalizacion', (
    tester,
  ) async {
    final auth = _Auth();
    final analitica = _Analitica();
    await _mostrar(tester, auth, analitica);
    await tester.enterText(
      find.byKey(const Key('recuperar_correo')),
      'correo-invalido',
    );
    await _enviar(tester);
    expect(auth.solicitudes, 0);
    expect(
      analitica.eventos.where(
        (e) => [EventosAnalitica.recuperacionSolicitada].contains(e.$1),
      ),
      isEmpty,
    );
  });

  for (final excepcion in [false, true]) {
    testWidgets(
      'error del servicio, excepcion: $excepcion, no registra y permite reintentar',
      (tester) async {
        final auth = _Auth()
          ..fallar = !excepcion
          ..lanzar = excepcion;
        final analitica = _Analitica();
        await _mostrar(tester, auth, analitica);
        await _correo(tester);
        await _enviar(tester);
        expect(
          analitica.eventos.where(
            (e) => [EventosAnalitica.recuperacionSolicitada].contains(e.$1),
          ),
          isEmpty,
        );
        expect(find.text('¡Solicitud procesada!'), findsNothing);
        auth.fallar = false;
        auth.lanzar = false;
        await _enviar(tester);
        _verificar(analitica);
        expect(auth.solicitudes, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('espera al servidor y evita un segundo envio pendiente', (
    tester,
  ) async {
    final respuesta = Completer<void>();
    final auth = _Auth()..pendiente = respuesta.future;
    final analitica = _Analitica();
    await _mostrar(tester, auth, analitica);
    await _correo(tester);
    await _enviar(tester, esperar: false);
    await tester.tap(find.byKey(const Key('recuperar_enviar')));
    await tester.pump();
    expect(auth.solicitudes, 1);
    expect(
      analitica.eventos.where(
        (e) => [EventosAnalitica.recuperacionSolicitada].contains(e.$1),
      ),
      isEmpty,
    );
    respuesta.complete();
    await tester.pumpAndSettle();
    _verificar(analitica);
  });

  testWidgets('volver a login sin enviar no registra finalizacion', (tester) async {
    final auth = _Auth();
    final analitica = _Analitica();
    await _mostrar(tester, auth, analitica, desdeLogin: true);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(auth.solicitudes, 0);
    expect(
      analitica.eventos.where(
        (e) => [EventosAnalitica.recuperacionSolicitada].contains(e.$1),
      ),
      isEmpty,
    );
    expect(find.byType(VistaLogin), findsOneWidget);
  });

  testWidgets('fallo de analitica no impide confirmar la solicitud', (
    tester,
  ) async {
    final analitica = _Analitica()..fallar = true;
    await _mostrar(tester, _Auth(), analitica);
    await _correo(tester);
    await _enviar(tester);
    expect(find.text('¡Solicitud procesada!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analitica pendiente no retrasa la pantalla de exito', (
    tester,
  ) async {
    final pendiente = Completer<void>();
    final analitica = _Analitica()..pendiente = pendiente.future;
    await _mostrar(tester, _Auth(), analitica);
    await _correo(tester);
    await _enviar(tester);
    expect(find.text('¡Solicitud procesada!'), findsOneWidget);
    pendiente.complete();
    await tester.pumpAndSettle();
    _verificar(analitica);
  });

  testWidgets(
    'el resultado se registra aunque la pantalla se cierre durante la solicitud',
    (tester) async {
      final respuesta = Completer<void>();
      final auth = _Auth()..pendiente = respuesta.future;
      final analitica = _Analitica();
      await _mostrar(tester, auth, analitica);
      await _correo(tester);
      await _enviar(tester, esperar: false);
      await tester.pumpWidget(const SizedBox());
      respuesta.complete();
      await tester.pumpAndSettle();
      _verificar(analitica);
      expect(tester.takeException(), isNull);
    },
  );
}
