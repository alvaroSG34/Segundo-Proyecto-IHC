import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/tema/caja_mensaje.dart';

void main() {
  for (final ancho in [320.0, 390.0]) {
    testWidgets('la confirmación ofrece opciones equivalentes a $ancho px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(ancho, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await confirmarAccion(
                    context,
                    titulo: '¿Salir del partido?',
                    mensaje: 'Liberarás tu cupo.',
                    textoConfirmar: 'Sí, retirarme',
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

      final cancelar = find.widgetWithText(OutlinedButton, 'Cancelar');
      final confirmar = find.widgetWithText(OutlinedButton, 'Sí, retirarme');
      expect(tester.getSize(cancelar), tester.getSize(confirmar));
      expect(
        tester.widget<OutlinedButton>(cancelar).style,
        tester.widget<OutlinedButton>(confirmar).style,
      );
      await tester.tap(cancelar);
      await tester.pumpAndSettle();
      expect(resultado, isFalse);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(resultado, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
