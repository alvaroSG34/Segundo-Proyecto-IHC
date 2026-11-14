import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisport/tema/tema_app.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/servicios/partidos/controlador_explorar.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_historial.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/autenticacion/vista_perfil.dart';
import 'package:unisport/vistas/autenticacion/vista_registro.dart';

import 'apoyo/servicio_autenticacion_falso.dart';
import 'apoyo/repositorio_en_memoria.dart';
import 'resultado_partido_test.dart' show preparar;

// Capturas locales con datos ficticios. Activar con REVISION_CAPTURAS=true.
void main() {
  const capturar = bool.fromEnvironment('REVISION_CAPTURAS');
  testWidgets('revisar registro y confirmación de cuenta', (tester) async {
    const rutaFuente = String.fromEnvironment(
      'REVISION_FUENTE',
      defaultValue:
          '/usr/share/fonts/liberation-sans-fonts/LiberationSans-Regular.ttf',
    );
    final datos = ByteData.sublistView(File(rutaFuente).readAsBytesSync());
    for (final familia in [
      'Inter_regular',
      'Inter_500',
      'Inter_600',
      'Inter_700',
      'Plus Jakarta Sans_800',
      'PlusJakartaSans_800',
    ]) {
      await (FontLoader(familia)..addFont(Future.value(datos))).load();
    }
    final manifiesto =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entrada in manifiesto) {
      final fuente = FontLoader(entrada['family'] as String);
      for (final font in entrada['fonts'] as List) {
        fuente.addFont(rootBundle.load(font['asset'] as String));
      }
      await fuente.load();
    }
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = ServicioAutenticacionFalso();
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaRegistro(servicioAuth: auth),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-registro.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaLogin(servicioAuth: auth),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login_correo')),
      'ficticio@ejemplo.edu',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('login_clave')),
        matching: find.byType(EditableText),
      ),
      'incorrecta',
    );
    await tester.ensureVisible(find.byKey(const Key('login_enviar')));
    await tester.tap(find.byKey(const Key('login_enviar')));
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-acceso-error.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: const VistaCrearPartido(
          organizadorNombre: 'Estudiante de prueba',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-crear-partido.png'),
    );
    await tester.ensureVisible(find.byKey(const Key('partido_guardar')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-crear-controles.png'),
    );
    await tester.tap(find.byKey(const Key('partido_guardar')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-crear-validacion.png'),
    );
    await auth.iniciarSesion('diego@unisport.edu', '123456');
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaPerfil(servicioAuth: auth),
      ),
    );
    await tester.pumpAndSettle();
    final eliminar = find.byKey(const Key('eliminar_cuenta'));
    await tester.ensureVisible(eliminar);
    await tester.pumpAndSettle();
    await tester.tap(eliminar);
    await tester.pumpAndSettle();
    final cancelar = find.widgetWithText(OutlinedButton, 'Cancelar');
    final confirmar = find.byKey(const Key('confirmar_eliminar_cuenta'));
    expect(tester.getSize(cancelar), tester.getSize(confirmar));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-confirmacion-cuenta.png'),
    );
    await tester.tap(cancelar);
    await tester.pumpAndSettle();
    expect(auth.estaAutenticado, isTrue);
    final controlador = ControladorExplorar();
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaHistorial(
          servicioAuth: auth,
          repositorioPartidos: auth.repositorio,
          controladorExplorar: controlador,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-historial-vacio.png'),
    );
    auth.repositorio.sembrar(
      'otro',
      ModeloPartido(
        id: 'partido-ficticio',
        titulo: 'Partido de prueba',
        disciplina: 'Futsal',
        icono: 'Futsal',
        ubicacion: 'Cancha',
        fechaHora: '10/10/2099 · 19:00',
        cuposTotales: 10,
        cuposOcupados: 2,
        organizadorNombre: 'Organizador de prueba',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaExplorarPartidos(
          servicioAuth: auth,
          repositorioPartidos: auth.repositorio,
          controladorExplorar: controlador,
          referenciaTemporal: DateTime(2099, 10, 10, 18, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-explorar.png'),
    );
    final unirse = find.text('Unirme al equipo');
    await tester.ensureVisible(unirse);
    await tester.tap(unirse);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-confirmar-union.png'),
    );
    await tester.tap(find.text('Sí, unirme'));
    await tester.pumpAndSettle();
    final salir = find.text('Salir del partido');
    await tester.ensureVisible(salir);
    await tester.tap(salir);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-confirmar-salida.png'),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'deporte inexistente');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-sin-resultados.png'),
    );
    auth.repositorio.usarSesionDe('otro', 'Organizador de prueba');
    await auth.repositorio.reprogramarPartido(
      'partido-ficticio',
      DateTime(2099, 10, 11, 19),
      'Otra cancha',
      'Cambio de cancha',
    );
    auth.repositorio.usarSesionDe('u-diego', 'Diego');
    controlador.actualizarFiltro(
      const FiltroPartidos(periodo: PeriodoPartidos.proximos),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaExplorarPartidos(
          servicioAuth: auth,
          repositorioPartidos: auth.repositorio,
          controladorExplorar: controlador,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('partido_reconfirmar')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-reconfirmacion.png'),
    );

    final repoResultados = await preparar();
    await repoResultados.registrarResultado('m-1', 2, 1);
    repoResultados.usarSesionDe('capitan', 'Capitán rival');
    final partidoResultado =
        (await repoResultados.obtenerPartidosUnidos()).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaEquipos(
          partido: partidoResultado,
          repositorio: repoResultados,
          usuarioId: 'capitan',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar resultado'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-resultado-pendiente.png'),
    );
    auth.repositorio.sembrar(
      'u-diego',
      ModeloPartido(
        id: 'propio',
        titulo: 'Partido organizado de prueba',
        disciplina: 'Futsal',
        icono: 'Futsal',
        ubicacion: 'Cancha',
        fechaHora: '10/10/2099 · 19:00',
        cuposTotales: 10,
        cuposOcupados: 1,
        organizadorNombre: 'Diego',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaMisPartidos(
          servicioAuth: auth,
          repositorioPartidos: auth.repositorio,
          controladorExplorar: ControladorExplorar(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final borrar = find.text('Eliminar');
    await tester.ensureVisible(borrar);
    await tester.tap(borrar);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-eliminar-partido.png'),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    final cerrarSesion = find.byKey(const Key('mis_partidos_cerrar_sesion'));
    await tester.ensureVisible(cerrarSesion);
    await tester.tap(cerrarSesion);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-cerrar-sesion.png'),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(auth.estaAutenticado, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaMisPartidos(
          servicioAuth: auth,
          key: const Key('pantalla_error'),
          repositorioPartidos: _RepositorioConError(),
          controladorExplorar: ControladorExplorar(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mis_partidos_reintentar')),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-error-carga.png'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.tema,
        home: VistaExplorarPartidos(
          servicioAuth: auth,
          repositorioPartidos: _RepositorioExplorarConError(),
          controladorExplorar: ControladorExplorar(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('explorar_reintentar')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../evidencias/tarea-10-explorar-error.png'),
    );
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  }, skip: !capturar);
}

class _RepositorioConError extends RepositorioEnMemoria {
  @override
  Future<List<ModeloPartido>> obtenerMisPartidos() async {
    throw StateError('No se pudieron cargar tus partidos. Inténtalo de nuevo.');
  }
}

class _RepositorioExplorarConError extends RepositorioEnMemoria {
  @override
  Future<List<ModeloPartido>> buscarPartidos(
    FiltroPartidos filtro, {
    DateTime? ahora,
  }) async {
    throw StateError('No se pudieron cargar los partidos.');
  }
}
