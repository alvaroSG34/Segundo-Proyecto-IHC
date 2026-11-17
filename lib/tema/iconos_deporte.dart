import 'package:material_ui/material_ui.dart';
import 'package:unisport/tema/iconos_app.dart';

/// Ícono y color asociados a cada disciplina (reemplaza a los emojis).
class EstiloDeporte {
  final IconData icono;
  final Color color;
  final Color fondo;

  const EstiloDeporte(this.icono, this.color, this.fondo);

  static const _futbol = EstiloDeporte(
    LucideIcons.goal,
    Color(0xFF15803D),
    Color(0xFFDCFCE7),
  );
  static const _basquet = EstiloDeporte(
    LucideIcons.circleDot,
    Color(0xFFC2410C),
    Color(0xFFFFEDD5),
  );
  static const _voley = EstiloDeporte(
    LucideIcons.volleyball,
    Color(0xFFA16207),
    Color(0xFFFEF9C3),
  );
  static const _tenis = EstiloDeporte(
    LucideIcons.zap,
    Color(0xFF0369A1),
    Color(0xFFE0F2FE),
  );
  static const _otro = EstiloDeporte(
    LucideIcons.medal,
    Color(0xFF475569),
    Color(0xFFF1F5F9),
  );

  static EstiloDeporte de(String disciplina) {
    switch (disciplina) {
      case 'Futsal':
      case 'Fútbol':
        return _futbol;
      case 'Básquetbol':
      case 'Básquet':
        return _basquet;
      case 'Voleibol':
      case 'Vóley':
        return _voley;
      case 'Tenis':
        return _tenis;
      default:
        return _otro;
    }
  }
}

/// Cuadro redondeado con el ícono del deporte.
class InsigniaDeporte extends StatelessWidget {
  final String disciplina;
  final double tamano;

  const InsigniaDeporte({
    super.key,
    required this.disciplina,
    this.tamano = 44,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloDeporte.de(disciplina);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: estilo.fondo,
        borderRadius: BorderRadius.circular(tamano * 0.3),
      ),
      child: Icon(estilo.icono, color: estilo.color, size: tamano * 0.5),
    );
  }
}
