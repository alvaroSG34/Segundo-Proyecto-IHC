import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/tema/tema_app.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

import 'tarjeta_partido_test.dart' show crearPartido;

// Fixture local: genera capturas reales del widget, sin cuentas ni servidor.
// flutter test test/evidencias_clase22_test.dart --update-goldens
//   --dart-define=CLASE22_CAPTURA=antes (o despues)
void main() {
  const etapa = String.fromEnvironment('CLASE22_CAPTURA');
  testWidgets('captura local de la decisión de entrar como suplente', (
    tester,
  ) async {
    // Flutter usa Ahem en tests. Sustituirla por Arial local solo para capturas
    // legibles; no se distribuye la fuente ni se modifica el tema del producto.
    const rutaFuente = String.fromEnvironment(
      'CLASE22_FUENTE',
      defaultValue: 'C:/Windows/Fonts/arial.ttf',
    );
    final bytes = ByteData.sublistView(File(rutaFuente).readAsBytesSync());
    for (final familia in [
      'EvidenciaArial',
      'Inter_regular',
      'Inter_500',
      'Inter_600',
      'Inter_700',
      'Plus Jakarta Sans_800',
      'PlusJakartaSans_800',
    ]) {
      final fuente = FontLoader(familia)..addFont(Future.value(bytes));
      await fuente.load();
    }
    final manifiesto = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    ) as List<dynamic>;
    for (final entrada in manifiesto) {
      final fuente = FontLoader(entrada['family'] as String);
      for (final font in entrada['fonts'] as List<dynamic>) {
        fuente.addFont(rootBundle.load(font['asset'] as String));
      }
      await fuente.load();
    }
    await tester.binding.setSurfaceSize(const Size(480, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: TemaApp.tema.copyWith(
          textTheme: TemaApp.tema.textTheme.apply(fontFamily: 'EvidenciaArial'),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Explorar partidos')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Clase 22 · Entorno local de prueba',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('Datos ficticios · Sin conexión a Supabase'),
                const SizedBox(height: 20),
                TarjetaPartido(
                  partido: crearPartido(
                    estado: EstadoPartido.equipoCompleto,
                    soyOrganizador: false,
                    estoyUnido: false,
                  ),
                  onEntrarEnEspera: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../evidencias/clase-22-suplentes-$etapa.png'),
    );
  }, skip: etapa != 'antes' && etapa != 'despues');
}
