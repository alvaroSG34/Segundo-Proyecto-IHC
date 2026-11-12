import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';

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
    eventos.add((evento, Map.of(props)));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => [];
}

class _Repositorio extends RepositorioEnMemoria {
  Object? error;
  Future<void>? pendiente;

  @override
  Future<ModeloPartido> entrarEnEspera(String partidoId) async {
    if (pendiente != null) await pendiente;
    if (error != null) throw error!;
    return super.entrarEnEspera(partidoId);
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  _Repositorio repo,
  _Analitica analitica,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  repo.sembrar(
    'u-lorgio',
    ModeloPartido(
      id: 'partido-1',
      titulo: 'Partido privado',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Lugar privado',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 2,
      cuposOcupados: 1,
      organizadorNombre: 'Nombre privado',
    ),
  );
  repo.usarSesionDe('u-ana', 'Ana');
  await repo.unirseAPartido('partido-1');
  final auth = ServicioAutenticacionFalso(repo);
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await tester.pumpWidget(
    MaterialApp(
      home: VistaExplorarPartidos(
        servicioAuth: auth,
        repositorioPartidos: repo,
        servicioAnalitica: analitica,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _entrar(WidgetTester tester) async {
  final boton = find.text('Entrar como suplente');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<ModeloPartido> _partido(_Repositorio repo) async =>
    (await repo.buscarPartidos(const FiltroPartidos())).single;

void main() {
  testWidgets('solo registra espera confirmada despues de anotarse', (
    tester,
  ) async {
    final analitica = _Analitica();
    final repo = _Repositorio();
    await _mostrar(tester, repo, analitica);
    expect(analitica.eventos, isEmpty);
    await _entrar(tester);
    expect(analitica.eventos.last.$1, EventosAnalitica.esperaConfirmada);
    expect(analitica.eventos.map((e) => e.$1), [
      EventosAnalitica.esperaIniciada,
      EventosAnalitica.esperaConfirmada,
    ]);
    final id = analitica.eventos.last.$2['intento_id'];
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(analitica.eventos.last.$2, {'intento_id': id});
    expect((await _partido(repo)).posicionEspera, 1);
  });

  for (final error in [
    StateError('Motivo privado'),
    Exception('Mensaje privado'),
  ]) {
    testWidgets(
      '${error.runtimeType}: registra fallo fijo y permite reintentar',
      (tester) async {
        final analitica = _Analitica();
        final repo = _Repositorio()..error = error;
        await _mostrar(tester, repo, analitica);
        await _entrar(tester);
        expect(analitica.eventos.last.$1, EventosAnalitica.esperaFallida);
        final id = analitica.eventos.last.$2['intento_id'];
        expect(analitica.eventos.last.$2, {
          'intento_id': id,
          'codigo_error': 'servicio_partidos',
        });
        expect((await _partido(repo)).estoyEnEspera, isFalse);
        repo.error = null;
        await _entrar(tester);
        expect(analitica.eventos.last.$1, EventosAnalitica.esperaConfirmada);
        expect(analitica.eventos.last.$2['intento_id'], isNot(id));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'registra inicio sin exito mientras el servidor esta pendiente',
    (tester) async {
      final respuesta = Completer<void>();
      final repo = _Repositorio()..pendiente = respuesta.future;
      final analitica = _Analitica();
      await _mostrar(tester, repo, analitica);
      await _entrar(tester);
      expect(analitica.eventos.map((e) => e.$1), [
        EventosAnalitica.esperaIniciada,
      ]);
      expect((await _partido(repo)).estoyEnEspera, isFalse);
      respuesta.complete();
      await tester.pumpAndSettle();
      expect(analitica.eventos.last.$1, EventosAnalitica.esperaConfirmada);
    },
  );

  testWidgets(
    'cancelar espera no agrega eventos y volver a anotarse genera otro intento',
    (tester) async {
      final analitica = _Analitica();
      final repo = _Repositorio();
      await _mostrar(tester, repo, analitica);
      await _entrar(tester);
      final id = analitica.eventos.last.$2['intento_id'];
      await tester.ensureVisible(find.text('Cancelar espera'));
      await tester.tap(find.text('Cancelar espera'));
      await tester.pumpAndSettle();
      expect(analitica.eventos, hasLength(2));
      expect((await _partido(repo)).estoyEnEspera, isFalse);
      await _entrar(tester);
      expect(analitica.eventos.map((e) => e.$1), [
        EventosAnalitica.esperaIniciada,
        EventosAnalitica.esperaConfirmada,
        EventosAnalitica.esperaIniciada,
        EventosAnalitica.esperaConfirmada,
      ]);
      expect(analitica.eventos.last.$2['intento_id'], isNot(id));
    },
  );

  testWidgets('fallo de analitica no impide anotarse', (tester) async {
    final analitica = _Analitica()..fallar = true;
    final repo = _Repositorio();
    await _mostrar(tester, repo, analitica);
    await _entrar(tester);
    expect((await _partido(repo)).posicionEspera, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analitica pendiente no retrasa la inscripcion', (tester) async {
    final pendiente = Completer<void>();
    final analitica = _Analitica()..pendiente = pendiente.future;
    final repo = _Repositorio();
    await _mostrar(tester, repo, analitica);
    await _entrar(tester);
    expect((await _partido(repo)).posicionEspera, 1);
    pendiente.complete();
    await tester.pumpAndSettle();
    expect(analitica.eventos.last.$1, EventosAnalitica.esperaConfirmada);
  });

  testWidgets(
    'refrescar una promocion no vuelve a registrarla desde el cliente',
    (tester) async {
      final analitica = _Analitica();
      final repo = _Repositorio();
      await _mostrar(tester, repo, analitica);
      await _entrar(tester);
      repo.usarSesionDe('u-ana', 'Ana');
      await repo.salirDelPartido('partido-1');
      repo.usarSesionDe('u-diego', 'Diego');
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect((await _partido(repo)).estoyUnido, isTrue);
      expect(analitica.eventos.last.$1, EventosAnalitica.esperaConfirmada);
    },
  );
}
