import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/main.dart';
import 'package:unisport/servicios/autenticacion/servicio_autenticacion.dart';
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_equipos.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const organizadorCorreo = String.fromEnvironment('E2E_ORGANIZADOR_CORREO');
const organizadorClave = String.fromEnvironment('E2E_ORGANIZADOR_CLAVE');
const capitanCorreo = String.fromEnvironment('E2E_CAPITAN_CORREO');
const capitanClave = String.fromEnvironment('E2E_CAPITAN_CLAVE');

const limite = Duration(seconds: 45);

class PartidoResultadoE2E {
  final String id;
  final String titulo;
  final String organizadorId;
  final String capitanId;
  final DateTime fechaInicio;

  const PartidoResultadoE2E({
    required this.id,
    required this.titulo,
    required this.organizadorId,
    required this.capitanId,
    required this.fechaInicio,
  });
}

void validarCredencialesE2E() {
  expect(
    organizadorCorreo.trim().contains('@') &&
        organizadorClave.length >= 6 &&
        capitanCorreo.trim().contains('@') &&
        capitanClave.length >= 6,
    isTrue,
    reason:
        'Indica E2E_ORGANIZADOR_CORREO, E2E_ORGANIZADOR_CLAVE, '
        'E2E_CAPITAN_CORREO y E2E_CAPITAN_CLAVE mediante --dart-define.',
  );
  expect(
    organizadorCorreo.trim().toLowerCase(),
    isNot(capitanCorreo.trim().toLowerCase()),
    reason: 'El organizador y el capitán deben ser cuentas diferentes.',
  );
}

Future<SupabaseClient> inicializarSupabaseE2E() async {
  await Supabase.initialize(
    url: ConfiguracionSupabase.url,
    publishableKey: ConfiguracionSupabase.clavePublica,
  );
  final cliente = Supabase.instance.client;
  await cliente.auth.signOut().timeout(limite);
  return cliente;
}

Future<PartidoResultadoE2E> prepararPartidoResultado(
  SupabaseClient cliente,
  String escenario,
) async {
  final marca = DateTime.now().microsecondsSinceEpoch;
  final titulo = 'E2E Resultado $escenario $marca';
  final fechaInicio = DateTime.now().toUtc().add(const Duration(seconds: 30));

  final sesionOrganizador = await cliente.auth
      .signInWithPassword(
        email: organizadorCorreo.trim(),
        password: organizadorClave,
      )
      .timeout(limite);
  final organizadorId = sesionOrganizador.user!.id;
  final perfilOrganizador = await cliente
      .from('perfiles')
      .select('nombre')
      .eq('id', organizadorId)
      .single()
      .timeout(limite);

  final partido = await cliente
      .from('partidos')
      .insert({
        'organizador_id': organizadorId,
        'organizador_nombre': perfilOrganizador['nombre'] as String,
        'titulo': titulo,
        'disciplina': 'Futsal',
        'ubicacion': 'Cancha E2E Resultado',
        'fecha_inicio': fechaInicio.toIso8601String(),
        'cupos_totales': 2,
        'cupos_ocupados': 1,
        'estado': 'cuposAbiertos',
      })
      .select('id')
      .single()
      .timeout(limite);
  final partidoId = partido['id'] as String;

  final sesionCapitan = await cliente.auth
      .signInWithPassword(email: capitanCorreo.trim(), password: capitanClave)
      .timeout(limite);
  final capitanId = sesionCapitan.user!.id;
  await cliente
      .rpc('unirse_a_partido', params: {'p_partido': partidoId})
      .timeout(limite);

  await cliente.auth
      .signInWithPassword(
        email: organizadorCorreo.trim(),
        password: organizadorClave,
      )
      .timeout(limite);
  await cliente
      .rpc(
        'guardar_propuesta_equipos',
        params: {
          'p_partido': partidoId,
          'p_equipo_a': [organizadorId],
          'p_equipo_b': [capitanId],
          'p_capitan_rival': capitanId,
        },
      )
      .timeout(limite);
  final propuesta = await cliente
      .from('propuestas_equipos')
      .select('revision')
      .eq('partido_id', partidoId)
      .single()
      .timeout(limite);

  await cliente.auth
      .signInWithPassword(email: capitanCorreo.trim(), password: capitanClave)
      .timeout(limite);
  await cliente
      .rpc(
        'responder_propuesta_equipos',
        params: {
          'p_partido': partidoId,
          'p_revision': propuesta['revision'],
          'p_acepta': true,
        },
      )
      .timeout(limite);
  await cliente.auth.signOut().timeout(limite);

  return PartidoResultadoE2E(
    id: partidoId,
    titulo: titulo,
    organizadorId: organizadorId,
    capitanId: capitanId,
    fechaInicio: fechaInicio,
  );
}

Future<void> limpiarPartidoResultado(
  SupabaseClient cliente,
  PartidoResultadoE2E partido,
) async {
  await cliente.auth
      .signInWithPassword(
        email: organizadorCorreo.trim(),
        password: organizadorClave,
      )
      .timeout(limite);
  await cliente
      .from('partidos')
      .delete()
      .eq('id', partido.id)
      .eq('organizador_id', partido.organizadorId)
      .timeout(limite);
  await cliente.auth.signOut().timeout(limite);
}

Future<void> iniciarAplicacionSinSesion(
  WidgetTester tester,
  SupabaseClient cliente,
) async {
  await cliente.auth.signOut().timeout(limite);
  final servicio = ServicioAutenticacionSupabase(cliente);
  await servicio.inicializar();
  await tester.pumpWidget(UniSportApp(servicioAuth: servicio));
  await esperar(tester, find.byType(VistaInicioPublico));
}

Future<void> iniciarSesionUI(
  WidgetTester tester,
  String correo,
  String clave,
) async {
  await tocar(tester, find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
  await esperar(tester, find.byType(VistaLogin));
  await escribir(tester, find.byKey(const Key('login_correo')), correo.trim());
  await escribir(
    tester,
    find.descendant(
      of: find.byKey(const Key('login_clave')),
      matching: find.byType(EditableText),
    ),
    clave,
  );
  await tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
  await esperar(
    tester,
    find.byType(VistaPrincipal),
    motivo: 'La cuenta indicada debe iniciar sesión.',
  );
}

Future<void> cambiarSesionUI(
  WidgetTester tester,
  String correo,
  String clave,
) async {
  for (
    var intento = 0;
    intento < 4 && find.byType(VistaPrincipal).evaluate().isEmpty;
    intento++
  ) {
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
  }
  await esperar(tester, find.byType(VistaPrincipal));
  await tocar(tester, find.text('CERRAR SESIÓN'));
  await esperar(tester, find.byType(VistaInicioPublico));
  await iniciarSesionUI(tester, correo, clave);
}

Future<void> abrirPartidoUI(
  WidgetTester tester,
  PartidoResultadoE2E partido,
) async {
  await tocar(tester, find.widgetWithText(ElevatedButton, 'Mis\nPartidos'));
  await esperar(tester, find.byType(VistaMisPartidos));
  final tarjeta = find.byWidgetPredicate(
    (widget) => widget is TarjetaPartido && widget.partido.id == partido.id,
    description: 'tarjeta del partido E2E ${partido.titulo}',
  );
  await esperar(
    tester,
    tarjeta,
    motivo: 'El partido preparado debe aparecer en Mis partidos.',
  );
  final verEquipos = find.descendant(
    of: tarjeta,
    matching: find.text('Ver equipos'),
  );
  await tocar(tester, verEquipos);
  await esperar(tester, find.byType(VistaEquipos));
  await esperar(tester, find.text(partido.titulo));
}

Future<void> recargarPartidoUI(
  WidgetTester tester,
  PartidoResultadoE2E partido,
) async {
  await tester.pageBack();
  await esperar(tester, find.byType(VistaMisPartidos));
  final tarjeta = find.byWidgetPredicate(
    (widget) => widget is TarjetaPartido && widget.partido.id == partido.id,
  );
  await esperar(tester, tarjeta);
  await tocar(
    tester,
    find.descendant(of: tarjeta, matching: find.text('Ver equipos')),
  );
  await esperar(tester, find.byType(VistaEquipos));
  await esperar(tester, find.text(partido.titulo));
}

Future<void> esperarPartidoTerminado(
  WidgetTester tester,
  PartidoResultadoE2E partido,
) async {
  final espera = partido.fechaInicio.difference(DateTime.now().toUtc());
  if (espera > Duration.zero) {
    // La regla se evalúa con now() en PostgreSQL, por eso debe transcurrir
    // tiempo real y no solamente el reloj simulado de WidgetTester.
    await Future<void>.delayed(espera + const Duration(seconds: 1));
    await tester.pump();
  }
}

Future<void> escribir(WidgetTester tester, Finder campo, String texto) async {
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(objetivo);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> esperar(
  WidgetTester tester,
  Finder objetivo, {
  String? motivo,
}) async {
  final reloj = Stopwatch()..start();
  while (objetivo.evaluate().isEmpty && reloj.elapsed < limite) {
    final errores = tester.widgetList<CajaMensaje>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CajaMensaje &&
            widget.tipo == TipoMensaje.error &&
            !widget.texto.startsWith('Motivo de la disputa:') &&
            !widget.texto.startsWith('Resultado definitivo:'),
      ),
    );
    if (errores.isNotEmpty) {
      fail('La aplicación mostró un error: ${errores.first.texto}');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(objetivo, findsWidgets, reason: motivo);
}
