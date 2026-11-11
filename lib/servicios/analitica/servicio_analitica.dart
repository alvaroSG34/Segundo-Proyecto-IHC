import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Nombres estables de los eventos del embudo "Unirme al equipo".
abstract final class EventosAnalitica {
  static const unionIniciada = 'union_iniciada';
  static const partidoUnido = 'partido_unido';
}

/// Conteos globales y acumulados del flujo de unión.
class ResumenAnalitica {
  final int unionesIniciadas;
  final int partidosUnidos;

  const ResumenAnalitica({
    required this.unionesIniciadas,
    required this.partidosUnidos,
  });

  static const vacio = ResumenAnalitica(unionesIniciadas: 0, partidosUnidos: 0);

  double get tasaFinalizacion =>
      unionesIniciadas == 0 ? 0 : partidosUnidos / unionesIniciadas * 100;

  factory ResumenAnalitica.desdeJson(Map<String, dynamic> json) {
    int entero(Object? valor) => valor is num
        ? valor.toInt()
        : int.tryParse(valor?.toString() ?? '') ?? 0;

    return ResumenAnalitica(
      unionesIniciadas: entero(json['uniones_iniciadas']),
      partidosUnidos: entero(json['partidos_unidos']),
    );
  }
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
  Future<ResumenAnalitica> obtenerResumen();
  Future<List<EventoAnalitica>> obtenerEventos();
}

class ServicioAnaliticaSupabase implements ServicioAnalitica {
  final SupabaseClient _cliente;

  ServicioAnaliticaSupabase(this._cliente);

  @override
  Future<void> track(String evento, Map<String, dynamic> props) async {
    await _cliente.rpc('track', params: {'p_evento': evento, 'p_props': props});
  }

  @override
  Future<ResumenAnalitica> obtenerResumen() async {
    try {
      final respuesta = await _cliente.rpc('obtener_resumen_analitica');
      return ResumenAnalitica.desdeJson(
        Map<String, dynamic>.from(respuesta as Map),
      );
    } on PostgrestException catch (e) {
      throw StateError(e.message);
    } catch (e) {
      debugPrint('Error al consultar analitica: $e');
      throw StateError(
        'No se pudo cargar la analítica. Revisa tu conexión a internet.',
      );
    }
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
  Future<ResumenAnalitica> obtenerResumen() async => ResumenAnalitica.vacio;

  @override
  Future<List<EventoAnalitica>> obtenerEventos() async => const [];
}
