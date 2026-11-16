import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../servicios/analitica/servicio_analitica.dart';
import '../servicios/autenticacion/servicio_autenticacion.dart';
import '../servicios/partidos/controlador_explorar.dart';
import '../servicios/partidos/repositorio_partidos.dart';
import '../vistas/partidos/vista_explorar_partidos.dart';
import '../vistas/partidos/vista_historial.dart';
import '../vistas/partidos/vista_mis_partidos.dart';

class BarraNavegacionPartidos extends StatelessWidget {
  final int selectedIndex;
  final ServicioAutenticacion servicioAuth;
  final RepositorioPartidos repositorioPartidos;
  final ServicioAnalitica servicioAnalitica;
  final ControladorExplorar controladorExplorar;
  final DateTime? referenciaTemporal;

  const BarraNavegacionPartidos({
    super.key,
    required this.selectedIndex,
    required this.servicioAuth,
    required this.repositorioPartidos,
    required this.servicioAnalitica,
    required this.controladorExplorar,
    this.referenciaTemporal,
  });

  void _navegarA(BuildContext context, int indice) {
    if (indice == selectedIndex) return;

    final Widget destino = switch (indice) {
      0 => VistaExplorarPartidos(
        servicioAuth: servicioAuth,
        repositorioPartidos: repositorioPartidos,
        servicioAnalitica: servicioAnalitica,
        controladorExplorar: controladorExplorar,
        referenciaTemporal: referenciaTemporal,
      ),
      1 => VistaMisPartidos(
        servicioAuth: servicioAuth,
        repositorioPartidos: repositorioPartidos,
        servicioAnalitica: servicioAnalitica,
        controladorExplorar: controladorExplorar,
        referenciaTemporal: referenciaTemporal,
      ),
      2 => VistaHistorial(
        servicioAuth: servicioAuth,
        repositorioPartidos: repositorioPartidos,
        servicioAnalitica: servicioAnalitica,
        controladorExplorar: controladorExplorar,
        referenciaTemporal: referenciaTemporal,
      ),
      _ => throw RangeError.range(indice, 0, 2, 'indice'),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth.clamp(0, 480),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (indice) => _navegarA(context, indice),
              destinations: const [
                NavigationDestination(
                  icon: Icon(LucideIcons.compass),
                  label: 'Explorar',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.calendarDays),
                  label: 'Mis partidos',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.history),
                  label: 'Historial',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
