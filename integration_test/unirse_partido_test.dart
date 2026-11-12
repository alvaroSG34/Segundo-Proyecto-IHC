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
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _correoAux = String.fromEnvironment('E2E_CORREO_AUXILIAR');
const _claveAux = String.fromEnvironment('E2E_CLAVE_AUXILIAR');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Unirse a un partido: cancelar, confirmar e inscripción persistida',
    (tester) async {
      await verificarTracksAlTerminar(['union_iniciada']);
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
      debugPrint('Unirse E2E · 1/5: preparación, ingreso y búsqueda');
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
      expect(
        organizador != null,
        isTrue,
        reason: 'Debe existir un organizador autenticado.',
      );
      final perfilAux = await datos
          .from('perfiles')
          .select()
          .eq('id', organizador!)
          .maybeSingle()
          .timeout(_limite);
      expect(
        perfilAux != null &&
            (perfilAux['nombre'] as String? ?? '').trim().isNotEmpty,
        isTrue,
        reason: 'El auxiliar debe tener perfil con nombre.',
      );
      final ahora = DateTime.now();
      final titulo = 'E2E unirse ${ahora.microsecondsSinceEpoch}';
      String? id;
      // Registrar antes de insertar para cubrir una respuesta de creación perdida.
      addTearDown(() async {
        var borrar = datos
            .from('partidos')
            .delete()
            .eq('organizador_id', organizador);
        borrar = id == null ? borrar.eq('titulo', titulo) : borrar.eq('id', id);
        await borrar.timeout(
          _limite,
        ); // Las inscripciones se eliminan en cascada.
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
              cuposTotales: 6,
              cuposOcupados: 1,
              organizadorNombre: perfilAux!['nombre'] as String,
            ),
          )
          .timeout(_limite);
      id = partido.id;
      final original = await datos
          .from('partidos')
          .select()
          .eq('id', partido.id)
          .single()
          .timeout(_limite);
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
          reason: 'Debe cerrarse cualquier sesión previa.',
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
          reason: 'El jugador autenticado debe ser distinto del organizador.',
        );
        expect(
          cliente.auth.currentUser?.email?.toLowerCase() ==
              _correo.trim().toLowerCase(),
          isTrue,
          reason:
              'La sesión debe corresponder a la cuenta principal suministrada.',
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
          reason: 'Preparación: el jugador debe tener un perfil completo.',
        );
        var toques = 0;
        final acceso = find.widgetWithText(ElevatedButton, 'Explorar');
        await _visible(tester, acceso);
        _accesible(
          tester,
          find.bySemanticsLabel('Explorar'),
          acceso,
          'Explorar',
        );
        await _tocar(tester, find.bySemanticsLabel('Explorar'));
        toques++;
        await _esperar(tester, find.byType(VistaExplorarPartidos));
        expect(
          toques,
          1,
          reason: 'Acceder a Explorar requiere un toque desde el menú.',
        );
        expect(
          toques,
          lessThanOrEqualTo(3),
          reason: 'El acceso debe respetar el máximo de tres toques.',
        );
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
              .soyOrganizador,
          isFalse,
          reason: 'El resultado debe pertenecer al organizador auxiliar.',
        );

        debugPrint('Unirse E2E · 2/5: cancelar sin ocupar cupo');
        await _abrirConfirmacion(tester, partido.id, titulo);
        final cancelar = _dialogo(find.widgetWithText(TextButton, 'Cancelar'));
        await _visible(tester, cancelar);
        _accesible(
          tester,
          _dialogo(find.bySemanticsLabel('Cancelar')),
          cancelar,
          'Cancelar',
        );
        await _tocar(tester, _dialogo(find.bySemanticsLabel('Cancelar')));
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'Cancelar debe cerrar el diálogo.',
        );
        expect(
          _tarjeta(partido.id),
          findsOneWidget,
          reason: 'Cancelar conserva la tarjeta.',
        );
        expect(
          tester
              .widget<TarjetaPartido>(_tarjeta(partido.id))
              .partido
              .estoyUnido,
          isFalse,
          reason: 'Cancelar no debe mostrar al jugador como inscrito.',
        );
        expect(
          await datos
              .from('partidos')
              .select()
              .eq('id', partido.id)
              .single()
              .timeout(_limite),
          original,
          reason: 'Cancelar conserva la fila completa y el único cupo ocupado.',
        );
        expect(
          await _inscripciones(datos, partido.id, jugador),
          isEmpty,
          reason: 'Cancelar no debe crear una inscripción.',
        );

        debugPrint('Unirse E2E · 3/5: confirmar unión real');
        await _abrirConfirmacion(tester, partido.id, titulo);
        final confirmar = _dialogo(
          find.widgetWithText(ElevatedButton, 'Sí, unirme'),
        );
        await _visible(tester, confirmar);
        _accesible(
          tester,
          _dialogo(find.bySemanticsLabel('Sí, unirme')),
          confirmar,
          'Sí, unirme',
        );
        await _tocar(tester, _dialogo(find.bySemanticsLabel('Sí, unirme')));
        await _esperar(tester, find.text('¡Te uniste a "$titulo"! (2/6)'));
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'Confirmar debe cerrar el diálogo.',
        );
        await _esperar(
          tester,
          find.byKey(const Key('explorar_cargando')),
          ausente: true,
        );
        await _comprobarUnion(tester, partido.id);

        debugPrint(
          'Unirse E2E · 4/5: inscripción única en Supabase antes de limpiar',
        );
        final inscripciones = await _inscripciones(datos, partido.id, jugador);
        expect(
          inscripciones.length,
          1,
          reason: 'Debe existir exactamente una inscripción del jugador en el partido.',
        );
        expect(
          inscripciones.single['jugador_id'] == jugador,
          isTrue,
          reason: 'La inscripción debe pertenecer al jugador autenticado.',
        );
        expect(
          inscripciones.single['partido_id'],
          partido.id,
          reason: 'La inscripción debe corresponder al partido preparado.',
        );
        final fila = await datos
            .from('partidos')
            .select()
            .eq('id', partido.id)
            .single()
            .timeout(_limite);
        expect(
          fila['organizador_id'] == organizador,
          isTrue,
          reason: 'Unirse conserva el organizador.',
        );
        expect(
          fila['cupos_ocupados'],
          2,
          reason: 'Confirmar debe ocupar exactamente un cupo adicional.',
        );
        expect(
          fila['cupos_totales'],
          6,
          reason: 'Unirse no debe cambiar el total de cupos.',
        );
        expect(
          fila['estado'],
          'cuposAbiertos',
          reason: 'El equipo debe permanecer abierto.',
        );

        debugPrint('Unirse E2E · 5/5: persistencia en Mis partidos');
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
        await _esperar(tester, find.byType(VistaMisPartidos));
        await _esperar(
          tester,
          find.byKey(const Key('mis_partidos_cargando')),
          ausente: true,
        );
        await _comprobarUnion(tester, partido.id);
        expect(
          cliente.auth.currentSession != null &&
              cliente.auth.currentUser?.id == jugador,
          isTrue,
          reason: 'La unión y la consulta deben conservar la sesión principal.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<List<Map<String, dynamic>>> _inscripciones(
  SupabaseClient c,
  String partido,
  String jugador,
) => c
    .from('inscripciones')
    .select()
    .eq('partido_id', partido)
    .eq('jugador_id', jugador)
    .timeout(_limite);
Finder _tarjeta(String id) => find.byWidgetPredicate(
  (w) => w is TarjetaPartido && w.partido.id == id,
  description: 'tarjeta del partido temporal por ID',
);
Finder _dialogo(Finder control) =>
    find.descendant(of: find.byType(AlertDialog), matching: control);
Future<void> _abrirConfirmacion(
  WidgetTester tester,
  String id,
  String titulo,
) async {
  final visual = find.descendant(
    of: _tarjeta(id),
    matching: find.widgetWithText(ElevatedButton, 'Unirme al equipo'),
  );
  await _visible(tester, visual);
  final accesible = find.descendant(
    of: _tarjeta(id),
    matching: find.bySemanticsLabel('Unirme al equipo'),
  );
  _accesible(tester, accesible, visual, 'Unirme al equipo');
  await _tocar(tester, accesible);
  await _esperar(tester, find.byType(AlertDialog));
  expect(
    _dialogo(find.text('¿Unirte al equipo?')),
    findsOneWidget,
    reason: 'Debe mostrar la confirmación de unión.',
  );
  final mensaje = _dialogo(find.text('Ocuparás un cupo en "$titulo" (1/6).'));
  await _visible(tester, mensaje);
  expect(
    mensaje.hitTestable(),
    findsOneWidget,
    reason: 'La confirmación debe identificar el partido y sus cupos.',
  );
}

Future<void> _comprobarUnion(WidgetTester tester, String id) async {
  await _esperar(tester, _tarjeta(id));
  final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
  expect(
    p.estoyUnido,
    isTrue,
    reason: 'La tarjeta debe reconocer la pertenencia del jugador.',
  );
  expect(
    p.soyOrganizador,
    isFalse,
    reason: 'Debe aparecer como jugador, no como organizador.',
  );
  expect(
    p.cuposOcupados,
    2,
    reason: 'La tarjeta debe mostrar dos cupos ocupados.',
  );
  expect(
    p.cuposTotales,
    6,
    reason: 'La tarjeta debe mantener seis cupos totales.',
  );
  expect(
    p.estado,
    EstadoPartido.cuposAbiertos,
    reason: 'La tarjeta debe conservar el estado abierto.',
  );
  final cupos = find.descendant(of: _tarjeta(id), matching: find.text('2/6'));
  await _visible(tester, cupos);
  expect(
    cupos.hitTestable(),
    findsOneWidget,
    reason: 'Los cupos actualizados deben ser visibles.',
  );
  expect(
    find.descendant(
      of: _tarjeta(id),
      matching: find.text('Ya formas parte de este equipo.'),
    ),
    findsOneWidget,
    reason: 'Debe mostrarse el estado de pertenencia.',
  );
  expect(
    find.descendant(
      of: _tarjeta(id),
      matching: find.widgetWithText(ElevatedButton, 'Unirme al equipo'),
    ),
    findsNothing,
    reason: 'No debe ofrecer inscribirse otra vez.',
  );
}

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
    reason: '$nombre debe tener rol de botón.',
  );
  final size = tester.getSize(visual);
  expect(
    size.width,
    greaterThanOrEqualTo(48),
    reason: '$nombre: ancho mínimo 48.',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(48),
    reason: '$nombre: alto mínimo 48.',
  );
}

Future<void> _visible(WidgetTester tester, Finder control) async {
  if (control.evaluate().isEmpty &&
      find.byType(VistaExplorarPartidos).evaluate().isNotEmpty) {
    final scroll = find
        .descendant(
          of: find.byType(VistaExplorarPartidos),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));
  }
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
    reason: 'El campo debe conservar el dato introducido.',
  );
}

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  bool ausente = false,
}) async {
  final reloj = Stopwatch()..start();
  while (reloj.elapsed < _limite) {
    if (tester
            .widgetList<CajaMensaje>(find.byType(CajaMensaje))
            .any((c) => c.tipo == TipoMensaje.error) ||
        tester
            .widgetList<SnackBar>(find.byType(SnackBar))
            .any((aviso) => aviso.backgroundColor == TemaApp.rojoAlerta)) {
      fail(
        'La aplicación mostró un error inesperado durante la autenticación, unión o consulta. Revisa conexión, cuenta y esquema.',
      );
    }
    if (objetivo.evaluate().isEmpty == ausente) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    objetivo,
    ausente ? findsNothing : findsOneWidget,
    reason: 'La pantalla debe responder en menos de 45 segundos.',
  );
  await tester.pump(const Duration(milliseconds: 300));
}
