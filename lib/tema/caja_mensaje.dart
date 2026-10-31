import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'tema_app.dart';

enum TipoMensaje { error, info, exito }

/// Devuelve false al cancelar o cerrar el diálogo sin confirmar.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
  ButtonStyle? estiloConfirmar,
  TextStyle? estiloCancelar,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: TemaApp.titulo(tamano: 20)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: estiloCancelar),
          ),
          ElevatedButton(
            style:
                estiloConfirmar ??
                ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    ) ??
    false;

/// Aviso en línea con ícono (reemplaza a los emojis y cajas con borde grueso).
class CajaMensaje extends StatelessWidget {
  final String texto;
  final TipoMensaje tipo;

  const CajaMensaje({
    super.key,
    required this.texto,
    this.tipo = TipoMensaje.error,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color color, IconData icono) = switch (tipo) {
      TipoMensaje.error => (
        TemaApp.rojoSuave,
        const Color(0xFF991B1B),
        LucideIcons.circleAlert,
      ),
      TipoMensaje.info => (
        TemaApp.azulSuave,
        const Color(0xFF075985),
        LucideIcons.info,
      ),
      TipoMensaje.exito => (
        TemaApp.verdeSuave,
        const Color(0xFF166534),
        LucideIcons.circleCheck,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
