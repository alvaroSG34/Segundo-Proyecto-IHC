import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';

import 'apoyo/repositorio_en_memoria.dart';

final ahora = DateTime(2030, 5, 15, 12);

ModeloPartido partido(String id, DateTime fecha) => ModeloPartido(
  id: id,
  titulo: 'Futsal $id',
  disciplina: 'Futsal',
  icono: 'Futsal',
  ubicacion: 'Coliseo Campus',
  fechaHora: ModeloPartido.formatearFechaHora(fecha),
  cuposTotales: 10,
  cuposOcupados: 2,
  organizadorNombre: 'Ana',
);

void main() {
  test('la categoría general es todos y Explorar inicia en próximos', () {
    expect(const FiltroPartidos().periodo, PeriodoPartidos.todos);
    final controlador = ControladorExplorar();
    expect(controlador.filtro.periodo, PeriodoPartidos.proximos);
    expect(controlador.filtro.estaActivo, isFalse);
  });

  test('el límite incluye ahora en próximos y lo excluye de vencidos', () {
    final antes = partido('antes', ahora.subtract(const Duration(minutes: 1)));
    final limite = partido('limite', ahora);
    const proximos = FiltroPartidos(periodo: PeriodoPartidos.proximos);
    const vencidos = FiltroPartidos(periodo: PeriodoPartidos.vencidos);
    expect(proximos.coincide(antes, ahora), isFalse);
    expect(proximos.coincide(limite, ahora), isTrue);
    expect(vencidos.coincide(antes, ahora), isTrue);
    expect(vencidos.coincide(limite, ahora), isFalse);
  });

  test('cambiar de categoría conserva filtros y quita Con cupos', () {
    final original = FiltroPartidos(
      periodo: PeriodoPartidos.proximos,
      texto: 'futsal',
      deporte: 'Futsal',
      lugar: 'Coliseo Campus',
      fecha: FiltroFecha.rango,
      desde: ahora,
      hasta: ahora,
      soloConCupos: true,
    );
    final vencidos = original.copiarCon(periodo: PeriodoPartidos.vencidos);
    expect(vencidos.texto, original.texto);
    expect(vencidos.deporte, original.deporte);
    expect(vencidos.lugar, original.lugar);
    expect(vencidos.fecha, original.fecha);
    expect(vencidos.desde, original.desde);
    expect(vencidos.hasta, original.hasta);
    expect(vencidos.soloConCupos, isFalse);
    expect(
      vencidos.copiarCon(periodo: PeriodoPartidos.proximos).soloConCupos,
      isFalse,
    );
    expect(vencidos.limpiar().periodo, PeriodoPartidos.vencidos);
    expect(vencidos.limpiar().estaActivo, isFalse);
  });

  test('la consulta de Supabase usa el instante UTC y el operador de cada categoría', () {
    for (final periodo in [
      PeriodoPartidos.proximos,
      PeriodoPartidos.vencidos,
    ]) {
      final condiciones = RepositorioPartidosSupabase.condicionesConsulta(
        FiltroPartidos(periodo: periodo),
        ahora,
      );
      expect(condiciones, hasLength(1));
      expect(condiciones.single.columna, 'fecha_inicio');
      expect(
        condiciones.single.operador,
        periodo == PeriodoPartidos.vencidos ? 'lt' : 'gte',
      );
      expect(condiciones.single.valor, ahora.toUtc().toIso8601String());
    }
  });

  test('repositorio clasifica y ordena ambas categorías, excluyendo partidos propios', () async {
    final repo = RepositorioEnMemoria(usuarioId: 'yo', usuarioNombre: 'Diego');
    for (final (id, minutos) in [
      ('viejo', -120),
      ('reciente', -1),
      ('ahora', 0),
      ('futuro', 120),
    ]) {
      repo.sembrar('otro', partido(id, ahora.add(Duration(minutes: minutos))));
    }
    repo.sembrar('yo', partido('propio', ahora));
    Future<List<String>> ids(FiltroPartidos filtro) async => [
      for (final p in await repo.buscarPartidos(filtro, ahora: ahora)) p.id,
    ];
    expect(await ids(const FiltroPartidos(periodo: PeriodoPartidos.proximos)), [
      'ahora',
      'futuro',
    ]);
    expect(await ids(const FiltroPartidos(periodo: PeriodoPartidos.vencidos)), [
      'reciente',
      'viejo',
    ]);
    expect(await ids(const FiltroPartidos()), [
      'viejo',
      'reciente',
      'ahora',
      'futuro',
    ]);
    expect(
      await ids(
        const FiltroPartidos(
          periodo: PeriodoPartidos.vencidos,
          texto: 'reciente',
          deporte: 'Futsal',
          lugar: 'Coliseo',
          fecha: FiltroFecha.hoy,
        ),
      ),
      ['reciente'],
    );
    expect(
      await ids(
        const FiltroPartidos(
          periodo: PeriodoPartidos.vencidos,
          fecha: FiltroFecha.proximos7Dias,
          deporte: 'Tenis',
        ),
      ),
      isEmpty,
    );
  });
}
