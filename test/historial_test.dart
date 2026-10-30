import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/modelos/evento_historial.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_historial.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_historial.dart';

import 'apoyo/repositorio_en_memoria.dart';
import 'apoyo/servicio_autenticacion_falso.dart';

void main() {
  group('Clase 16 · Tarea 4: Modelo y Consulta de Historial (refs #17, #18, #19, #21)', () {
    late RepositorioEnMemoria repo;
    final ahora = DateTime(2026, 10, 18, 14, 0);

    setUp(() {
      repo = RepositorioEnMemoria(usuarioId: 'u-diego', usuarioNombre: 'Diego');
    });

    test('1. Consulta: devuelve los partidos que organizo y a los que me uní', () async {
      repo.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'p-organizado',
          titulo: 'Futsal organizado por mí',
          disciplina: 'Futsal',
          icono: 'Futsal',
          ubicacion: 'Cancha Central',
          fechaHora: '18/10/2026 · 18:00',
          cuposTotales: 10,
          cuposOcupados: 2,
          organizadorNombre: 'Diego',
        ),
      );

      final otroPartido = repo.sembrar(
        'u-carlos',
        ModeloPartido(
          id: 'p-unido',
          titulo: 'Básquetbol con Carlos',
          disciplina: 'Básquetbol',
          icono: 'Básquetbol',
          ubicacion: 'Coliseo',
          fechaHora: '18/10/2026 · 20:00',
          cuposTotales: 8,
          cuposOcupados: 1,
          organizadorNombre: 'Carlos',
        ),
      );
      await repo.unirseAPartido(otroPartido.id);

      repo.sembrar(
        'u-ana',
        ModeloPartido(
          id: 'p-ajeno',
          titulo: 'Vóley de Ana',
          disciplina: 'Voleibol',
          icono: 'Voleibol',
          ubicacion: 'Cancha 2',
          fechaHora: '19/10/2026 · 10:00',
          cuposTotales: 12,
          cuposOcupados: 4,
          organizadorNombre: 'Ana',
        ),
      );

      final historial = await repo.obtenerHistorial(ahora: ahora);

      expect(historial.length, 2);
      final ids = historial.map((e) => e.partidoId).toList();
      expect(ids, contains('p-organizado'));
      expect(ids, contains('p-unido'));
      expect(ids.contains('p-ajeno'), isFalse, reason: 'No debe incluir partidos de otros donde no participó');
    });

    test('2. Orden cronológico: los eventos se ordenan del más reciente al más antiguo', () async {
      repo.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'p-antiguo',
          titulo: 'Partido pasado',
          disciplina: 'Fútbol',
          icono: 'Fútbol',
          ubicacion: 'Cancha 1',
          fechaHora: '10/10/2026 · 09:00',
          cuposTotales: 10,
          cuposOcupados: 10,
          organizadorNombre: 'Diego',
        ),
      );

      repo.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'p-reciente',
          titulo: 'Partido de hoy',
          disciplina: 'Tenis',
          icono: 'Tenis',
          ubicacion: 'Cancha Tenis',
          fechaHora: '18/10/2026 · 16:00',
          cuposTotales: 4,
          cuposOcupados: 2,
          organizadorNombre: 'Diego',
        ),
      );

      final historial = await repo.obtenerHistorial(ahora: ahora);

      expect(historial.length, 2);
      expect(historial.first.partidoId, 'p-reciente');
      expect(historial.last.partidoId, 'p-antiguo');
      expect(historial.first.fechaInicio.isAfter(historial.last.fechaInicio), isTrue);
    });

    test('3. Roles y resultados: distingue organizador vs jugador y finalizado vs abierto', () async {
      repo.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'p-1',
          titulo: 'Futsal jugado ayer',
          disciplina: 'Futsal',
          icono: 'Futsal',
          ubicacion: 'Cancha 1',
          fechaHora: '17/10/2026 · 19:00',
          cuposTotales: 10,
          cuposOcupados: 10,
          organizadorNombre: 'Diego',
        ),
      );

      final pFuturo = repo.sembrar(
        'u-maria',
        ModeloPartido(
          id: 'p-2',
          titulo: 'Vóley completo',
          disciplina: 'Voleibol',
          icono: 'Voleibol',
          ubicacion: 'Coliseo',
          fechaHora: '20/10/2026 · 18:00',
          cuposTotales: 2,
          cuposOcupados: 1,
          organizadorNombre: 'María',
        ),
      );
      await repo.unirseAPartido(pFuturo.id);

      final historial = await repo.obtenerHistorial(ahora: ahora);
      final eventoOrganizador = historial.firstWhere((e) => e.partidoId == 'p-1');
      final eventoJugador = historial.firstWhere((e) => e.partidoId == 'p-2');

      expect(eventoOrganizador.rol, RolParticipacion.organizador);
      expect(eventoOrganizador.resultado, ResultadoPartido.finalizado);
      expect(eventoOrganizador.yaDisputado, isTrue);

      expect(eventoJugador.rol, RolParticipacion.jugador);
      expect(eventoJugador.resultado, ResultadoPartido.equipoCompleto);
      expect(eventoJugador.yaDisputado, isFalse);
    });

    test('4. Carga cognitiva: fechaAmigable reduce el esfuerzo mental con Hoy y Ayer', () {
      final eventoHoy = EventoHistorial(
        id: '1',
        partidoId: 'p-hoy',
        tituloPartido: 'Partido de hoy',
        disciplina: 'Futsal',
        ubicacion: 'Cancha 1',
        fechaInicio: DateTime(2026, 10, 18, 19, 30),
        fechaHoraTexto: '18/10/2026 · 19:30',
        rol: RolParticipacion.organizador,
        resultado: ResultadoPartido.enConvocatoria,
        cuposOcupados: 3,
        cuposTotales: 10,
        organizadorNombre: 'Diego',
      );

      final eventoAyer = EventoHistorial(
        id: '2',
        partidoId: 'p-ayer',
        tituloPartido: 'Partido de ayer',
        disciplina: 'Futsal',
        ubicacion: 'Cancha 1',
        fechaInicio: DateTime(2026, 10, 17, 18, 0),
        fechaHoraTexto: '17/10/2026 · 18:00',
        rol: RolParticipacion.jugador,
        resultado: ResultadoPartido.finalizado,
        cuposOcupados: 10,
        cuposTotales: 10,
        organizadorNombre: 'Carlos',
      );

      expect(eventoHoy.fechaAmigable(ahora: ahora), 'Hoy · 19:30');
      expect(eventoAyer.fechaAmigable(ahora: ahora), 'Ayer · 18:00');
    });
  });

  group('Clase 16 · Tarea 4: Interfaz de Historial y Decisiones de Diseño (refs #17, #20, #21)', () {
    testWidgets('5. Fitts: botón para abrir Historial en Mis Partidos mide al menos 48 px', (
      tester,
    ) async {
      final auth = ServicioAutenticacionFalso();
      await auth.iniciarSesion('diego@unisport.edu', '123456');

      await tester.pumpWidget(
        MaterialApp(home: VistaMisPartidos(servicioAuth: auth)),
      );
      await tester.pumpAndSettle();

      final botonHistorial = find.byKey(const Key('boton_abrir_historial'));
      expect(botonHistorial, findsOneWidget);

      final tamano = tester.getSize(botonHistorial);
      expect(
        tamano.height,
        greaterThanOrEqualTo(48.0),
        reason: 'Ley de Fitts: la acción de acceso frecuente debe tener al menos 48 px de alto',
      );
    });

    testWidgets('6. Estado vacío orientador: muestra mensaje y CTA para Explorar partidos', (
      tester,
    ) async {
      final auth = ServicioAutenticacionFalso();
      await auth.iniciarSesion('diego@unisport.edu', '123456');

      await tester.pumpWidget(
        MaterialApp(home: VistaHistorial(servicioAuth: auth)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes partidos en tu historial'), findsOneWidget);
      final botonExplorar = find.byKey(const Key('boton_orientador_explorar'));
      expect(botonExplorar, findsOneWidget);

      final tamanoBoton = tester.getSize(botonExplorar);
      expect(tamanoBoton.height, greaterThanOrEqualTo(48.0));

      // Tocar el botón orientador abre Explorar partidos
      await tester.tap(botonExplorar);
      await tester.pumpAndSettle();

      expect(find.byType(VistaExplorarPartidos), findsOneWidget);
    });

    testWidgets('7. Hick: selector de filtros permite cambiar entre Todos, Organizados y Jugador', (
      tester,
    ) async {
      final auth = ServicioAutenticacionFalso();
      auth.repositorio.sembrar(
        'u-diego',
        ModeloPartido(
          id: 'p-1',
          titulo: 'Futsal mío',
          disciplina: 'Futsal',
          icono: 'Futsal',
          ubicacion: 'Cancha Central',
          fechaHora: '18/10/2026 · 18:00',
          cuposTotales: 10,
          cuposOcupados: 2,
          organizadorNombre: 'Diego',
        ),
      );
      final pOtro = auth.repositorio.sembrar(
        'u-carlos',
        ModeloPartido(
          id: 'p-2',
          titulo: 'Tenis Carlos',
          disciplina: 'Tenis',
          icono: 'Tenis',
          ubicacion: 'Cancha Tenis',
          fechaHora: '19/10/2026 · 10:00',
          cuposTotales: 4,
          cuposOcupados: 1,
          organizadorNombre: 'Carlos',
        ),
      );
      await auth.iniciarSesion('diego@unisport.edu', '123456');
      await auth.partidos.unirseAPartido(pOtro.id);

      await tester.pumpWidget(
        MaterialApp(
          home: VistaHistorial(
            servicioAuth: auth,
            referenciaTemporal: DateTime(2026, 10, 18, 14, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En 'Todos' deben verse ambos partidos
      expect(find.byType(TarjetaHistorial), findsNWidgets(2));

      // Filtrar por 'Organizados'
      await tester.tap(find.byKey(const Key('filtro_organizador')));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaHistorial), findsOneWidget);
      expect(find.text('Futsal mío'), findsOneWidget);

      // Filtrar por 'Como jugador'
      await tester.tap(find.byKey(const Key('filtro_jugador')));
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaHistorial), findsOneWidget);
      expect(find.text('Tenis Carlos'), findsOneWidget);
    });
  });
}
