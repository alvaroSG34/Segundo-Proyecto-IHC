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
const _correoAux = String.fromEnvironment('E2E_CORREO_AUXILIAR');
const _claveAux = String.fromEnvironment('E2E_CLAVE_AUXILIAR');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Consultar jugadores inscritos: nombre persistido y consulta sin cambios',
    (tester) async {
      expect(
        [_correo, _correoAux].every((v) => v.trim().contains('@')) &&
            [_clave, _claveAux].every((v) => v.trim().length >= 6),
        isTrue,
        reason: 'Indica E2E_CORREO, E2E_CLAVE, E2E_CORREO_AUXILIAR y E2E_CLAVE_AUXILIAR de dos cuentas existentes, confirmadas y con perfil completo.',
      );
      expect(
        _correo.trim().toLowerCase() != _correoAux.trim().toLowerCase(),
        isTrue,
        reason: 'El organizador y el jugador deben usar cuentas distintas.',
      );
      final clientes = List.generate(
        2,
        (_) => SupabaseClient(
          ConfiguracionSupabase.url,
          ConfiguracionSupabase.clavePublica,
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
        ),
      );
      addTearDown(
        () => Future.wait(
          clientes.map((c) async {
            try {
              if (c.auth.currentSession != null) {
                await c.auth.signOut().timeout(_limite);
              }
            } finally {
              await c.dispose();
            }
          }),
        ),
      );
      debugPrint('Inscritos E2E · 1/5: preparación e ingreso');
      final perfiles = <Map<String, dynamic>>[];
      for (var i = 0; i < clientes.length; i++) {
        final c = clientes[i];
        try {
          await c.auth
              .signInWithPassword(
                email: (i == 0 ? _correo : _correoAux).trim(),
                password: i == 0 ? _clave : _claveAux,
              )
              .timeout(_limite);
        } catch (_) {
          fail(
            'Preparación: no se pudo autenticar la cuenta ${i + 1}. Verifica credenciales, confirmación y conexión.',
          );
        }
        expect(
          c.auth.currentUser != null,
          isTrue,
          reason: 'Preparación: la cuenta ${i + 1} debe estar autenticada.',
        );
        final perfil = await c
            .from('perfiles')
            .select()
            .eq('id', c.auth.currentUser!.id)
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
          reason: 'Preparación: la cuenta ${i + 1} debe tener perfil completo.',
        );
        perfiles.add(perfil!);
      }
      final datos = clientes[0], auxiliar = clientes[1];
      final organizador = datos.auth.currentUser!.id,
          jugador = auxiliar.auth.currentUser!.id;
      expect(
        organizador != jugador,
        isTrue,
        reason: 'Los ID de las cuentas deben ser distintos.',
      );
      final ahora = DateTime.now();
      final titulo = 'E2E inscritos ${ahora.microsecondsSinceEpoch}';
      String? id;
      // Registrar antes de insertar: el título cubre respuestas de creación perdidas.
      addTearDown(() async {
        var borrar = datos
            .from('partidos')
            .delete()
            .eq('organizador_id', organizador);
        borrar = id == null ? borrar.eq('titulo', titulo) : borrar.eq('id', id);
        await borrar.timeout(_limite); // La inscripción se elimina en cascada.
      });
      var partido = await RepositorioPartidosSupabase(datos)
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
              organizadorNombre: perfiles[0]['nombre'] as String,
            ),
          )
          .timeout(_limite);
      id = partido.id;
      partido = await RepositorioPartidosSupabase(auxiliar)
          .unirseAPartido(partido.id)
          .timeout(_limite);
      final original = await datos
          .from('partidos')
          .select()
          .eq('id', partido.id)
          .single()
          .timeout(_limite);
      final inscripcionesOriginales = await _inscripciones(datos, partido.id);
      expect(
        inscripcionesOriginales.length,
        1,
        reason: 'La preparación debe dejar una única inscripción.',
      );
      final inscrito = inscripcionesOriginales.single;
      expect(
        inscrito['jugador_id'] == jugador,
        isTrue,
        reason: 'El inscrito debe ser el auxiliar.',
      );
      expect(
        inscrito['jugador_nombre'] == perfiles[1]['nombre'],
        isTrue,
        reason: 'La inscripción debe persistir el nombre del auxiliar.',
      );
      final nombre = inscrito['jugador_nombre'] as String;
      expect(
        nombre.trim().isNotEmpty,
        isTrue,
        reason: 'El nombre persistido no debe estar vacío.',
      );
      expect(
        original['cupos_ocupados'],
        2,
        reason: 'La preparación debe dejar dos cupos ocupados.',
      );
      expect(
        original['cupos_totales'],
        6,
        reason: 'La preparación debe conservar seis cupos totales.',
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
          cliente.auth.currentUser?.id == organizador,
          isTrue,
          reason: 'Debe ingresar el organizador principal.',
        );

        debugPrint('Inscritos E2E · 2/5: acceso y accesibilidad');
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
        await _esperarTarjeta(tester, partido.id);

        debugPrint('Inscritos E2E · 3/5: consultar en dos toques');
        await _abrirLista(tester, partido.id);
        toques++;
        expect(
          toques,
          2,
          reason: 'Menú → Mis partidos → Ver jugadores inscritos requiere dos toques.',
        );
        expect(
          toques,
          lessThanOrEqualTo(3),
          reason: 'El acceso debe respetar el máximo de tres toques.',
        );
        await _comprobarLista(tester, nombre);

        debugPrint('Inscritos E2E · 4/5: cerrar y consultar nuevamente');
        await _cerrarLista(tester);
        expect(
          _tarjeta(partido.id),
          findsOneWidget,
          reason: 'Cerrar el diálogo debe conservar la tarjeta.',
        );
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
        await _esperar(tester, find.byType(VistaMisPartidos));
        await _esperarTarjeta(tester, partido.id);
        await _abrirLista(tester, partido.id);
        await _comprobarLista(tester, nombre);
        await _cerrarLista(tester);

        debugPrint('Inscritos E2E · 5/5: datos intactos antes de la limpieza');
        expect(
          await datos
              .from('partidos')
              .select()
              .eq('id', partido.id)
              .single()
              .timeout(_limite),
          original,
          reason:
              'Consultar inscritos no debe modificar el partido ni los cupos.',
        );
        expect(
          await _inscripciones(datos, partido.id),
          inscripcionesOriginales,
          reason:
              'Consultar no debe crear, modificar ni eliminar inscripciones.',
        );
        expect(
          cliente.auth.currentSession != null &&
              cliente.auth.currentUser?.id == organizador,
          isTrue,
          reason: 'Consultar debe conservar la sesión del organizador.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<List<Map<String, dynamic>>> _inscripciones(
  SupabaseClient c,
  String partido,
) => c
    .from('inscripciones')
    .select()
    .eq('partido_id', partido)
    .order('jugador_id')
    .timeout(_limite);
Finder _tarjeta(String id) => find.descendant(
  of: find.byType(VistaMisPartidos),
  matching: find.byWidgetPredicate(
    (w) => w is TarjetaPartido && w.partido.id == id,
    description: 'tarjeta del partido temporal por ID',
  ),
);
Finder _dialogo(Finder control) =>
    find.descendant(of: find.byType(AlertDialog), matching: control);
Future<void> _esperarTarjeta(WidgetTester tester, String id) async {
  await _esperar(
    tester,
    find.byKey(const Key('mis_partidos_cargando')),
    ausente: true,
  );
  await _esperar(
    tester,
    _tarjeta(id),
    condicion: () {
      final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
      return p.soyOrganizador && p.cuposTotales == 6 && p.cuposOcupados == 2;
    },
    motivo: 'La tarjeta debe pertenecer al organizador y mostrar 2/6 cupos.',
  );
}

Future<void> _abrirLista(WidgetTester tester, String id) async {
  final visual = find.descendant(
    of: _tarjeta(id),
    matching: find.widgetWithText(
      OutlinedButton,
      'Ver jugadores inscritos (1)',
    ),
  );
  final accesible = find.descendant(
    of: _tarjeta(id),
    matching: find.bySemanticsLabel('Ver jugadores inscritos (1)'),
  );
  await _visible(tester, visual);
  _accesible(tester, accesible, visual, 'Ver jugadores inscritos (1)');
  await _tocar(tester, accesible);
  await _esperar(tester, find.byType(AlertDialog));
}

Future<void> _comprobarLista(WidgetTester tester, String nombre) async {
  expect(
    _dialogo(find.text('Jugadores inscritos (1)')),
    findsOneWidget,
    reason: 'El título debe anunciar un inscrito.',
  );
  final fila = _dialogo(find.byType(ListTile));
  expect(
    fila,
    findsOneWidget,
    reason: 'El diálogo debe contener exactamente un elemento.',
  );
  final texto = find.descendant(
    of: fila,
    matching: find.byWidgetPredicate(
      (w) => w is Text && w.data == nombre,
      description: 'nombre de la inscripción real del auxiliar',
    ),
  );
  await _visible(tester, texto);
  expect(
    texto.hitTestable(),
    findsOneWidget,
    reason: 'Debe verse el nombre persistido del auxiliar.',
  );
}

Future<void> _cerrarLista(WidgetTester tester) async {
  final visual = _dialogo(find.widgetWithText(TextButton, 'Cerrar'));
  final accesible = _dialogo(find.bySemanticsLabel('Cerrar'));
  await _visible(tester, visual);
  _accesible(tester, accesible, visual, 'Cerrar');
  await _tocar(tester, accesible);
  expect(
    find.byType(AlertDialog),
    findsNothing,
    reason: 'Cerrar debe descartar el diálogo.',
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
        'La aplicación mostró un error inesperado durante la autenticación o consulta de inscritos. Revisa conexión, cuenta y esquema.',
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
