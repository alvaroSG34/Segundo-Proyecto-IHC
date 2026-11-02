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
import 'package:unisport/widgets/panel_filtros.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _correoAux = String.fromEnvironment('E2E_CORREO_AUXILIAR');
const _claveAux = String.fromEnvironment('E2E_CLAVE_AUXILIAR');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Explorar partidos: búsqueda, deporte, sin resultados y restauración',
    (tester) async {
      expect(
        [_correo, _correoAux].every((c) => c.trim().contains('@')) &&
            [_clave, _claveAux].every((c) => c.trim().length >= 6),
        isTrue,
        reason: 'Indica E2E_CORREO, E2E_CLAVE, E2E_CORREO_AUXILIAR y E2E_CLAVE_AUXILIAR de dos cuentas existentes.',
      );
      expect(
        _correo.trim().toLowerCase() != _correoAux.trim().toLowerCase(),
        isTrue,
        reason: 'Las cuentas deben ser distintas: Explorar excluye partidos propios.',
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
      debugPrint('Explorar E2E · 1/6: preparación e ingreso');
      try {
        await datos.auth
            .signInWithPassword(email: _correoAux.trim(), password: _claveAux)
            .timeout(_limite);
      } catch (_) {
        fail(
          'Preparación: el auxiliar debe tener credenciales válidas, estar confirmado y disponer de conexión.',
        );
      }
      final uidAux = datos.auth.currentUser?.id;
      expect(
        uidAux != null,
        isTrue,
        reason: 'El organizador auxiliar debe estar autenticado.',
      );
      final perfil = await datos
          .from('perfiles')
          .select()
          .eq('id', uidAux!)
          .maybeSingle()
          .timeout(_limite);
      expect(
        perfil != null && (perfil['nombre'] as String? ?? '').trim().isNotEmpty,
        isTrue,
        reason: 'El auxiliar debe tener un perfil con nombre.',
      );
      final ahora = DateTime.now();
      final busqueda = 'E2E explorar ${ahora.microsecondsSinceEpoch}';
      final titulos = ['$busqueda futsal', '$busqueda basquet'];
      final ids = <String>[];
      addTearDown(() async {
        if (ids.isNotEmpty) {
          await datos
              .from('partidos')
              .delete()
              .eq('organizador_id', uidAux)
              .inFilter('id', ids)
              .timeout(_limite);
        }
        await datos
            .from('partidos')
            .delete()
            .eq('organizador_id', uidAux)
            .inFilter('titulo', titulos)
            .timeout(_limite);
      });
      final partidos = <ModeloPartido>[];
      final repo = RepositorioPartidosSupabase(datos);
      for (var i = 0; i < titulos.length; i++) {
        final p = await repo
            .crearPartido(
              ModeloPartido(
                id: '',
                titulo: titulos[i],
                disciplina: i == 0 ? 'Futsal' : 'Básquetbol',
                icono: i == 0 ? 'Futsal' : 'Básquetbol',
                ubicacion: 'Cancha E2E',
                fechaHora: ModeloPartido.formatearFechaHora(
                  DateTime(ahora.year, ahora.month, ahora.day + 2, 18 + i),
                ),
                cuposTotales: 6,
                cuposOcupados: 1,
                organizadorNombre: perfil!['nombre'] as String,
              ),
            )
            .timeout(_limite);
        ids.add(p.id);
        partidos.add(p);
      }
      final originales = await datos
          .from('partidos')
          .select()
          .inFilter('id', ids)
          .order('id')
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
          cliente.auth.currentUser?.email?.toLowerCase() ==
              _correo.trim().toLowerCase(),
          isTrue,
          reason: 'Debe ingresar la cuenta principal suministrada.',
        );
        expect(
          cliente.auth.currentUser?.id != uidAux,
          isTrue,
          reason: 'El explorador debe ser distinto del organizador.',
        );

        debugPrint('Explorar E2E · 2/6: acceso y accesibilidad');
        final acceso = find.widgetWithText(ElevatedButton, 'Explorar');
        await _visible(tester, acceso);
        _accesible(
          tester,
          find.bySemanticsLabel('Explorar'),
          acceso,
          'Explorar',
        );
        var toques = 0;
        await _tocar(tester, find.bySemanticsLabel('Explorar'));
        toques++;
        await _esperar(tester, find.byType(VistaExplorarPartidos));
        await _listo(tester);
        expect(
          find.text('Explorar partidos'),
          findsOneWidget,
          reason: 'Debe abrir la pantalla de exploración.',
        );
        expect(
          toques,
          1,
          reason: 'Explorar se abre en un toque desde el menú.',
        );
        expect(
          toques,
          lessThanOrEqualTo(3),
          reason: 'El acceso respeta el máximo de tres toques.',
        );
        final campo = find.byKey(const Key('explorar_busqueda'));
        await _visible(tester, campo);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Buscar partido por nombre'))
              .getSemanticsData()
              .flagsCollection
              .isTextField,
          isTrue,
          reason: 'La búsqueda debe tener nombre y rol de campo.',
        );
        final deporte = find.byKey(const Key('explorar_deporte'));
        await _visible(tester, deporte);
        _accesible(
          tester,
          find.bySemanticsLabel('Deporte'),
          deporte,
          'Deporte',
        );

        debugPrint(
          'Explorar E2E · 3/6: búsqueda con dos resultados propios de la prueba',
        );
        await _escribir(tester, 'explorar_busqueda', busqueda);
        await _listo(tester);
        _cantidad(tester, 2);
        for (final p in partidos) {
          await _verPartido(tester, p);
        }

        debugPrint('Explorar E2E · 4/6: combinar búsqueda y deporte');
        await _visible(tester, deporte);
        await _tocar(tester, find.bySemanticsLabel('Deporte'));
        await _esperar(tester, find.widgetWithText(ListTile, 'Futsal'));
        await _tocar(tester, find.widgetWithText(ListTile, 'Futsal'));
        await _listo(tester);
        _cantidad(tester, 1);
        await _visible(tester, deporte);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Futsal'))
              .getSemanticsData()
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isTrue,
          reason: 'El filtro de deporte debe anunciarse seleccionado.',
        );
        expect(
          find.text('Deporte: Futsal'),
          findsOneWidget,
          reason: 'Debe mostrarse el filtro activo.',
        );
        await _verPartido(tester, partidos[0]);
        expect(
          _tarjeta(partidos[1].id),
          findsNothing,
          reason: 'El partido de Básquetbol debe quedar excluido.',
        );

        debugPrint('Explorar E2E · 5/6: sin resultados');
        await _escribir(tester, 'explorar_busqueda', '$busqueda inexistente');
        await _listo(tester);
        await _esperar(tester, find.byType(MensajeSinResultados));
        final mensaje = find.text('Ningún partido coincide con tu búsqueda');
        await _visible(tester, mensaje);
        expect(
          mensaje.hitTestable(),
          findsOneWidget,
          reason: 'Debe verse la orientación cuando no hay coincidencias.',
        );
        expect(
          find.byType(TarjetaPartido),
          findsNothing,
          reason: 'La búsqueda sin coincidencias no debe dejar tarjetas anteriores.',
        );

        debugPrint('Explorar E2E · 6/6: quitar filtros y recuperar resultados');
        final quitar = find.widgetWithText(OutlinedButton, 'Quitar filtros');
        await _visible(tester, quitar);
        _accesible(
          tester,
          find.bySemanticsLabel('Quitar filtros'),
          quitar,
          'Quitar filtros',
        );
        await _tocar(tester, find.bySemanticsLabel('Quitar filtros'));
        await _listo(tester);
        expect(
          tester
              .widget<PanelFiltros>(find.byType(PanelFiltros))
              .filtro
              .estaActivo,
          isFalse,
          reason: 'Quitar filtros debe restaurar todos los valores iniciales.',
        );
        expect(
          tester.widget<TextField>(campo).controller!.text,
          isEmpty,
          reason: 'Debe vaciarse la búsqueda.',
        );
        expect(
          find.byType(MensajeSinResultados),
          findsNothing,
          reason: 'Debe desaparecer el mensaje sin coincidencias.',
        );
        // Hay datos anteriores en la base: no suponer que el total global es dos.
        for (final p in partidos) {
          await _verPartido(tester, p);
        }
        await _escribir(tester, 'explorar_busqueda', busqueda);
        await _listo(tester);
        _cantidad(tester, 2);
        for (final p in partidos) {
          await _verPartido(tester, p);
        }
        expect(
          await datos
              .from('partidos')
              .select()
              .inFilter('id', ids)
              .order('id')
              .timeout(_limite),
          originales,
          reason:
              'Buscar y filtrar no deben modificar los partidos ni sus cupos.',
        );
        expect(
          cliente.auth.currentSession != null &&
              cliente.auth.currentUser?.email?.toLowerCase() ==
                  _correo.trim().toLowerCase(),
          isTrue,
          reason: 'La exploración debe conservar la sesión principal.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Finder _tarjeta(String id) => find.descendant(
  of: find.byType(VistaExplorarPartidos),
  matching: find.byWidgetPredicate(
    (w) => w is TarjetaPartido && w.partido.id == id,
    description: 'tarjeta temporal de otro organizador por ID',
  ),
);
Future<void> _verPartido(WidgetTester tester, ModeloPartido esperado) async {
  final scroll = find
      .descendant(
        of: find.byType(VistaExplorarPartidos),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.scrollUntilVisible(
    _tarjeta(esperado.id),
    300,
    scrollable: scroll,
    maxScrolls: 100,
  );
  final texto = find.descendant(
    of: _tarjeta(esperado.id),
    matching: find.text(esperado.titulo),
  );
  await _visible(tester, texto);
  expect(
    texto.hitTestable(),
    findsOneWidget,
    reason: 'El título del resultado esperado debe ser visible.',
  );
  final p = tester.widget<TarjetaPartido>(_tarjeta(esperado.id)).partido;
  expect(
    p.disciplina,
    esperado.disciplina,
    reason: 'El deporte del resultado debe coincidir.',
  );
  expect(
    p.soyOrganizador,
    isFalse,
    reason: 'Explorar muestra partidos de otros estudiantes.',
  );
}

void _cantidad(WidgetTester tester, int cantidad) {
  expect(
    tester.widget<Text>(find.byKey(const Key('explorar_cantidad'))).data,
    cantidad == 1 ? '1 partido encontrado' : '$cantidad partidos encontrados',
    reason: 'El conteo debe coincidir con los resultados de la búsqueda única.',
  );
}

Future<void> _listo(WidgetTester tester) =>
    _esperar(tester, find.byKey(const Key('explorar_cargando')), ausente: true);
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
        'La aplicación mostró un error inesperado durante la autenticación o exploración. Revisa conexión, cuenta y esquema.',
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
