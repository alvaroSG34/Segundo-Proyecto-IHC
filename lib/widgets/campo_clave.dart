import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tema/tema_app.dart';

/// Campo de contraseña que muestra balones deportivos que caen y rebotan
/// (fútbol, básquet, vóley, tenis) en lugar de asteriscos. Por debajo hay un TextField real (invisible) que recibe el
/// teclado, así que pegar, borrar y los gestores de contraseñas siguen funcionando.
class CampoClave extends StatefulWidget {
  final TextEditingController controller;
  final String etiqueta;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  const CampoClave({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.validator,
    this.onSubmitted,
  });

  @override
  State<CampoClave> createState() => _CampoClaveState();
}

class _CampoClaveState extends State<CampoClave>
    with SingleTickerProviderStateMixin {
  static const int _maxPelotas = 9;

  static const List<(IconData, Color)> _balones = [
    (Icons.sports_soccer, TemaApp.verdeDeportivo),
    (Icons.sports_basketball, Color(0xFFEA580C)),
    (Icons.sports_volleyball, Color(0xFFCA8A04)),
    (Icons.sports_tennis, TemaApp.azulDeportivo),
  ];

  final FocusNode _foco = FocusNode();
  late final AnimationController _parpadeo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 530),
  )..repeat(reverse: true);

  bool _oculta = true;

  void _refrescar() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _foco.addListener(_refrescar);
    widget.controller.addListener(_refrescar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refrescar);
    _foco.dispose();
    _parpadeo.dispose();
    super.dispose();
  }

  Widget _cursor() => FadeTransition(
    opacity: _parpadeo,
    child: Container(
      width: 2,
      height: 20,
      decoration: BoxDecoration(
        color: TemaApp.verdeDeportivo,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _contenido(String texto, bool enfocado) {
    if (texto.isEmpty) {
      return Row(
        children: [
          if (enfocado) _cursor(),
          if (enfocado) const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                color: TemaApp.textoSecundario,
              ),
            ),
          ),
        ],
      );
    }

    if (!_oculta) {
      return Row(
        children: [
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                fontSize: 16,
                color: TemaApp.textoPrincipal,
              ),
            ),
          ),
          if (enfocado) ...[const SizedBox(width: 2), _cursor()],
        ],
      );
    }

    final inicio = texto.length > _maxPelotas ? texto.length - _maxPelotas : 0;
    return Row(
      children: [
        for (var i = inicio; i < texto.length; i++)
          TweenAnimationBuilder<double>(
            key: ValueKey(i),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.bounceOut,
            builder: (context, valor, _) {
              final (icono, color) = _balones[i % _balones.length];
              return Transform.translate(
                offset: Offset(0, -22 * (1 - valor)),
                child: Transform.rotate(
                  angle: (1 - valor) * -math.pi,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(icono, size: 21, color: color),
                  ),
                ),
              );
            },
          ),
        if (enfocado) _cursor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (campo) {
        final error = campo.errorText;
        final enfocado = _foco.hasFocus;
        final colorBorde = error != null
            ? TemaApp.rojoAlerta
            : enfocado
            ? TemaApp.verdeDeportivo
            : TemaApp.borde;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 56,
                  padding: const EdgeInsets.only(left: 12, right: 56),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorBorde,
                      width: enfocado || error != null ? 1.8 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.lock,
                        size: 22,
                        color: TemaApp.textoSecundario,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRect(
                          child: ExcludeSemantics(
                            child: _contenido(widget.controller.text, enfocado),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // TextField real e invisible: recibe teclado, pegado y borrado.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: 56,
                  child: Semantics(
                    container: true,
                    label: widget.etiqueta,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _foco,
                      obscureText: _oculta,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      onSubmitted: (_) => widget.onSubmitted?.call(),
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        filled: false,
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Semantics(
                      container: true,
                      button: true,
                      enabled: true,
                      excludeSemantics: true,
                      onTap: () => setState(() => _oculta = !_oculta),
                      label: _oculta
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      child: IconButton(
                        visualDensity: VisualDensity.standard,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: _oculta
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _oculta ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 20,
                        ),
                        color: TemaApp.textoSecundario,
                        onPressed: () => setState(() => _oculta = !_oculta),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TemaApp.rojoAlerta,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
