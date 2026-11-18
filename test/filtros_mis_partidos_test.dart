import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/widgets/filtros_mis_partidos.dart';

void main() {
  testWidgets('aplica deporte y fecha seleccionados', (tester) async {
    FiltroPartidos? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await mostrarFiltrosMisPartidos(
                  context,
                  const FiltroPartidos(),
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
    await tester.tap(find.byKey(const Key('mis_partidos_filtro_deporte')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futsal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mis_partidos_filtro_fecha')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoy').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mis_partidos_aplicar_filtros')));
    await tester.pumpAndSettle();
    expect(resultado?.deporte, 'Futsal');
    expect(resultado?.fecha, FiltroFecha.hoy);
  });
}
