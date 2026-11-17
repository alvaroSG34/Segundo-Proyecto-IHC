import 'package:material_ui/material_ui.dart';

import '../../servicios/autenticacion/servicio_autenticacion.dart';
import '../../servicios/analitica/servicio_analitica.dart';
import 'vista_principal.dart' deferred as principal;

/// Carga las pantallas autenticadas solo cuando el usuario llega a ellas.
class VistaPrincipalDiferida extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;
  final ServicioAnalitica? servicioAnalitica;

  const VistaPrincipalDiferida({
    super.key,
    required this.servicioAuth,
    this.servicioAnalitica,
  });

  @override
  State<VistaPrincipalDiferida> createState() => _VistaPrincipalDiferidaState();
}

class _VistaPrincipalDiferidaState extends State<VistaPrincipalDiferida> {
  late final Future<void> _carga = principal.loadLibrary();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _carga,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('No se pudo cargar la pantalla principal.')),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return principal.VistaPrincipal(
        servicioAuth: widget.servicioAuth,
        servicioAnalitica: widget.servicioAnalitica,
      );
    },
  );
}
