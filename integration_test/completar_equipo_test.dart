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
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Completar equipo: estado real y persistencia', (tester) async {
    expect(
      _correo.trim().contains('@') && _clave.trim().length >= 6,
      isTrue,
      reason: 'Indica E2E_CORREO y E2E_CLAVE de una cuenta existente, confirmada y con perfil completo.',
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
    debugPrint('Completar E2E · 1/5: preparación e ingreso');
    try {
      await datos.auth
          .signInWithPassword(email: _correo.trim(), password: _clave)
          .timeout(_limite);
    } catch (_) {
      fail(
        'Preparación: no se pudo autenticar la cuenta. Verifica credenciales, confirmación y conexión.',
      );
    }
    final uid = datos.auth.currentUser?.id;
    expect(
      uid != null,
      isTrue,
      reason: 'La preparación requiere un usuario autenticado.',
    );
    final perfil = await datos
        .from('perfiles')
        .select()
        .eq('id', uid!)
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
      reason: 'Preparación: la cuenta debe tener un perfil completo.',
    );
    final ahora = DateTime.now();
    final titulo = 'E2E completar ${ahora.microsecondsSinceEpoch}';
    String? id;
    // Registrar antes de insertar, incluso si se pierde la respuesta de creación.
    addTearDown(() async {
      var borrar = datos.from('partidos').delete().eq('organizador_id', uid);
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
            cuposTotales: 6,
            cuposOcupados: 1,
            organizadorNombre: perfil!['nombre'] as String,
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
    expect(
      await _inscripciones(datos, partido.id),
      isEmpty,
      reason: 'La preparación no debe crear inscripciones.',
    );
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
      expect(
        cliente.auth.currentUser?.id == uid,
        isTrue,
        reason: 'Debe ingresar el organizador del partido preparado.',
      );

      debugPrint('Completar E2E · 2/5: acceso y accesibilidad');
      var toques = 0;
      final acceso = find.widgetWithText(ElevatedButton, 'Mis\nPartidos');
      await _visible(tester, acceso);
      _accesible(
        tester,
        find.bySemanticsLabel('Mis\nPartidos'),
        acceso,
        'Mis partidos',
      );
      await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
      toques++;
      await _esperar(tester, find.byType(VistaMisPartidos));
      await _comprobarTarjeta(tester, partido.id, 1);
      final visual = find.descendant(
        of: _tarjeta(partido.id),
        matching: find.widgetWithText(ElevatedButton, 'Completar equipo'),
      );
      final completar = find.descendant(
        of: _tarjeta(partido.id),
        matching: find.bySemanticsLabel('Completar equipo'),
      );
      await _visible(tester, visual);
      _accesible(tester, completar, visual, 'Completar equipo');

      debugPrint('Completar E2E · 3/5: completar una vez en dos toques');
      await _tocar(tester, completar);
      toques++;
      expect(
        toques,
        2,
        reason: 'Menú → Mis partidos → Completar equipo requiere dos toques.',
      );
      expect(
        toques,
        lessThanOrEqualTo(3),
        reason: 'El recorrido debe respetar el máximo de tres toques.',
      );
      await _esperar(tester, find.text('¡Equipo completo en "$titulo"!'));
      await _comprobarTarjeta(tester, partido.id, 6);

      debugPrint('Completar E2E · 4/5: persistencia real sin inscripción');
      final fila = await datos
          .from('partidos')
          .select()
          .eq('id', partido.id)
          .single()
          .timeout(_limite);
      expect(
        fila['id'],
        partido.id,
        reason: 'Debe actualizar el mismo partido.',
      );
      expect(
        fila['organizador_id'] == uid,
        isTrue,
        reason: 'El organizador debe conservarse.',
      );
      expect(
        fila['cupos_ocupados'],
        6,
        reason: 'Debe persistir la ocupación de los seis cupos.',
      );
      expect(
        fila['cupos_totales'],
        6,
        reason: 'El total debe permanecer en seis.',
      );
      expect(
        fila['estado'],
        'equipoCompleto',
        reason: 'Debe persistir el estado de equipo completo.',
      );
      expect(fila, {
        ...original,
        'cupos_ocupados': 6,
        'estado': 'equipoCompleto',
        'hay_cupos': false,
      }, reason: 'Completar debe conservar el partido y cerrar sus cupos.');
      expect(
        await _inscripciones(datos, partido.id),
        isEmpty,
        reason: 'Completar equipo no debe crear inscripciones.',
      );

      debugPrint('Completar E2E · 5/5: persistencia al reabrir Mis partidos');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaPrincipal));
      await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
      await _esperar(tester, find.byType(VistaMisPartidos));
      await _comprobarTarjeta(tester, partido.id, 6);
      expect(
        find.descendant(
          of: _tarjeta(partido.id),
          matching: find.bySemanticsLabel('Completar equipo'),
        ),
        findsNothing,
        reason: 'El equipo completo no debe ofrecer completar nuevamente.',
      );
      final aviso = find.descendant(
        of: _tarjeta(partido.id),
        matching: find.text(
          'No puedes agregar más jugadores. Convocatoria cerrada: el equipo ya está completo.',
        ),
      );
      await _visible(tester, aviso);
      expect(
        aviso.hitTestable(),
        findsOneWidget,
        reason: 'Debe explicar de forma visible que no admite más jugadores.',
      );
      expect(
        cliente.auth.currentSession != null &&
            cliente.auth.currentUser?.id == uid,
        isTrue,
        reason:
            'Completar y consultar deben conservar la sesión del organizador.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<List<Map<String, dynamic>>> _inscripciones(
  SupabaseClient c,
  String partido,
) => c
    .from('inscripciones')
    .select('partido_id')
    .eq('partido_id', partido)
    .timeout(_limite);
Finder _tarjeta(String id) => find.descendant(
  of: find.byType(VistaMisPartidos),
  matching: find.byWidgetPredicate(
    (w) => w is TarjetaPartido && w.partido.id == id,
    description: 'tarjeta del partido temporal por ID',
  ),
);
Future<void> _comprobarTarjeta(
  WidgetTester tester,
  String id,
  int ocupados,
) async {
  final estado = ocupados == 6
      ? EstadoPartido.equipoCompleto
      : EstadoPartido.cuposAbiertos;
  await _esperar(
    tester,
    _tarjeta(id),
    condicion: () {
      final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
      return p.cuposOcupados == ocupados &&
          p.cuposTotales == 6 &&
          p.soyOrganizador &&
          p.estado == estado;
    },
    motivo: 'La tarjeta debe mostrar los cupos actualizados y el rol de organizador.',
  );
  final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
  expect(
    p.cuposOcupados,
    ocupados,
    reason: 'La tarjeta debe reflejar los ocupados esperados.',
  );
  expect(
    p.cuposTotales,
    6,
    reason: 'La tarjeta debe conservar seis cupos totales.',
  );
  expect(
    p.soyOrganizador,
    isTrue,
    reason: 'Debe mostrar el rol de organizador.',
  );
  expect(
    p.estado,
    estado,
    reason: 'La tarjeta debe mostrar el estado esperado.',
  );
  expect(
    find.descendant(of: _tarjeta(id), matching: find.text(estado.etiqueta)),
    findsOneWidget,
    reason: 'La etiqueta del estado debe mostrarse en la tarjeta.',
  );
  final texto = find.descendant(
    of: _tarjeta(id),
    matching: find.text('$ocupados/6'),
  );
  await _visible(tester, texto);
  expect(
    texto.hitTestable(),
    findsOneWidget,
    reason: 'Los cupos de la tarjeta deben ser visibles.',
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
        'La aplicación mostró un error inesperado durante la autenticación, consulta o cierre del equipo. Revisa conexión, cuenta y esquema.',
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
