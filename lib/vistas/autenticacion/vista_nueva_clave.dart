import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../tema/caja_mensaje.dart';
import '../../tema/tema_app.dart';
import '../../widgets/boton_accion.dart';
import '../../widgets/campo_clave.dart';

class VistaNuevaClave extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;

  const VistaNuevaClave({super.key, required this.servicioAuth});

  @override
  State<VistaNuevaClave> createState() => _VistaNuevaClaveState();
}

class _VistaNuevaClaveState extends State<VistaNuevaClave> {
  final _formulario = GlobalKey<FormState>();
  final _clave = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _guardando = false;
  bool _guardada = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final error = await widget.servicioAuth.guardarContrasenaRecuperada(
      _clave.text,
    );
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _guardada = error == null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TemaApp.fondo,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _guardada ? _exito() : _formularioNuevaClave(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formularioNuevaClave() => Form(
    key: _formulario,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: TemaApp.azulSuave,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              LucideIcons.keyRound,
              size: 34,
              color: TemaApp.azulDeportivo,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Crea una nueva contraseña',
          textAlign: TextAlign.center,
          style: TemaApp.titulo(tamano: 25),
        ),
        const SizedBox(height: 8),
        const Text(
          'El enlace de tu correo ya confirmó tu identidad. No necesitas recordar la contraseña anterior.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TemaApp.textoSecundario, height: 1.4),
        ),
        const SizedBox(height: 28),
        CampoClave(
          key: const Key('recuperacion_clave_nueva'),
          controller: _clave,
          etiqueta: 'Nueva contraseña',
          validator: (valor) => valor == null || valor.length < 6
              ? 'Usa al menos 6 caracteres'
              : null,
        ),
        const SizedBox(height: 14),
        CampoClave(
          key: const Key('recuperacion_clave_confirmar'),
          controller: _confirmacion,
          etiqueta: 'Confirmar nueva contraseña',
          onSubmitted: _guardar,
          validator: (valor) =>
              valor != _clave.text ? 'Las contraseñas no coinciden' : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          CajaMensaje(texto: _error!),
        ],
        const SizedBox(height: 22),
        BotonAccion(
          key: const Key('recuperacion_guardar_clave'),
          texto: 'Guardar nueva contraseña',
          estado: _guardando ? EstadoBoton.cargando : EstadoBoton.normal,
          onPressed: _guardar,
        ),
      ],
    ),
  );

  Widget _exito() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: TemaApp.tarjeta(radio: 22),
        child: Column(
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: 58,
              color: TemaApp.verdeDeportivo,
            ),
            const SizedBox(height: 14),
            Text('Contraseña actualizada', style: TemaApp.titulo(tamano: 22)),
            const SizedBox(height: 8),
            const Text(
              'Ya puedes continuar en UniSport con tu nueva contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TemaApp.textoSecundario),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        key: const Key('recuperacion_continuar'),
        onPressed: widget.servicioAuth.finalizarRecuperacionContrasena,
        child: const Text('Continuar a UniSport'),
      ),
    ],
  );
}
