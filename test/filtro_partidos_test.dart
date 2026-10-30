import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';

import 'apoyo/repositorio_en_memoria.dart';

/// Pruebas de búsqueda y filtrado de partidos (Issues #9 y #11, requisito #6).
///
/// - Los resultados se prueban sobre un repositorio en memoria con los mismos
///   datos de varios usuarios y la misma regla que la app.
/// - El grupo "Consulta enviada a la base de datos" verifica las condiciones
///   exactas que RepositorioPartidosSupabase aplica en la consulta a PostgreSQL.
///
/// Ejecutar con:  flutter test test/filtro_partidos_test.dart
const lorgio = 'u-lorgio';
const ana = 'u-ana';
const diego = 'u-diego';

/// "Ahora" fijo para que las pruebas no dependan del día en que se ejecutan:
/// miércoles 15 de mayo de 2030 a mediodía.
final ahora = DateTime(2030, 5, 15, 12);

late RepositorioEnMemoria repositorio;

ModeloPartido partido(
  String id,
  String titulo,
  String disciplina,
  String lugar,
  String fechaHora, {
  int total = 10,
  int ocupados = 2,
  EstadoPartido estado = EstadoPartido.cuposAbiertos,
}) {
  return ModeloPartido(
    id: id,
    titulo: titulo,
    disciplina: disciplina,
    icono: disciplina,
    ubicacion: lugar,
    fechaHora: fechaHora,
    cuposTotales: total,
    cuposOcupados: ocupados,
    organizadorNombre: 'Organizador',
    estado: estado,
  );
}

Future<List<String>> buscar(FiltroPartidos filtro) async {
  final resultado = await repositorio.buscarPartidos(filtro, ahora: ahora);
  return [for (final p in resultado) p.id];
}

void main() {
  setUp(() {
    // Diego es quien busca
    repositorio = RepositorioEnMemoria(usuarioId: diego, usuarioNombre: 'Diego');

    // hoy, con cupos
    repositorio.sembrar(
      lorgio,
      partido('hoy', 'Futsal nocturno', 'Futsal', 'Cancha Campus',
          '15/05/2030 · 19:00', ocupados: 3),
    );
    // dentro de 7 días, equipo completo
    repositorio.sembrar(
      lorgio,
      partido('completo', 'Básquet 3x3', 'Básquetbol', 'Coliseo Campus',
          '18/05/2030 · 18:00', total: 6, ocupados: 6,
          estado: EstadoPartido.equipoCompleto),
    );
    // fuera de los próximos 7 días
    repositorio.sembrar(
      lorgio,
      partido('junio', 'Vóley mixto', 'Voleibol', 'Estadio Módulo',
          '01/06/2030 · 10:00'),
    );
    // ya pasó (antes de "ahora")
    repositorio.sembrar(
      lorgio,
      partido('pasado', 'Futsal de práctica', 'Futsal', 'Coliseo Campus',
          '10/05/2030 · 09:00'),
    );
    repositorio.sembrar(
      ana,
      partido('ana', 'Futsal femenino', 'Futsal', 'Cancha Campus 2',
          '20/05/2030 · 17:00', ocupados: 4),
    );
    // Partido de quien busca: nunca debe aparecer en sus resultados
    repositorio.sembrar(
      diego,
      partido('propio', 'Futsal de Diego', 'Futsal', 'Cancha Diego',
          '16/05/2030 · 20:00'),
    );
  });

  group('Búsqueda por nombre', () {
    test('devuelve resultados sin distinguir mayúsculas', () async {
      expect(
        await buscar(const FiltroPartidos(texto: 'FUTSAL')),
        ['pasado', 'hoy', 'ana'],
      );
    });

    test('no devuelve nada si ningún partido coincide', () async {
      expect(await buscar(const FiltroPartidos(texto: 'rugby')), isEmpty);
    });

    test('los comodines escritos por el usuario se buscan como texto', () async {
      expect(await buscar(const FiltroPartidos(texto: '%')), isEmpty);
    });
  });

  group('Filtros', () {
    test('por deporte', () async {
      expect(
        await buscar(const FiltroPartidos(deporte: 'Voleibol')),
        ['junio'],
      );
    });

    test('por fecha: hoy', () async {
      expect(
        await buscar(const FiltroPartidos(fecha: FiltroFecha.hoy)),
        ['hoy'],
      );
    });

    test('por fecha: próximos 7 días', () async {
      expect(
        await buscar(const FiltroPartidos(fecha: FiltroFecha.proximos7Dias)),
        ['hoy', 'completo', 'ana'],
      );
    });

    test('por fecha: rango de fechas (días incluidos)', () async {
      expect(
        await buscar(
          FiltroPartidos(
            fecha: FiltroFecha.rango,
            desde: DateTime(2030, 6, 1),
            hasta: DateTime(2030, 6, 1),
          ),
        ),
        ['junio'],
      );
    });

    test('por lugar', () async {
      expect(
        await buscar(const FiltroPartidos(lugar: 'Coliseo Campus')),
        ['pasado', 'completo'],
      );
    });

    test(
      'solo con cupos: excluye equipos completos y partidos que ya pasaron',
      () async {
        expect(
          await buscar(const FiltroPartidos(soloConCupos: true)),
          ['hoy', 'ana', 'junio'],
        );
      },
    );

    test('nunca muestra los partidos propios', () async {
      final ids = await buscar(const FiltroPartidos());
      expect(ids, isNot(contains('propio')));
      expect(ids, hasLength(5));
    });
  });

  group('Filtros combinados', () {
    test('fútbol (Futsal) + esta semana + con cupos', () async {
      expect(
        await buscar(
          const FiltroPartidos(
            deporte: 'Futsal',
            fecha: FiltroFecha.proximos7Dias,
            soloConCupos: true,
          ),
        ),
        ['hoy', 'ana'],
      );
    });

    test('combinación sin coincidencias devuelve lista vacía', () async {
      expect(
        await buscar(
          const FiltroPartidos(deporte: 'Voleibol', fecha: FiltroFecha.hoy),
        ),
        isEmpty,
      );
    });
  });

  test('lugares: sugeridos más los existentes, sin repetir ni incluir los propios',
      () async {
    expect(await repositorio.obtenerLugares(), [
      'Cancha Campus',
      'Coliseo Campus',
      'Estadio Módulo',
      'Cancha Campus 2',
    ]);
  });

  group('Consulta enviada a la base de datos (Supabase)', () {
    List<String> describir(FiltroPartidos filtro) => [
      for (final c in filtro.condicionesConsulta(ahora))
        '${c.columna} ${c.operador} ${c.valor}',
    ];

    test('sin filtros no agrega condiciones', () {
      expect(describir(const FiltroPartidos()), isEmpty);
    });

    test('el lugar se busca con ILIKE y el nombre se compara en la app', () {
      expect(
        describir(const FiltroPartidos(texto: ' Futsal ', lugar: 'Coliseo')),
        ['ubicacion ilike %Coliseo%'],
      );
    });

    test('H2: la búsqueda por nombre ignora tildes y mayúsculas', () {
      const filtro = FiltroPartidos(texto: 'voley');
      expect(filtro.coincideTitulo('Vóley mixto'), isTrue);
      expect(const FiltroPartidos(texto: 'VÓLEY').coincideTitulo('voley'), isTrue);
      expect(const FiltroPartidos(texto: 'futbol').coincideTitulo('Fútbol 5'), isTrue);
      expect(filtro.coincideTitulo('Futsal nocturno'), isFalse);
    });

    test('próximos 7 días: desde hoy 00:00 hasta el final del 7.º día', () {
      final condiciones = const FiltroPartidos(
        fecha: FiltroFecha.proximos7Dias,
      ).condicionesConsulta(ahora);

      expect(condiciones, hasLength(2));
      expect(condiciones[0].operador, 'gte');
      expect(
        DateTime.parse(condiciones[0].valor as String).toLocal(),
        DateTime(2030, 5, 15),
      );
      expect(condiciones[1].operador, 'lt');
      expect(
        DateTime.parse(condiciones[1].valor as String).toLocal(),
        DateTime(2030, 5, 23),
      );
    });

    test('con cupos usa la regla del #5: cupos abiertos, lugares y fecha futura',
        () {
      final condiciones = describir(const FiltroPartidos(soloConCupos: true));

      expect(condiciones, hasLength(3));
      expect(condiciones[0], 'estado eq cuposAbiertos');
      expect(condiciones[1], 'hay_cupos eq true');
      expect(condiciones[2], startsWith('fecha_inicio gte '));
    });

    test('los comodines escritos por el usuario se envían escapados', () {
      expect(
        describir(const FiltroPartidos(lugar: '50%_off')),
        [r'ubicacion ilike %50\%\_off%'],
      );
    });
  });

  group('Estado del filtro', () {
    test('sin filtros no está activo; con cualquiera sí', () {
      expect(const FiltroPartidos().estaActivo, isFalse);
      expect(const FiltroPartidos(soloConCupos: true).estaActivo, isTrue);
      expect(const FiltroPartidos(texto: '  ').estaActivo, isFalse);
    });

    test('se puede quitar un filtro sin perder los demás', () {
      const filtro = FiltroPartidos(deporte: 'Futsal', lugar: 'Coliseo Campus');

      final sinDeporte = filtro.copiarCon(quitarDeporte: true);

      expect(sinDeporte.deporte, isNull);
      expect(sinDeporte.lugar, 'Coliseo Campus');
    });
  });
}
