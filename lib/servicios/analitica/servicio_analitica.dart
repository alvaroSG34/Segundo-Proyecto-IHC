import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nombres estables de los eventos de los flujos principales.
abstract final class EventosAnalitica {
  static const unionFallida = 'union_fallida';
  static const busquedaIniciada = 'busqueda_iniciada';
  static const loginIniciado = 'login_iniciado';
  static const esperaIniciada = 'espera_iniciada';
  static const reprogramacionIniciada = 'reprogramacion_iniciada';
  static const reprogramacionFallida = 'reprogramacion_fallida';
  static const reconfirmacionIniciada = 'reconfirmacion_iniciada';
  static const reconfirmacionFallida = 'reconfirmacion_fallida';
  static const respuestaPropuestaIniciada = 'respuesta_propuesta_iniciada';
  static const respuestaPropuestaFallida = 'respuesta_propuesta_fallida';
  static const validacionResultadoIniciada = 'validacion_resultado_iniciada';
  static const validacionResultadoFallida = 'validacion_resultado_fallida';
  static const edicionIniciada = 'edicion_iniciada';
  static const edicionFallida = 'edicion_fallida';
  static const eliminacionIniciada = 'eliminacion_iniciada';
  static const eliminacionFallida = 'eliminacion_fallida';
  static const recuperacionIniciada = 'recuperacion_iniciada';
  static const recuperacionFallida = 'recuperacion_fallida';
  static const unionIniciada = 'union_iniciada';
  static const partidoUnido = 'partido_unido';
  static const creacionIniciada = 'creacion_iniciada';
  static const partidoCreado = 'partido_creado';
  static const creacionFallida = 'creacion_fallida';
  static const busquedaRealizada = 'busqueda_realizada';
  static const busquedaSinResultados = 'busqueda_sin_resultados';
  static const busquedaFallida = 'busqueda_fallida';
  static const registroIniciado = 'registro_iniciado';
  static const registroCompletado = 'registro_completado';
  static const registroFallido = 'registro_fallido';
  static const loginExitoso = 'login_exitoso';
  static const loginFallido = 'login_fallido';
  static const salidaIniciada = 'salida_iniciada';
  static const salidaCompletada = 'salida_completada';
  static const salidaFallida = 'salida_fallida';
  static const esperaConfirmada = 'espera_confirmada';
  static const esperaFallida = 'espera_fallida';
  static const suplentePromovido = 'suplente_promovido';
  static const partidoReprogramado = 'partido_reprogramado';
  static const reprogramacionAceptada = 'reprogramacion_aceptada';
  static const reprogramacionRechazada = 'reprogramacion_rechazada';
  static const propuestaAceptada = 'propuesta_aceptada';
  static const propuestaRechazada = 'propuesta_rechazada';
  static const resultadoConfirmado = 'resultado_confirmado';
  static const resultadoDisputado = 'resultado_disputado';
  static const partidoEditado = 'partido_editado';
  static const partidoEliminado = 'partido_eliminado';
  static const recuperacionSolicitada = 'recuperacion_solicitada';
}

String crearIntentoId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

String? anticipacionSalida(DateTime? inicio, DateTime ahora) {
  if (inicio == null) return null;
  final tiempo = inicio.difference(ahora);
  if (tiempo <= Duration.zero) return 'partido_iniciado';
  if (tiempo < const Duration(hours: 1)) return 'menos_1_hora';
  if (tiempo <= const Duration(hours: 24)) return 'entre_1_y_24_horas';
  return 'mas_24_horas';
}

class EventoAnalitica {
  final String evento;
  final Map<String, dynamic> props;
  final DateTime fecha;

  const EventoAnalitica({
    required this.evento,
    required this.props,
    required this.fecha,
  });

  factory EventoAnalitica.desdeJson(Map<String, dynamic> json) =>
      EventoAnalitica(
        evento: json['evento'] as String,
        props: Map<String, dynamic>.from(json['props'] as Map? ?? const {}),
        fecha: DateTime.parse(json['fecha'] as String).toLocal(),
      );
}

/// Contrato pequeno para poder reemplazar Supabase en pruebas.
abstract interface class ServicioAnalitica {
  Future<void> track(String evento, Map<String, dynamic> props);
  Future<List<EventoAnalitica>> obtenerEventos();
}

ServicioAnalitica crearAnalitica(bool usarSupabase) {
  if (!usarSupabase) return const ServicioAnaliticaNula();
  return ServicioAnaliticaSupabase(Supabase.instance.client);
}

/// Comparte el manejo de errores para que la analítica no interrumpa la tarea.
Future<void> registrarEvento(
  ServicioAnalitica servicio,
  String evento,
  Map<String, dynamic> props,
) async {
  try {
    await servicio.track(evento, props).timeout(const Duration(seconds: 15));
  } catch (error) {
    debugPrint('No se pudo registrar $evento: $error');
  }
}

class ServicioAnaliticaSupabase implements ServicioAnalitica {
  final SupabaseClient _cliente;

  ServicioAnaliticaSupabase(this._cliente);

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    await _cliente.rpc('track', params: {'p_evento': evento, 'p_props': props});
  }

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async {
    try {
      final respuesta = await _cliente.rpc('obtener_eventos_analitica');
      return [
        for (final fila in respuesta as List)
          EventoAnalitica.desdeJson(Map<String, dynamic>.from(fila as Map)),
      ];
    } on PostgrestException catch (e) {
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error al consultar eventos de analítica: $e');
      throw StateError(
        'No se pudo cargar la analítica. Revisa tu conexión a internet.',
      );
    }
  }
}

/// Implementación segura por defecto para vistas aisladas y pruebas.
class ServicioAnaliticaNula implements ServicioAnalitica {
  const ServicioAnaliticaNula();

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {}

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => const [];
}
