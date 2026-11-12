import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/analitica/servicio_analitica.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/widgets/panel_filtros.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

class _Analitica implements ServicioAnalitica {
  final eventos = <(String, Map<String, dynamic>)>[];
  bool fallar = false;
  Future<void>? pendiente;

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => const [];

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    if (fallar) throw StateError('Fallo de analitica');
    if (pendiente != null) await pendiente;
    eventos.add((evento, Map.of(props)));
  }
}

class _Repositorio extends RepositorioEnMemoria {
  Future<List<ModeloPartido>> Function(FiltroPartidos)? consultar;
  bool fallarLugares = false;

  @override
  Future<List<ModeloPartido>> buscarPartidos(
    FiltroPartidos filtro, {
    DateTime? ahora,
  }) async => consultar == null
      ? super.buscarPartidos(filtro, ahora: ahora)
      : consultar!(filtro);

  @override
  Future<List<String>> obtenerLugares() async {
    if (fallarLugares) {
      throw StateError('Texto con datos que no deben enviarse');
    }
    return super.obtenerLugares();
  }
}

ModeloPartido _partido() => ModeloPartido(
  id: 'p1',
  titulo: 'Futsal nocturno',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Cancha privada',
  fechaHora: '10/10/2099 · 19:00',
  cuposTotales: 10,
  cuposOcupados: 2,
  organizadorNombre: 'Organizador',
);

Future<void> _mostrar(
  WidgetTester tester,
  _Analitica analitica,
  _Repositorio repositorio,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = ServicioAutenticacionFalso(repositorio);
  repositorio.sembrar('u-lorgio', _partido());
  await auth.iniciarSesion('diego@unisport.edu', '123456');
  await tester.pumpWidget(
    MaterialApp(
      home: VistaExplorarPartidos(
        servicioAuth: auth,
        repositorioPartidos: repositorio,
        servicioAnalitica: analitica,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _filtrar(WidgetTester tester, FiltroPartidos filtro) {
  tester.widget<PanelFiltros>(find.byType(PanelFiltros)).alCambiar(filtro);
}

Future<void> _esperarEvento(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('abrir y actualizar no cuentan como una busqueda', (
    tester,
  ) async {
    final analitica = _Analitica();
    await _mostrar(tester, analitica, _Repositorio());
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await _esperarEvento(tester);
    expect(analitica.eventos, isEmpty);
  });

  testWidgets(
    'agrupa escritura continua y registra solamente el resultado final',
    (tester) async {
      final analitica = _Analitica();
      await _mostrar(tester, analitica, _Repositorio());
      for (final texto in ['F', 'Fu', 'Futsal']) {
        await tester.enterText(find.byType(TextField), texto);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(analitica.eventos, isEmpty);
      await _esperarEvento(tester);
      expect(analitica.eventos, hasLength(2));
      expect(analitica.eventos.last.$1, EventosAnalitica.busquedaRealizada);
      expect(analitica.eventos.first.$1, EventosAnalitica.busquedaIniciada);
      expect(
        analitica.eventos.first.$2['intento_id'],
        analitica.eventos.last.$2['intento_id'],
      );
      expect(analitica.eventos.last.$2, {
        'intento_id': analitica.eventos.last.$2['intento_id'],
        'filtros_activos': ['texto', 'periodo'],
        'cantidad_resultados': 1,
      });
    },
  );

  testWidgets(
    'cero resultados registra realizada y sin resultados sin valores privados',
    (tester) async {
      final analitica = _Analitica();
      await _mostrar(tester, analitica, _Repositorio());
      _filtrar(
        tester,
        FiltroPartidos(
          texto: 'nombre privado',
          deporte: 'Futsal',
          fecha: FiltroFecha.rango,
          desde: DateTime(2099, 10, 10),
          hasta: DateTime(2099, 10, 11),
          lugar: 'domicilio privado',
          soloConCupos: true,
          periodo: PeriodoPartidos.proximos,
        ),
      );
      await _esperarEvento(tester);
      expect(analitica.eventos.map((e) => e.$1), [
        EventosAnalitica.busquedaIniciada,
        EventosAnalitica.busquedaRealizada,
        EventosAnalitica.busquedaSinResultados,
      ]);
      for (final evento in analitica.eventos) {
        expect(evento.$2, {
          'intento_id': analitica.eventos.first.$2['intento_id'],
          'filtros_activos': [
            'texto',
            'deporte',
            'fecha',
            'lugar',
            'cupos',
            'periodo',
          ],
          if (evento.$1 != EventosAnalitica.busquedaIniciada)
            'cantidad_resultados': 0,
        });
      }
    },
  );

  testWidgets(
    'una consulta fallida registra codigo fijo y permite reintentar',
    (tester) async {
      final analitica = _Analitica();
      final repositorio = _Repositorio();
      await _mostrar(tester, analitica, repositorio);
      repositorio.consultar = (_) async => throw Exception('mensaje privado');
      _filtrar(tester, const FiltroPartidos(texto: 'Futsal'));
      await _esperarEvento(tester);
      expect(analitica.eventos, hasLength(2));
      expect(analitica.eventos.last.$1, EventosAnalitica.busquedaFallida);
      expect(analitica.eventos.first.$1, EventosAnalitica.busquedaIniciada);
      expect(
        analitica.eventos.first.$2['intento_id'],
        analitica.eventos.last.$2['intento_id'],
      );
      expect(analitica.eventos.last.$2, {
        'intento_id': analitica.eventos.last.$2['intento_id'],
        'filtros_activos': ['texto'],
        'codigo_error': 'consulta_fallida',
      });
      repositorio.consultar = null;
      _filtrar(tester, const FiltroPartidos(texto: 'Futsal'));
      await _esperarEvento(tester);
      expect(analitica.eventos.last.$1, EventosAnalitica.busquedaRealizada);
    },
  );

  testWidgets('distingue el fallo al obtener lugares', (tester) async {
    final analitica = _Analitica();
    final repositorio = _Repositorio();
    await _mostrar(tester, analitica, repositorio);
    repositorio.fallarLugares = true;
    _filtrar(tester, const FiltroPartidos());
    await _esperarEvento(tester);
    expect(analitica.eventos, hasLength(2));
    expect(analitica.eventos.last.$1, EventosAnalitica.busquedaFallida);
    expect(analitica.eventos.last.$2, {
      'filtros_activos': <String>[],
      'codigo_error': 'carga_lugares_fallida',
      'intento_id': analitica.eventos.last.$2['intento_id'],
    });
  });

  testWidgets(
    'una respuesta antigua no genera eventos ni reemplaza resultados nuevos',
    (tester) async {
      final analitica = _Analitica();
      final repositorio = _Repositorio();
      await _mostrar(tester, analitica, repositorio);
      final antigua = Completer<List<ModeloPartido>>();
      repositorio.consultar = (f) async =>
          f.texto == 'vieja' ? antigua.future : [_partido()];
      _filtrar(tester, const FiltroPartidos(texto: 'vieja'));
      await tester.pump();
      _filtrar(tester, const FiltroPartidos(texto: 'nueva'));
      await _esperarEvento(tester);
      antigua.complete([]);
      await _esperarEvento(tester);
      expect(analitica.eventos, hasLength(2));
      expect(analitica.eventos.last.$2['cantidad_resultados'], 1);
      expect(find.text('1 partido encontrado'), findsOneWidget);
    },
  );

  testWidgets('cerrar cancela el evento pendiente', (tester) async {
    final analitica = _Analitica();
    await _mostrar(tester, analitica, _Repositorio());
    _filtrar(tester, const FiltroPartidos(texto: 'Futsal'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await _esperarEvento(tester);
    expect(analitica.eventos, isEmpty);
  });

  testWidgets('una analitica fallida no impide mostrar los partidos', (
    tester,
  ) async {
    final analitica = _Analitica()..fallar = true;
    await _mostrar(tester, analitica, _Repositorio());
    await tester.enterText(find.byType(TextField), 'Futsal');
    await _esperarEvento(tester);
    expect(find.text('1 partido encontrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una analitica pendiente no deja la pantalla cargando', (
    tester,
  ) async {
    final pendiente = Completer<void>();
    final analitica = _Analitica()..pendiente = pendiente.future;
    await _mostrar(tester, analitica, _Repositorio());
    _filtrar(tester, const FiltroPartidos(texto: 'Futsal'));
    await _esperarEvento(tester);
    expect(find.text('1 partido encontrado'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pendiente.complete();
    await tester.pumpAndSettle();
    expect(analitica.eventos, hasLength(2));
  });
}
