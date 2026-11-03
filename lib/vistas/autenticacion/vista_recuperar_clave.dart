import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../tema/caja_mensaje.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../tema/tema_app.dart';
import '../../widgets/boton_accion.dart';

/// Solicita a Supabase las instrucciones de recuperación de contraseña.
class VistaRecuperarClave extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;

  const VistaRecuperarClave({super.key, required this.servicioAuth});

  @override
  State<VistaRecuperarClave> createState() => _VistaRecuperarClaveState();
}

class _VistaRecuperarClaveState extends State<VistaRecuperarClave> {
  final _controladorCorreo = TextEditingController();
  bool _enviado = false;
  String? _mensajeError;
  bool _cargando = false;

  @override
  void dispose() {
    _controladorCorreo.dispose();
    super.dispose();
  }

  Future<void> _solicitarRecuperacion() async {
    final correo = _controladorCorreo.text.trim();
    if (correo.isEmpty || !correo.contains('@')) {
      setState(() => _mensajeError = 'Ingresa un correo electrónico válido');
      return;
    }

    setState(() {
      _cargando = true;
      _mensajeError = null;
    });

    final error = await widget.servicioAuth.recuperarContrasena(correo);

    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (error != null) {
        _mensajeError = error;
      } else {
        _enviado = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _enviado ? _construirVistaExito() : _construirFormulario(),
      ),
    );
  }

  Widget _construirFormulario() {
    return Column(
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
              LucideIcons.mailCheck,
              size: 34,
              color: TemaApp.azulDeportivo,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¿Problemas para acceder?',
          textAlign: TextAlign.center,
          style: TemaApp.titulo(tamano: 24),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa tu correo institucional y te enviaremos las instrucciones de restablecimiento.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: TemaApp.textoSecundario),
        ),
        const SizedBox(height: 28),

        TextFormField(
          key: const Key('recuperar_correo'),
          controller: _controladorCorreo,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo Institucional',
            prefixIcon: Icon(LucideIcons.mail),
          ),
        ),

        if (_mensajeError != null) ...[
          const SizedBox(height: 14),
          CajaMensaje(texto: _mensajeError!),
        ],

        const SizedBox(height: 24),

        BotonAccion(
          key: const Key('recuperar_enviar'),
          texto: 'Enviar instrucciones',
          estado: _cargando ? EstadoBoton.cargando : EstadoBoton.normal,
          onPressed: _solicitarRecuperacion,
        ),
      ],
    );
  }

  Widget _construirVistaExito() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: TemaApp.tarjeta(radio: 22),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: TemaApp.verdeSuave,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  LucideIcons.circleCheck,
                  size: 32,
                  color: TemaApp.verdeDeportivo,
                ),
              ),
              const SizedBox(height: 14),
              Text('¡Solicitud procesada!', style: TemaApp.titulo(tamano: 20)),
              const SizedBox(height: 8),
              Text(
                'Procesamos la solicitud para ${_controladorCorreo.text.trim()}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: TemaApp.textoSecundario,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const CajaMensaje(
                tipo: TipoMensaje.info,
                texto: 'Si el correo está registrado, Supabase envía un enlace para crear una nueva contraseña. Revisa también la carpeta de spam.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('recuperar_volver'),
          style: ElevatedButton.styleFrom(
            visualDensity: VisualDensity.standard,
            minimumSize: const Size(48, 52),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}
