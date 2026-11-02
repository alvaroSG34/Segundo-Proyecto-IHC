import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tema/tema_app.dart';

enum EstadoBoton { normal, cargando, exito }

/// Botón primario que pasa por texto -> spinner -> check.
class BotonAccion extends StatelessWidget {
  final String texto;
  final EstadoBoton estado;
  final VoidCallback onPressed;

  const BotonAccion({
    super.key,
    required this.texto,
    required this.onPressed,
    this.estado = EstadoBoton.normal,
  });

  @override
  Widget build(BuildContext context) {
    final Widget contenido = switch (estado) {
      EstadoBoton.cargando => const SizedBox(
        key: ValueKey('cargando'),
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      ),
      EstadoBoton.exito => const Icon(
        LucideIcons.check,
        key: ValueKey('exito'),
        size: 24,
        color: Colors.white,
      ),
      EstadoBoton.normal => Text(texto, key: const ValueKey('texto')),
    };

    return Semantics(
      label: texto,
      button: true,
      enabled: estado == EstadoBoton.normal,
      excludeSemantics: true,
      onTap: estado == EstadoBoton.normal ? onPressed : null,
      value: switch (estado) {
        EstadoBoton.normal => '',
        EstadoBoton.cargando => 'Cargando',
        EstadoBoton.exito => 'Completado',
      },
      liveRegion: estado != EstadoBoton.normal,
      child: ElevatedButton(
        onPressed: estado == EstadoBoton.normal ? onPressed : null,
        style: ElevatedButton.styleFrom(
          visualDensity: VisualDensity.standard,
          minimumSize: const Size(double.infinity, 52),
          disabledBackgroundColor: estado == EstadoBoton.exito
              ? TemaApp.verdeOscuro
              : TemaApp.verdeDeportivo,
          disabledForegroundColor: Colors.white,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (hijo, animacion) => ScaleTransition(
            scale: animacion,
            child: FadeTransition(opacity: animacion, child: hijo),
          ),
          child: ExcludeSemantics(key: ValueKey(estado), child: contenido),
        ),
      ),
    );
  }
}
