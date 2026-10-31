import '../../modelos/filtro_partidos.dart';

/// Conserva la búsqueda y los filtros de Explorar mientras dura la sesión.
class ControladorExplorar {
  FiltroPartidos _filtro = const FiltroPartidos();

  FiltroPartidos get filtro => _filtro;

  void actualizarFiltro(FiltroPartidos filtro) {
    _filtro = filtro;
  }
}
