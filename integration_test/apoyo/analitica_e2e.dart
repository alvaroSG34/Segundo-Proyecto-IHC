import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';

// La portada ya no ofrece el botón privado: probar el acceso directo a la ruta.
void abrirRutaProtegidaE2E(WidgetTester tester) {
  final portada = find.byType(VistaInicioPublico);
  final auth = tester.widget<VistaInicioPublico>(portada).servicioAuth ??
      (throw StateError('The E2E landing page must receive an auth service.'));
  Navigator.of(tester.element(portada)).push(
    MaterialPageRoute<void>(
      builder: (_) => VistaMisPartidos(
        servicioAuth: auth,
        controladorExplorar: ControladorExplorar(),
      ),
    ),
  );
}

// Analítica omitida por solicitud: no-op para no romper firmas en los tests E2E.
Future<void> verificarTracksAlTerminar(List<String> inicios) async {
  return;
}
