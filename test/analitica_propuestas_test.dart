import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/propuesta_equipos.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';
import 'resultado_partido_test.dart' show preparar;

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

  @override
  Future<void> responderPropuesta(
    String id,
    String revision,
    bool acepta,
  ) async {
    if (pendiente != null) await pendiente;
    if (fallar) throw StateError('Motivo privado del servidor');
    await super.responderPropuesta(id, revision, acepta);
  }
}

PropuestaEquipos _propuesta() => PropuestaEquipos(
  revision: '',
  equipoA: ['u-lorgio'],
  equipoB: ['u-diego'],
  capitanRivalId: 'u-diego',
);

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
      cuposTotales: 2,
      cuposOcupados: 1,
      organizadorNombre: 'Lorgio',
    ),
  );
  final auth = ServicioAutenticacionFalso(repo);
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await repo.unirseAPartido('partido-1');
  repo.usarSesionDe('u-lorgio', 'Lorgio');
  await repo.guardarPropuesta('partido-1', _propuesta());
  await auth.iniciarSesion('diego@unisport.edu', '123456');
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
  await _tocar(tester, 'Ver equipos');
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final boton = find.text(texto);
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void _verificar(_Analitica analitica, bool acepta) {
  expect(
    analitica.eventos.last.$1,
    acepta
        ? EventosAnalitica.propuestaAceptada
        : EventosAnalitica.propuestaRechazada,
  );
  final id = analitica.eventos.last.$2['intento_id'];
  expect(
    analitica.eventos.any(
      (e) =>
          e.$1 == EventosAnalitica.respuestaPropuestaIniciada &&
          e.$2['intento_id'] == id,
    ),
    isTrue,
  );
  expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  expect(analitica.eventos.last.$2, {'intento_id': id});
}

void main() {
  for (final disputar in [false, true]) {
    testWidgets(
      'validar resultado: inicio, cancelación, error y decisión, disputa: $disputar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = await preparar();
        await repo.registrarResultado('m-1', 2, 1);
        repo.usarSesionDe('capitan', 'Capitán rival');
        final analitica = _Analitica();
        await tester.pumpWidget(
          MaterialApp(
            home: VistaEquipos(
              partido: (await repo.obtenerPartidosUnidos()).single,
              repositorio: repo,
              usuarioId: 'capitan',
              servicioAnalitica: analitica,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (disputar) {
          await _tocar(tester, 'Disputar resultado');
          expect(
            analitica.eventos.single.$1,
            EventosAnalitica.validacionResultadoIniciada,
          );
          await _tocar(tester, 'Cancelar');
          expect(analitica.eventos, hasLength(1));
          await _tocar(tester, 'Disputar resultado');
          await _tocar(tester, 'Enviar disputa');
          expect(
            analitica.eventos.last.$1,
            EventosAnalitica.validacionResultadoFallida,
          );
          expect(
            analitica.eventos.last.$2['codigo_error'],
            'servicio_partidos',
          );
          await _tocar(tester, 'Disputar resultado');
          await tester.enterText(find.byType(TextField), 'Motivo privado');
          await _tocar(tester, 'Enviar disputa');
        } else {
          await _tocar(tester, 'Confirmar resultado');
        }
        final ultimo = analitica.eventos.last;
        expect(
          ultimo.$1,
          disputar
              ? EventosAnalitica.resultadoDisputado
              : EventosAnalitica.resultadoConfirmado,
        );
        expect(
          analitica.eventos
              .where((e) => e.$2['intento_id'] == ultimo.$2['intento_id'])
              .map((e) => e.$1),
          [EventosAnalitica.validacionResultadoIniciada, ultimo.$1],
        );
        expect(ultimo.$2, {'intento_id': ultimo.$2['intento_id']});
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final acepta in [true, false]) {
    final accion = acepta ? 'Aceptar' : 'Rechazar';
    testWidgets(
      '$accion: solo registra la respuesta confirmada sin datos de jugadores',
      (tester) async {
        final repo = _Repositorio();
        final analitica = _Analitica();
        await _mostrar(tester, repo, analitica);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.propuestaAceptada,
              EventosAnalitica.propuestaRechazada,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        repo.fallar = true;
        await _tocar(tester, accion);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.propuestaAceptada,
              EventosAnalitica.propuestaRechazada,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        expect(
          (await repo.obtenerPropuesta('partido-1'))!.estado,
          EstadoPropuesta.pendiente,
        );
        repo.fallar = false;
        final respuesta = Completer<void>();
        repo.pendiente = respuesta.future;
        await _tocar(tester, accion);
        expect(
          analitica.eventos.where(
            (e) => [
              EventosAnalitica.propuestaAceptada,
              EventosAnalitica.propuestaRechazada,
            ].contains(e.$1),
          ),
          isEmpty,
        );
        respuesta.complete();
        await tester.pumpAndSettle();
        _verificar(analitica, acepta);
        expect(
          (await repo.obtenerPropuesta('partido-1'))!.estado,
          acepta ? EstadoPropuesta.aceptada : EstadoPropuesta.rechazada,
        );
        expect(find.text(accion), findsNothing);
      },
    );

    testWidgets('$accion: fallo de analitica no impide responder', (
      tester,
    ) async {
      final repo = _Repositorio();
      final analitica = _Analitica()..fallar = true;
      await _mostrar(tester, repo, analitica);
      await _tocar(tester, accion);
      expect(
        (await repo.obtenerPropuesta('partido-1'))!.estado,
        acepta ? EstadoPropuesta.aceptada : EstadoPropuesta.rechazada,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$accion: analitica pendiente no retrasa la respuesta', (
      tester,
    ) async {
      final repo = _Repositorio();
      final pendiente = Completer<void>();
      final analitica = _Analitica()..pendiente = pendiente.future;
      await _mostrar(tester, repo, analitica);
      await _tocar(tester, accion);
      expect(
        (await repo.obtenerPropuesta('partido-1'))!.estado,
        acepta ? EstadoPropuesta.aceptada : EstadoPropuesta.rechazada,
      );
      pendiente.complete();
      await tester.pumpAndSettle();
      _verificar(analitica, acepta);
    });
  }

  testWidgets(
    'una propuesta reemplazada no genera evento hasta responder su revision actual',
    (tester) async {
      final repo = _Repositorio();
      final analitica = _Analitica();
      await _mostrar(tester, repo, analitica);
      repo.usarSesionDe('u-lorgio', 'Lorgio');
      await repo.guardarPropuesta('partido-1', _propuesta());
      repo.usarSesionDe('u-diego', 'Diego');
      await _tocar(tester, 'Aceptar');
      expect(
        analitica.eventos.where(
          (e) => [
            EventosAnalitica.propuestaAceptada,
            EventosAnalitica.propuestaRechazada,
          ].contains(e.$1),
        ),
        isEmpty,
      );
      expect(
        (await repo.obtenerPropuesta('partido-1'))!.estado,
        EstadoPropuesta.pendiente,
      );
      await _tocar(tester, 'Aceptar');
      _verificar(analitica, true);
    },
  );
}
