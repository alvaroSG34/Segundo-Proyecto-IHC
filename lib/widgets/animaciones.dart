import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Hace aparecer a su hijo con fade + leve deslizamiento, con un retraso
/// proporcional a [indice] para lograr una entrada escalonada.
class Aparecer extends StatefulWidget {
  final Widget child;
  final int indice;

  const Aparecer({super.key, required this.child, this.indice = 0});

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _curva = CurvedAnimation(
    parent: _controlador,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.indice), () {
      if (mounted) _controlador.forward();
    });
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

/// Sacude horizontalmente a su hijo cuando se llama a [SacudidaState.sacudir].
/// Se usa con una `GlobalKey<SacudidaState>`.
class Sacudida extends StatefulWidget {
  final Widget child;

  const Sacudida({super.key, required this.child});

  @override
  State<Sacudida> createState() => SacudidaState();
}

class SacudidaState extends State<Sacudida>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  void sacudir() {
    HapticFeedback.mediumImpact();
    _controlador.forward(from: 0);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controlador,
      child: widget.child,
      builder: (context, hijo) {
        final t = _controlador.value;
        final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: hijo);
      },
    );
  }
}
