import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/autenticacion/vista_registro.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/boton_accion.dart';

const _correoExistente = String.fromEnvironment('E2E_CORREO_EXISTENTE');
const _enviar = 'Crear cuenta e ingresar';
const _etiquetaClave = 'Contraseña (mínimo 6 caracteres)';
const _errorDuplicado = 'Este correo ya se encuentra registrado.';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Registrarse: alternativos, accesibilidad y perfil persistido', (
    tester,
  ) async {
    expect(
      _correoExistente.trim(),
      isNotEmpty,
      reason:
          'Indica --dart-define=E2E_CORREO_EXISTENTE=<correo-semilla> '
          'con una cuenta ya registrada y confirmación de correo desactivada.',
    );
    final correo =
        'e2e-registro-${DateTime.now().microsecondsSinceEpoch}@unisport.edu';
    const nombre = 'Estudiante E2E';
    const carrera = 'Ingeniería en Sistemas';
    const clave = 'RegistroE2E2026!';
    debugPrint(
      'Cuenta de esta ejecución (borrado manual en Supabase): $correo',
    );
    final semantica = tester.ensureSemantics();
    try {
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
        // La cuenta queda identificada por el correo impreso para borrado manual.
        await cliente.auth.signOut().timeout(const Duration(seconds: 45));
      });
      if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
        await _tocar(tester, find.text('CERRAR SESIÓN'));
        await _esperar(tester, find.byType(VistaInicioPublico));
      }

      // 1. Permiso: una persona sin sesión no accede a Mis partidos.
      debugPrint('Registro E2E · 1/9: Permiso sin sesión');
      await _tocar(tester, find.text('Mis partidos'));
      await _esperar(tester, find.byType(VistaLogin));
      expect(
        find.text('Inicia sesión para ver tus partidos.'),
        findsOneWidget,
        reason: 'El bloqueo debe explicar cómo acceder.',
      );
      expect(
        find.byType(VistaMisPartidos),
        findsNothing,
        reason: 'La pantalla privada no debe estar abierta.',
      );
      expect(
        cliente.auth.currentSession,
        isNull,
        reason: 'La navegación protegida no debe autenticar al invitado.',
      );
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaInicioPublico));

      // 2. Regla de tres toques: solo portada -> formulario, sin contar escritura.
      debugPrint('Registro E2E · 2/9: Acceso en un toque');
      final abrirRegistro = find.widgetWithText(
        OutlinedButton,
        'Crear nueva cuenta',
      );
      await _visible(tester, abrirRegistro);
      _botonAccesible(tester, 'Crear nueva cuenta');
      _areaTactil(tester, abrirRegistro, 'Crear nueva cuenta');
      var toquesDeAcceso = 0;
      Future<void> tocarParaAcceder(Finder control) async {
        await _tocar(tester, control);
        toquesDeAcceso++;
      }

      await tocarParaAcceder(find.bySemanticsLabel('Crear nueva cuenta'));
      await _esperar(tester, find.byType(VistaRegistro));
      expect(
        toquesDeAcceso,
        1,
        reason: 'El registro debe abrirse en un toque.',
      );
      expect(
        toquesDeAcceso,
        lessThanOrEqualTo(3),
        reason: 'El acceso al registro debe respetar el máximo de tres toques.',
      );

      // 3. Semántica y áreas táctiles, también con controles fuera del viewport.
      debugPrint('Registro E2E · 3/9: Accesibilidad y áreas táctiles');
      for (final campo in const [
        ('registro_nombre', 'Nombre y apellido'),
        (
          'registro_correo',
          'Correo institucional (@uagrm.edu / @unisport.edu)',
        ),
        ('registro_carrera', 'Carrera o facultad'),
        ('registro_clave', _etiquetaClave),
      ]) {
        await _visible(tester, find.byKey(Key(campo.$1)));
        final accesible = find.bySemanticsLabel(campo.$2);
        expect(
          accesible,
          findsOneWidget,
          reason: 'El campo ${campo.$1} debe tener un nombre accesible.',
        );
        expect(
          tester
              .getSemantics(accesible)
              .getSemanticsData()
              .flagsCollection
              .isTextField,
          isTrue,
          reason: '${campo.$2} debe anunciarse como campo de texto.',
        );
      }
      final campoClave = find.bySemanticsLabel(_etiquetaClave);
      expect(
        tester
            .getSemantics(campoClave)
            .getSemanticsData()
            .flagsCollection
            .isObscured,
        isTrue,
        reason: 'La contraseña debe estar oculta inicialmente.',
      );
      final mostrarClave = find.byTooltip('Mostrar contraseña');
      _botonAccesible(tester, 'Mostrar contraseña');
      _areaTactil(tester, mostrarClave, 'Mostrar contraseña');
      await _tocar(tester, find.bySemanticsLabel('Mostrar contraseña'));
      expect(
        tester
            .getSemantics(campoClave)
            .getSemanticsData()
            .flagsCollection
            .isObscured,
        isFalse,
        reason: 'El control debe permitir mostrar la contraseña.',
      );
      await _tocar(tester, find.bySemanticsLabel('Ocultar contraseña'));
      expect(
        tester
            .getSemantics(campoClave)
            .getSemanticsData()
            .flagsCollection
            .isObscured,
        isTrue,
        reason: 'El control debe permitir ocultar de nuevo la contraseña.',
      );

      for (final deporte in ['Futsal', 'Básquetbol', 'Voleibol']) {
        await _visible(tester, find.text(deporte));
        _botonAccesible(tester, deporte);
        _areaTactil(tester, find.bySemanticsLabel(deporte), deporte);
      }
      await _tocar(tester, find.bySemanticsLabel('Básquetbol'));
      expect(
        _datos(tester, 'Básquetbol').flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
        reason: 'Debe anunciarse el deporte seleccionado.',
      );
      expect(
        _datos(tester, 'Futsal').flagsCollection.isSelected.toBoolOrNull(),
        isFalse,
        reason: 'La selección anterior debe quedar desmarcada.',
      );
      await _visible(tester, _botonEnviar());
      _botonAccesible(tester, _enviar);
      _areaTactil(tester, _botonEnviar(), _enviar);

      // 4. Campos vacíos: carrera es opcional.
      debugPrint('Registro E2E · 4/9: Campos vacíos');
      await _tocar(tester, find.bySemanticsLabel(_enviar));
      for (final mensaje in [
        'Ingresa tu nombre',
        'Ingresa tu correo',
        'Define una contraseña',
      ]) {
        await _visible(tester, find.text(mensaje));
        expect(
          find.text(mensaje).hitTestable(),
          findsOneWidget,
          reason: 'La validación debe mostrar: $mensaje.',
        );
      }
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const Key('registro_carrera')),
            )
            .hasError,
        isFalse,
        reason: 'La carrera debe seguir siendo opcional.',
      );
      _sinSesionEnRegistro(cliente);

      // 5. Datos inválidos, sin enviar ninguna petición de registro válida.
      debugPrint('Registro E2E · 5/9: Datos inválidos');
      await _escribir(tester, 'registro_nombre', nombre);
      await _escribir(tester, 'registro_correo', 'correo-invalido');
      await _escribir(tester, 'registro_clave', '12345');
      await _visible(tester, _botonEnviar());
      await _tocar(tester, find.bySemanticsLabel(_enviar));
      for (final mensaje in [
        'Correo no válido',
        'La contraseña debe tener al menos 6 caracteres',
      ]) {
        await _visible(tester, find.text(mensaje));
        expect(
          find.text(mensaje).hitTestable(),
          findsOneWidget,
          reason: 'Debe verse el error: $mensaje.',
        );
      }
      expect(
        find.text('Ingresa tu nombre'),
        findsNothing,
        reason: 'Un nombre corregido ya no debe mostrar error.',
      );
      _sinSesionEnRegistro(cliente);

      // 6. Cancelar y abrir un formulario nuevo.
      debugPrint('Registro E2E · 6/9: Cancelación');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaInicioPublico));
      expect(
        cliente.auth.currentSession,
        isNull,
        reason: 'Cancelar el registro no debe iniciar sesión.',
      );
      await _tocar(tester, abrirRegistro);
      await _esperar(tester, find.byType(VistaRegistro));

      // 7. Cuenta semilla existente: rechazo real del servidor y reintento.
      debugPrint('Registro E2E · 7/9: Correo ya registrado');
      await _escribir(tester, 'registro_nombre', nombre);
      await _escribir(tester, 'registro_correo', _correoExistente.trim());
      await _escribir(tester, 'registro_carrera', carrera);
      await _escribir(tester, 'registro_clave', clave);
      await _visible(tester, _botonEnviar());
      await _tocar(tester, find.bySemanticsLabel(_enviar));
      await _esperar(
        tester,
        find.text(_errorDuplicado),
        errorPermitido: _errorDuplicado,
        motivo: 'Supabase debe rechazar la cuenta semilla ya existente.',
      );
      await _visible(tester, find.text(_errorDuplicado));
      expect(
        find.text(_errorDuplicado).hitTestable(),
        findsOneWidget,
        reason: 'El rechazo debe ser visible.',
      );
      _sinSesionEnRegistro(cliente);
      expect(
        tester.widget<ElevatedButton>(_botonEnviar()).onPressed,
        isNotNull,
        reason: 'El formulario debe permitir corregir y reintentar.',
      );

      // 8. Registro válido; observar carga antes de esperar la respuesta de red.
      debugPrint('Registro E2E · 8/9: Registro exitoso y carga');
      await _escribir(tester, 'registro_correo', correo);
      await _visible(tester, find.text('Básquetbol'));
      await _tocar(tester, find.bySemanticsLabel('Básquetbol'));
      await _visible(tester, _botonEnviar());
      await tester.tap(find.bySemanticsLabel(_enviar));
      await tester.pump();
      expect(
        tester
            .widget<BotonAccion>(find.byKey(const Key('registro_enviar')))
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
        reason: 'La petición pendiente debe impedir el doble envío.',
      );
      expect(
        _datos(tester, _enviar).value,
        'Cargando',
        reason: 'La carga debe tener una descripción accesible.',
      );
      await _esperar(
        tester,
        find.byType(VistaPrincipal),
        motivo: 'El registro válido debe abrir el menú principal.',
      );

      // 9. Resultado visible y persistencia real (sin depender del fallback Auth).
      debugPrint('Registro E2E · 9/9: Perfil persistido');
      expect(
        find.text(nombre),
        findsOneWidget,
        reason: 'El menú debe mostrar el nombre registrado.',
      );
      expect(
        find.text('$correo · $carrera'),
        findsOneWidget,
        reason: 'El menú debe mostrar correo y carrera registrados.',
      );
      expect(
        cliente.auth.currentSession,
        isNotNull,
        reason: 'El registro debe dejar una sesión activa.',
      );
      final usuario = cliente.auth.currentUser;
      expect(
        usuario,
        isNotNull,
        reason: 'Debe existir un usuario autenticado.',
      );
      expect(
        usuario!.email,
        correo,
        reason: 'La sesión debe ser de la nueva cuenta.',
      );
      final perfil = await cliente
          .from('perfiles')
          .select()
          .eq('id', usuario.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 45));
      expect(
        perfil,
        isNotNull,
        reason: 'El perfil debe persistir en Supabase.',
      );
      for (final entrada in {
        'id': usuario.id,
        'nombre': nombre,
        'correo': correo,
        'carrera': carrera,
        'deporte_favorito': 'Básquetbol',
      }.entries) {
        expect(
          perfil![entrada.key],
          entrada.value,
          reason: 'El perfil guardado debe conservar ${entrada.key}.',
        );
      }
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Finder _botonEnviar() => find.descendant(
  of: find.byKey(const Key('registro_enviar')),
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

void _sinSesionEnRegistro(SupabaseClient cliente) {
  expect(
    find.byType(VistaRegistro),
    findsOneWidget,
    reason: 'El rechazo debe conservar el formulario de registro.',
  );
  expect(
    find.byType(VistaPrincipal),
    findsNothing,
    reason: 'Un registro inválido no debe abrir el menú privado.',
  );
  expect(
    cliente.auth.currentSession,
    isNull,
    reason: 'Un registro inválido no debe iniciar sesión.',
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
  // Esperar la conexión del teclado nativo antes de inyectar el texto evita
  // que un evento tardío de foco restaure el valor anterior en escritorio.
  await tester.showKeyboard(editable);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(editable, texto);
  await tester.pump(const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.widget<EditableText>(editable).controller.text,
    texto,
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
      fail('${motivo ?? 'Error inesperado'}: ${errores.first.texto}');
    }
    if (errorPermitido == _errorDuplicado &&
        find.byType(VistaPrincipal).evaluate().isNotEmpty) {
      fail(
        'El correo E2E_CORREO_EXISTENTE no fue rechazado: se abrió el menú. '
        'Comprueba que la cuenta semilla ya existía en este Supabase.',
      );
    }
    if (objetivo.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 300));
}
