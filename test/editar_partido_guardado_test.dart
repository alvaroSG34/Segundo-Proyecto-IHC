import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';

void main() {
  testWidgets(
    'edición espera al servidor, bloquea doble envío y atrás y conserva el ID',
    (tester) async {
      final respuesta = Completer<ModeloPartido>();
      var llamadas = 0;
      ModeloPartido? recibido;
      ModeloPartido? resultado;
      await _abrir(tester, (partido) {
        llamadas++;
        recibido = partido;
        return respuesta.future;
      }, (partido) => resultado = partido);
      await _completar(tester);
      await _enviar(tester, esperar: false);

      expect(find.byType(VistaCrearPartido), findsOneWidget);
      expect(resultado, isNull);
      expect(llamadas, 1);
      expect(tester.widget<ElevatedButton>(_guardar()).onPressed, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('partido_titulo')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('partido_ubicacion')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(const Key('partido_cupos_mas')))
            .properties
            .enabled,
        isFalse,
      );
      await tester.tap(_guardar(), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(VistaCrearPartido),
        findsOneWidget,
        reason: 'Atrás no debe abandonar una escritura pendiente.',
      );
      expect(
        llamadas,
        1,
        reason: 'El segundo toque no debe enviar otra petición.',
      );

      respuesta.complete(recibido!);
      await tester.pumpAndSettle();
      expect(find.byType(VistaCrearPartido), findsNothing);
      expect(resultado!.id, 'partido-editado');
      expect(resultado!.cuposOcupados, 1);
      expect(resultado!.titulo, 'Partido de prueba');
      expect(llamadas, 1);
    },
  );

  testWidgets('edición conserva los cambios ante error y permite reintentar', (
    tester,
  ) async {
    final intentos = <ModeloPartido>[];
    ModeloPartido? resultado;
    await _abrir(tester, (partido) async {
      intentos.add(partido);
      if (intentos.length == 1) {
        throw StateError('No se pudo guardar en la prueba.');
      }
      return partido;
    }, (partido) => resultado = partido);
    await _completar(tester);
    await _enviar(tester);
    expect(find.byType(VistaCrearPartido), findsOneWidget);
    expect(find.text('No se pudo guardar en la prueba.'), findsOneWidget);
    expect(resultado, isNull);
    for (final entrada in {
      'partido_titulo': 'Partido de prueba',
      'partido_ubicacion': 'Cancha de prueba',
    }.entries) {
      final campo = tester.widget<TextFormField>(find.byKey(Key(entrada.key)));
      expect(campo.controller!.text, entrada.value);
      expect(campo.enabled, isTrue);
    }
    expect(tester.widget<ElevatedButton>(_guardar()).onPressed, isNotNull);
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('partido_cupos_mas')))
          .properties
          .enabled,
      isTrue,
    );
    await _enviar(tester);
    expect(find.byType(VistaCrearPartido), findsNothing);
    expect(resultado!.id, 'partido-editado');
    expect(resultado!.cuposOcupados, 1);
    expect(intentos.length, 2);
    expect(intentos[1].titulo, intentos[0].titulo);
    expect(intentos[1].ubicacion, intentos[0].ubicacion);
    expect(intentos[1].fechaHora, intentos[0].fechaHora);
    expect(intentos[1].disciplina, intentos[0].disciplina);
    expect(intentos[1].cuposTotales, intentos[0].cuposTotales);
  });

  testWidgets('con jugadores inscritos indica usar Reprogramar', (
    tester,
  ) async {
    await _abrir(tester, (partido) async => partido, (_) {}, ocupados: 3);
    expect(find.textContaining('Usa Reprogramar partido'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('partido_ubicacion')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(const Key('partido_fecha')))
          .properties
          .enabled,
      isFalse,
    );
  });
}

Future<void> _abrir(
  WidgetTester tester,
  Future<ModeloPartido> Function(ModeloPartido) guardar,
  void Function(ModeloPartido?) alVolver, {
  int ocupados = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              alVolver(
                await Navigator.push<ModeloPartido>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VistaCrearPartido(
                      organizadorNombre: 'Estudiante',
                      partidoAEditar: ModeloPartido(
                        id: 'partido-editado',
                        titulo: 'Título original',
                        disciplina: 'Futsal',
                        icono: 'Futsal',
                        ubicacion: 'Lugar original',
                        fechaHora: '15/06/2099 · 09:30',
                        cuposTotales: 6,
                        cuposOcupados: ocupados,
                        organizadorNombre: 'Estudiante',
                        soyOrganizador: true,
                      ),
                      guardarPartido: guardar,
                    ),
                  ),
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Finder _guardar() => find.descendant(
  of: find.byKey(const Key('partido_guardar')),
  matching: find.byType(ElevatedButton),
);

Future<void> _completar(WidgetTester tester) async {
  for (final entrada in {
    'partido_titulo': 'Partido de prueba',
    'partido_ubicacion': 'Cancha de prueba',
  }.entries) {
    final campo = find.byKey(Key(entrada.key));
    await tester.ensureVisible(campo);
    await tester.enterText(campo, entrada.value);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  for (final texto in ['Mañana', '19:00']) {
    await tester.ensureVisible(find.text(texto));
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }
}

Future<void> _enviar(WidgetTester tester, {bool esperar = true}) async {
  await tester.ensureVisible(_guardar());
  await tester.pump();
  await tester.tap(_guardar());
  if (esperar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
