import 'package:flutter/material.dart';

import '../../servicios/autenticacion/servicio_autenticacion.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../tema/iconos_deporte.dart';
import '../../tema/tema_app.dart';
import '../partidos/vista_explorar_partidos.dart';
import '../autenticacion/vista_login.dart';
import '../autenticacion/vista_registro.dart';
import '../partidos/vista_mis_partidos.dart';

/// Ruta Pública: Portada de bienvenida a UniSport accesible sin sesión
class VistaInicioPublico extends StatefulWidget {
  final ServicioAutenticacion servicioAuth;

  const VistaInicioPublico({super.key, required this.servicioAuth});

  @override
  State<VistaInicioPublico> createState() => _VistaInicioPublicoState();
}

class _VistaInicioPublicoState extends State<VistaInicioPublico> {
  final int _indiceNavegacion = 0;

  // Pestañas: 0 Inicio · 1 Explorar · 2 Mis partidos.
  // "Explorar" está en la navegación principal (Clase 15, hallazgo #1 · H6):
  // encontrar partidos de otros no debe depender de recordar dónde está.
  void _alSeleccionarPestana(int indice) {
    if (indice == 0) return;
    final destino = indice == 1
        ? VistaExplorarPartidos(servicioAuth: widget.servicioAuth)
        : VistaMisPartidos(servicioAuth: widget.servicioAuth);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.servicioAuth.estaAutenticado
            ? destino
            // Ruta privada: sin sesión se redirige al login explicando el motivo
            : VistaLogin(
                servicioAuth: widget.servicioAuth,
                mensajeRedireccion: indice == 1
                    ? 'Inicia sesión para explorar partidos.'
                    : 'Inicia sesión para ver tus partidos.',
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                if (!widget.servicioAuth.estaAutenticado) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VistaLogin(servicioAuth: widget.servicioAuth),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.logIn, size: 19),
                    label: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              VistaRegistro(servicioAuth: widget.servicioAuth),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.userPlus, size: 19),
                    label: const Text('Crear nueva cuenta'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VistaMisPartidos(
                            servicioAuth: widget.servicioAuth,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.calendarDays, size: 19),
                    label: const Text('Ver mis partidos'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceNavegacion,
        onDestinationSelected: _alSeleccionarPestana,
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.house), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(LucideIcons.compass),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.calendarDays),
            label: 'Mis partidos',
          ),
        ],
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
          colors: [Color(0xFF16A34A), Color(0xFF0F766E)],
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
                  color: Colors.white.withValues(alpha: 0.18),
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
                    color: Color(0xE6FFFFFF),
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
