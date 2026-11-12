import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/autenticacion/vista_registro.dart';

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
  int registros = 0;
  int logins = 0;

  Future<String?> _error() async {
    if (pendiente != null) await pendiente;
    if (lanzar) throw StateError('Error con contenido privado');
    return fallar ? 'Mensaje privado del servidor' : null;
  }

  @override
  Future<String?> iniciarSesion(String correo, String contrasena) async {
    logins++;
    final error = await _error();
    return error ?? await super.iniciarSesion(correo, contrasena);
  }

  @override
  Future<String?> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String carrera,
    required String deporteFavorito,
  }) async {
    registros++;
    final error = await _error();
    if (error != null) return error;
    return super.registrarUsuario(
      nombre: nombre,
      correo: correo,
      contrasena: contrasena,
      carrera: carrera,
      deporteFavorito: deporteFavorito,
    );
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  bool registro,
  _Auth auth,
  _Analitica analitica,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AnimatedBuilder(
        animation: auth,
        builder: (_, _) {
          if (auth.estaAutenticado) {
            return const Scaffold(body: Text('Acceso confirmado'));
          }
          return registro
              ? VistaRegistro(servicioAuth: auth, servicioAnalitica: analitica)
              : VistaLogin(servicioAuth: auth, servicioAnalitica: analitica);
        },
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _completar(WidgetTester tester, bool registro) async {
  final campos = registro
      ? {
          'registro_nombre': 'Nombre privado',
          'registro_correo': 'nuevo@unisport.edu',
          'registro_carrera': 'Carrera privada',
          'registro_clave': '123456',
        }
      : {'login_correo': 'diego@unisport.edu', 'login_clave': '123456'};
  for (final campo in campos.entries) {
    final selector = find.byKey(Key(campo.key));
    await tester.ensureVisible(selector);
    await tester.enterText(selector, campo.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _enviar(WidgetTester tester, bool registro) async {
  final boton = find.byKey(Key(registro ? 'registro_enviar' : 'login_enviar'));
  await tester.ensureVisible(boton);
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(boton);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final registro in [true, false]) {
    final nombre = registro ? 'registro' : 'login';
    final fallo = registro
        ? EventosAnalitica.registroFallido
        : EventosAnalitica.loginFallido;
    final exito = registro
        ? EventosAnalitica.registroCompletado
        : EventosAnalitica.loginExitoso;

    testWidgets('$nombre: apertura y validacion sin datos personales', (
      tester,
    ) async {
      final analitica = _Analitica();
      final auth = _Auth();
      await _mostrar(tester, registro, auth, analitica);
      expect(
        analitica.eventos.map((e) => e.$1),
        registro
            ? [EventosAnalitica.registroIniciado]
            : [EventosAnalitica.loginIniciado],
      );
      await _enviar(tester, registro);
      expect(auth.registros + auth.logins, 0);
      expect(analitica.eventos.last.$1, fallo);
      final id = analitica.eventos.last.$2['intento_id'];
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(analitica.eventos.last.$2, {
        'intento_id': id,
        'codigo_error': 'validacion_formulario',
      });
      if (registro) expect(analitica.eventos.first.$2, {'intento_id': id});
    });

    testWidgets(
      '$nombre: registra exito aunque la sesion sustituya la pantalla',
      (tester) async {
        final analitica = _Analitica();
        final auth = _Auth();
        await _mostrar(tester, registro, auth, analitica);
        await _completar(tester, registro);
        await _enviar(tester, registro);
        expect(find.text('Acceso confirmado'), findsOneWidget);
        expect(
          analitica.eventos.map((e) => e.$1),
          registro
              ? [EventosAnalitica.registroIniciado, exito]
              : [EventosAnalitica.loginIniciado, exito],
        );
        final id = analitica.eventos.last.$2['intento_id'];
        for (final evento in analitica.eventos) {
          expect(evento.$2, {'intento_id': id});
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$nombre: fallo y reintento comparten identificador', (
      tester,
    ) async {
      final analitica = _Analitica();
      final auth = _Auth()..fallar = true;
      await _mostrar(tester, registro, auth, analitica);
      await _completar(tester, registro);
      await _enviar(tester, registro);
      final id = analitica.eventos.last.$2['intento_id'];
      expect(analitica.eventos.last.$1, fallo);
      expect(analitica.eventos.last.$2, {
        'intento_id': id,
        'codigo_error': 'servicio_autenticacion',
      });
      auth.fallar = false;
      await _enviar(tester, registro);
      expect(analitica.eventos.last.$1, exito);
      expect(analitica.eventos.last.$2, {'intento_id': id});
      expect(
        analitica.eventos.map((e) => e.$2['intento_id']).toSet(),
        hasLength(1),
      );
    });

    testWidgets('$nombre: una excepcion no deja el formulario bloqueado', (
      tester,
    ) async {
      final analitica = _Analitica();
      final auth = _Auth()..lanzar = true;
      await _mostrar(tester, registro, auth, analitica);
      await _completar(tester, registro);
      await _enviar(tester, registro);
      expect(analitica.eventos.last.$1, fallo);
      expect(
        analitica.eventos.last.$2['codigo_error'],
        'servicio_autenticacion',
      );
      expect(tester.takeException(), isNull);
      auth.lanzar = false;
      await _enviar(tester, registro);
      expect(analitica.eventos.last.$1, exito);
    });

    testWidgets(
      '$nombre: no registra exito mientras el servidor esta pendiente',
      (tester) async {
        final pendiente = Completer<void>();
        final auth = _Auth()..pendiente = pendiente.future;
        final analitica = _Analitica();
        await _mostrar(tester, registro, auth, analitica);
        await _completar(tester, registro);
        await _enviar(tester, registro);
        final boton = find.byKey(
          Key(registro ? 'registro_enviar' : 'login_enviar'),
        );
        await tester.tap(boton);
        await tester.pump();
        expect(analitica.eventos.where((e) => e.$1 == exito), isEmpty);
        expect(registro ? auth.registros : auth.logins, 1);
        pendiente.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(analitica.eventos.last.$1, exito);
      },
    );

    testWidgets('$nombre: analitica fallida no impide acceder', (tester) async {
      final analitica = _Analitica()..fallar = true;
      final auth = _Auth();
      await _mostrar(tester, registro, auth, analitica);
      await _completar(tester, registro);
      await _enviar(tester, registro);
      expect(find.text('Acceso confirmado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$nombre: analitica pendiente no retrasa el acceso', (
      tester,
    ) async {
      final pendiente = Completer<void>();
      final analitica = _Analitica()..pendiente = pendiente.future;
      final auth = _Auth();
      await _mostrar(tester, registro, auth, analitica);
      await _completar(tester, registro);
      await _enviar(tester, registro);
      expect(find.text('Acceso confirmado'), findsOneWidget);
      pendiente.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(analitica.eventos.last.$1, exito);
    });
  }

  testWidgets(
    'cambiar de login a registro conserva el servicio y reabrir cambia el intento',
    (tester) async {
      final analitica = _Analitica();
      await _mostrar(tester, false, _Auth(), analitica);
      await tester.ensureVisible(find.text('Regístrate aquí'));
      await tester.tap(find.text('Regístrate aquí'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(analitica.eventos.last.$1, EventosAnalitica.registroIniciado);
      final id = analitica.eventos.last.$2['intento_id'];
      await tester.ensureVisible(find.text('Inicia sesión'));
      await tester.tap(find.text('Inicia sesión'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('Regístrate aquí'));
      await tester.tap(find.text('Regístrate aquí'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(analitica.eventos.map((e) => e.$1), [
        EventosAnalitica.loginIniciado, EventosAnalitica.registroIniciado,
        EventosAnalitica.loginIniciado, EventosAnalitica.registroIniciado,
      ]);
      expect(analitica.eventos.last.$2['intento_id'], isNot(id));
    },
  );
}
