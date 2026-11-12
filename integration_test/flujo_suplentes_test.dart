import 'apoyo/analitica_e2e.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

// Tres cuentas diferentes, registradas previamente en el mismo Supabase.
// Las credenciales se pasan al ejecutar la prueba, nunca se guardan aquí.
const _organizadorCorreo = String.fromEnvironment('E2E_ORGANIZADOR_CORREO');
const _organizadorClave = String.fromEnvironment('E2E_ORGANIZADOR_CLAVE');
const _titularCorreo = String.fromEnvironment('E2E_TITULAR_CORREO');
const _titularClave = String.fromEnvironment('E2E_TITULAR_CLAVE');
const _suplenteCorreo = String.fromEnvironment('E2E_SUPLENTE_CORREO');
const _suplenteClave = String.fromEnvironment('E2E_SUPLENTE_CLAVE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Un suplente ocupa el cupo que deja un titular', (tester) async {
    await verificarTracksAlTerminar(['espera_iniciada']);
    expect(
      [
        _organizadorCorreo,
        _organizadorClave,
        _titularCorreo,
        _titularClave,
        _suplenteCorreo,
        _suplenteClave,
      ].every((valor) => valor.isNotEmpty),
      isTrue,
      reason:
          'Indica las seis variables E2E_ORGANIZADOR_*, '
          'E2E_TITULAR_* y E2E_SUPLENTE_* con tres cuentas registradas.',
    );

    final titulo = 'E2E Suplentes ${DateTime.now().microsecondsSinceEpoch}';
    final tituloTardio =
        'E2E Baja tardía ${DateTime.now().microsecondsSinceEpoch}';
    const ubicacion = 'Cancha E2E Suplentes';

    app.main();
    await _esperar(
      tester,
      find.byWidgetPredicate(
        (widget) => widget is VistaInicioPublico || widget is VistaPrincipal,
      ),
    );
    await _iniciarSesion(tester, _organizadorCorreo, _organizadorClave);
    final cliente = Supabase.instance.client;
    final organizadorId = cliente.auth.currentUser!.id;

    // Elimina solo el partido creado por esta prueba, incluso si falla un paso.
    addTearDown(() async {
      await cliente.auth.signInWithPassword(
        email: _organizadorCorreo,
        password: _organizadorClave,
      );
      await cliente
          .from('partidos')
          .delete()
          .eq('organizador_id', organizadorId)
          .eq('titulo', titulo);
      await cliente
          .from('partidos')
          .delete()
          .eq('organizador_id', organizadorId)
          .eq('titulo', tituloTardio);
    });

    // Organizador: crea por la interfaz un partido de dos cupos.
    await _tocar(tester, find.widgetWithText(ElevatedButton, 'Crear\nPartido'));
    await _esperar(tester, find.byType(VistaCrearPartido));
    await _escribir(tester, find.byKey(const Key('partido_titulo')), titulo);
    await _escribir(
      tester,
      find.byKey(const Key('partido_ubicacion')),
      ubicacion,
    );
    await _tocar(tester, find.text('Mañana'));
    await _tocar(tester, find.text('19:00'));
    for (var i = 0; i < 8; i++) {
      await _tocar(tester, find.byIcon(LucideIcons.minus));
    }
    await _tocar(tester, find.text('Guardar partido'));
    await _esperar(
      tester,
      find.text('Partido creado y guardado correctamente.').first,
      motivo: 'El organizador debe poder guardar el partido.',
    );

    // Titular: ocupa el último cupo desde Explorar.
    await _iniciarSesion(tester, _titularCorreo, _titularClave);
    final titularId = cliente.auth.currentUser!.id;
    expect(titularId, isNot(organizadorId));
    var tarjeta = await _buscarPartido(tester, titulo);
    expect(tester.widget<TarjetaPartido>(tarjeta).partido.cuposTotales, 2);
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Unirme al equipo')),
    );
    await _tocar(tester, find.text('Sí, unirme'));
    tarjeta = await _esperarPartido(
      tester,
      titulo,
      (partido) =>
          partido.partido.estoyUnido &&
          partido.partido.cuposOcupados == 2 &&
          partido.partido.estaLleno,
      motivo: 'El titular debe ocupar el último cupo.',
    );

    // Suplente: se anota, ve su turno y no aumenta los cupos ocupados.
    await _volverAlMenu(tester);
    await _iniciarSesion(tester, _suplenteCorreo, _suplenteClave);
    expect(cliente.auth.currentUser!.id, isNot(organizadorId));
    expect(cliente.auth.currentUser!.id, isNot(titularId));
    tarjeta = await _buscarPartido(tester, titulo);
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Entrar como suplente')),
    );
    tarjeta = await _esperarPartido(
      tester,
      titulo,
      (partido) =>
          partido.partido.estoyEnEspera &&
          partido.partido.posicionEspera == 1 &&
          partido.partido.cuposOcupados == 2,
      motivo: 'El suplente debe estar en turno 1 sin ocupar un cupo.',
    );
    expect(
      find.descendant(of: tarjeta, matching: find.text('Cancelar espera')),
      findsOneWidget,
    );

    // Titular: sale y el servidor promueve al primer suplente.
    await _volverAlMenu(tester);
    await _iniciarSesion(tester, _titularCorreo, _titularClave);
    tarjeta = await _buscarPartido(tester, titulo);
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Salir del partido')),
    );
    await _tocar(tester, find.text('Sí, salir'));
    await _esperar(
      tester,
      find.text('Saliste de "$titulo". Entró el primer suplente.').first,
      motivo: 'La salida debe anunciar la promoción.',
    );

    // Suplente: en una sesión nueva, la consulta a Supabase lo muestra unido.
    await _volverAlMenu(tester);
    await _iniciarSesion(tester, _suplenteCorreo, _suplenteClave);
    tarjeta = await _buscarPartido(tester, titulo);
    tarjeta = await _esperarPartido(
      tester,
      titulo,
      (partido) =>
          partido.partido.estoyUnido &&
          !partido.partido.estoyEnEspera &&
          partido.partido.cuposOcupados == 2 &&
          partido.partido.estaLleno,
      motivo: 'El suplente debe ser titular y el partido seguir en 2/2.',
    );
    expect(
      find.descendant(of: tarjeta, matching: find.text('Salir del partido')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tarjeta, matching: find.text('Cancelar espera')),
      findsNothing,
    );

    // Segunda demostración: dentro de las dos horas la salida se registra como
    // baja tardía y queda visible únicamente para el organizador.
    await _volverAlMenu(tester);
    await _iniciarSesion(tester, _organizadorCorreo, _organizadorClave);
    final repositorio = RepositorioPartidosSupabase(cliente);
    final partidoTardio = await repositorio.crearPartido(
      ModeloPartido(
        id: '',
        titulo: tituloTardio,
        disciplina: 'Futsal',
        icono: 'Futsal',
        ubicacion: ubicacion,
        fechaHora: ModeloPartido.formatearFechaHora(
          DateTime.now().add(const Duration(minutes: 90)),
        ),
        cuposTotales: 2,
        cuposOcupados: 1,
        organizadorNombre: 'Organizador E2E',
      ),
    );

    await _iniciarSesion(tester, _titularCorreo, _titularClave);
    tarjeta = await _buscarPartido(tester, tituloTardio);
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Unirme al equipo')),
    );
    await _tocar(tester, find.text('Sí, unirme'));
    tarjeta = await _esperarPartido(
      tester,
      tituloTardio,
      (partido) => partido.partido.estoyUnido,
    );
    await _tocar(
      tester,
      find.descendant(of: tarjeta, matching: find.text('Salir del partido')),
    );
    await _esperar(tester, find.text('¿Registrar baja tardía?'));
    await _tocar(tester, find.text('Registrar baja tardía'));
    await _esperar(
      tester,
      find.text('Baja tardía registrada en "$tituloTardio".').first,
    );

    await _volverAlMenu(tester);
    await _iniciarSesion(tester, _organizadorCorreo, _organizadorClave);
    await _tocar(tester, find.widgetWithText(ElevatedButton, 'Mis\nPartidos'));
    await _esperar(tester, find.byType(VistaMisPartidos));
    final tarjetaOrganizador = find.byWidgetPredicate(
      (widget) =>
          widget is TarjetaPartido && widget.partido.id == partidoTardio.id,
    );
    await _esperar(tester, tarjetaOrganizador);
    final verBajas = find.descendant(
      of: tarjetaOrganizador,
      matching: find.text('Ver bajas tardías (1)'),
    );
    await _tocar(tester, verBajas);
    await _esperar(tester, find.text('Bajas tardías (1)'));
  });
}

Future<void> _iniciarSesion(
  WidgetTester tester,
  String correo,
  String clave,
) async {
  if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
    await _tocar(tester, find.text('CERRAR SESIÓN'));
    await _esperar(tester, find.byType(VistaInicioPublico));
  }
  await _tocar(tester, find.text('Iniciar sesión'));
  await _esperar(tester, find.byType(VistaLogin));
  await _escribir(tester, find.byKey(const Key('login_correo')), correo);
  await _escribir(
    tester,
    find.descendant(
      of: find.byKey(const Key('login_clave')),
      matching: find.byType(EditableText),
    ),
    clave,
  );
  await _tocar(tester, find.text('Entrar a UniSport'));
  await _esperar(
    tester,
    find.byType(VistaPrincipal),
    motivo: 'Debe iniciar sesión con la cuenta $correo.',
  );
}

Future<Finder> _buscarPartido(WidgetTester tester, String titulo) async {
  await _tocar(tester, find.widgetWithText(ElevatedButton, 'Explorar'));
  await _esperar(tester, find.byType(VistaExplorarPartidos));
  await _escribir(tester, find.byType(TextField), titulo);
  await tester.pump(const Duration(milliseconds: 600));
  return _esperarPartido(
    tester,
    titulo,
    (_) => true,
    motivo: 'El partido debe aparecer en Explorar.',
  );
}

Future<Finder> _esperarPartido(
  WidgetTester tester,
  String titulo,
  bool Function(TarjetaPartido) cumple, {
  String? motivo,
}) async {
  final tarjeta = find.byWidgetPredicate(
    (widget) =>
        widget is TarjetaPartido &&
        widget.partido.titulo == titulo &&
        cumple(widget),
  );
  await _esperar(tester, tarjeta, motivo: motivo);
  return tarjeta;
}

Future<void> _volverAlMenu(WidgetTester tester) async {
  await tester.pageBack();
  await _esperar(tester, find.byType(VistaPrincipal));
}

Future<void> _escribir(WidgetTester tester, Finder campo, String texto) async {
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pump(const Duration(milliseconds: 300));
  final esperaPulsable = Stopwatch()..start();
  while (objetivo.hitTestable().evaluate().isEmpty &&
      esperaPulsable.elapsed < const Duration(seconds: 6)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  if (objetivo.hitTestable().evaluate().isEmpty) {
    final desplazable = find.ancestor(
      of: objetivo,
      matching: find.byType(Scrollable),
    );
    if (desplazable.evaluate().isNotEmpty) {
      await tester.drag(desplazable.first, const Offset(0, -160));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  await tester.tap(objetivo.hitTestable());
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  String? motivo,
}) async {
  final reloj = Stopwatch()..start();
  while (objetivo.evaluate().isEmpty && reloj.elapsed.inSeconds < 45) {
    final errores = tester.widgetList<CajaMensaje>(
      find.byWidgetPredicate(
        (widget) => widget is CajaMensaje && widget.tipo == TipoMensaje.error,
      ),
    );
    if (errores.isNotEmpty) {
      fail('La app mostró un error: ${errores.first.texto}');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  // El campo de contraseña tiene una animación continua.
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 500));
}
