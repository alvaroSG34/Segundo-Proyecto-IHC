import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../modelos/evento_historial.dart';
import '../tema/iconos_deporte.dart';
import '../tema/tema_app.dart';

/// Tarjeta visual para un evento en el historial de participación (Clase 16).
///
/// Aplica los principios de interacción:
/// - Fitts: tarjeta con objetivo táctil amplio y espaciado de 16 px.
/// - Carga cognitiva: responde de un vistazo qué ocurrió, cuándo, cuál fue el
///   resultado y qué deporte/partido estuvo involucrado.
class TarjetaHistorial extends StatelessWidget {
  final EventoHistorial evento;
  final DateTime? referenciaTemporal;

  const TarjetaHistorial({
    super.key,
    required this.evento,
    this.referenciaTemporal,
  });

  @override
  Widget build(BuildContext context) {
    final esOrganizador = evento.rol == RolParticipacion.organizador;
    final esFinalizado = evento.resultado == ResultadoPartido.finalizado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: TemaApp.tarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: deporte, badges de rol y resultado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InsigniaDeporte(disciplina: evento.disciplina, tamano: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evento.tituloPartido,
                      style: TemaApp.titulo(tamano: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evento.rol.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: esOrganizador
                            ? TemaApp.verdeOscuro
                            : TemaApp.azulDeportivo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de resultado
              _construirBadgeResultado(evento.resultado),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: TemaApp.borde),
          const SizedBox(height: 12),

          // Fila inferior: cuándo y dónde
          Row(
            children: [
              // Fecha amigable (Carga cognitiva reducida)
              Icon(
                LucideIcons.calendar,
                size: 15,
                color: esFinalizado
                    ? TemaApp.textoSecundario
                    : TemaApp.textoPrincipal,
              ),
              const SizedBox(width: 6),
              Text(
                evento.fechaAmigable(ahora: referenciaTemporal),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: esFinalizado
                      ? TemaApp.textoSecundario
                      : TemaApp.textoPrincipal,
                ),
              ),
              const Spacer(),
              // Ubicación
              Icon(
                LucideIcons.mapPin,
                size: 15,
                color: TemaApp.textoSecundario,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  evento.ubicacion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TemaApp.textoSecundario,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBadgeResultado(ResultadoPartido resultado) {
    Color fondo;
    Color texto;

    switch (resultado) {
      case ResultadoPartido.finalizado:
        fondo = TemaApp.superficieSuave;
        texto = TemaApp.textoSecundario;
        break;
      case ResultadoPartido.equipoCompleto:
      case ResultadoPartido.convocatoriaCerrada:
        fondo = TemaApp.naranjaSuave;
        texto = TemaApp.naranjaAviso;
        break;
      case ResultadoPartido.enConvocatoria:
        fondo = TemaApp.verdeSuave;
        texto = TemaApp.verdeOscuro;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: texto.withValues(alpha: 0.2)),
      ),
      child: Text(
        resultado.etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }
}
