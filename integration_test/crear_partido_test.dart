import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

// Credenciales de una cuenta semilla ya registrada en Supabase.
const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Crear partido -> aparece en Mis partidos y se conserva al volver',
    (tester) async {
      expect(
        _correo.isNotEmpty && _clave.isNotEmpty,
        isTrue,
        reason:
            'Indica --dart-define=E2E_CORREO=... y '
            '--dart-define=E2E_CLAVE=... con una cuenta semilla existente.',
      );

      final titulo =
          'E2E Crear partido ${DateTime.now().microsecondsSinceEpoch}';
      const ubicacion = 'Cancha E2E Campus';

      // Arranca el mismo punto de entrada que usa la aplicación normal.
      app.main();
      await _esperar(
        tester,
        find.byWidgetPredicate(
          (widget) => widget is VistaInicioPublico || widget is VistaPrincipal,
        ),
        motivo: 'La app debe arrancar con la configuración real de Supabase.',
      );

      // No depender de la sesión que haya quedado guardada en el emulador.
      if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
        await _tocar(tester, find.text('CERRAR SESIÓN'));
        await _esperar(tester, find.byType(VistaInicioPublico));
      }

      await _tocar(tester, find.text('Iniciar sesión'));
      await _esperar(tester, find.byType(VistaLogin));
      await _escribir(tester, find.byKey(const Key('login_correo')), _correo);
      await _escribir(
        tester,
        find.descendant(
          of: find.byKey(const Key('login_clave')),
          matching: find.byType(EditableText),
        ),
        _clave,
      );
      await _tocar(tester, find.text('Entrar a UniSport'));
      await _esperar(
        tester,
        find.byType(VistaPrincipal),
        motivo:
            'Debe iniciar sesión. Comprueba la cuenta semilla y la conexión.',
      );

      final cliente = Supabase.instance.client;
      final usuarioId = cliente.auth.currentUser!.id;
      addTearDown(() async {
        // Limpia solamente el partido único de ESTA ejecución y ESTE usuario,
        // incluso si falla una comprobación después de guardarlo.
        await cliente
            .from('partidos')
            .delete()
            .eq('organizador_id', usuarioId)
            .eq('titulo', titulo);
      });

      // 1. Crear desde el menú y completar el formulario por la interfaz.
      await _tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Crear\nPartido'),
      );
      await _esperar(tester, find.byType(VistaCrearPartido));
      await _escribir(tester, find.byKey(const Key('partido_titulo')), titulo);
      await _escribir(
        tester,
        find.byKey(const Key('partido_ubicacion')),
        ubicacion,
      );
      // Una fecha futura evita que la prueba dependa de la hora del día.
      await _tocar(tester, find.text('Mañana'));
      await _tocar(tester, find.text('19:00'));
      await _tocar(tester, find.text('Guardar partido'));
      await _esperar(
        tester,
        find.text('Partido creado y guardado correctamente.'),
        motivo: 'El servidor debe confirmar que se guardó el partido.',
      );

      // 2. Mis partidos consulta Supabase; la vista previa ya no está abierta.
      await _tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Mis\nPartidos'),
      );
      await _comprobarPartido(tester, titulo, ubicacion);

      // 3. Volver al menú y abrir otra vez fuerza una nueva lectura del servidor.
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaPrincipal));
      await _tocar(
        tester,
        find.widgetWithText(ElevatedButton, 'Mis\nPartidos'),
      );
      await _comprobarPartido(tester, titulo, ubicacion);
    },
  );
}

Future<void> _comprobarPartido(
  WidgetTester tester,
  String titulo,
  String ubicacion,
) async {
  await _esperar(tester, find.byType(VistaMisPartidos));
  final tarjeta = find.descendant(
    of: find.byType(VistaMisPartidos),
    matching: find.byWidgetPredicate(
      (widget) => widget is TarjetaPartido && widget.partido.titulo == titulo,
    ),
  );
  await _esperar(
    tester,
    tarjeta,
    motivo: 'El partido recién creado debe aparecer en Mis partidos.',
  );
  final textoTitulo = find.descendant(of: tarjeta, matching: find.text(titulo));
  await tester.ensureVisible(textoTitulo);
  await tester.pump(const Duration(milliseconds: 300));
  expect(textoTitulo.hitTestable(), findsOneWidget);
  expect(
    find.descendant(of: tarjeta, matching: find.text(ubicacion)),
    findsOneWidget,
  );
  final partido = tester.widget<TarjetaPartido>(tarjeta).partido;
  expect(partido.disciplina, 'Futsal');
  expect(partido.cuposTotales, 10);
  expect(partido.cuposOcupados, 1);
  expect(partido.soyOrganizador, isTrue);
}

Future<void> _escribir(WidgetTester tester, Finder campo, String texto) async {
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(objetivo);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _esperar(
  WidgetTester tester,
  Finder objetivo, {
  String? motivo,
}) async {
  final reloj = Stopwatch()..start();
  while (objetivo.evaluate().isEmpty && reloj.elapsed.inSeconds < 45) {
    final errores = tester.widgetList<CajaMensaje>(
      find.byWidgetPredicate(
        (widget) => widget is CajaMensaje && widget.tipo == TipoMensaje.error,
      ),
    );
    if (errores.isNotEmpty) {
      fail('La app mostró un error: ${errores.first.texto}');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  // No usar pumpAndSettle: el campo de contraseña tiene animación continua.
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 500));
}
