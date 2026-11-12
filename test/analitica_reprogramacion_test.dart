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
    eventos.add((evento, Map.of(props)));
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => [];
}

class _Repositorio extends RepositorioEnMemoria {
  bool fallar = false;
  Future<void>? pendiente;
  int cambios = 0;

  Future<void> _esperar() async {
    if (pendiente != null) await pendiente;
    if (fallar) throw StateError('Motivo privado del servidor');
  }

  @override
  Future<ModeloPartido> reprogramarPartido(
    String id,
    DateTime fecha,
    String lugar,
    String motivo,
  ) async {
    cambios++;
    await _esperar();
    return super.reprogramarPartido(id, fecha, lugar, motivo);
  }

  @override
  Future<ModeloPartido> responderReprogramacion(String id, bool acepta) async {
    await _esperar();
    return super.responderReprogramacion(id, acepta);
  }
}

Future<void> _mostrar(
  WidgetTester tester,
  _Repositorio repo,
  _Analitica analitica, {
  bool organizador = false,
  bool explorar = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  repo.sembrar(
    'u-lorgio',
    ModeloPartido(
      id: 'partido-1',
      titulo: 'Titulo privado',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Lugar privado',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 3,
      cuposOcupados: 1,
      organizadorNombre: 'Lorgio',
    ),
  );
  final auth = ServicioAutenticacionFalso(repo);
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await repo.unirseAPartido('partido-1');
  repo.usarSesionDe('u-lorgio', 'Lorgio');
  if (!organizador) {
    await repo.reprogramarPartido(
      'partido-1',
      DateTime(2099, 10, 11, 19),
      'Nuevo lugar privado',
      'Motivo privado',
    );
  }
  await auth.iniciarSesion(
    organizador ? 'lorgio@unisport.edu' : 'diego@unisport.edu',
    '123456',
  );
  final controlador = ControladorExplorar();
  await tester.pumpWidget(
    MaterialApp(
      home: explorar
          ? VistaExplorarPartidos(
              servicioAuth: auth,
              repositorioPartidos: repo,
              servicioAnalitica: analitica,
              controladorExplorar: controlador,
            )
          : VistaMisPartidos(
              servicioAuth: auth,
              repositorioPartidos: repo,
              servicioAnalitica: analitica,
              controladorExplorar: controlador,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> _responder(WidgetTester tester, bool acepta) async {
  await _tocar(
    tester,
    find.byKey(
      Key(acepta ? 'partido_reconfirmar' : 'partido_retirarse_reprogramacion'),
    ),
  );
  if (!acepta) await _tocar(tester, find.text('Sí, retirarme'));
}

void _verificarEvento(_Analitica analitica, String nombre) {
  expect(analitica.eventos.last.$1, nombre);
  final id = analitica.eventos.last.$2['intento_id'];
  final inicio = nombre == EventosAnalitica.partidoReprogramado
      ? EventosAnalitica.reprogramacionIniciada
      : EventosAnalitica.reconfirmacionIniciada;
  expect(
    analitica.eventos.any((e) => e.$1 == inicio && e.$2['intento_id'] == id),
    isTrue,
  );
  expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  expect(analitica.eventos.last.$2, {'intento_id': id});
}

void main() {
  testWidgets(
    'reprogramar solo registra el guardado confirmado, sin datos del formulario',
    (tester) async {
      final repo = _Repositorio();
      final analitica = _Analitica();
      await _mostrar(tester, repo, analitica, organizador: true);
      await _tocar(tester, find.byKey(const Key('partido_reprogramar')));
      await _tocar(tester, find.byKey(const Key('reprogramar_guardar')));
      expect(repo.cambios, 0);
      expect(
        analitica.eventos.where(
          (e) => [
            EventosAnalitica.partidoReprogramado,
            EventosAnalitica.reprogramacionAceptada,
            EventosAnalitica.reprogramacionRechazada,
          ].contains(e.$1),
        ),
        isEmpty,
      );
      await tester.enterText(
        find.byKey(const Key('reprogramar_lugar')),
        'Lugar secreto',
      );
      await tester.enterText(
        find.byKey(const Key('reprogramar_motivo')),
        'Motivo secreto',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      repo.fallar = true;
      await _tocar(tester, find.byKey(const Key('reprogramar_guardar')));
      expect(
        analitica.eventos.where(
          (e) => [
            EventosAnalitica.partidoReprogramado,
            EventosAnalitica.reprogramacionAceptada,
            EventosAnalitica.reprogramacionRechazada,
          ].contains(e.$1),
        ),
        isEmpty,
      );
      repo.fallar = false;
      final respuesta = Completer<void>();
      repo.pendiente = respuesta.future;
      await _tocar(tester, find.byKey(const Key('reprogramar_guardar')));
      expect(
        analitica.eventos.where(
          (e) => [
            EventosAnalitica.partidoReprogramado,
            EventosAnalitica.reprogramacionAceptada,
            EventosAnalitica.reprogramacionRechazada,
          ].contains(e.$1),
        ),
        isEmpty,
      );
      respuesta.complete();
      await tester.pumpAndSettle();
      _verificarEvento(analitica, EventosAnalitica.partidoReprogramado);
      expect(
        (await repo.obtenerMisPartidos()).single.ubicacion,
        'Lugar secreto',
      );
    },
  );

  testWidgets('cerrar el formulario no registra reprogramacion', (
    tester,
  ) async {
    final analitica = _Analitica();
    await _mostrar(tester, _Repositorio(), analitica, organizador: true);
    await _tocar(tester, find.byKey(const Key('partido_reprogramar')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      analitica.eventos.where(
        (e) => [
          EventosAnalitica.partidoReprogramado,
          EventosAnalitica.reprogramacionAceptada,
          EventosAnalitica.reprogramacionRechazada,
        ].contains(e.$1),
      ),
      isEmpty,
    );
  });

  for (final explorar in [true, false]) {
    final pantalla = explorar ? 'Explorar' : 'Mis partidos';
    for (final acepta in [true, false]) {
      testWidgets(
        '$pantalla: ${acepta ? 'aceptar' : 'rechazar'} solo registra respuesta confirmada',
        (tester) async {
          final repo = _Repositorio();
          final analitica = _Analitica();
          await _mostrar(tester, repo, analitica, explorar: explorar);
          repo.fallar = true;
          await _responder(tester, acepta);
          expect(
            analitica.eventos.where(
              (e) => [
                EventosAnalitica.partidoReprogramado,
                EventosAnalitica.reprogramacionAceptada,
                EventosAnalitica.reprogramacionRechazada,
              ].contains(e.$1),
            ),
            isEmpty,
          );
          expect(
            (await repo.obtenerPartidosUnidos()).single.reconfirmacionPendiente,
            isTrue,
          );
          repo.fallar = false;
          final respuesta = Completer<void>();
          repo.pendiente = respuesta.future;
          await _responder(tester, acepta);
          expect(
            analitica.eventos.where(
              (e) => [
                EventosAnalitica.partidoReprogramado,
                EventosAnalitica.reprogramacionAceptada,
                EventosAnalitica.reprogramacionRechazada,
              ].contains(e.$1),
            ),
            isEmpty,
          );
          respuesta.complete();
          await tester.pumpAndSettle();
          _verificarEvento(
            analitica,
            acepta
                ? EventosAnalitica.reprogramacionAceptada
                : EventosAnalitica.reprogramacionRechazada,
          );
          final partidos = await repo.obtenerPartidosUnidos();
          if (acepta) {
            expect(partidos.single.reconfirmacionAceptada, isTrue);
          } else {
            expect(partidos, isEmpty);
          }
        },
      );
    }

    testWidgets(
      '$pantalla: cancelar el rechazo no registra ni libera la plaza',
      (tester) async {
        final repo = _Repositorio();
        final analitica = _Analitica();
        await _mostrar(tester, repo, analitica, explorar: explorar);
        await _tocar(
          tester,
          find.byKey(const Key('partido_retirarse_reprogramacion')),
        );
        await _tocar(tester, find.text('Cancelar'));
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.partidoReprogramado,
              EventosAnalitica.reprogramacionAceptada,
              EventosAnalitica.reprogramacionRechazada,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        expect(
          (await repo.obtenerPartidosUnidos()).single.reconfirmacionPendiente,
          isTrue,
        );
      },
    );

    testWidgets('$pantalla: fallo de analitica no impide aceptar', (
      tester,
    ) async {
      final repo = _Repositorio();
      final analitica = _Analitica()..fallar = true;
      await _mostrar(tester, repo, analitica, explorar: explorar);
      await _responder(tester, true);
      expect(
        (await repo.obtenerPartidosUnidos()).single.reconfirmacionAceptada,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('analitica pendiente no retrasa la respuesta', (tester) async {
    final repo = _Repositorio();
    final pendiente = Completer<void>();
    final analitica = _Analitica()..pendiente = pendiente.future;
    await _mostrar(tester, repo, analitica);
    await _responder(tester, true);
    expect(
      (await repo.obtenerPartidosUnidos()).single.reconfirmacionAceptada,
      isTrue,
    );
    pendiente.complete();
    await tester.pumpAndSettle();
    _verificarEvento(analitica, EventosAnalitica.reprogramacionAceptada);
  });
}
