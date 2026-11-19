import 'package:material_ui/material_ui.dart';
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
const _nombreCierre = 'CERRAR SESIÓN';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cerrar sesion y bloquear acceso a pantallas privadas', (
    tester,
  ) async {
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
          (w) =>
              w is VistaPrincipal ||
              (w is VistaInicioPublico && !w.estaPreparando),
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
      final esperaInicial = Stopwatch()..start();
      while (cliente.auth.currentSession != null &&
          esperaInicial.elapsed < const Duration(seconds: 45)) {
        await tester.pump(const Duration(milliseconds: 100));
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
      // 2. La interfaz actual cierra la sesión desde la pantalla principal.
      debugPrint('Cierre E2E · 2/3: Control accesible en el menú principal');
      final cerrar = find.widgetWithText(OutlinedButton, _nombreCierre);
      await _visible(tester, cerrar);
      expect(find.bySemanticsLabel(_nombreCierre), findsOneWidget);
      _areaTactil(tester, cerrar, _nombreCierre);
      await _tocar(tester, cerrar);
      await _esperar(
        tester,
        find.byType(VistaInicioPublico),
        motivo: 'Cerrar sesión debe llevar a la portada pública.',
      );
      final esperaCierre = Stopwatch()..start();
      while (cliente.auth.currentSession != null &&
          esperaCierre.elapsed < const Duration(seconds: 45)) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 3. Validar cierre y protección de las rutas privadas.
      debugPrint('Cierre E2E · 3/3: Sesión eliminada y acceso bloqueado');
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
        Navigator.of(tester.element(find.byType(VistaInicioPublico))).canPop(),
        isFalse,
        reason: 'Atrás no debe recuperar las pantallas privadas.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
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
