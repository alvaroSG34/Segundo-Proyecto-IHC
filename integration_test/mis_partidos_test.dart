import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/config/configuracion_supabase.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/servicios/partidos/repositorio_partidos_supabase.dart';
import 'package:unisport/tema/caja_mensaje.dart';
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
const _filtros = {
  'todos': 'Todos',
  'organizados': 'Creados por mí',
  'unido': 'Como jugador',
};
Finder _key(String nombre) => find.byKey(Key('mis_partidos_$nombre'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Mis partidos: consulta real, roles, filtros y nueva apertura', (
    tester,
  ) async {
    expect(
      [_correo, _correoAux].every((v) => v.trim().contains('@')) &&
          [_clave, _claveAux].every((v) => v.trim().length >= 6),
      isTrue,
      reason:
          'Preparación: proporciona E2E_CORREO, E2E_CLAVE, '
          'E2E_CORREO_AUXILIAR y E2E_CLAVE_AUXILIAR de dos cuentas existentes.',
    );
    expect(
      _correo.trim().toLowerCase() != _correoAux.trim().toLowerCase(),
      isTrue,
      reason: 'Preparación: las cuentas deben ser distintas.',
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
    final a = clientes[0], b = clientes[1];
    debugPrint(
      'Mis partidos E2E · 1/9: preparación con dos cuentas existentes',
    );
    for (var i = 0; i < clientes.length; i++) {
      try {
        await clientes[i].auth
            .signInWithPassword(
              email: (i == 0 ? _correo : _correoAux).trim(),
              password: i == 0 ? _clave : _claveAux,
            )
            .timeout(_limite);
      } catch (_) {
        fail(
          'Preparación: no se pudo autenticar la cuenta ${i + 1}; verifica credenciales, confirmación y conexión.',
        );
      }
      expect(
        clientes[i].auth.currentUser != null,
        isTrue,
        reason: 'Preparación: cuenta ${i + 1} autenticada.',
      );
    }
    final uid = a.auth.currentUser!.id, auxiliar = b.auth.currentUser!.id;
    expect(
      uid != auxiliar,
      isTrue,
      reason: 'Preparación: los ID deben ser distintos.',
    );
    final perfil = await a
        .from('perfiles')
        .select()
        .eq('id', uid)
        .maybeSingle()
        .timeout(_limite);
    final perfilAux = await b
        .from('perfiles')
        .select()
        .eq('id', auxiliar)
        .maybeSingle()
        .timeout(_limite);
    expect(
      perfil != null &&
          [
            'nombre',
            'correo',
            'carrera',
          ].every((c) => (perfil[c] as String? ?? '').trim().isNotEmpty),
      isTrue,
      reason: 'Preparación: el principal debe tener un perfil completo.',
    );
    expect(
      perfilAux != null &&
          (perfilAux['nombre'] as String? ?? '').trim().isNotEmpty,
      isTrue,
      reason: 'Preparación: el auxiliar debe tener un perfil con nombre.',
    );
    final marca = DateTime.now().microsecondsSinceEpoch;
    final titulos = [
      'E2E mis propio $marca',
      'E2E mis inscrito $marca',
      'E2E mis ajeno $marca',
    ];
    // Registrar antes de escribir: también elimina una inserción cuya respuesta se pierda.
    addTearDown(
      () => Future.wait([
        a
            .from('partidos')
            .delete()
            .eq('organizador_id', uid)
            .inFilter('titulo', [titulos[0]])
            .timeout(_limite),
        b
            .from('partidos')
            .delete()
            .eq('organizador_id', auxiliar)
            .inFilter('titulo', titulos.sublist(1))
            .timeout(_limite),
      ]),
    );
    final repoA = RepositorioPartidosSupabase(a),
        repoB = RepositorioPartidosSupabase(b);
    ModeloPartido nuevo(String titulo, String nombre) => ModeloPartido(
      id: '',
      titulo: titulo,
      disciplina: 'Futsal',
      icono: 'Futsal',
      ubicacion: 'Cancha E2E',
      fechaHora: ModeloPartido.formatearFechaHora(
        DateTime.now().add(const Duration(days: 2)),
      ),
      cuposTotales: 10,
      cuposOcupados: 1,
      organizadorNombre: nombre,
    );
    final propio = await repoA
        .crearPartido(nuevo(titulos[0], perfil!['nombre'] as String))
        .timeout(_limite);
    final inscrito = await repoB
        .crearPartido(nuevo(titulos[1], perfilAux!['nombre'] as String))
        .timeout(_limite);
    final ajeno = await repoB
        .crearPartido(nuevo(titulos[2], perfilAux['nombre'] as String))
        .timeout(_limite);
    await repoA.unirseAPartido(inscrito.id).timeout(_limite);
    final propios =
        (await a
                .from('partidos')
                .select('id')
                .eq('organizador_id', uid)
                .timeout(_limite))
            .map((r) => r['id'] as String)
            .toSet();
    final inscripciones = await a
        .from('inscripciones')
        .select('partido_id')
        .eq('jugador_id', uid)
        .timeout(_limite);
    final idsInscritos = inscripciones
        .map((r) => r['partido_id'] as String)
        .toSet();
    final unidos = idsInscritos.isEmpty
        ? <String>{}
        : (await a
                  .from('partidos')
                  .select('id, organizador_id')
                  .inFilter('id', idsInscritos.toList())
                  .timeout(_limite))
              .where((r) => r['organizador_id'] != uid)
              .map((r) => r['id'] as String)
              .toSet();
    final todos = {...propios, ...unidos};
    expect(
      propios.contains(propio.id) &&
          unidos.contains(inscrito.id) &&
          !todos.contains(ajeno.id),
      isTrue,
      reason: 'La preparación debe producir ambos roles y un partido ajeno excluido.',
    );
    final snapshot = await _snapshot(a, [propio.id, inscrito.id, ajeno.id]);
    final semantica = tester.ensureSemantics();
    try {
      debugPrint('Mis partidos E2E · 2/9: acceso protegido e inicio de sesión');
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
        reason: 'La portada debe estar sin sesión.',
      );
      await _tocar(tester, find.text('Mis partidos'));
      await _esperar(tester, find.byType(VistaLogin));
      expect(
        find.text('Inicia sesión para ver tus partidos.'),
        findsOneWidget,
        reason: 'Debe orientar al usuario sin sesión.',
      );
      expect(
        find.byType(VistaMisPartidos),
        findsNothing,
        reason: 'El acceso privado debe estar bloqueado.',
      );
      expect(
        cliente.auth.currentSession == null,
        isTrue,
        reason: 'La redirección no debe autenticar.',
      );
      await _escribir(tester, 'login_correo', _correo.trim());
      await _escribir(tester, 'login_clave', _clave);
      await _tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
      await _esperar(tester, find.byType(VistaPrincipal));
      expect(
        cliente.auth.currentUser?.id == uid,
        isTrue,
        reason: 'Debe iniciar sesión el principal.',
      );

      debugPrint('Mis partidos E2E · 3/9: acceso en un toque y carga');
      final acceso = find.widgetWithText(ElevatedButton, 'Mis\nPartidos');
      await _visible(tester, acceso);
      _area(tester, acceso);
      expect(
        tester.getSemantics(acceso).getSemanticsData().flagsCollection.isButton,
        isTrue,
        reason: 'El acceso debe tener rol de botón.',
      );
      expect(
        find.bySemanticsLabel('Mis\nPartidos'),
        findsOneWidget,
        reason: 'El acceso debe tener nombre accesible.',
      );
      var toques = 0;
      await tester.tap(find.bySemanticsLabel('Mis\nPartidos'));
      toques++;
      await _carga(tester);
      expect(toques, 1, reason: 'Acceder a Mis partidos requiere un toque.');
      expect(
        toques,
        lessThanOrEqualTo(3),
        reason: 'Debe respetar el límite de tres toques.',
      );

      debugPrint('Mis partidos E2E · 4/9: identidad y accesibilidad');
      await _visible(tester, _key('identidad'));
      for (final texto in [
        perfil['nombre'],
        '${perfil['correo']} · ${perfil['carrera']}',
      ]) {
        expect(
          find.descendant(
            of: _key('identidad'),
            matching: find.byWidgetPredicate(
              (w) => w is Text && w.data == texto,
              description: 'dato del perfil real en la cabecera',
            ),
          ),
          findsOneWidget,
          reason: 'La cabecera debe coincidir con el perfil persistido.',
        );
      }
      await _seleccion(tester, 'todos');
      for (final filtro in _filtros.entries) {
        final control = _key('filtro_${filtro.key}');
        await _visible(tester, control);
        final datos = tester
            .getSemantics(find.bySemanticsLabel(filtro.value))
            .getSemanticsData();
        expect(
          datos.flagsCollection.isButton,
          isTrue,
          reason: '${filtro.value}: rol de botón.',
        );
        expect(
          datos.flagsCollection.isEnabled.toBoolOrNull(),
          isTrue,
          reason: '${filtro.value}: disponible tras cargar.',
        );
        _area(tester, control);
      }

      debugPrint('Mis partidos E2E · 5/9: Todos');
      _tarjetas(tester, todos, propios, todos.length);
      expect(
        _ids(tester).contains(propio.id),
        isTrue,
        reason: 'Todos incluye el partido propio.',
      );
      expect(
        _ids(tester).contains(inscrito.id),
        isTrue,
        reason: 'Todos incluye el partido inscrito.',
      );
      expect(
        _ids(tester).contains(ajeno.id),
        isFalse,
        reason: 'Todos excluye el ajeno sin inscripción.',
      );
      debugPrint('Mis partidos E2E · 6/9: Creados por mí');
      await _filtrar(tester, 'organizados');
      _tarjetas(tester, propios, propios, todos.length);
      expect(
        _ids(tester).contains(inscrito.id),
        isFalse,
        reason: 'Creados por mí excluye el inscrito como jugador.',
      );
      debugPrint('Mis partidos E2E · 7/9: Como jugador');
      await _filtrar(tester, 'unido');
      _tarjetas(tester, unidos, propios, todos.length);
      expect(
        _ids(tester).contains(inscrito.id),
        isTrue,
        reason: 'Como jugador incluye la inscripción preparada.',
      );
      expect(
        _ids(tester).intersection({propio.id, ajeno.id}),
        isEmpty,
        reason: 'Como jugador excluye propio y ajeno no inscrito.',
      );
      debugPrint('Mis partidos E2E · 8/9: restaurar Todos sin modificar datos');
      await _filtrar(tester, 'todos');
      _tarjetas(tester, todos, propios, todos.length);
      expect(
        await _snapshot(a, [propio.id, inscrito.id, ajeno.id]),
        snapshot,
        reason: 'Filtrar no modifica partidos ni inscripciones.',
      );
      debugPrint('Mis partidos E2E · 9/9: nueva consulta al volver');
      await _filtrar(tester, 'unido');
      await tester.pageBack();
      await _esperar(tester, find.byType(VistaPrincipal));
      await _visible(tester, acceso);
      await tester.tap(find.bySemanticsLabel('Mis\nPartidos'));
      await _carga(tester);
      await _seleccion(tester, 'todos');
      _tarjetas(tester, todos, propios, todos.length);
      expect(
        cliente.auth.currentUser?.id == uid,
        isTrue,
        reason: 'Consultar conserva la sesión principal.',
      );
      expect(
        find.byType(VistaLogin),
        findsNothing,
        reason: 'La consulta autorizada no redirige al login.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}

Future<List<Object>> _snapshot(SupabaseClient c, List<String> ids) async => [
  await c
      .from('partidos')
      .select()
      .inFilter('id', ids)
      .order('id')
      .timeout(_limite),
  await c
      .from('inscripciones')
      .select()
      .inFilter('partido_id', ids)
      .order('partido_id')
      .order('jugador_id')
      .timeout(_limite),
];
Set<String> _ids(WidgetTester tester) => tester
    .widgetList<TarjetaPartido>(find.byType(TarjetaPartido))
    .map((t) => t.partido.id)
    .toSet();
void _tarjetas(
  WidgetTester tester,
  Set<String> esperados,
  Set<String> propios,
  int total,
) {
  final tarjetas = tester
      .widgetList<TarjetaPartido>(find.byType(TarjetaPartido))
      .toList();
  expect(
    _ids(tester),
    unorderedEquals(esperados),
    reason: 'Las tarjetas deben corresponder a todos los ID esperados de la cuenta.',
  );
  expect(
    tarjetas.length,
    esperados.length,
    reason: 'No debe haber tarjetas duplicadas.',
  );
  for (final tarjeta in tarjetas) {
    expect(
      tarjeta.partido.soyOrganizador,
      propios.contains(tarjeta.partido.id),
      reason: 'El rol de cada tarjeta debe coincidir con su propietario real.',
    );
  }
  expect(
    tester.widget<Text>(_key('cantidad_visible')).data,
    '${esperados.length}',
    reason: 'La cantidad visible debe coincidir con el filtro.',
  );
  expect(
    tester.widget<Text>(_key('cantidad_total')).data,
    'Todos ($total)',
    reason: 'La cantidad total incluye ambos roles.',
  );
  expect(
    tester
        .getSemantics(find.bySemanticsLabel('Todos'))
        .getSemanticsData()
        .value,
    '$total partidos',
    reason: 'Todos anuncia su cantidad como valor, con nombre estable.',
  );
}

Future<void> _seleccion(WidgetTester tester, String elegido) async {
  for (final filtro in _filtros.entries) {
    await _visible(tester, _key('filtro_${filtro.key}'));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(filtro.value))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      filtro.key == elegido,
      reason: '${filtro.value}: selección accesible correcta.',
    );
  }
}

Future<void> _filtrar(WidgetTester tester, String clave) async {
  await _visible(tester, _key('filtro_$clave'));
  await _tocar(tester, find.bySemanticsLabel(_filtros[clave]!));
  await _seleccion(tester, clave);
}

Future<void> _carga(WidgetTester tester) async {
  // La ruta se monta después del primer cuadro de la transición.
  final reloj = Stopwatch()..start();
  while (_key('cargando').evaluate().isEmpty && reloj.elapsed < _limite) {
    await tester.pump(const Duration(milliseconds: 16));
    if (find.byType(VistaMisPartidos).evaluate().isNotEmpty &&
        _key('cargando').evaluate().isEmpty) {
      break;
    }
  }
  expect(
    _key('cargando'),
    findsOneWidget,
    reason: 'Cada apertura debe consultar mostrando carga.',
  );
  for (final filtro in _filtros.keys) {
    expect(
      tester.widget<Semantics>(_key('filtro_$filtro')).properties.enabled,
      isFalse,
      reason: 'Los filtros deben bloquearse durante la consulta.',
    );
  }
  await tester.ensureVisible(_key('cargando'));
  await tester.pump(const Duration(milliseconds: 16));
  expect(
    find.bySemanticsLabel('Cargando mis partidos'),
    findsOneWidget,
    reason: 'La carga debe anunciarse de forma accesible.',
  );
  expect(
    find.descendant(
      of: _key('cargando'),
      matching: find.byType(CircularProgressIndicator),
    ),
    findsOneWidget,
    reason: 'Debe verse el indicador de carga.',
  );
  await _esperar(tester, _key('cargando'), ausente: true);
  expect(
    _key('error'),
    findsNothing,
    reason: 'La consulta real debe completarse sin error.',
  );
}

void _area(WidgetTester tester, Finder control) {
  final size = tester.getSize(control);
  expect(
    size.width,
    greaterThanOrEqualTo(48),
    reason: 'El ancho táctil debe ser al menos 48.',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(48),
    reason: 'El alto táctil debe ser al menos 48.',
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
        .any((c) => c.tipo == TipoMensaje.error)) {
      fail(
        'La aplicación mostró un error inesperado durante la consulta o autenticación. Revisa conexión, cuenta y esquema.',
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
