import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/modelo_partido.dart';
import '../tema/iconos_deporte.dart';
import '../tema/tema_app.dart';

/// Tarjeta de un partido (se usa en Mis partidos y en la vista previa de Crear partido).
class TarjetaPartido extends StatelessWidget {
  final ModeloPartido partido;

  /// Si se entrega, el organizador ve el botón "Completar equipo"
  /// mientras el partido tenga los cupos abiertos.
  final VoidCallback? onCompletarEquipo;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;
  final VoidCallback? onUnirse;

  /// "Salir del partido" (H3): lo ve quien se unió, mientras la regla lo permita.
  final VoidCallback? onSalir;

  /// Acción del organizador: suma un jugador. Si la restricción lo bloquea
  /// (equipo completo), el botón se ve apagado y explica el motivo.
  final VoidCallback? onAgregarJugador;

  /// Nombres de quienes se unieron desde Explorar. Si se entrega, el
  /// organizador y los jugadores inscritos ven la lista en la tarjeta.
  final List<String>? jugadoresUnidos;

  const TarjetaPartido({
    super.key,
    required this.partido,
    this.onCompletarEquipo,
    this.onEditar,
    this.onEliminar,
    this.onUnirse,
    this.onSalir,
    this.onAgregarJugador,
    this.jugadoresUnidos,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = partido.cuposTotales == 0
        ? 0.0
        : (partido.cuposOcupados / partido.cuposTotales).clamp(0.0, 1.0);
    final colorEstado = partido.estaLleno
        ? TemaApp.verdeOscuro
        : TemaApp.naranjaAviso;
    final completo = partido.estado == EstadoPartido.equipoCompleto;

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
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              completo
                  ? _etiquetaPequena(
                      partido.estado.etiqueta,
                      TemaApp.verdeSuave,
                      TemaApp.verdeOscuro,
                      LucideIcons.circleCheck,
                    )
                  : _etiquetaPequena(
                      partido.estado.etiqueta,
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
          // QUIÉN SE UNIÓ (organizador y jugadores inscritos)
          if ((partido.soyOrganizador || partido.estoyUnido) &&
              jugadoresUnidos != null) ...[
            const SizedBox(height: 12),
            _construirJugadoresUnidos(jugadoresUnidos!),
          ],
          // ACCIONES DEL ORGANIZADOR
          if (partido.soyOrganizador) ...[
            if (onAgregarJugador != null ||
                (onCompletarEquipo != null && partido.puedeCompletarEquipo)) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (onAgregarJugador != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAgregarJugador,
                        icon: Icon(
                          partido.puedeAgregarJugador
                              ? LucideIcons.userPlus
                              : LucideIcons.ban,
                          size: 17,
                        ),
                        label: const Text('Agregar jugador'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          // Bloqueado: se ve apagado, pero al tocarlo explica el motivo
                          foregroundColor: partido.puedeAgregarJugador
                              ? TemaApp.textoPrincipal
                              : const Color(0xFF94A3B8),
                          backgroundColor: partido.puedeAgregarJugador
                              ? TemaApp.superficie
                              : TemaApp.superficieSuave,
                        ),
                      ),
                    ),
                  if (onAgregarJugador != null &&
                      onCompletarEquipo != null &&
                      partido.puedeCompletarEquipo)
                    const SizedBox(width: 10),
                  if (onCompletarEquipo != null && partido.puedeCompletarEquipo)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onCompletarEquipo,
                        icon: const Icon(LucideIcons.userCheck, size: 17),
                        label: const Text('Completar equipo'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            // MOTIVO DEL BLOQUEO, siempre visible cuando no se pueden agregar jugadores
            if (!partido.puedeAgregarJugador) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        LucideIcons.ban,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No puedes agregar más jugadores. '
                        '${partido.motivoBloqueoAgregarJugador ?? "Convocatoria cerrada."}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
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
          ] else ...[
            // PARA QUIEN NO ORGANIZA (Issue #4): la regla puedeUnirse decide
            if (partido.puedeUnirse && onUnirse != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onUnirse,
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text('Unirme al equipo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ] else if (partido.estoyUnido) ...[
              // Rechazo del criterio 4: ya forma parte del equipo
              const SizedBox(height: 12),
              _avisoUnion(
                partido.motivoRechazoUnirse ?? 'Ya formas parte de este equipo.',
                icono: LucideIcons.circleCheck,
                fondo: TemaApp.azulSuave,
                borde: const Color(0xFFBAE6FD),
                color: const Color(0xFF075985),
              ),
              if (onSalir != null && partido.puedeSalir) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onSalir,
                  icon: const Icon(LucideIcons.logOut, size: 17),
                  label: const Text('Salir del partido'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: TemaApp.rojoAlerta,
                  ),
                ),
              ],
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

  Widget _construirJugadoresUnidos(List<String> nombres) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TemaApp.superficieSuave,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              LucideIcons.users,
              size: 15,
              color: TemaApp.textoSecundario,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              nombres.isEmpty
                  ? 'Todavía no se unió nadie desde Explorar.'
                  : 'Se unieron (${nombres.length}): ${nombres.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TemaApp.textoPrincipal,
                height: 1.35,
              ),
            ),
          ),
        ],
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
