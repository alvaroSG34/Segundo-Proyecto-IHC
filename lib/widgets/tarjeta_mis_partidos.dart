import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/modelo_partido.dart';
import '../tema/iconos_deporte.dart';
import '../tema/tema_app.dart';

/// Tarjeta de resumen exclusiva de «Mis partidos».
class TarjetaMisPartidos extends StatelessWidget {
  final ModeloPartido partido;
  final VoidCallback alVerDetalle;

  const TarjetaMisPartidos({
    super.key,
    required this.partido,
    required this.alVerDetalle,
  });

  String _fechaCorta(DateTime fecha) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '${fecha.day} ${meses[fecha.month - 1]} · $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloDeporte.de(partido.disciplina);
    final progreso = partido.cuposTotales <= 0
        ? 0.0
        : (partido.cuposOcupados / partido.cuposTotales).clamp(0.0, 1.0);
    final estado = partido.estaLleno
        ? TemaApp.verdeOscuro
        : TemaApp.naranjaAviso;
    final fecha = partido.fechaInicio;

    return Container(
      key: Key('tarjeta_mis_partidos_${partido.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: TemaApp.tarjeta(radio: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsigniaDeporte(disciplina: partido.disciplina, tamano: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partido.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TemaApp.titulo(tamano: 17),
                    ),
                    const SizedBox(height: 5),
                    Chip(
                      avatar: Icon(estilo.icono, size: 14, color: estilo.color),
                      label: Text(partido.disciplina),
                      backgroundColor: estilo.fondo,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        color: estilo.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: _estadoUnion(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dato(
            LucideIcons.calendarDays,
            fecha == null ? partido.fechaHora : _fechaCorta(fecha),
          ),
          const SizedBox(height: 5),
          _dato(LucideIcons.mapPin, partido.ubicacion),
          if (!partido.soyOrganizador) ...[
            const SizedBox(height: 5),
            _dato(LucideIcons.user, 'Organiza: ${partido.organizadorNombre}'),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                LucideIcons.users,
                size: 19,
                color: TemaApp.textoSecundario,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${partido.cuposOcupados}/${partido.cuposTotales} jugadores',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TemaApp.textoPrincipal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                partido.estaLleno
                    ? 'Completo'
                    : '${partido.cuposRestantes} libres',
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: estado,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                color: partido.estaLleno
                    ? TemaApp.verdeDeportivo
                    : TemaApp.naranjaAviso,
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: Key('mis_partidos_detalle_${partido.id}'),
            onPressed: alVerDetalle,
            icon: const Icon(LucideIcons.externalLink, size: 18),
            label: const Text('Ver detalle'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: TemaApp.textoSecundario,
              side: const BorderSide(color: TemaApp.borde, width: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoUnion() {
    final texto = partido.soyOrganizador
        ? 'Organizador'
        : partido.estoyEnEspera
        ? 'En espera'
        : 'Inscrito';
    return Chip(
      avatar: const Icon(
        LucideIcons.circleCheck,
        size: 16,
        color: TemaApp.azulDeportivo,
      ),
      label: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis),
      backgroundColor: TemaApp.azulSuave,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: TemaApp.azulDeportivo,
        fontSize: 12,
      ),
    );
  }

  Widget _dato(IconData icono, String texto) => Row(
    children: [
      Icon(icono, size: 20, color: TemaApp.textoSecundario),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: TemaApp.textoSecundario),
        ),
      ),
    ],
  );
}
