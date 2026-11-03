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
  testWidgets('Eliminar partido: cancelar, confirmar y comprobar borrado real', (
    tester,
  ) async {
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
    debugPrint('Eliminar E2E · 1/5: preparación e ingreso');
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
    final titulo = 'E2E eliminar ${ahora.microsecondsSinceEpoch}';
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
        reason: 'Debe ingresar el propietario del partido temporal.',
      );
      await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
      await _esperar(tester, _tarjeta(partido.id));

      debugPrint('Eliminar E2E · 2/5: cancelar conserva tarjeta y fila');
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
        reason: 'Cancelar debe cerrar la confirmación.',
      );
      expect(
        _tarjeta(partido.id),
        findsOneWidget,
        reason: 'Cancelar conserva la tarjeta.',
      );
      expect(
        await datos
            .from('partidos')
            .select()
            .eq('id', partido.id)
            .single()
            .timeout(_limite),
        original,
        reason: 'Cancelar conserva la fila completa sin modificarla.',
      );

      debugPrint('Eliminar E2E · 3/5: confirmar en tres toques');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaPrincipal));
      var toques = 0;
      await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
      toques++;
      await _esperar(tester, _tarjeta(partido.id));
      await _abrirConfirmacion(tester, partido.id, titulo);
      toques++;
      final confirmar = _dialogo(
        find.widgetWithText(ElevatedButton, 'Eliminar'),
      );
      await _visible(tester, confirmar);
      _accesible(
        tester,
        _dialogo(find.bySemanticsLabel('Eliminar')),
        confirmar,
        'Confirmar eliminación',
      );
      await _tocar(tester, _dialogo(find.bySemanticsLabel('Eliminar')));
      toques++;
      expect(
        toques,
        3,
        reason:
            'Menú → Mis partidos → Eliminar → confirmar requiere tres toques.',
      );

      debugPrint('Eliminar E2E · 4/5: borrado real antes de la limpieza');
      await _esperar(tester, find.text('Partido "$titulo" eliminado'));
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'Confirmar debe cerrar el diálogo.',
      );
      expect(
        _tarjeta(partido.id),
        findsNothing,
        reason: 'La tarjeta debe desaparecer después de eliminar.',
      );
      expect(
        await datos
                .from('partidos')
                .select('id')
                .eq('id', partido.id)
                .maybeSingle()
                .timeout(_limite) ==
            null,
        isTrue,
        reason: 'La fila debe estar eliminada en Supabase antes de ejecutar la limpieza.',
      );

      debugPrint('Eliminar E2E · 5/5: reabrir confirma persistencia');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaPrincipal));
      await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
      await _esperar(tester, find.byType(VistaMisPartidos));
      await _esperar(
        tester,
        find.byKey(const Key('mis_partidos_cargando')),
        ausente: true,
      );
      expect(
        _tarjeta(partido.id),
        findsNothing,
        reason: 'El partido eliminado no debe reaparecer tras consultar nuevamente.',
      );
      expect(
        cliente.auth.currentSession != null &&
            cliente.auth.currentUser?.id == uid,
        isTrue,
        reason: 'Eliminar un partido debe conservar la sesión del propietario.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Finder _tarjeta(String id) => find.descendant(
  of: find.byType(VistaMisPartidos),
  matching: find.byWidgetPredicate(
    (w) => w is TarjetaPartido && w.partido.id == id,
    description: 'tarjeta del partido temporal por ID',
  ),
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
    matching: find.widgetWithText(TextButton, 'Eliminar'),
  );
  await _visible(tester, visual);
  final accesible = find.descendant(
    of: _tarjeta(id),
    matching: find.bySemanticsLabel('Eliminar'),
  );
  _accesible(tester, accesible, visual, 'Eliminar partido');
  await _tocar(tester, accesible);
  await _esperar(tester, find.byType(AlertDialog));
  expect(
    _dialogo(find.text('¿Eliminar partido?')),
    findsOneWidget,
    reason: 'Debe mostrarse el título de confirmación.',
  );
  final advertencia = _dialogo(
    find.text(
      '¿Estás seguro de que deseas eliminar "$titulo"? Esta acción no se puede deshacer.',
    ),
  );
  await _visible(tester, advertencia);
  expect(
    advertencia.hitTestable(),
    findsOneWidget,
    reason: 'La advertencia debe identificar el partido e indicar que no se puede deshacer.',
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
    reason:
        '$nombre debe tener un nombre accesible único dentro de su contexto.',
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
    reason: '$nombre: ancho táctil mínimo 48.',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(48),
    reason: '$nombre: alto táctil mínimo 48.',
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
        'La aplicación mostró un error inesperado durante la autenticación, consulta o eliminación. Revisa conexión, cuenta y esquema.',
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
