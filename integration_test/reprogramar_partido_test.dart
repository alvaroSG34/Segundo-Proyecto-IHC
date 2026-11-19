import 'apoyo/analitica_e2e.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/vistas/partidos/vista_detalle_partido.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/partidos/vista_reprogramar_partido.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';
import 'package:unisport/widgets/tarjeta_mis_partidos.dart';

import 'apoyo/resultado_partido_e2e.dart'
    show
        cambiarSesionUI,
        escribir,
        esperar,
        esperarDetalleCargado,
        inicializarSupabaseE2E,
        iniciarAplicacionSinSesion,
        iniciarSesionUI,
        limite,
        tocar;

const _organizadorCorreo = String.fromEnvironment('E2E_ORGANIZADOR_CORREO');
const _organizadorClave = String.fromEnvironment('E2E_ORGANIZADOR_CLAVE');
const _titularCorreo = String.fromEnvironment('E2E_TITULAR_CORREO');
const _titularClave = String.fromEnvironment('E2E_TITULAR_CLAVE');
const _suplenteCorreo = String.fromEnvironment('E2E_SUPLENTE_CORREO');
const _suplenteClave = String.fromEnvironment('E2E_SUPLENTE_CLAVE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Reprogramar, reconfirmar y promover un suplente registra tracks',
    (tester) async {
      await verificarTracksAlTerminar([
        'reprogramacion_iniciada',
        'reconfirmacion_iniciada',
      ]);
      final correos = [_organizadorCorreo, _titularCorreo, _suplenteCorreo];
      expect(
        correos.every((correo) => correo.trim().contains('@')) &&
            [
              _organizadorClave,
              _titularClave,
              _suplenteClave,
            ].every((clave) => clave.length >= 6),
        isTrue,
        reason:
            'Indica las seis variables E2E de organizador, titular y suplente.',
      );
      expect(
        correos.map((correo) => correo.trim().toLowerCase()).toSet(),
        hasLength(3),
      );
      final semantica = tester.ensureSemantics();
      try {
        final cliente = await inicializarSupabaseE2E();
        final datos = SupabaseClient(
          ConfiguracionSupabase.url,
          ConfiguracionSupabase.clavePublica,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(() async {
          await cliente.auth.signOut().timeout(limite);
          await datos.dispose();
        });
        await datos.auth
            .signInWithPassword(
              email: _organizadorCorreo.trim(),
              password: _organizadorClave,
            )
            .timeout(limite);
        final organizadorId = datos.auth.currentUser!.id;
        final perfil = await datos
            .from('perfiles')
            .select('nombre')
            .eq('id', organizadorId)
            .single()
            .timeout(limite);
        final titulo =
            'E2E Reprogramar ${DateTime.now().microsecondsSinceEpoch}';
        addTearDown(() async {
          await datos
              .from('partidos')
              .delete()
              .eq('organizador_id', organizadorId)
              .eq('titulo', titulo)
              .timeout(limite);
        });
        final ahora = DateTime.now();
        final fecha = DateTime(ahora.year, ahora.month, ahora.day + 2, 19);
        final partido = await RepositorioPartidosSupabase(datos)
            .crearPartido(
              ModeloPartido(
                id: '',
                titulo: titulo,
                disciplina: 'Futsal',
                icono: 'Futsal',
                ubicacion: 'Cancha E2E original',
                fechaHora: ModeloPartido.formatearFechaHora(fecha),
                cuposTotales: 2,
                cuposOcupados: 1,
                organizadorNombre: perfil['nombre'] as String,
              ),
            )
            .timeout(limite);
        final repositorio = RepositorioPartidosSupabase(cliente);
        for (final cuenta in [
          (_titularCorreo, _titularClave),
          (_suplenteCorreo, _suplenteClave),
        ]) {
          await cliente.auth
              .signInWithPassword(email: cuenta.$1.trim(), password: cuenta.$2)
              .timeout(limite);
          if (cuenta.$1 == _titularCorreo) {
            await repositorio.unirseAPartido(partido.id).timeout(limite);
          } else {
            await repositorio.entrarEnEspera(partido.id).timeout(limite);
          }
        }
        final suplenteId = cliente.auth.currentUser!.id;

        await iniciarAplicacionSinSesion(tester, cliente);
        await iniciarSesionUI(tester, _organizadorCorreo, _organizadorClave);
        await _abrirPartido(tester, partido.id);
        await _reprogramar(
          tester,
          partido.id,
          fecha.add(const Duration(days: 1)),
          'Cancha E2E nueva',
        );
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.respuestasPendientes == 1 && p.cuposOcupados == 2,
        );
        expect(_partidoActual(tester).puedeReprogramar, isFalse);

        await cambiarSesionUI(tester, _titularCorreo, _titularClave);
        await _abrirPartido(tester, partido.id);
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.reconfirmacionPendiente && p.ubicacion == 'Cancha E2E nueva',
        );
        await _tocarReconfirmar(tester, partido.id);
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.reconfirmacionAceptada && !p.reconfirmacionPendiente,
        );

        // Una segunda reprogramación vuelve a pedir la confirmación del titular.
        await cambiarSesionUI(tester, _organizadorCorreo, _organizadorClave);
        await _abrirPartido(tester, partido.id);
        await _reprogramar(
          tester,
          partido.id,
          fecha.add(const Duration(days: 2)),
          'Cancha E2E final',
        );
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.respuestasPendientes == 1,
        );
        await cambiarSesionUI(tester, _titularCorreo, _titularClave);
        await _abrirPartido(tester, partido.id);
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.reconfirmacionPendiente && !p.reconfirmacionAceptada,
        );
        await _tocarRetirarme(tester, partido.id);
        await esperar(tester, find.text('¿Retirarte del partido?'));
        await tocar(tester, find.text('Cancelar'));
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.reconfirmacionPendiente && p.estoyUnido,
        );
        await _tocarRetirarme(tester, partido.id);
        await esperar(tester, find.text('Sí, retirarme'));
        await tocar(tester, find.text('Sí, retirarme'));
        await esperar(tester, find.text('Te retiraste del partido.'));

        // El suplente promovido también debe reconfirmar, desde Explorar.
        await cambiarSesionUI(tester, _suplenteCorreo, _suplenteClave);
        await _abrirPartido(tester, partido.id, explorar: true, titulo: titulo);
        await _esperarPartido(
          tester,
          partido.id,
          (p) =>
              p.estoyUnido &&
              !p.estoyEnEspera &&
              p.reconfirmacionPendiente &&
              p.cuposOcupados == 2,
        );
        await _tocarReconfirmar(tester, partido.id);
        await _esperarPartido(
          tester,
          partido.id,
          (p) => p.reconfirmacionAceptada && p.respuestasPendientes == 0,
        );

        // Reabrir con otra sesión comprueba que los cambios quedaron guardados.
        await cambiarSesionUI(tester, _organizadorCorreo, _organizadorClave);
        await _abrirPartido(tester, partido.id);
        await _esperarPartido(
          tester,
          partido.id,
          (p) =>
              p.respuestasPendientes == 0 &&
              p.cuposOcupados == 2 &&
              p.ubicacion == 'Cancha E2E final' &&
              p.fechaInicio == fecha.add(const Duration(days: 2)),
        );
        expect(_partidoActual(tester).puedeReprogramar, isTrue);
        final participantes = await repositorio
            .obtenerParticipantes(partido.id)
            .timeout(limite);
        expect(
          participantes.map((p) => p.id),
          unorderedEquals([organizadorId, suplenteId]),
        );
        debugPrint(
          'Reprogramación E2E: datos y participantes verificados.',
        );
      } finally {
        semantica.dispose();
      }
    },
  );
}

Future<void> _abrirPartido(
  WidgetTester tester,
  String id, {
  bool explorar = false,
  String titulo = '',
}) async {
  await tocar(
    tester,
    find.widgetWithText(
      ElevatedButton,
      explorar ? 'Explorar' : 'Mis\nPartidos',
    ),
  );
  await esperar(
    tester,
    find.byType(explorar ? VistaExplorarPartidos : VistaMisPartidos),
  );
  if (explorar) {
    await escribir(tester, find.byType(TextField).first, titulo);
    await _esperarPartido(tester, id, (_) => true);
  } else {
    final chipTodos = find.descendant(
      of: find.byKey(const Key('mis_partidos_filtro_todos')),
      matching: find.byWidgetPredicate(
        (w) => w is ChoiceChip && w.onSelected != null,
      ),
    );
    await esperar(tester, chipTodos);
    await tocar(tester, find.byKey(const Key('mis_partidos_filtro_todos')));
    final resumen = find.byWidgetPredicate(
      (widget) => widget is TarjetaMisPartidos && widget.partido.id == id,
    );
    await esperar(tester, resumen);
    await tocar(tester, find.byKey(Key('mis_partidos_detalle_$id')));
    await esperar(tester, find.byType(VistaDetallePartido));
    await esperarDetalleCargado(tester);
    await _esperarPartido(tester, id, (_) => true);
  }
}

ModeloPartido _partidoActual(WidgetTester tester) {
  if (find.byType(VistaDetallePartido).evaluate().isNotEmpty) {
    final state = tester.state(find.byType(VistaDetallePartido));
    return (state as dynamic).partido as ModeloPartido;
  }
  if (find.byType(TarjetaPartido).evaluate().isNotEmpty) {
    final tarjeta = tester.widget<TarjetaPartido>(find.byType(TarjetaPartido));
    return tarjeta.partido;
  }
  final tarjetaMis =
      tester.widget<TarjetaMisPartidos>(find.byType(TarjetaMisPartidos));
  return tarjetaMis.partido;
}

Future<void> _esperarPartido(
  WidgetTester tester,
  String id,
  bool Function(ModeloPartido) cumple,
) => esperar(
  tester,
  find.byWidgetPredicate((widget) {
    if (widget is VistaDetallePartido) {
      final p = _partidoActual(tester);
      return p.id == id && cumple(p);
    }
    if (widget is TarjetaPartido) {
      return widget.partido.id == id && cumple(widget.partido);
    }
    if (widget is TarjetaMisPartidos) {
      return widget.partido.id == id && cumple(widget.partido);
    }
    return false;
  }),
);

Future<void> _tocarReconfirmar(WidgetTester tester, String id) async {
  if (find.byType(VistaDetallePartido).evaluate().isNotEmpty) {
    await esperarDetalleCargado(tester);
    final btn = find.widgetWithText(FilledButton, 'Confirmar asistencia');
    final scroll = find.descendant(
      of: find.byType(VistaDetallePartido),
      matching: find.byType(Scrollable),
    );
    if (scroll.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(btn, 250, scrollable: scroll.first);
      } catch (_) {}
    }
    await esperar(tester, btn);
    await tocar(tester, btn);
  } else {
    final tarjeta = _tarjeta(id);
    final btn = _boton(id, 'partido_reconfirmar');
    final scroll = find.byType(Scrollable);
    if (scroll.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          tarjeta,
          250,
          scrollable: scroll.first,
          maxScrolls: 30,
        );
      } catch (_) {}
      try {
        await tester.scrollUntilVisible(
          btn,
          150,
          scrollable: scroll.first,
          maxScrolls: 30,
        );
      } catch (_) {}
    }
    await esperar(tester, btn);
    await tocar(tester, btn);
  }
}

Future<void> _tocarRetirarme(WidgetTester tester, String id) async {
  if (find.byType(VistaDetallePartido).evaluate().isNotEmpty) {
    await esperarDetalleCargado(tester);
    await tocar(tester, find.byTooltip('Más acciones'));
    await esperar(tester, find.text('Retirarme de la nueva fecha'));
    await tocar(tester, find.text('Retirarme de la nueva fecha').last);
  } else {
    final tarjeta = _tarjeta(id);
    final btn = _boton(id, 'partido_retirarse_reprogramacion');
    final scroll = find.byType(Scrollable);
    if (scroll.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          tarjeta,
          250,
          scrollable: scroll.first,
          maxScrolls: 30,
        );
      } catch (_) {}
      try {
        await tester.scrollUntilVisible(
          btn,
          150,
          scrollable: scroll.first,
          maxScrolls: 30,
        );
      } catch (_) {}
    }
    await esperar(tester, btn);
    await tocar(tester, btn);
  }
}

Finder _tarjeta(String id) => find.byWidgetPredicate(
  (widget) => widget is TarjetaPartido && widget.partido.id == id,
);

Finder _boton(String id, String clave) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is TarjetaPartido && widget.partido.id == id,
  ),
  matching: find.byKey(Key(clave)),
);

Future<void> _reprogramar(
  WidgetTester tester,
  String id,
  DateTime fecha,
  String lugar,
) async {
  if (find.byType(VistaDetallePartido).evaluate().isNotEmpty) {
    await esperarDetalleCargado(tester);
    await tocar(tester, find.byTooltip('Más acciones'));
    await esperar(tester, find.text('Reprogramar'));
    await tocar(tester, find.text('Reprogramar').last);
  } else {
    await tocar(tester, _boton(id, 'partido_reprogramar'));
  }
  await esperar(tester, find.byType(VistaReprogramarPartido));
  final formulario = tester.widget<VistaReprogramarPartido>(
    find.byType(VistaReprogramarPartido),
  );
  await tocar(tester, find.byKey(const Key('reprogramar_fecha')));
  await esperar(tester, find.byType(DatePickerDialog));
  final localizacion = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  );
  if (formulario.partido.fechaInicio!.month != fecha.month) {
    await tocar(tester, find.byTooltip(localizacion.nextMonthTooltip));
  }
  await tocar(
    tester,
    find
        .descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('${fecha.day}'),
        )
        .hitTestable()
        .last,
  );
  await tocar(tester, find.text(localizacion.okButtonLabel));
  await escribir(tester, find.byKey(const Key('reprogramar_lugar')), lugar);
  await escribir(
    tester,
    find.byKey(const Key('reprogramar_motivo')),
    'Cambio de cancha para la prueba E2E',
  );
  await tocar(tester, find.byKey(const Key('reprogramar_guardar')));
  await esperar(
    tester,
    find.byWidgetPredicate(
      (w) => w is VistaDetallePartido || w is VistaMisPartidos,
    ),
  );
}
