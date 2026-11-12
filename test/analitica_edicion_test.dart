import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
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

  Future<void> _esperar() async {
    if (pendiente != null) await pendiente;
    if (fallar) throw StateError('Error privado del servidor');
  }

  @override
  Future<ModeloPartido> editarPartido(ModeloPartido partido) async {
    await _esperar();
    return super.editarPartido(partido);
  }

  @override
  Future<void> eliminarPartido(String id) async {
    await _esperar();
    await super.eliminarPartido(id);
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
      titulo: 'Titulo privado',
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Lugar privado',
      fechaHora: '10/10/2099 · 19:00',
      cuposTotales: 6,
      cuposOcupados: 1,
      organizadorNombre: 'Lorgio',
    ),
  );
  final auth = ServicioAutenticacionFalso(repo);
  await auth.iniciarSesion('lorgio@unisport.edu', '123456');
  await tester.pumpWidget(
    MaterialApp(
      home: VistaMisPartidos(
        servicioAuth: auth,
        repositorioPartidos: repo,
        servicioAnalitica: analitica,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _abrir(WidgetTester tester, bool editar) async {
  final boton = find.text(editar ? 'Editar' : 'Eliminar');
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
  if (editar) {
    final campo = find.byKey(const Key('partido_titulo'));
    await tester.ensureVisible(campo);
    await tester.enterText(campo, 'Titulo editado privado');
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

Future<void> _enviar(
  WidgetTester tester,
  bool editar, {
  bool esperar = true,
}) async {
  final boton = editar
      ? find.descendant(
          of: find.byKey(const Key('partido_guardar')),
          matching: find.byType(ElevatedButton),
        )
      : find.widgetWithText(ElevatedButton, 'Eliminar');
  await tester.ensureVisible(boton);
  await tester.pump();
  await tester.tap(boton);
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _verificarDatos(_Repositorio repo, bool editar) async {
  final partidos = await repo.obtenerMisPartidos();
  if (editar) {
    expect(partidos.single.titulo, 'Titulo editado privado');
  } else {
    expect(partidos, isEmpty);
  }
}

void _verificarEvento(_Analitica analitica, bool editar) {
  expect(
    analitica.eventos.last.$1,
    editar
        ? EventosAnalitica.partidoEditado
        : EventosAnalitica.partidoEliminado,
  );
  final id = analitica.eventos.last.$2['intento_id'];
  final inicio = editar
      ? EventosAnalitica.edicionIniciada
      : EventosAnalitica.eliminacionIniciada;
  expect(
    analitica.eventos.any((e) => e.$1 == inicio && e.$2['intento_id'] == id),
    isTrue,
  );
  expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  expect(analitica.eventos.last.$2, {'intento_id': id});
}

void main() {
  for (final editar in [true, false]) {
    final accion = editar ? 'editar' : 'eliminar';
    testWidgets(
      '$accion: solo registra despues de la confirmacion del servidor',
      (tester) async {
        final repo = _Repositorio();
        final analitica = _Analitica();
        await _mostrar(tester, repo, analitica);
        await _abrir(tester, editar);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.partidoEditado,
              EventosAnalitica.partidoEliminado,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        repo.fallar = true;
        await _enviar(tester, editar);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.partidoEditado,
              EventosAnalitica.partidoEliminado,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        expect(
          (await repo.obtenerMisPartidos()).single.titulo,
          'Titulo privado',
        );
        if (!editar) await _abrir(tester, editar);
        repo.fallar = false;
        final respuesta = Completer<void>();
        repo.pendiente = respuesta.future;
        await _enviar(tester, editar, esperar: false);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.partidoEditado,
              EventosAnalitica.partidoEliminado,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        respuesta.complete();
        await tester.pumpAndSettle();
        _verificarEvento(analitica, editar);
        await _verificarDatos(repo, editar);
      },
    );

    testWidgets('$accion: cancelar no cambia el partido ni registra finalizacion', (
      tester,
    ) async {
      final repo = _Repositorio();
      final analitica = _Analitica();
      await _mostrar(tester, repo, analitica);
      await _abrir(tester, editar);
      if (editar) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Cancelar'));
      }
      await tester.pumpAndSettle();
      expect(
        analitica.eventos.where(
          (e) => [
            EventosAnalitica.partidoEditado,
            EventosAnalitica.partidoEliminado,
          ].contains(e.$1),
        ),
        isEmpty,
      );
      expect((await repo.obtenerMisPartidos()).single.titulo, 'Titulo privado');
    });

    testWidgets('$accion: fallo de analitica no impide la operacion', (
      tester,
    ) async {
      final repo = _Repositorio();
      final analitica = _Analitica()..fallar = true;
      await _mostrar(tester, repo, analitica);
      await _abrir(tester, editar);
      await _enviar(tester, editar);
      await _verificarDatos(repo, editar);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$accion: analitica pendiente no retrasa la operacion', (
      tester,
    ) async {
      final repo = _Repositorio();
      final pendiente = Completer<void>();
      final analitica = _Analitica()..pendiente = pendiente.future;
      await _mostrar(tester, repo, analitica);
      await _abrir(tester, editar);
      await _enviar(tester, editar);
      await _verificarDatos(repo, editar);
      pendiente.complete();
      await tester.pumpAndSettle();
      _verificarEvento(analitica, editar);
    });
  }
}
