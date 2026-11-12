import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

class _Analitica implements ServicioAnalitica {
  final eventos = <(String, Map<String, dynamic>)>[];
  bool fallar = false;
  Future<void>? pendiente;

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    if (fallar) throw StateError('Analitica no disponible');
    if (pendiente != null) await pendiente;
    eventos.add((evento, props));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => [];
}

class _Repositorio extends RepositorioEnMemoria {
  Object? errorSalida;
  Future<void>? pendiente;
  int salidas = 0;

  @override
  Future<ModeloPartido> salirDelPartido(String partidoId) async {
    salidas++;
    if (pendiente != null) await pendiente;
    if (errorSalida != null) throw errorSalida!;
    return super.salirDelPartido(partidoId);
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  bool explorar,
  _Repositorio repositorio,
  _Analitica analitica,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  repositorio.sembrar(
    'u-lorgio',
    ModeloPartido(
      id: 'partido-1',
      titulo: 'Partido privado',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Lugar privado',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 10,
      cuposOcupados: 1,
      organizadorNombre: 'Nombre privado',
    ),
  );
  final auth = ServicioAutenticacionFalso(repositorio);
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await repositorio.unirseAPartido('partido-1');
  final referencia = DateTime(2099, 10, 10, 18, 30);
  final controlador = ControladorExplorar();
  await tester.pumpWidget(
    MaterialApp(
      home: explorar
          ? VistaExplorarPartidos(
              servicioAuth: auth,
              repositorioPartidos: repositorio,
              servicioAnalitica: analitica,
              controladorExplorar: controlador,
              referenciaTemporal: referencia,
            )
          : VistaMisPartidos(
              servicioAuth: auth,
              repositorioPartidos: repositorio,
              servicioAnalitica: analitica,
              controladorExplorar: controlador,
              referenciaTemporal: referencia,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrirSalida(WidgetTester tester) async {
  final boton = find.text('Salir del partido');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> _confirmar(WidgetTester tester) async {
  await tester.tap(find.text('Registrar baja tardía'));
  await tester.pumpAndSettle();
}

void main() {
  test('anticipacion: limites de una hora, 24 horas y fecha desconocida', () {
    final ahora = DateTime(2099, 10, 10, 18);
    expect(anticipacionSalida(null, ahora), isNull);
    expect(
      anticipacionSalida(ahora.subtract(const Duration(minutes: 1)), ahora),
      'partido_iniciado',
    );
    expect(anticipacionSalida(ahora, ahora), 'partido_iniciado');
    expect(
      anticipacionSalida(ahora.add(const Duration(minutes: 59)), ahora),
      'menos_1_hora',
    );
    expect(
      anticipacionSalida(ahora.add(const Duration(hours: 1)), ahora),
      'entre_1_y_24_horas',
    );
    expect(
      anticipacionSalida(ahora.add(const Duration(hours: 24)), ahora),
      'entre_1_y_24_horas',
    );
    expect(
      anticipacionSalida(
        ahora.add(const Duration(hours: 24, minutes: 1)),
        ahora,
      ),
      'mas_24_horas',
    );
  });

  for (final explorar in [true, false]) {
    final pantalla = explorar ? 'Explorar' : 'Mis partidos';

    testWidgets(
      '$pantalla: cancelar solo conserva inicio y reabrir cambia el intento',
      (tester) async {
        final analitica = _Analitica();
        final repositorio = _Repositorio();
        await _mostrar(tester, explorar, repositorio, analitica);
        expect(analitica.eventos, isEmpty);
        await _abrirSalida(tester);
        expect(analitica.eventos.single.$1, EventosAnalitica.salidaIniciada);
        final id = analitica.eventos.single.$2['intento_id'];
        expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(repositorio.salidas, 0);
        expect(analitica.eventos, hasLength(1));
        expect((await repositorio.obtenerPartidosUnidos()), hasLength(1));
        await _abrirSalida(tester);
        expect(analitica.eventos.map((e) => e.$1), [
          EventosAnalitica.salidaIniciada,
          EventosAnalitica.salidaIniciada,
        ]);
        expect(analitica.eventos.last.$2['intento_id'], isNot(id));
      },
    );

    testWidgets(
      '$pantalla: baja tardía registra anticipacion sin datos del partido',
      (tester) async {
        final analitica = _Analitica();
        final repositorio = _Repositorio();
        await _mostrar(tester, explorar, repositorio, analitica);
        await _abrirSalida(tester);
        await _confirmar(tester);
        expect(analitica.eventos.map((e) => e.$1), [
          EventosAnalitica.salidaIniciada,
          EventosAnalitica.salidaCompletada,
        ]);
        final id = analitica.eventos.first.$2['intento_id'];
        expect(analitica.eventos.first.$2, {'intento_id': id});
        expect(analitica.eventos.last.$2, {
          'intento_id': id,
          'anticipacion': 'menos_1_hora',
        });
        expect(repositorio.salidas, 1);
        expect(await repositorio.obtenerPartidosUnidos(), isEmpty);
        expect(find.text('Salir del partido'), findsNothing);
        expect(find.textContaining('Baja tardía registrada'), findsOneWidget);
      },
    );

    for (final error in [
      StateError('Motivo privado'),
      Exception('Contenido privado'),
    ]) {
      testWidgets('$pantalla: ${error.runtimeType} registra fallo sin exito', (
        tester,
      ) async {
        final analitica = _Analitica();
        final repositorio = _Repositorio()..errorSalida = error;
        await _mostrar(tester, explorar, repositorio, analitica);
        await _abrirSalida(tester);
        await _confirmar(tester);
        expect(analitica.eventos.map((e) => e.$1), [
          EventosAnalitica.salidaIniciada,
          EventosAnalitica.salidaFallida,
        ]);
        expect(analitica.eventos.last.$2, {
          'intento_id': analitica.eventos.first.$2['intento_id'],
          'codigo_error': 'servicio_partidos',
        });
        expect(await repositorio.obtenerPartidosUnidos(), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '$pantalla: no registra exito antes de la respuesta del servidor',
      (tester) async {
        final analitica = _Analitica();
        final respuesta = Completer<void>();
        final repositorio = _Repositorio()..pendiente = respuesta.future;
        await _mostrar(tester, explorar, repositorio, analitica);
        await _abrirSalida(tester);
        await _confirmar(tester);
        expect(analitica.eventos.single.$1, EventosAnalitica.salidaIniciada);
        expect(await repositorio.obtenerPartidosUnidos(), hasLength(1));
        respuesta.complete();
        await tester.pumpAndSettle();
        expect(analitica.eventos.last.$1, EventosAnalitica.salidaCompletada);
      },
    );

    testWidgets('$pantalla: fallo de analitica no impide salir', (
      tester,
    ) async {
      final analitica = _Analitica()..fallar = true;
      final repositorio = _Repositorio();
      await _mostrar(tester, explorar, repositorio, analitica);
      await _abrirSalida(tester);
      await _confirmar(tester);
      expect(await repositorio.obtenerPartidosUnidos(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$pantalla: analitica pendiente no retrasa la salida', (
      tester,
    ) async {
      final pendiente = Completer<void>();
      final analitica = _Analitica()..pendiente = pendiente.future;
      final repositorio = _Repositorio();
      await _mostrar(tester, explorar, repositorio, analitica);
      await _abrirSalida(tester);
      await _confirmar(tester);
      expect(await repositorio.obtenerPartidosUnidos(), isEmpty);
      pendiente.complete();
      await tester.pumpAndSettle();
      expect(analitica.eventos.last.$1, EventosAnalitica.salidaCompletada);
    });
  }
}
