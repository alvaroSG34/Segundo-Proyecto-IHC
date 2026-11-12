import 'apoyo/analitica_e2e.dart';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/autenticacion/vista_recuperar_clave.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/widgets/boton_accion.dart';

const _abrir = '¿Olvidaste tu contraseña?';
const _enviar = 'Enviar instrucciones';
const _volver = 'Volver al inicio de sesión';
const _errorValidacion = 'Ingresa un correo electrónico válido';
const _explicacion =
    'Si el correo está registrado, Supabase envía un enlace para '
    'crear una nueva contraseña. Revisa también la carpeta de spam.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Solicitar recuperación: alternativos, accesibilidad y respuesta genérica',
    (tester) async {
      await verificarTracksAlTerminar(['recuperacion_iniciada']);
      // Dirección única sin preparación de cuenta ni buzón: no prueba entrega.
      final correo =
          'e2e-recuperacion-${DateTime.now().microsecondsSinceEpoch}@example.com';
      final semantica = tester.ensureSemantics();
      try {
        // 1. Arranque real, sin depender de una sesión anterior.
        debugPrint('Recuperación E2E · 1/9: Estado inicial');
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
          await cliente.auth.signOut().timeout(const Duration(seconds: 45));
        });
        if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
          await _tocar(tester, find.text('CERRAR SESIÓN'));
          await _esperar(tester, find.byType(VistaInicioPublico));
        }
        expect(
          find.byType(VistaInicioPublico),
          findsOneWidget,
          reason: 'El recorrido debe comenzar en la portada pública.',
        );
        _sinSesion(cliente);

        // 2. Contar portada -> login -> recuperación, sin incluir escritura.
        debugPrint('Recuperación E2E · 2/9: Acceso en dos toques');
        final abrirLogin = find.widgetWithText(
          ElevatedButton,
          'Iniciar sesión',
        );
        await _visible(tester, abrirLogin);
        _botonAccesible(tester, 'Iniciar sesión');
        _areaTactil(tester, abrirLogin, 'Iniciar sesión');
        var toquesDeAcceso = 0;
        Future<void> tocarParaAcceder(Finder control) async {
          await _tocar(tester, control);
          toquesDeAcceso++;
        }

        await tocarParaAcceder(find.bySemanticsLabel('Iniciar sesión'));
        await _esperar(tester, find.byType(VistaLogin));
        final abrirRecuperacion = find.widgetWithText(TextButton, _abrir);
        await _visible(tester, abrirRecuperacion);
        _botonAccesible(tester, _abrir);
        _areaTactil(tester, abrirRecuperacion, _abrir);
        await tocarParaAcceder(find.bySemanticsLabel(_abrir));
        await _esperar(tester, find.byType(VistaRecuperarClave));
        expect(
          toquesDeAcceso,
          2,
          reason: 'Recuperación debe abrirse en dos toques.',
        );
        expect(
          toquesDeAcceso,
          lessThanOrEqualTo(3),
          reason: 'El acceso debe respetar el máximo de tres toques.',
        );

        // 3. Campo identificable y acción accesible con área táctil suficiente.
        debugPrint('Recuperación E2E · 3/9: Accesibilidad y áreas táctiles');
        await _visible(tester, find.byKey(const Key('recuperar_correo')));
        final campoAccesible = find.bySemanticsLabel('Correo Institucional');
        expect(
          campoAccesible,
          findsOneWidget,
          reason: 'El campo debe tener un nombre accesible único.',
        );
        expect(
          tester
              .getSemantics(campoAccesible)
              .getSemanticsData()
              .flagsCollection
              .isTextField,
          isTrue,
          reason: 'El correo debe anunciarse como campo de texto.',
        );
        await _visible(tester, _botonEnviar());
        _botonAccesible(tester, _enviar);
        _areaTactil(tester, _botonEnviar(), _enviar);

        // 4. La validación local no debe aceptar un formulario vacío.
        debugPrint('Recuperación E2E · 4/9: Campo vacío');
        await _tocar(tester, find.bySemanticsLabel(_enviar));
        await _comprobarRechazo(tester, cliente);

        // 5. Rechazar texto sin @ y permitir corregirlo.
        debugPrint('Recuperación E2E · 5/9: Correo inválido');
        await _escribir(tester, 'correo-invalido');
        await _visible(tester, _botonEnviar());
        await _tocar(tester, find.bySemanticsLabel(_enviar));
        await _comprobarRechazo(tester, cliente);

        // 6. Cancelar sin enviar una solicitud válida y abrir un formulario nuevo.
        debugPrint('Recuperación E2E · 6/9: Cancelación');
        await tester.pageBack();
        await _esperar(
          tester,
          find.byType(VistaLogin),
          errorPermitido: _errorValidacion,
        );
        _sinSesion(cliente);
        await _visible(tester, abrirRecuperacion);
        await _tocar(tester, find.bySemanticsLabel(_abrir));
        await _esperar(tester, find.byType(VistaRecuperarClave));
        expect(
          find.text(_errorValidacion),
          findsNothing,
          reason: 'Reabrir debe mostrar un formulario sin el error anterior.',
        );

        // 7. Una sola solicitud válida real. Sin reenvíos ni reintentos automáticos.
        debugPrint('Recuperación E2E · 7/9: Solicitud real y carga');
        await _escribir(tester, correo);
        await _visible(tester, _botonEnviar());
        await tester.tap(find.bySemanticsLabel(_enviar));
        await tester.pump();
        expect(
          tester
              .widget<BotonAccion>(find.byKey(const Key('recuperar_enviar')))
              .estado,
          EstadoBoton.cargando,
          reason: 'El envío debe comenzar mostrando carga.',
        );
        expect(
          find.descendant(
            of: _botonEnviar(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason: 'La petición pendiente debe mostrar un indicador.',
        );
        expect(
          tester.widget<ElevatedButton>(_botonEnviar()).onPressed,
          isNull,
          reason: 'Mientras carga no debe permitirse un doble envío.',
        );
        expect(
          _datos(tester, _enviar).value,
          'Cargando',
          reason: 'La carga debe tener una descripción accesible.',
        );

        // 8. Aceptación genérica: no demostrar existencia de cuenta ni entrega.
        debugPrint('Recuperación E2E · 8/9: Respuesta genérica');
        await _esperar(
          tester,
          find.text('¡Solicitud procesada!'),
          motivo:
              'Supabase debe aceptar la solicitud. Un error del servidor, '
              'incluido un límite de solicitudes, no cuenta como éxito.',
        );
        await _visible(tester, find.text('¡Solicitud procesada!'));
        expect(
          find.text('¡Solicitud procesada!').hitTestable(),
          findsOneWidget,
          reason: 'La confirmación de solicitud debe ser visible.',
        );
        expect(
          find
              .byWidgetPredicate(
                (w) =>
                    w is Text &&
                    w.data == 'Procesamos la solicitud para $correo.',
                description: 'detalle de solicitud con el correo introducido',
              )
              .evaluate()
              .length,
          1,
          reason: 'La confirmación debe identificar el correo solicitado.',
        );
        await _visible(tester, find.text(_explicacion));
        expect(
          find.text(_explicacion).hitTestable(),
          findsOneWidget,
          reason:
              'Debe aclararse que el envío depende de una cuenta registrada.',
        );
        expect(
          find.byKey(const Key('recuperar_correo')),
          findsNothing,
          reason: 'La confirmación debe reemplazar el campo del formulario.',
        );
        expect(
          find.byKey(const Key('recuperar_enviar')),
          findsNothing,
          reason: 'El formulario de envío ya no debe estar abierto.',
        );
        _sinSesion(cliente);

        // 9. Regresar al login conservando el estado público.
        debugPrint('Recuperación E2E · 9/9: Regreso al login');
        final volver = find.byKey(const Key('recuperar_volver'));
        await _visible(tester, volver);
        _botonAccesible(tester, _volver);
        _areaTactil(tester, volver, _volver);
        await _tocar(tester, find.bySemanticsLabel(_volver));
        await _esperar(tester, find.byType(VistaLogin));
        expect(
          find.byType(VistaRecuperarClave),
          findsNothing,
          reason: 'Volver debe cerrar la pantalla de recuperación.',
        );
        _sinSesion(cliente);
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Finder _botonEnviar() => find.descendant(
  of: find.byKey(const Key('recuperar_enviar')),
  matching: find.byType(ElevatedButton),
);

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

void _sinSesion(SupabaseClient cliente) {
  expect(
    cliente.auth.currentSession == null,
    isTrue,
    reason: 'La solicitud de recuperación no debe iniciar sesión.',
  );
  expect(
    find.byType(VistaPrincipal),
    findsNothing,
    reason: 'La recuperación no debe abrir el menú privado.',
  );
}

Future<void> _comprobarRechazo(
  WidgetTester tester,
  SupabaseClient cliente,
) async {
  await _visible(tester, find.text(_errorValidacion));
  expect(
    find.text(_errorValidacion).hitTestable(),
    findsOneWidget,
    reason: 'La validación local debe ser visible.',
  );
  expect(
    find.byType(VistaRecuperarClave),
    findsOneWidget,
    reason: 'El rechazo debe conservar la pantalla de recuperación.',
  );
  expect(
    find.byKey(const Key('recuperar_correo')),
    findsOneWidget,
    reason: 'El campo debe permanecer disponible para corregir.',
  );
  expect(
    tester.widget<ElevatedButton>(_botonEnviar()).onPressed,
    isNotNull,
    reason: 'El rechazo debe permitir reintentar.',
  );
  expect(
    find.text('¡Solicitud procesada!'),
    findsNothing,
    reason: 'Un dato inválido no debe mostrar confirmación de solicitud.',
  );
  _sinSesion(cliente);
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

Future<void> _escribir(WidgetTester tester, String texto) async {
  final campo = find.byKey(const Key('recuperar_correo'));
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
    reason: 'El campo de correo debe conservar el texto introducido.',
  );
}

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  String? motivo,
  String? errorPermitido,
}) async {
  final reloj = Stopwatch()..start();
  while (reloj.elapsed < const Duration(seconds: 45)) {
    final errores = tester
        .widgetList<CajaMensaje>(find.byType(CajaMensaje))
        .where(
          (caja) =>
              caja.tipo == TipoMensaje.error && caja.texto != errorPermitido,
        );
    if (errores.isNotEmpty) {
      final detalle = errores.first.texto.replaceAll(
        RegExp(r'[\w.%+-]+@[\w.-]+\.[a-zA-Z]{2,}'),
        '[correo]',
      );
      fail('${motivo ?? 'Error inesperado'}: $detalle');
    }
    if (objetivo.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 300));
}
