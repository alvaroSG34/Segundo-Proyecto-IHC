import 'package:material_ui/material_ui.dart';

import '../../config/enlaces_publicos.dart';
import '../../servicios/autenticacion/servicio_autenticacion.dart';

import 'package:unisport/tema/iconos_app.dart';

import '../../tema/iconos_deporte.dart';
import '../../tema/tema_app.dart';
import '../autenticacion/pantallas_autenticacion.dart' deferred as auth_screens;
import 'vista_principal_diferida.dart';

/// Ruta Pública: Portada de bienvenida a UniSport accesible sin sesión
class VistaInicioPublico extends StatefulWidget {
  final ServicioAutenticacion? servicioAuth;
  final bool estaPreparando;

  const VistaInicioPublico({
    super.key,
    this.servicioAuth,
    this.estaPreparando = false,
  });

  @override
  State<VistaInicioPublico> createState() => _VistaInicioPublicoState();
}

class _VistaInicioPublicoState extends State<VistaInicioPublico> {
  @override
  Widget build(BuildContext context) {
    final servicioAuth = widget.servicioAuth;
    if (servicioAuth?.estaAutenticado ?? false) {
      return VistaPrincipalDiferida(servicioAuth: servicioAuth!);
    }
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TemaApp.verdeDeportivo,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      LucideIcons.trophy,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('UniSport', style: TemaApp.titulo(tamano: 21)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _construirHero(),
                const SizedBox(height: 28),
                Text(
                  'Disciplinas disponibles',
                  style: TemaApp.titulo(tamano: 17),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    _ChipDisciplina(disciplina: 'Futsal'),
                    SizedBox(width: 10),
                    _ChipDisciplina(disciplina: 'Básquet'),
                    SizedBox(width: 10),
                    _ChipDisciplina(disciplina: 'Vóley'),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.standard,
                    minimumSize: const Size(48, 52),
                  ),
                  onPressed: servicioAuth == null
                      ? null
                      : () async {
                          await auth_screens.loadLibrary();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => auth_screens.VistaLogin(
                                servicioAuth: servicioAuth,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(LucideIcons.logIn, size: 19),
                  label: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.standard,
                    minimumSize: const Size(48, 52),
                  ),
                  onPressed: servicioAuth == null
                      ? null
                      : () async {
                          await auth_screens.loadLibrary();
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => auth_screens.VistaRegistro(
                                servicioAuth: servicioAuth,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(LucideIcons.userPlus, size: 19),
                  label: const Text('Crear nueva cuenta'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('inicio_politica_privacidad'),
                  onPressed: () async {
                    final abierta = await abrirPoliticaPrivacidad();
                    if (!abierta && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se pudo abrir la política de privacidad.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.shieldCheck, size: 18),
                  label: const Text('Política de privacidad'),
                ),
                if (widget.estaPreparando) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Preparando el inicio de sesión…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TemaApp.textoSecundario,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15803D), Color(0xFF0F766E)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3316A34A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            bottom: -44,
            child: Icon(
              LucideIcons.trophy,
              size: 150,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: TemaApp.verdeOscuro,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.mapPin, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Canchas del campus',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Crea partidos y completa tu equipo',
                style: TemaApp.titulo(tamano: 26, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.only(right: 40),
                child: Text(
                  'La plataforma universitaria para coordinar encuentros deportivos sin fricción.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipDisciplina extends StatelessWidget {
  final String disciplina;

  const _ChipDisciplina({required this.disciplina});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: TemaApp.tarjeta(radio: 16),
        child: Column(
          children: [
            InsigniaDeporte(disciplina: disciplina, tamano: 44),
            const SizedBox(height: 10),
            Text(
              disciplina,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: TemaApp.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
