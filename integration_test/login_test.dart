import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/autenticacion/vista_recuperar_clave.dart';
import 'package:unisport/vistas/autenticacion/vista_registro.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/boton_accion.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _enviar = 'Entrar a UniSport';
const _errorCredenciales =
    'Correo o contraseña incorrectos. Verifica tus credenciales.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Iniciar sesión: alternativos, accesibilidad y acceso autorizado', (
    tester,
  ) async {
    expect(
      _correo.trim().contains('@') && _clave.trim().length >= 6,
      isTrue,
      reason:
          'Indica --dart-define=E2E_CORREO=... y --dart-define=E2E_CLAVE=... '
          'con una cuenta existente, habilitada, confirmada y con perfil completo.',
    );
    final semantica = tester.ensureSemantics();
    try {
      // 1. Estado inicial: no depender de la sesión guardada en el dispositivo.
      debugPrint('Login E2E · 1/10: Estado inicial');
      app.main();
      await _esperar(
        tester,
        find.byWidgetPredicate(
          (w) => w is VistaInicioPublico || w is VistaPrincipal,
        ),
        motivo: 'La aplicación debe arrancar con Supabase real.',
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
        reason: 'La prueba debe comenzar en la portada pública.',
      );
      expect(
        cliente.auth.currentSession == null,
        isTrue,
        reason: 'No debe quedar una sesión previa.',
      );

      // 2. Contar únicamente los toques de acceso desde la portada al formulario.
      debugPrint('Login E2E · 2/10: Acceso en un toque');
      final abrirLogin = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
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
      expect(toquesDeAcceso, 1, reason: 'El login debe abrirse en un toque.');
      expect(
        toquesDeAcceso,
        lessThanOrEqualTo(3),
        reason: 'El acceso al login debe respetar el máximo de tres toques.',
      );

      // 3. Semántica, contraseña y áreas táctiles de las acciones del flujo.
      debugPrint('Login E2E · 3/10: Accesibilidad y áreas táctiles');
      for (final campo in <(String, Pattern)>[
        ('login_correo', RegExp(r'^Correo institucional(?:\n|$)')),
        ('login_clave', 'Contraseña'),
      ]) {
        await _visible(tester, find.byKey(Key(campo.$1)));
        final accesible = find.bySemanticsLabel(campo.$2);
        expect(
          accesible,
          findsOneWidget,
          reason: '${campo.$1} debe tener un nombre accesible único.',
        );
        expect(
          tester
              .getSemantics(accesible)
              .getSemanticsData()
              .flagsCollection
              .isTextField,
          isTrue,
          reason: '${campo.$1} debe anunciarse como campo de texto.',
        );
      }
      expect(
        _datos(tester, 'Contraseña').flagsCollection.isObscured,
        isTrue,
        reason: 'La contraseña debe estar oculta inicialmente.',
      );
      _botonAccesible(tester, 'Mostrar contraseña');
      _areaTactil(
        tester,
        find.byTooltip('Mostrar contraseña'),
        'Mostrar contraseña',
      );
      await _tocar(tester, find.bySemanticsLabel('Mostrar contraseña'));
      expect(
        _datos(tester, 'Contraseña').flagsCollection.isObscured,
        isFalse,
        reason: 'Mostrar contraseña debe actualizar el estado accesible.',
      );
      _botonAccesible(tester, 'Ocultar contraseña');
      await _tocar(tester, find.bySemanticsLabel('Ocultar contraseña'));
      expect(
        _datos(tester, 'Contraseña').flagsCollection.isObscured,
        isTrue,
        reason: 'La contraseña debe poder ocultarse de nuevo.',
      );
      for (final nombre in [
        _enviar,
        '¿Olvidaste tu contraseña?',
        'Regístrate aquí',
      ]) {
        final control = nombre == _enviar
            ? _botonEnviar()
            : find.widgetWithText(TextButton, nombre);
        await _visible(tester, control);
        _botonAccesible(tester, nombre);
        _areaTactil(tester, control, nombre);
      }

      // 4. Validaciones vacías: formulario visible y sin sesión.
      debugPrint('Login E2E · 4/10: Campos vacíos');
      await _enviarFormulario(tester);
      for (final mensaje in [
        'Ingresa tu correo institucional',
        'Ingresa tu contraseña',
      ]) {
        await _mensajeVisible(tester, mensaje);
      }
      _sinSesionEnLogin(cliente);

      // 5. Correo sin @ y contraseña de cinco caracteres.
      debugPrint('Login E2E · 5/10: Datos inválidos');
      await _escribir(tester, 'login_correo', 'correo-invalido');
      await _escribir(tester, 'login_clave', '12345');
      await _enviarFormulario(tester);
      for (final mensaje in [
        'Formato de correo no válido',
        'La contraseña debe tener al menos 6 caracteres',
      ]) {
        await _mensajeVisible(tester, mensaje);
      }
      _sinSesionEnLogin(cliente);

      // 6. Navegación secundaria: no enviar recuperación ni registrar cuentas.
      debugPrint('Login E2E · 6/10: Cancelación y accesos secundarios');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaInicioPublico));
      expect(
        cliente.auth.currentSession == null,
        isTrue,
        reason: 'Cancelar el login no debe iniciar sesión.',
      );
      await _tocar(tester, abrirLogin);
      await _esperar(tester, find.byType(VistaLogin));
      await _tocar(tester, find.bySemanticsLabel('¿Olvidaste tu contraseña?'));
      await _esperar(tester, find.byType(VistaRecuperarClave));
      expect(
        cliente.auth.currentSession == null,
        isTrue,
        reason: 'Abrir recuperación no debe iniciar sesión.',
      );
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaLogin));
      await _visible(
        tester,
        find.widgetWithText(TextButton, 'Regístrate aquí'),
      );
      await _tocar(tester, find.bySemanticsLabel('Regístrate aquí'));
      await _esperar(tester, find.byType(VistaRegistro));
      expect(
        cliente.auth.currentSession == null,
        isTrue,
        reason: 'Abrir registro no debe crear una sesión.',
      );
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaInicioPublico));
      await _tocar(tester, abrirLogin);
      await _esperar(tester, find.byType(VistaLogin));
      _sinSesionEnLogin(cliente);

      // 7. Volver a portada y acceder por la ruta privada protegida.
      debugPrint('Login E2E · 7/10: Ruta protegida');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaInicioPublico));
      await _tocar(tester, find.text('Mis partidos'));
      await _esperar(tester, find.byType(VistaLogin));
      await _mensajeVisible(tester, 'Inicia sesión para ver tus partidos.');
      expect(
        find.byType(VistaMisPartidos),
        findsNothing,
        reason: 'Sin sesión no debe abrirse la pantalla privada.',
      );
      _sinSesionEnLogin(cliente);

      // 8. Un único intento incorrecto; no registrar ni modificar la cuenta.
      debugPrint('Login E2E · 8/10: Credenciales incorrectas');
      final claveIncorrecta = _clave.trim() == 'IncorrectaE2E!2026'
          ? 'OtraIncorrectaE2E!2026'
          : 'IncorrectaE2E!2026';
      await _escribir(tester, 'login_correo', _correo.trim());
      await _escribir(tester, 'login_clave', claveIncorrecta);
      await _enviarFormulario(tester);
      await _esperar(
        tester,
        find.text(_errorCredenciales),
        errorPermitido: _errorCredenciales,
        motivo: 'Supabase debe rechazar la contraseña incorrecta.',
      );
      await _mensajeVisible(tester, _errorCredenciales);
      _sinSesionEnLogin(cliente);
      expect(
        tester.widget<ElevatedButton>(_botonEnviar()).onPressed,
        isNotNull,
        reason: 'El rechazo debe permitir corregir y reintentar.',
      );

      // 9. Observar carga inmediatamente, antes de esperar la respuesta de red.
      debugPrint('Login E2E · 9/10: Inicio correcto y carga');
      await _escribir(tester, 'login_clave', _clave);
      await _visible(tester, _botonEnviar());
      await tester.tap(find.bySemanticsLabel(_enviar));
      await tester.pump();
      expect(
        tester
            .widget<BotonAccion>(find.byKey(const Key('login_enviar')))
            .estado,
        EstadoBoton.cargando,
        reason: 'Al enviar debe comenzar el estado de carga.',
      );
      expect(
        find.descendant(
          of: _botonEnviar(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'La petición pendiente debe mostrar un indicador de carga.',
      );
      expect(
        tester.widget<ElevatedButton>(_botonEnviar()).onPressed,
        isNull,
        reason: 'La carga debe impedir el doble envío.',
      );
      expect(
        _datos(tester, _enviar).value,
        'Cargando',
        reason: 'La carga debe tener una descripción accesible.',
      );
      await _esperar(
        tester,
        find.byType(VistaPrincipal),
        motivo: 'La cuenta debe estar habilitada, confirmada y aceptar las credenciales.',
      );

      // 10. Identidad real, perfil completo y acceso privado autorizado.
      debugPrint('Login E2E · 10/10: Identidad y acceso autorizado');
      expect(
        cliente.auth.currentSession != null,
        isTrue,
        reason: 'El login debe dejar una sesión activa.',
      );
      final usuario = cliente.auth.currentUser;
      expect(
        usuario != null,
        isTrue,
        reason: 'Debe existir un usuario autenticado.',
      );
      expect(
        usuario!.email?.toLowerCase() == _correo.trim().toLowerCase(),
        isTrue,
        reason: 'La sesión debe corresponder a la cuenta suministrada.',
      );
      final perfil = await cliente
          .from('perfiles')
          .select()
          .eq('id', usuario.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 45));
      expect(
        perfil != null,
        isTrue,
        reason: 'Preparación: la cuenta debe tener un perfil persistido.',
      );
      for (final campo in ['nombre', 'correo', 'carrera']) {
        expect(
          perfil![campo] is String &&
              (perfil[campo] as String).trim().isNotEmpty,
          isTrue,
          reason: 'Preparación: el perfil debe tener $campo completo.',
        );
      }
      expect(
        perfil!['id'] == usuario.id,
        isTrue,
        reason: 'El perfil debe pertenecer al usuario autenticado.',
      );
      expect(
        (perfil['correo'] as String).toLowerCase() ==
            usuario.email?.toLowerCase(),
        isTrue,
        reason: 'El correo del perfil debe coincidir con la sesión.',
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == perfil['nombre'],
          description: 'nombre del perfil en la cabecera',
        ),
        findsOneWidget,
        reason: 'El menú debe mostrar el nombre del perfil.',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == '${perfil['correo']} · ${perfil['carrera']}',
          description: 'correo y carrera del perfil en la cabecera',
        ),
        findsOneWidget,
        reason: 'El menú debe mostrar correo y carrera del perfil.',
      );
      await _tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Mis\nPartidos'),
      );
      await _esperar(tester, find.byType(VistaMisPartidos));
      expect(
        find.byType(VistaLogin),
        findsNothing,
        reason: 'La cuenta autenticada debe acceder sin volver al login.',
      );
      expect(
        cliente.auth.currentSession != null,
        isTrue,
        reason: 'El acceso privado debe conservar la sesión.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Finder _botonEnviar() => find.descendant(
  of: find.byKey(const Key('login_enviar')),
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

void _sinSesionEnLogin(SupabaseClient cliente) {
  expect(
    find.byType(VistaLogin),
    findsOneWidget,
    reason: 'Un intento inválido debe conservar el formulario.',
  );
  expect(
    find.byType(VistaPrincipal),
    findsNothing,
    reason: 'Un intento inválido no debe abrir el menú privado.',
  );
  expect(
    cliente.auth.currentSession == null,
    isTrue,
    reason: 'Un intento inválido no debe iniciar sesión.',
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

Future<void> _enviarFormulario(WidgetTester tester) async {
  await _visible(tester, _botonEnviar());
  await _tocar(tester, find.bySemanticsLabel(_enviar));
}

Future<void> _mensajeVisible(WidgetTester tester, String mensaje) async {
  await _visible(tester, find.text(mensaje));
  expect(
    find.text(mensaje).hitTestable(),
    findsOneWidget,
    reason: 'Debe mostrarse el mensaje esperado.',
  );
}

Future<void> _escribir(WidgetTester tester, String key, String texto) async {
  final campo = find.byKey(Key(key));
  await _visible(tester, campo);
  final editable = find.descendant(
    of: campo,
    matching: find.byType(EditableText),
  );
  // El binding recuerda el último EditableText incluso después de unfocus.
  // Reiniciarlo permite volver a editar el mismo campo tras un envío fallido.
  tester.binding.focusedEditable = null;
  await tester.showKeyboard(editable);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(editable, texto);
  await tester.pump(const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 100));
  // Comparar como booleano evita imprimir las credenciales si falla la entrada.
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
      final detalle = errores.first.texto
          .replaceAll(
            RegExp(RegExp.escape(_correo.trim()), caseSensitive: false),
            '[correo]',
          )
          .replaceAll(_clave, '[clave]')
          .replaceAll(_clave.trim(), '[clave]');
      fail('${motivo ?? 'Error inesperado'}: $detalle');
    }
    if (errorPermitido != null &&
        find.byType(VistaPrincipal).evaluate().isNotEmpty) {
      fail('El intento con credenciales incorrectas no debe abrir el menú.');
    }
    if (objetivo.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 300));
}
