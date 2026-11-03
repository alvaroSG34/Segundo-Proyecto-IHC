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
import 'package:unisport/vistas/partidos/vista_historial.dart';
import 'package:unisport/widgets/tarjeta_historial.dart';
import 'package:unisport/modelos/evento_historial.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _correoAux = String.fromEnvironment('E2E_CORREO_AUXILIAR');
const _claveAux = String.fromEnvironment('E2E_CLAVE_AUXILIAR');
const _limite = Duration(seconds: 45);

const _filtros = {
  'todos': 'Todos',
  'organizador': 'Organizados',
  'jugador': 'Como jugador',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Historial: consulta, filtros por rol y reapertura', (
    tester,
  ) async {
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
    debugPrint('Historial E2E · 1/6: preparación e ingreso');
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
    final uid = datos.auth.currentUser!.id,
        uidAux = auxiliar.auth.currentUser!.id;
    expect(
      uid != uidAux,
      isTrue,
      reason: 'Los ID de las cuentas deben ser distintos.',
    );
    final ahora = DateTime.now();
    final marca = ahora.microsecondsSinceEpoch;
    final titulos = [
      'E2E historial organizado $marca',
      'E2E historial jugador $marca',
    ];
    // Registrar ambas limpiezas antes de insertar, incluyendo respuestas perdidas.
    final ids = [<String>[], <String>[]];
    addTearDown(
      () => Future.wait(
        List.generate(2, (i) async {
          final c = clientes[i], propietario = i == 0 ? uid : uidAux;
          if (ids[i].isNotEmpty) {
            await c
                .from('partidos')
                .delete()
                .eq('organizador_id', propietario)
                .inFilter('id', ids[i])
                .timeout(_limite);
          }
          await c
              .from('partidos')
              .delete()
              .eq('organizador_id', propietario)
              .eq('titulo', titulos[i])
              .timeout(_limite);
        }),
      ),
    );
    final preparados = <ModeloPartido>[];
    for (var i = 0; i < clientes.length; i++) {
      final p = await RepositorioPartidosSupabase(clientes[i])
          .crearPartido(
            ModeloPartido(
              id: '',
              titulo: titulos[i],
              disciplina: 'Futsal',
              icono: 'Futsal',
              ubicacion: 'Cancha E2E',
              fechaHora: ModeloPartido.formatearFechaHora(
                DateTime(ahora.year, ahora.month, ahora.day + 2 + i, 18 + i),
              ),
              cuposTotales: 6,
              cuposOcupados: 1,
              organizadorNombre: perfiles[i]['nombre'] as String,
            ),
          )
          .timeout(_limite);
      ids[i].add(p.id);
      preparados.add(p);
    }
    await RepositorioPartidosSupabase(datos)
        .unirseAPartido(preparados[1].id)
        .timeout(_limite);
    // Oráculo independiente del RPC de historial; incluye datos anteriores.
    final filasPropias = await datos
        .from('partidos')
        .select()
        .eq('organizador_id', uid)
        .timeout(_limite);
    final inscripciones = await datos
        .from('inscripciones')
        .select('partido_id')
        .eq('jugador_id', uid)
        .timeout(_limite);
    final idsInscritos = inscripciones
        .map((r) => r['partido_id'] as String)
        .toSet();
    final filasUnidas = idsInscritos.isEmpty
        ? <Map<String, dynamic>>[]
        : (await datos
                  .from('partidos')
                  .select()
                  .inFilter('id', idsInscritos.toList())
                  .timeout(_limite))
              .where((r) => r['organizador_id'] != uid)
              .toList();
    final propios = filasPropias.map((r) => r['id'] as String).toSet();
    final unidos = filasUnidas.map((r) => r['id'] as String).toSet();
    final filas = <String, Map<String, dynamic>>{
      for (final fila in [...filasPropias, ...filasUnidas])
        fila['id'] as String: fila,
    };
    final todos = filas.keys.toSet();
    expect(
      propios.contains(preparados[0].id) && unidos.contains(preparados[1].id),
      isTrue,
      reason: 'La preparación debe cubrir ambos roles del usuario principal.',
    );
    final temporales = preparados.map((p) => p.id).toList();
    final snapshot = await _snapshot(datos, temporales);
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
        reason: 'Debe ingresar el usuario principal.',
      );

      debugPrint('Historial E2E · 2/6: acceso y accesibilidad');
      final acceso = find.widgetWithText(ElevatedButton, 'Historial');
      await _visible(tester, acceso);
      _accesible(
        tester,
        find.bySemanticsLabel('Historial'),
        acceso,
        'Historial',
      );
      var toques = 0;
      await _tocar(tester, find.bySemanticsLabel('Historial'));
      toques++;
      await _listo(tester);
      expect(
        find.text('Historial de participación'),
        findsOneWidget,
        reason: 'Debe abrirse la pantalla Historial.',
      );
      expect(toques, 1, reason: 'Historial se abre en un toque desde el menú.');
      expect(
        toques,
        lessThanOrEqualTo(3),
        reason: 'El acceso respeta el máximo de tres toques.',
      );
      for (final filtro in _filtros.entries) {
        await _visible(tester, _filtro(filtro.key));
        _accesible(
          tester,
          _accion(filtro.key),
          _filtro(filtro.key),
          filtro.value,
        );
      }
      await _seleccion(tester, 'todos');

      debugPrint('Historial E2E · 3/6: Todos, cantidades, roles y orden');
      _comprobar(tester, todos, filas, propios, unidos);
      expect(
        _ids(tester).contains(preparados[0].id),
        isTrue,
        reason: 'Todos debe incluir el partido organizado.',
      );
      expect(
        _ids(tester).contains(preparados[1].id),
        isTrue,
        reason: 'Todos debe incluir el partido como jugador.',
      );
      for (final p in preparados) {
        await _tituloVisible(tester, p);
      }

      debugPrint('Historial E2E · 4/6: filtros por rol');
      await _filtrar(tester, 'organizador');
      _comprobar(tester, propios, filas, propios, unidos);
      expect(
        _ids(tester).contains(preparados[0].id),
        isTrue,
        reason: 'Organizados debe incluir el partido propio.',
      );
      expect(
        _ids(tester).contains(preparados[1].id),
        isFalse,
        reason: 'Organizados debe excluir la participación como jugador.',
      );
      await _filtrar(tester, 'jugador');
      _comprobar(tester, unidos, filas, propios, unidos);
      expect(
        _ids(tester).contains(preparados[1].id),
        isTrue,
        reason: 'Como jugador debe incluir el partido inscrito.',
      );
      expect(
        _ids(tester).contains(preparados[0].id),
        isFalse,
        reason: 'Como jugador debe excluir el partido organizado.',
      );

      debugPrint('Historial E2E · 5/6: restaurar Todos y reabrir');
      await _filtrar(tester, 'todos');
      _comprobar(tester, todos, filas, propios, unidos);
      await _filtrar(tester, 'jugador');
      await _tocar(tester, find.byTooltip('Volver'));
      await _esperar(tester, find.byType(VistaPrincipal));
      await _tocar(tester, find.bySemanticsLabel('Historial'));
      await _listo(tester);
      await _seleccion(tester, 'todos');
      _comprobar(tester, todos, filas, propios, unidos);

      debugPrint('Historial E2E · 6/6: datos intactos antes de la limpieza');
      expect(
        await _snapshot(datos, temporales),
        snapshot,
        reason: 'Consultar y filtrar no deben modificar partidos ni inscripciones temporales.',
      );
      expect(
        cliente.auth.currentSession != null &&
            cliente.auth.currentUser?.id == uid,
        isTrue,
        reason: 'El historial debe conservar la sesión principal.',
      );
    } finally {
      semantica.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
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
Finder _filtro(String clave) => find.byKey(Key('filtro_$clave'));
Finder _accion(String clave) => find.descendant(
  of: _filtro(clave),
  matching: find.bySemanticsLabel(_filtros[clave]!),
  matchRoot: true,
);
Finder _tarjetas() => find.descendant(
  of: find.byType(VistaHistorial),
  matching: find.byType(TarjetaHistorial),
);
Set<String> _ids(WidgetTester tester) => tester
    .widgetList<TarjetaHistorial>(_tarjetas())
    .map((t) => t.evento.partidoId)
    .toSet();
Future<void> _listo(WidgetTester tester) async {
  await _esperar(tester, find.byType(VistaHistorial));
  await _esperar(
    tester,
    find.byKey(const Key('historial_cargando')),
    ausente: true,
  );
}

Future<void> _seleccion(WidgetTester tester, String elegido) async {
  for (final filtro in _filtros.entries) {
    await _visible(tester, _filtro(filtro.key));
    expect(
      tester
          .getSemantics(_accion(filtro.key))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull(),
      filtro.key == elegido,
      reason: '${filtro.value} debe anunciar su selección correcta.',
    );
  }
}

Future<void> _filtrar(WidgetTester tester, String clave) async {
  await _visible(tester, _filtro(clave));
  await _tocar(tester, _accion(clave));
  await _seleccion(tester, clave);
}

void _comprobar(
  WidgetTester tester,
  Set<String> esperados,
  Map<String, Map<String, dynamic>> filas,
  Set<String> propios,
  Set<String> unidos,
) {
  final eventos = tester
      .widgetList<TarjetaHistorial>(_tarjetas())
      .map((t) => t.evento)
      .toList();
  expect(
    _ids(tester),
    unorderedEquals(esperados),
    reason:
        'Los ID deben corresponder al conjunto completo esperado del filtro.',
  );
  expect(
    eventos.length,
    esperados.length,
    reason: 'No debe haber tarjetas duplicadas.',
  );
  for (var i = 0; i < eventos.length; i++) {
    final e = eventos[i], fila = filas[e.partidoId]!;
    expect(
      e.rol,
      propios.contains(e.partidoId)
          ? RolParticipacion.organizador
          : RolParticipacion.jugador,
      reason: 'El rol de la tarjeta debe coincidir con los datos reales.',
    );
    expect(
      e.tituloPartido,
      fila['titulo'],
      reason: 'La tarjeta debe mostrar el título persistido.',
    );
    expect(
      e.fechaInicio,
      DateTime.parse(fila['fecha_inicio'] as String).toLocal(),
      reason: 'La fecha de cada tarjeta debe coincidir con Supabase.',
    );
    if (i > 0) {
      expect(
        e.fechaInicio.isAfter(eventos[i - 1].fechaInicio),
        isFalse,
        reason: 'Las fechas deben ir de más reciente a más antigua; se permiten empates.',
      );
    }
  }
  final n = esperados.length;
  expect(
    tester
        .widget<Text>(find.byKey(const Key('historial_cantidad_visible')))
        .data,
    '$n ${n == 1 ? 'partido registrado' : 'partidos registrados'} (más recientes primero)',
    reason: 'La cantidad visible debe corresponder al filtro.',
  );
  for (final valor in {
    'historial_total': filas.length,
    'historial_organizados': propios.length,
    'historial_jugador': unidos.length,
  }.entries) {
    expect(
      tester.widget<Text>(find.byKey(Key(valor.key))).data,
      '${valor.value}',
      reason: 'El indicador ${valor.key} debe reflejar el historial completo.',
    );
  }
}

Future<void> _tituloVisible(WidgetTester tester, ModeloPartido p) async {
  final tarjeta = find.descendant(
    of: find.byType(VistaHistorial),
    matching: find.byWidgetPredicate(
      (w) => w is TarjetaHistorial && w.evento.partidoId == p.id,
      description: 'evento temporal por ID',
    ),
  );
  final titulo = find.descendant(of: tarjeta, matching: find.text(p.titulo));
  await _visible(tester, titulo);
  expect(
    titulo.hitTestable(),
    findsOneWidget,
    reason: 'El título preparado debe ser visible en el historial.',
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
        'La aplicación mostró un error inesperado durante la autenticación o consulta del historial. Revisa conexión, cuenta y esquema.',
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
