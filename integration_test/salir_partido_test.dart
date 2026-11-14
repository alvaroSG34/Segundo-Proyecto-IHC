import 'apoyo/analitica_e2e.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/tema/tema_app.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_explorar_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _correoAux = String.fromEnvironment('E2E_CORREO_AUXILIAR');
const _claveAux = String.fromEnvironment('E2E_CLAVE_AUXILIAR');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Salir de un partido: cancelar, confirmar y liberar el último cupo',
    (tester) async {
      await verificarTracksAlTerminar(['salida_iniciada']);
      expect(
        [_correo, _correoAux].every((v) => v.trim().contains('@')) &&
            [_clave, _claveAux].every((v) => v.trim().length >= 6),
        isTrue,
        reason: 'Indica E2E_CORREO, E2E_CLAVE, E2E_CORREO_AUXILIAR y E2E_CLAVE_AUXILIAR de dos cuentas existentes, confirmadas y con perfil.',
      );
      expect(
        _correo.trim().toLowerCase() != _correoAux.trim().toLowerCase(),
        isTrue,
        reason: 'El jugador y el organizador deben usar cuentas distintas.',
      );

      final datos = SupabaseClient(
        ConfiguracionSupabase.url,
        ConfiguracionSupabase.clavePublica,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      addTearDown(() async {
        try {
          if (datos.auth.currentSession != null) {
            await datos.auth.signOut().timeout(_limite);
          }
        } finally {
          await datos.dispose();
        }
      });

      debugPrint('Salir E2E · 1/5: preparación, cuentas y partido temporal');
      try {
        await datos.auth
            .signInWithPassword(email: _correoAux.trim(), password: _claveAux)
            .timeout(_limite);
      } catch (_) {
        fail(
          'Preparación: no se pudo autenticar el auxiliar. Verifica credenciales, cuenta confirmada y conexión.',
        );
      }
      final organizador = datos.auth.currentUser?.id;
      expect(organizador != null, isTrue, reason: 'Debe haber un organizador.');
      final perfilAux = await datos
          .from('perfiles')
          .select()
          .eq('id', organizador!)
          .maybeSingle()
          .timeout(_limite);
      expect(
        (perfilAux?['nombre'] as String? ?? '').trim().isNotEmpty,
        isTrue,
        reason: 'El auxiliar debe tener perfil con nombre.',
      );

      final ahora = DateTime.now();
      final titulo = 'E2E salir ${ahora.microsecondsSinceEpoch}';
      String? id;
      addTearDown(() async {
        var borrar = datos
            .from('partidos')
            .delete()
            .eq('organizador_id', organizador);
        borrar = id == null ? borrar.eq('titulo', titulo) : borrar.eq('id', id);
        await borrar.timeout(_limite);
      });
      final partido = await RepositorioPartidosSupabase(datos)
          .crearPartido(
            ModeloPartido(
              id: '',
              titulo: titulo,
              disciplina: 'Futsal',
              icono: 'Futsal',
              ubicacion: 'Cancha E2E',
              fechaHora: ModeloPartido.formatearFechaHora(
                DateTime(ahora.year, ahora.month, ahora.day + 2, 19),
              ),
              cuposTotales: 2,
              cuposOcupados: 1,
              organizadorNombre: perfilAux!['nombre'] as String,
            ),
          )
          .timeout(_limite);
      id = partido.id;

      final semantica = tester.ensureSemantics();
      try {
        app.main();
        await _esperar(
          tester,
          find.byWidgetPredicate(
            (w) => w is VistaInicioPublico || w is VistaPrincipal,
          ),
        );
        final cliente = Supabase.instance.client;
        addTearDown(() => cliente.auth.signOut().timeout(_limite));
        if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
          await _tocar(tester, find.text('CERRAR SESIÓN'));
          await _esperar(tester, find.byType(VistaInicioPublico));
        }
        expect(
          cliente.auth.currentSession == null,
          isTrue,
          reason: 'La app debe iniciar sin una sesión anterior.',
        );
        await _tocar(tester, find.bySemanticsLabel('Iniciar sesión'));
        await _esperar(tester, find.byType(VistaLogin));
        await _escribir(tester, 'login_correo', _correo.trim());
        await _escribir(tester, 'login_clave', _clave);
        await _tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
        await _esperar(tester, find.byType(VistaPrincipal));

        final jugador = cliente.auth.currentUser?.id;
        expect(
          jugador != null && jugador != organizador,
          isTrue,
          reason: 'La cuenta principal debe ser distinta del organizador.',
        );
        expect(
          cliente.auth.currentUser?.email?.toLowerCase() ==
              _correo.trim().toLowerCase(),
          isTrue,
          reason: 'Debe iniciar sesión la cuenta principal suministrada.',
        );
        final perfil = await cliente
            .from('perfiles')
            .select()
            .eq('id', jugador!)
            .maybeSingle()
            .timeout(_limite);
        expect(
          perfil != null &&
              [
                'nombre',
                'correo',
                'carrera',
              ].every((k) => (perfil[k] as String? ?? '').trim().isNotEmpty),
          isTrue,
          reason: 'La cuenta principal debe tener perfil completo.',
        );

        debugPrint('Salir E2E · 2/5: acceder a Explorar y unirse');
        final acceso = find.widgetWithText(ElevatedButton, 'Explorar');
        await _visible(tester, acceso);
        _accesible(
          tester,
          find.bySemanticsLabel('Explorar'),
          acceso,
          'Explorar',
        );
        await _tocar(tester, find.bySemanticsLabel('Explorar'));
        await _esperar(tester, find.byType(VistaExplorarPartidos));
        await _escribir(tester, 'explorar_busqueda', titulo);
        await _esperar(
          tester,
          find.byKey(const Key('explorar_cargando')),
          ausente: true,
        );
        await _esperar(tester, _tarjeta(partido.id));
        expect(
          tester
              .widget<TarjetaPartido>(_tarjeta(partido.id))
              .partido
              .cuposOcupados,
          1,
          reason: 'El partido temporal debe iniciar con 1/2 cupos.',
        );

        final unirse = find.descendant(
          of: _tarjeta(partido.id),
          matching: find.bySemanticsLabel('Unirme al equipo'),
        );
        await _tocar(tester, unirse);
        await _esperar(tester, find.byType(AlertDialog));
        await _tocar(tester, _dialogo(find.bySemanticsLabel('Sí, unirme')));
        await _esperar(
          tester,
          find.text('¡Te uniste a "$titulo"! (2/2) El equipo quedó completo.'),
        );
        await _esperar(
          tester,
          find.byKey(const Key('explorar_cargando')),
          ausente: true,
        );
        await _esperarEstado(tester, partido.id, unido: true, ocupados: 2);
        var tarjeta = tester.widget<TarjetaPartido>(_tarjeta(partido.id));
        expect(tarjeta.partido.estoyUnido, isTrue);
        expect(tarjeta.partido.cuposOcupados, 2);
        expect(tarjeta.partido.estado, EstadoPartido.equipoCompleto);
        await _comprobarPersistencia(datos, partido.id, jugador, 1, 2);

        debugPrint(
          'Salir E2E · 3/5: cancelar salida sin cambiar la inscripción',
        );
        final salir = find.descendant(
          of: _tarjeta(partido.id),
          matching: find.bySemanticsLabel('Salir del partido'),
        );
        final salirVisual = find.descendant(
          of: _tarjeta(partido.id),
          matching: find.widgetWithText(OutlinedButton, 'Salir del partido'),
        );
        await _visible(tester, salirVisual);
        _accesible(tester, salir, salirVisual, 'Salir del partido');
        await _tocar(tester, salir);
        await _esperar(tester, find.byType(AlertDialog));
        expect(
          _dialogo(find.text('¿Salir del partido?')),
          findsOneWidget,
          reason: 'Debe explicar que se liberará el cupo.',
        );
        final cancelar = _dialogo(find.bySemanticsLabel('Cancelar'));
        final cancelarVisual = _dialogo(
          find.widgetWithText(OutlinedButton, 'Cancelar'),
        );
        await _visible(tester, cancelarVisual);
        _accesible(tester, cancelar, cancelarVisual, 'Cancelar');
        await _tocar(tester, cancelar);
        expect(find.byType(AlertDialog), findsNothing);
        await _esperarEstado(tester, partido.id, unido: true, ocupados: 2);
        tarjeta = tester.widget<TarjetaPartido>(_tarjeta(partido.id));
        expect(tarjeta.partido.estoyUnido, isTrue);
        expect(tarjeta.partido.cuposOcupados, 2);
        expect(tarjeta.partido.estado, EstadoPartido.equipoCompleto);
        await _comprobarPersistencia(datos, partido.id, jugador, 1, 2);

        debugPrint('Salir E2E · 4/5: confirmar y comprobar salida real');
        await _tocar(tester, salir);
        await _esperar(tester, find.byType(AlertDialog));
        final confirmar = _dialogo(find.bySemanticsLabel('Sí, salir'));
        final confirmarVisual = _dialogo(
          find.widgetWithText(OutlinedButton, 'Sí, salir'),
        );
        await _visible(tester, confirmarVisual);
        _accesible(tester, confirmar, confirmarVisual, 'Sí, salir');
        await _tocar(tester, confirmar);
        await _esperar(
          tester,
          find.text('Saliste de "$titulo". Tu cupo quedó libre.'),
        );
        await _esperarEstado(tester, partido.id, unido: false, ocupados: 1);
        tarjeta = tester.widget<TarjetaPartido>(_tarjeta(partido.id));
        expect(tarjeta.partido.estoyUnido, isFalse);
        expect(tarjeta.partido.cuposOcupados, 1);
        expect(tarjeta.partido.cuposTotales, 2);
        expect(tarjeta.partido.estado, EstadoPartido.cuposAbiertos);
        expect(
          find.descendant(
            of: _tarjeta(partido.id),
            matching: find.bySemanticsLabel('Unirme al equipo'),
          ),
          findsOneWidget,
          reason: 'Al salir debe poder volver a unirse al cupo liberado.',
        );
        expect(
          find.descendant(
            of: _tarjeta(partido.id),
            matching: find.text('Salir del partido'),
          ),
          findsNothing,
          reason: 'Al salir ya no debe ofrecer salir de nuevo.',
        );
        await _comprobarPersistencia(datos, partido.id, jugador, 0, 1);

        debugPrint(
          'Salir E2E · 5/5: recargar Explorar y verificar persistencia',
        );
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        await _tocar(tester, find.bySemanticsLabel('Explorar'));
        await _esperar(tester, find.byType(VistaExplorarPartidos));
        await _escribir(tester, 'explorar_busqueda', titulo);
        await _esperar(
          tester,
          find.byKey(const Key('explorar_cargando')),
          ausente: true,
        );
        await _esperarEstado(tester, partido.id, unido: false, ocupados: 1);
        tarjeta = tester.widget<TarjetaPartido>(_tarjeta(partido.id));
        expect(tarjeta.partido.estoyUnido, isFalse);
        expect(tarjeta.partido.cuposOcupados, 1);
        expect(tarjeta.partido.estado, EstadoPartido.cuposAbiertos);
        expect(
          cliente.auth.currentSession != null &&
              cliente.auth.currentUser?.id == jugador,
          isTrue,
          reason:
              'La salida y la consulta deben conservar la sesión del jugador.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _comprobarPersistencia(
  SupabaseClient datos,
  String partido,
  String jugador,
  int cantidadInscripciones,
  int cuposOcupados,
) async {
  final inscripciones = await datos
      .from('inscripciones')
      .select()
      .eq('partido_id', partido)
      .eq('jugador_id', jugador)
      .timeout(_limite);
  expect(
    inscripciones.length,
    cantidadInscripciones,
    reason: 'La inscripción debe reflejar el estado de la salida.',
  );
  final fila = await datos
      .from('partidos')
      .select()
      .eq('id', partido)
      .single()
      .timeout(_limite);
  expect(fila['cupos_ocupados'], cuposOcupados);
  expect(fila['cupos_totales'], 2);
  expect(
    fila['estado'],
    cuposOcupados == 2 ? 'equipoCompleto' : 'cuposAbiertos',
  );
}

Finder _tarjeta(String id) => find.byWidgetPredicate(
  (w) => w is TarjetaPartido && w.partido.id == id,
  description: 'tarjeta del partido temporal por ID',
);

Finder _dialogo(Finder control) =>
    find.descendant(of: find.byType(AlertDialog), matching: control);

void _accesible(
  WidgetTester tester,
  Finder accesible,
  Finder visual,
  String nombre,
) {
  expect(
    accesible,
    findsOneWidget,
    reason: '$nombre debe tener nombre accesible.',
  );
  expect(
    tester.getSemantics(accesible).getSemanticsData().flagsCollection.isButton,
    isTrue,
    reason: '$nombre debe exponer el rol de botón.',
  );
  final size = tester.getSize(visual);
  expect(
    size.width,
    greaterThanOrEqualTo(48),
    reason: '$nombre: ancho táctil mínimo de 48.',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(48),
    reason: '$nombre: alto táctil mínimo de 48.',
  );
}

Future<void> _visible(WidgetTester tester, Finder control) async {
  expect(control, findsOneWidget);
  await tester.ensureVisible(control);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tocar(WidgetTester tester, Finder control) async {
  await _visible(tester, control);
  await tester.tap(control);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _escribir(WidgetTester tester, String key, String texto) async {
  final campo = find.byKey(Key(key));
  await _visible(tester, campo);
  final editable = find.descendant(
    of: campo,
    matching: find.byType(EditableText),
  );
  tester.binding.focusedEditable = null;
  await tester.showKeyboard(editable);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(editable, texto);
  await tester.pump(const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.widget<EditableText>(editable).controller.text == texto,
    isTrue,
    reason: 'El campo $key debe conservar el dato introducido.',
  );
}

// Esperar la tarjeta por ID no basta: puede seguir mostrando el estado anterior.
Future<void> _esperarEstado(
  WidgetTester tester,
  String id, {
  required bool unido,
  required int ocupados,
}) => _esperar(
  tester,
  _tarjeta(id),
  condicion: () {
    final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
    return p.estoyUnido == unido &&
        p.cuposOcupados == ocupados &&
        p.cuposTotales == 2 &&
        p.estado ==
            (ocupados == 2
                ? EstadoPartido.equipoCompleto
                : EstadoPartido.cuposAbiertos);
  },
  motivo: 'La tarjeta debe reflejar la pertenencia y los cupos después de la operación.',
);

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  bool ausente = false,
  bool Function()? condicion,
  String? motivo,
}) async {
  final reloj = Stopwatch()..start();
  while (reloj.elapsed < _limite) {
    if (tester
            .widgetList<CajaMensaje>(find.byType(CajaMensaje))
            .any((mensaje) => mensaje.tipo == TipoMensaje.error) ||
        tester
            .widgetList<SnackBar>(find.byType(SnackBar))
            .any((aviso) => aviso.backgroundColor == TemaApp.rojoAlerta)) {
      fail(
        'La aplicación mostró un error inesperado durante la autenticación, unión o salida. Revisa conexión, cuenta y esquema.',
      );
    }
    final cantidad = objetivo.evaluate().length;
    if ((ausente ? cantidad == 0 : cantidad == 1) &&
        (condicion == null || condicion())) {
      // Completar las transiciones finitas sin esperar animaciones continuas.
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(
    motivo ?? 'Tiempo agotado esperando $objetivo${ausente ? ' ausente' : ''}.',
  );
}
