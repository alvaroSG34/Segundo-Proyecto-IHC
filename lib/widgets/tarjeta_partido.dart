import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/baja_tardia.dart';
import '../modelos/modelo_partido.dart';
import '../tema/iconos_deporte.dart';
import '../tema/tema_app.dart';

/// Tarjeta de un partido (se usa en Mis partidos y en la vista previa de Crear partido).
class TarjetaPartido extends StatelessWidget {
  final ModeloPartido partido;

  final VoidCallback? onEquipos;
  final String? estadoEquipos;
  final String textoBotonEquipos;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback? onCompletarEquipo;
  final VoidCallback? onReprogramar;
  final VoidCallback? onReconfirmar;
  final VoidCallback? onRetirarseReprogramacion;
  final VoidCallback? onUnirse;
  final VoidCallback? onEntrarEnEspera;
  final VoidCallback? onSalirDeEspera;

  /// "Salir del partido" (H3): lo ve quien se unió, mientras la regla lo permita.
  final VoidCallback? onSalir;

  final List<String>? suplentes;
  final List<BajaTardia>? bajasTardias;

  const TarjetaPartido({
    super.key,
    required this.partido,
    this.onEquipos,
    this.estadoEquipos,
    this.textoBotonEquipos = 'Ver equipos',
    this.onEditar,
    this.onEliminar,
    this.onCompletarEquipo,
    this.onReprogramar,
    this.onReconfirmar,
    this.onRetirarseReprogramacion,
    this.onUnirse,
    this.onEntrarEnEspera,
    this.onSalirDeEspera,
    this.onSalir,
    this.suplentes,
    this.bajasTardias,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = partido.cuposTotales == 0
        ? 0.0
        : (partido.cuposOcupados / partido.cuposTotales).clamp(0.0, 1.0);
    final colorEstado = partido.estaLleno
        ? TemaApp.verdeOscuro
        : TemaApp.naranjaAviso;
    final completo = partido.estaLleno;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: TemaApp.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsigniaDeporte(disciplina: partido.disciplina, tamano: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partido.titulo, style: TemaApp.titulo(tamano: 16)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 13,
                          color: TemaApp.textoSecundario,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            partido.ubicacion,
                            style: const TextStyle(
                              fontSize: 12,
                              color: TemaApp.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!partido.soyOrganizador) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.user,
                            size: 13,
                            color: TemaApp.textoSecundario,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Organiza: ${partido.organizadorNombre}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TemaApp.textoSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 13,
                          color: TemaApp.textoSecundario,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            partido.fechaHora,
                            style: const TextStyle(
                              fontSize: 12,
                              color: TemaApp.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!partido.soyOrganizador && partido.estoyUnido) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: _avisoUnion(
                    partido.motivoRechazoUnirse ??
                        'Ya formas parte de este equipo.',
                    icono: LucideIcons.circleCheck,
                    fondo: TemaApp.azulSuave,
                    borde: const Color(0xFFBAE6FD),
                    color: const Color(0xFF075985),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              completo
                  ? _etiquetaPequena(
                      partido.etiquetaEstado,
                      TemaApp.verdeSuave,
                      TemaApp.verdeOscuro,
                      LucideIcons.circleCheck,
                    )
                  : _etiquetaPequena(
                      partido.etiquetaEstado,
                      TemaApp.naranjaSuave,
                      const Color(0xFF9A3412),
                      LucideIcons.circleDot,
                    ),
              if (partido.soyOrganizador)
                _etiquetaPequena(
                  'Organizador',
                  TemaApp.azulSuave,
                  const Color(0xFF075985),
                ),
            ],
          ),
          if (partido.motivoReprogramacion != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TemaApp.amarilloSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Partido reprogramado',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('Motivo: ${partido.motivoReprogramacion}'),
                  if (partido.fechaAnterior != null)
                    Text('Fecha anterior: ${partido.fechaAnterior}'),
                  if (partido.ubicacionAnterior != null)
                    Text('Lugar anterior: ${partido.ubicacionAnterior}'),
                  if (partido.soyOrganizador &&
                      partido.respuestasPendientes > 0)
                    Text('Faltan ${partido.respuestasPendientes} respuestas.'),
                  if (partido.reconfirmacionPendiente)
                    const Text(
                      'Tu respuesta está pendiente. Conservas tu plaza.',
                    ),
                  if (partido.reconfirmacionAceptada)
                    const Text('Tu plaza está reconfirmada.'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                LucideIcons.users,
                size: 16,
                color: TemaApp.textoSecundario,
              ),
              const SizedBox(width: 6),
              Text(
                '${partido.cuposOcupados}/${partido.cuposTotales}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: TemaApp.textoPrincipal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: partido.estaLleno
                        ? TemaApp.verdeDeportivo
                        : TemaApp.naranjaAviso,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                partido.estaLleno
                    ? 'Completo'
                    : 'Faltan ${partido.cuposRestantes}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorEstado,
                ),
              ),
            ],
          ),
          if (estadoEquipos != null) ...[
            const SizedBox(height: 12),
            Text(estadoEquipos!),
            if (onEquipos != null)
              OutlinedButton.icon(
                onPressed: onEquipos,
                icon: const Icon(Icons.groups_outlined),
                label: Text(textoBotonEquipos),
              ),
          ],
          if (partido.soyOrganizador &&
              suplentes != null &&
              suplentes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _construirSuplentes(context, suplentes!),
          ],
          if (partido.soyOrganizador &&
              bajasTardias != null &&
              bajasTardias!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _construirBajasTardias(context, bajasTardias!),
          ],
          // ACCIONES DEL ORGANIZADOR
          if (partido.soyOrganizador) ...[
            if (onReprogramar != null && partido.puedeReprogramar) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('partido_reprogramar'),
                onPressed: onReprogramar,
                icon: const Icon(Icons.event_repeat),
                label: const Text('Reprogramar partido'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
            // EDITAR Y ELIMINAR (Clase 16 · Fitts): antes eran íconos de 16 px,
            // pegados y arriba a la derecha. Ahora son botones con texto de 48 px
            // de alto, junto a las demás acciones del partido; eliminar queda
            // separado y con color de advertencia para no tocarlo por error.
            if (onEditar != null || onEliminar != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: TemaApp.borde),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onEditar != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(LucideIcons.pencil, size: 17),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.standard,
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (onEditar != null && onEliminar != null)
                    const SizedBox(width: 16),
                  if (onEliminar != null)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onEliminar,
                        icon: const Icon(LucideIcons.trash2, size: 17),
                        label: const Text('Eliminar'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.standard,
                          foregroundColor: TemaApp.rojoAlerta,
                          backgroundColor: TemaApp.rojoSuave,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (onCompletarEquipo != null && partido.puedeCompletarEquipo) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onCompletarEquipo,
                icon: const Icon(LucideIcons.circleCheck, size: 17),
                label: const Text('Completar equipo'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.standard,
                  minimumSize: const Size(double.infinity, 48),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cierra las inscripciones sin añadir jugadores.',
                style: TextStyle(fontSize: 12, color: TemaApp.textoSecundario),
              ),
            ],
          ] else ...[
            // PARA QUIEN NO ORGANIZA (Issue #4): la regla puedeUnirse decide
            if (partido.puedeUnirse && onUnirse != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onUnirse,
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text('Unirme al equipo'),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.standard,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ] else if (partido.estoyUnido) ...[
              if (partido.reconfirmacionPendiente) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('partido_reconfirmar'),
                        onPressed: onReconfirmar,
                        label: const Text(
                          'Confirmar mi asistencia',
                          textAlign: TextAlign.center,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('partido_retirarse_reprogramacion'),
                        onPressed: onRetirarseReprogramacion,
                        style: FilledButton.styleFrom(
                          backgroundColor: TemaApp.rojoAlerta,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                        ),
                        child: const Text('Retirarme'),
                      ),
                    ),
                  ],
                ),
              ] else if (onSalir != null && partido.puedeSalir) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onSalir,
                  icon: const Icon(LucideIcons.logOut, size: 17),
                  label: const Text('Salir del partido'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.standard,
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: TemaApp.rojoAlerta,
                  ),
                ),
              ],
            ] else if (partido.estoyEnEspera) ...[
              const SizedBox(height: 12),
              _avisoUnion(
                'Estás en la lista de suplentes. Turno ${partido.posicionEspera}. '
                'Si se libera un cupo, el primero entra automáticamente.',
                icono: LucideIcons.clock,
                fondo: TemaApp.azulSuave,
                borde: const Color(0xFFBAE6FD),
                color: const Color(0xFF075985),
              ),
              if (onSalirDeEspera != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onSalirDeEspera,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Cancelar espera'),
                ),
              ],
            ] else if (partido.puedeEntrarEnEspera &&
                onEntrarEnEspera != null) ...[
              const SizedBox(height: 12),
              _avisoUnion(
                'Entrarás en la lista de suplentes. Cuando llegue tu turno y se libere '
                'un cupo, te unirás automáticamente al partido. Puedes cancelar la '
                'espera antes de entrar al equipo.',
                icono: LucideIcons.info,
                fondo: TemaApp.azulSuave,
                borde: const Color(0xFFBAE6FD),
                color: const Color(0xFF075985),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onEntrarEnEspera,
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text('Entrar como suplente'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ] else if (!partido.puedeUnirse) ...[
              // Rechazo del criterio 3: equipo completo (se explica el motivo)
              const SizedBox(height: 12),
              _avisoUnion(
                'No puedes unirte. '
                '${partido.motivoRechazoUnirse ?? "Convocatoria no disponible."}',
                icono: LucideIcons.ban,
                fondo: const Color(0xFFFEF2F2),
                borde: const Color(0xFFFECACA),
                color: const Color(0xFFB91C1C),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _construirSuplentes(BuildContext context, List<String> nombres) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(LucideIcons.clock, size: 18),
        label: Text('Ver suplentes (${nombres.length})'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Suplentes (${nombres.length})'),
            content: SizedBox(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                itemCount: nombres.length,
                itemBuilder: (_, indice) => ListTile(
                  leading: CircleAvatar(child: Text('${indice + 1}')),
                  title: Text(nombres[indice]),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBajasTardias(BuildContext context, List<BajaTardia> bajas) {
    String fecha(DateTime valor) {
      String dos(int numero) => numero.toString().padLeft(2, '0');
      return '${dos(valor.day)}/${dos(valor.month)}/${valor.year} · '
          '${dos(valor.hour)}:${dos(valor.minute)}';
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const Key('partido_ver_bajas_tardias'),
        icon: const Icon(LucideIcons.triangleAlert, size: 18),
        label: Text('Ver bajas tardías (${bajas.length})'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: TemaApp.rojoAlerta,
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Bajas tardías (${bajas.length})'),
            content: SizedBox(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                itemCount: bajas.length,
                itemBuilder: (_, indice) => ListTile(
                  leading: const Icon(
                    LucideIcons.triangleAlert,
                    color: TemaApp.rojoAlerta,
                  ),
                  title: Text(bajas[indice].jugadorNombre),
                  subtitle: Text(fecha(bajas[indice].fecha)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoUnion(
    String texto, {
    required IconData icono,
    required Color fondo,
    required Color borde,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiquetaPequena(
    String texto,
    Color fondo,
    Color color, [
    IconData? icono,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
