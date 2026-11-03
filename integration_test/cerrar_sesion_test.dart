import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _nombreCierre = 'Cerrar sesión';
const _mensajeDialogo = 'Volverás a la pantalla pública de UniSport.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Cerrar sesión en Mis partidos: cancelar, confirmar y bloquear acceso',
    (tester) async {
      expect(
        _correo.trim().contains('@') && _clave.trim().length >= 6,
        isTrue,
        reason:
            'Indica E2E_CORREO y E2E_CLAVE mediante --dart-define con una '
            'cuenta existente, habilitada y confirmada.',
      );
      final semantica = tester.ensureSemantics();
      try {
        // 1. Preparación mediante la interfaz y Supabase reales.
        debugPrint('Cierre E2E · 1/9: Preparación e inicio de sesión');
        app.main();
        await _esperar(
          tester,
          find.byWidgetPredicate(
            (w) => w is VistaInicioPublico || w is VistaPrincipal,
          ),
          motivo: 'La aplicación debe arrancar conectada a Supabase.',
        );
        final cliente = Supabase.instance.client;
        addTearDown(() async {
          // Solo limpieza: todas las aserciones de cierre se ejecutan antes.
          await cliente.auth.signOut().timeout(const Duration(seconds: 45));
        });
        if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
          await _tocar(tester, find.text('CERRAR SESIÓN'));
          await _esperar(tester, find.byType(VistaInicioPublico));
        }
        expect(
          cliente.auth.currentSession == null,
          isTrue,
          reason: 'La preparación debe eliminar cualquier sesión anterior.',
        );
        await _tocar(
          tester,
          find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
        );
        await _esperar(tester, find.byType(VistaLogin));
        await _escribir(tester, 'login_correo', _correo.trim());
        await _escribir(tester, 'login_clave', _clave);
        final entrar = find.descendant(
          of: find.byKey(const Key('login_enviar')),
          matching: find.byType(ElevatedButton),
        );
        await _visible(tester, entrar);
        await _tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
        await _esperar(
          tester,
          find.byType(VistaPrincipal),
          motivo: 'La cuenta suministrada debe aceptar las credenciales.',
        );
        expect(
          cliente.auth.currentSession != null,
          isTrue,
          reason: 'Debe existir una sesión antes de probar su cierre.',
        );
        expect(
          cliente.auth.currentUser?.email?.toLowerCase() ==
              _correo.trim().toLowerCase(),
          isTrue,
          reason: 'La sesión debe corresponder a la cuenta suministrada.',
        );
        final usuarioId = cliente.auth.currentUser!.id;

        // 2. Acceso a Mis partidos y controles con nombre, rol y área suficiente.
        debugPrint('Cierre E2E · 2/9: Acceso y accesibilidad');
        final misPartidos = find.widgetWithText(
          ElevatedButton,
          'Mis\nPartidos',
        );
        await _visible(tester, misPartidos);
        _botonAccesible(tester, 'Mis\nPartidos');
        _areaTactil(tester, misPartidos, 'Mis partidos');
        await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
        await _esperar(tester, find.byType(VistaMisPartidos));
        final servicioAuth = tester
            .widget<VistaMisPartidos>(find.byType(VistaMisPartidos))
            .servicioAuth;
        _botonAccesible(tester, _nombreCierre);
        _areaTactil(tester, _controlCerrar(), _nombreCierre);
        _sesionConservada(cliente, usuarioId);

        // 3. El diálogo debe explicar el resultado antes de confirmar.
        debugPrint('Cierre E2E · 3/9: Confirmación visible');
        await _tocar(tester, find.bySemanticsLabel(_nombreCierre));
        await _esperar(tester, find.byType(AlertDialog));
        expect(
          find.text('¿Cerrar sesión?'),
          findsOneWidget,
          reason: 'Debe identificarse la acción a confirmar.',
        );
        expect(
          find.text(_mensajeDialogo),
          findsOneWidget,
          reason: 'El diálogo debe explicar que se volverá a la portada.',
        );
        for (final nombre in ['Cancelar', 'Salir']) {
          _botonAccesible(tester, nombre);
          final boton = nombre == 'Cancelar'
              ? find.widgetWithText(TextButton, nombre)
              : find.widgetWithText(ElevatedButton, nombre);
          _areaTactil(tester, boton, nombre);
        }

        // 4. Cancelar debe conservar usuario, sesión y pantalla privada.
        debugPrint('Cierre E2E · 4/9: Cancelar');
        await _tocar(tester, find.bySemanticsLabel('Cancelar'));
        await _esperar(tester, find.byType(AlertDialog), ausencia: true);
        _sesionConservada(cliente, usuarioId);
        expect(
          servicioAuth.estaAutenticado,
          isTrue,
          reason: 'Cancelar no debe desautenticar al estudiante.',
        );

        // 5. Simular navegación atrás del sistema, sin pulsar el botón del fondo.
        debugPrint('Cierre E2E · 5/9: Descartar con atrás');
        await _tocar(tester, find.bySemanticsLabel(_nombreCierre));
        await _esperar(tester, find.byType(AlertDialog));
        await tester.binding.handlePopRoute();
        await _esperar(tester, find.byType(AlertDialog), ausencia: true);
        _sesionConservada(cliente, usuarioId);
        expect(
          servicioAuth.estaAutenticado,
          isTrue,
          reason: 'Descartar el diálogo no debe cerrar sesión.',
        );

        // 6. Reiniciar en el menú: Mis partidos -> cerrar -> confirmar.
        debugPrint('Cierre E2E · 6/9: Recorrido principal en tres toques');
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        var toquesDeCierre = 0;
        Future<void> tocarEnRecorrido(
          Finder control, {
          bool esperarTransicion = true,
        }) async {
          await _visible(tester, control);
          await tester.tap(control);
          toquesDeCierre++;
          if (esperarTransicion) {
            await tester.pump(const Duration(milliseconds: 300));
          } else {
            await tester.pump();
          }
        }

        await tocarEnRecorrido(misPartidos);
        await _esperar(tester, find.byType(VistaMisPartidos));
        await tocarEnRecorrido(find.bySemanticsLabel(_nombreCierre));
        await _esperar(tester, find.byType(AlertDialog));
        final rutaDialogo = ModalRoute.of(
          tester.element(find.byType(AlertDialog)),
        )!;

        // 7. Observar carga antes de esperar la respuesta de Supabase.
        debugPrint('Cierre E2E · 7/9: Confirmar y observar cierre');
        await tocarEnRecorrido(
          find.bySemanticsLabel('Salir'),
          esperarTransicion: false,
        );
        expect(
          toquesDeCierre,
          3,
          reason: 'El cierre desde el menú debe requerir tres toques.',
        );
        expect(
          toquesDeCierre,
          lessThanOrEqualTo(3),
          reason:
              'El recorrido principal debe respetar el máximo de tres toques.',
        );
        expect(
          rutaDialogo.isCurrent,
          isFalse,
          reason: 'Confirmar debe cerrar la ruta del diálogo.',
        );
        expect(
          find.descendant(
            of: _controlCerrar(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason: 'La petición pendiente debe mostrar un indicador de cierre.',
        );
        expect(
          tester.widget<IconButton>(_iconoCerrar()).onPressed == null,
          isTrue,
          reason:
              'El control debe impedir llamadas duplicadas mientras cierra.',
        );
        // La ruta del diálogo puede seguir animándose al desaparecer y bloquear
        // temporalmente la semántica del fondo. Comprobar la descripción declarada
        // del control, cuyo nombre y rol ya se validaron en el árbol semántico.
        final propiedades = tester
            .widget<Semantics>(_controlCerrar())
            .properties;
        expect(
          propiedades.value,
          'Cerrando sesión',
          reason: 'El cierre debe tener una descripción accesible.',
        );
        expect(
          propiedades.enabled,
          isFalse,
          reason: 'El control debe anunciarse deshabilitado durante el cierre.',
        );
        expect(
          propiedades.onTap == null,
          isTrue,
          reason: 'La acción accesible tampoco debe permitir un doble envío.',
        );
        await _esperar(
          tester,
          find.byType(VistaInicioPublico),
          motivo: 'El cierre confirmado debe llevar a la portada pública.',
        );

        // 8. Validar el cierre real ANTES de la limpieza de addTearDown.
        debugPrint(
          'Cierre E2E · 8/9: Sesión eliminada y navegación reiniciada',
        );
        expect(
          cliente.auth.currentSession == null,
          isTrue,
          reason: 'Supabase no debe conservar la sesión tras cerrar.',
        );
        expect(
          cliente.auth.currentUser == null,
          isTrue,
          reason: 'Supabase no debe conservar un usuario autenticado.',
        );
        expect(
          servicioAuth.estaAutenticado,
          isFalse,
          reason: 'El servicio de la app debe reflejar el cierre.',
        );
        expect(
          servicioAuth.usuarioActual == null,
          isTrue,
          reason: 'El servicio no debe conservar el perfil activo.',
        );
        expect(
          find.byType(VistaPrincipal),
          findsNothing,
          reason: 'El menú autenticado debe haberse eliminado.',
        );
        expect(
          find.byType(VistaMisPartidos),
          findsNothing,
          reason: 'La pantalla privada debe haberse eliminado.',
        );
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'El diálogo no debe permanecer en la portada pública.',
        );
        expect(
          Navigator.of(tester.element(find.byType(VistaInicioPublico)))
              .canPop(),
          isFalse,
          reason: 'Atrás no debe recuperar las pantallas privadas.',
        );

        // 9. La ruta privada debe quedar protegida nuevamente.
        debugPrint('Cierre E2E · 9/9: Acceso posterior bloqueado');
        await _tocar(tester, find.text('Mis partidos'));
        await _esperar(tester, find.byType(VistaLogin));
        expect(
          find.text('Inicia sesión para ver tus partidos.'),
          findsOneWidget,
          reason: 'El bloqueo debe orientar al estudiante a iniciar sesión.',
        );
        expect(
          find.byType(VistaMisPartidos),
          findsNothing,
          reason: 'Sin sesión no debe abrirse la pantalla privada.',
        );
        expect(
          cliente.auth.currentSession == null,
          isTrue,
          reason:
              'Intentar entrar a una ruta privada no debe crear una sesión.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Finder _controlCerrar() => find.byKey(const Key('mis_partidos_cerrar_sesion'));
Finder _iconoCerrar() =>
    find.descendant(of: _controlCerrar(), matching: find.byType(IconButton));

SemanticsData _datos(WidgetTester tester, String nombre) =>
    tester.getSemantics(find.bySemanticsLabel(nombre)).getSemanticsData();

void _botonAccesible(WidgetTester tester, String nombre) {
  expect(
    find.bySemanticsLabel(nombre),
    findsOneWidget,
    reason: '$nombre debe tener un nombre accesible único.',
  );
  expect(
    _datos(tester, nombre).flagsCollection.isButton,
    isTrue,
    reason: '$nombre debe anunciarse como botón.',
  );
}

void _areaTactil(WidgetTester tester, Finder control, String nombre) {
  final area = tester.getSize(control);
  expect(
    area.width,
    greaterThanOrEqualTo(48),
    reason: '$nombre: ancho mínimo 48.',
  );
  expect(
    area.height,
    greaterThanOrEqualTo(48),
    reason: '$nombre: alto mínimo 48.',
  );
}

void _sesionConservada(SupabaseClient cliente, String usuarioId) {
  expect(
    cliente.auth.currentSession != null,
    isTrue,
    reason: 'Debe conservarse la sesión antes de confirmar el cierre.',
  );
  expect(
    cliente.auth.currentUser?.id == usuarioId,
    isTrue,
    reason: 'Debe conservarse el mismo usuario autenticado.',
  );
  expect(
    find.byType(VistaMisPartidos),
    findsOneWidget,
    reason: 'La pantalla privada debe permanecer abierta al cancelar.',
  );
  expect(
    find.byType(VistaInicioPublico),
    findsNothing,
    reason: 'Cancelar no debe abrir la portada pública.',
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
    reason: 'El campo $key debe conservar el texto introducido.',
  );
}

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  String? motivo,
  bool ausencia = false,
}) async {
  final reloj = Stopwatch()..start();
  while (reloj.elapsed < const Duration(seconds: 45)) {
    final errores = tester
        .widgetList<CajaMensaje>(find.byType(CajaMensaje))
        .where((caja) => caja.tipo == TipoMensaje.error);
    if (errores.isNotEmpty) {
      final detalle = errores.first.texto
          .replaceAll(
            RegExp(RegExp.escape(_correo.trim()), caseSensitive: false),
            '[correo]',
          )
          .replaceAll(_clave, '[clave]')
          .replaceAll(_clave.trim(), '[clave]');
      fail('${motivo ?? 'Error inesperado'}: $detalle');
    }
    if (find.text('No se pudo cerrar la sesión.').evaluate().isNotEmpty) {
      fail('No se pudo cerrar la sesión.');
    }
    final listo = ausencia
        ? objetivo.evaluate().isEmpty
        : objetivo.evaluate().isNotEmpty;
    if (listo) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(objetivo, ausencia ? findsNothing : findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 300));
}
