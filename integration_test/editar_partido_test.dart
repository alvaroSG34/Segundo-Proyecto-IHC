import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/widgets/boton_accion.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');
const _limite = Duration(seconds: 45);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Editar partido: alternativos, carga, persistencia y restricciones de cupos',
    (tester) async {
      expect(
        _correo.trim().contains('@') && _clave.trim().length >= 6,
        isTrue,
        reason: 'Preparación: proporciona E2E_CORREO y E2E_CLAVE de una cuenta existente, confirmada y con perfil completo.',
      );
      final inicio = DateTime.now();
      final marca = inicio.microsecondsSinceEpoch;
      final tituloOriginal = 'E2E editar abierto $marca';
      final tituloNuevo = 'E2E editado abierto $marca';
      final tituloCompleto = 'E2E editar completo $marca';
      final tituloCompletoNuevo = 'E2E editado completo $marca';
      final tituloDescartado = 'E2E descartado $marca';
      final titulos = [
        tituloOriginal,
        tituloNuevo,
        tituloCompleto,
        tituloCompletoNuevo,
        tituloDescartado,
      ];
      final ids = <String>[];
      final clienteDatos = SupabaseClient(
        ConfiguracionSupabase.url,
        ConfiguracionSupabase.clavePublica,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
      );
      addTearDown(() async {
        try {
          if (clienteDatos.auth.currentSession != null) {
            await clienteDatos.auth.signOut().timeout(_limite);
          }
        } finally {
          await clienteDatos.dispose();
        }
      });
      debugPrint('Editar E2E · 1/9: preparación e ingreso');
      try {
        await clienteDatos.auth
            .signInWithPassword(email: _correo.trim(), password: _clave)
            .timeout(_limite);
      } catch (_) {
        fail(
          'Preparación: no se pudo iniciar sesión. Verifica credenciales, confirmación, cuenta habilitada y conexión.',
        );
      }
      final uid = clienteDatos.auth.currentUser?.id;
      expect(
        uid != null,
        isTrue,
        reason: 'Preparación: debe existir usuario autenticado.',
      );
      final perfil = await clienteDatos
          .from('perfiles')
          .select()
          .eq('id', uid!)
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
        reason: 'Preparación: la cuenta debe tener perfil completo.',
      );
      // Registrar antes de insertar; el título cubre respuestas de creación perdidas.
      addTearDown(() async {
        if (ids.isNotEmpty) {
          await clienteDatos
              .from('partidos')
              .delete()
              .eq('organizador_id', uid)
              .inFilter('id', ids)
              .timeout(_limite);
        }
        await clienteDatos
            .from('partidos')
            .delete()
            .eq('organizador_id', uid)
            .inFilter('titulo', titulos)
            .timeout(_limite);
      });
      final repo = RepositorioPartidosSupabase(clienteDatos);
      ModeloPartido nuevo(String titulo, int cupos, int hora) => ModeloPartido(
        id: '',
        titulo: titulo,
        disciplina: 'Futsal',
        icono: 'Futsal',
        ubicacion: 'Cancha original E2E',
        fechaHora: ModeloPartido.formatearFechaHora(
          DateTime(inicio.year, inicio.month, inicio.day + 2, hora, 30),
        ),
        cuposTotales: cupos,
        cuposOcupados: 1,
        organizadorNombre: perfil!['nombre'] as String,
      );
      var abierto = await repo
          .crearPartido(nuevo(tituloOriginal, 6, 9))
          .timeout(_limite);
      ids.add(abierto.id);
      abierto = await repo.agregarJugadorSinCuenta(abierto.id).timeout(_limite);
      abierto = await repo.agregarJugadorSinCuenta(abierto.id).timeout(_limite);
      var completo = await repo
          .crearPartido(nuevo(tituloCompleto, 4, 11))
          .timeout(_limite);
      ids.add(completo.id);
      completo = await repo.completarEquipo(completo.id).timeout(_limite);
      final original = await _fila(clienteDatos, abierto.id);
      final originalCompleto = await _fila(clienteDatos, completo.id);
      expect(
        abierto.cuposOcupados,
        3,
        reason: 'Preparación: abierto con tres ocupados.',
      );
      expect(
        completo.estado,
        EstadoPartido.equipoCompleto,
        reason: 'Preparación: segundo partido completo.',
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
        final clienteApp = Supabase.instance.client;
        addTearDown(() => clienteApp.auth.signOut().timeout(_limite));
        if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
          await _tocar(tester, find.text('CERRAR SESIÓN'));
          await _esperar(tester, find.byType(VistaInicioPublico));
        }
        expect(
          clienteApp.auth.currentSession == null,
          isTrue,
          reason: 'No debe quedar una sesión previa.',
        );
        await _tocar(tester, find.bySemanticsLabel('Iniciar sesión'));
        await _esperar(tester, find.byType(VistaLogin));
        await _escribir(tester, 'login_correo', _correo.trim());
        await _escribir(tester, 'login_clave', _clave);
        await _tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
        await _esperar(tester, find.byType(VistaPrincipal));
        expect(
          clienteApp.auth.currentUser?.id == uid,
          isTrue,
          reason: 'Debe ingresar el propietario preparado.',
        );

        debugPrint('Editar E2E · 2/9: acceso en dos toques');
        var toques = 0;
        final acceso = find.widgetWithText(ElevatedButton, 'Mis\nPartidos');
        await _visible(tester, acceso);
        _botonAccesible(
          tester,
          find.bySemanticsLabel('Mis\nPartidos'),
          'Mis partidos',
        );
        _areaTactil(tester, acceso, 'Mis partidos');
        await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
        toques++;
        await _esperar(tester, _tarjeta(abierto.id));
        await _abrirEdicion(tester, abierto.id);
        toques++;
        expect(
          toques,
          2,
          reason: 'Menú → Mis partidos → Editar son dos toques.',
        );
        expect(
          toques,
          lessThanOrEqualTo(3),
          reason: 'Acceder a edición respeta el máximo de tres toques.',
        );

        debugPrint('Editar E2E · 3/9: precarga y accesibilidad');
        await _precarga(tester, abierto);
        for (final campo in [
          ('partido_titulo', 'Título del partido'),
          ('partido_ubicacion', 'Ubicación del partido'),
        ]) {
          await _visible(tester, find.byKey(Key(campo.$1)));
          final control = find.bySemanticsLabel(campo.$2);
          expect(
            control,
            findsOneWidget,
            reason: 'El campo debe tener nombre accesible único.',
          );
          expect(
            tester
                .getSemantics(control)
                .getSemanticsData()
                .flagsCollection
                .isTextField,
            isTrue,
            reason: '${campo.$2} debe tener rol de campo.',
          );
        }
        for (final nombre in [
          'Futsal',
          'Básquetbol',
          'Fecha del partido',
          'Hora del partido',
          'Aumentar cupos',
          'Disminuir cupos',
          '19:00',
        ]) {
          await _visible(tester, _marco(nombre));
          _botonAccesible(tester, _accion(nombre), nombre);
          _areaTactil(tester, _marco(nombre), nombre);
        }
        await _visible(tester, _guardar());
        _botonAccesible(
          tester,
          find.bySemanticsLabel('Guardar cambios'),
          'Guardar cambios',
        );
        _areaTactil(tester, _guardar(), 'Guardar cambios');

        debugPrint('Editar E2E · 4/9: campos inválidos sin escritura');
        await _escribir(tester, 'partido_titulo', '');
        await _escribir(tester, 'partido_ubicacion', '');
        await _tocar(tester, find.bySemanticsLabel('Guardar cambios'));
        await _mensajeVisible(tester, 'Escribe un título');
        await _mensajeVisible(tester, 'Escribe el lugar del partido');
        expect(
          find.byType(VistaCrearPartido),
          findsOneWidget,
          reason: 'La validación conserva el formulario.',
        );
        expect(
          await _fila(clienteDatos, abierto.id),
          original,
          reason: 'Vacíos no deben cambiar la fila.',
        );
        await _escribir(tester, 'partido_titulo', 'ab');
        await _escribir(tester, 'partido_ubicacion', 'Cancha válida E2E');
        await _tocar(tester, find.bySemanticsLabel('Guardar cambios'));
        await _mensajeVisible(tester, 'Debe tener al menos 3 caracteres');
        expect(
          find.byType(VistaCrearPartido),
          findsOneWidget,
          reason: 'El título corto conserva el formulario.',
        );
        expect(
          await _fila(clienteDatos, abierto.id),
          original,
          reason: 'Título corto no debe cambiar la fila.',
        );

        debugPrint('Editar E2E · 5/9: cancelar descarta cambios');
        await _escribir(tester, 'partido_titulo', tituloDescartado);
        await _escribir(tester, 'partido_ubicacion', 'Lugar descartado E2E');
        await tester.pageBack();
        await _esperar(tester, _tarjeta(abierto.id));
        expect(
          tester.widget<TarjetaPartido>(_tarjeta(abierto.id)).partido.titulo,
          tituloOriginal,
          reason: 'Cancelar conserva la tarjeta original.',
        );
        expect(
          await _fila(clienteDatos, abierto.id),
          original,
          reason: 'Cancelar conserva la fila original.',
        );
        await _abrirEdicion(tester, abierto.id);
        await _precarga(tester, abierto);

        debugPrint('Editar E2E · 6/9: mínimo de cupos ocupados');
        for (final esperado in [5, 4, 3]) {
          await _tocar(tester, _accion('Disminuir cupos'));
          _cupos(tester, esperado);
        }
        expect(
          tester
              .widget<Semantics>(_marco('Disminuir cupos'))
              .properties
              .enabled,
          isFalse,
          reason: 'No debe reducirse por debajo de tres jugadores ocupados.',
        );
        await tester.tap(_marco('Disminuir cupos'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
        _cupos(tester, 3);
        for (final esperado in [4, 5]) {
          await _tocar(tester, _accion('Aumentar cupos'));
          _cupos(tester, esperado);
        }

        debugPrint('Editar E2E · 7/9: cambios, vista previa y carga');
        await _escribir(tester, 'partido_titulo', tituloNuevo);
        await _escribir(tester, 'partido_ubicacion', 'Coliseo editado E2E');
        await _tocar(tester, _accion('Básquetbol'));
        expect(
          _datos(
            tester,
            'Básquetbol',
          ).flagsCollection.isSelected.toBoolOrNull(),
          isTrue,
          reason: 'El deporte elegido debe anunciarse seleccionado.',
        );
        final fechaNueva = DateTime(
          inicio.year,
          inicio.month,
          inicio.day + 3,
          19,
        );
        await _elegirFecha(tester, abierto.fechaInicio!, fechaNueva);
        await _tocar(tester, _accion('19:00'));
        final previa = _vistaPrevia(tester);
        expect(
          previa.id,
          abierto.id,
          reason: 'La vista previa conserva el ID editado.',
        );
        expect(
          previa.titulo,
          tituloNuevo,
          reason: 'Vista previa del título nuevo.',
        );
        expect(
          previa.ubicacion,
          'Coliseo editado E2E',
          reason: 'Vista previa del lugar nuevo.',
        );
        expect(
          previa.disciplina,
          'Básquetbol',
          reason: 'Vista previa del deporte nuevo.',
        );
        expect(
          previa.fechaInicio,
          fechaNueva,
          reason: 'Vista previa de fecha y hora nuevas.',
        );
        expect(previa.cuposTotales, 5, reason: 'Vista previa de cinco cupos.');
        expect(
          previa.cuposOcupados,
          3,
          reason: 'La edición conserva los ocupados.',
        );
        await _guardarConCarga(tester);

        debugPrint('Editar E2E · 8/9: resultado y persistencia');
        await _esperar(tester, find.text('Partido "$tituloNuevo" actualizado'));
        await _comprobarTarjeta(
          tester,
          abierto.id,
          tituloNuevo,
          'Coliseo editado E2E',
          'Básquetbol',
          fechaNueva,
          5,
          3,
          EstadoPartido.cuposAbiertos,
        );
        final fila = await _fila(clienteDatos, abierto.id);
        for (final entrada in {
          'id': abierto.id,
          'titulo': tituloNuevo,
          'ubicacion': 'Coliseo editado E2E',
          'disciplina': 'Básquetbol',
          'cupos_totales': 5,
          'cupos_ocupados': 3,
          'estado': 'cuposAbiertos',
        }.entries) {
          expect(
            fila[entrada.key],
            entrada.value,
            reason: 'Debe persistir ${entrada.key}.',
          );
        }
        expect(
          fila['organizador_id'] == uid,
          isTrue,
          reason: 'No debe cambiar el propietario.',
        );
        expect(
          fila['organizador_nombre'],
          original['organizador_nombre'],
          reason: 'No debe cambiar el nombre del organizador.',
        );
        expect(
          DateTime.parse(fila['fecha_inicio'] as String).toLocal(),
          fechaNueva,
          reason: 'Debe persistir la nueva fecha y hora.',
        );
        final filas = await clienteDatos
            .from('partidos')
            .select('id')
            .eq('organizador_id', uid)
            .inFilter('titulo', [tituloOriginal, tituloNuevo, tituloDescartado])
            .timeout(_limite);
        expect(
          filas.length,
          1,
          reason: 'Editar no debe crear filas duplicadas.',
        );
        expect(
          filas.single['id'],
          abierto.id,
          reason: 'La única fila debe conservar el ID.',
        );
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        await _tocar(tester, find.bySemanticsLabel('Mis\nPartidos'));
        await _comprobarTarjeta(
          tester,
          abierto.id,
          tituloNuevo,
          'Coliseo editado E2E',
          'Básquetbol',
          fechaNueva,
          5,
          3,
          EstadoPartido.cuposAbiertos,
        );

        debugPrint('Editar E2E · 9/9: edición de equipo completo');
        await _esperar(tester, _tarjeta(completo.id));
        await _abrirEdicion(tester, completo.id);
        await _precarga(tester, completo);
        for (final nombre in ['Aumentar cupos', 'Disminuir cupos']) {
          await _visible(tester, _marco(nombre));
          expect(
            tester
                .getSemantics(_accion(nombre))
                .getSemanticsData()
                .flagsCollection
                .isEnabled
                .toBoolOrNull(),
            isFalse,
            reason: '$nombre debe estar deshabilitado en equipo completo.',
          );
          await tester.tap(_marco(nombre), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 100));
          _cupos(tester, 4);
        }
        await _mensajeVisible(
          tester,
          'El equipo ya está completo: no se pueden cambiar los cupos.',
        );
        await _escribir(tester, 'partido_titulo', tituloCompletoNuevo);
        await _guardarConCarga(tester);
        await _esperar(
          tester,
          find.text('Partido "$tituloCompletoNuevo" actualizado'),
        );
        await _comprobarTarjeta(
          tester,
          completo.id,
          tituloCompletoNuevo,
          completo.ubicacion,
          completo.disciplina,
          completo.fechaInicio!,
          4,
          4,
          EstadoPartido.equipoCompleto,
        );
        final completoGuardado = await _fila(clienteDatos, completo.id);
        expect(completoGuardado, {
          ...originalCompleto,
          'titulo': tituloCompletoNuevo,
        }, reason: 'En equipo completo solo debe cambiar el título.');
        expect(
          clienteApp.auth.currentUser?.id == uid,
          isTrue,
          reason: 'Editar debe conservar la sesión del propietario.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<Map<String, dynamic>> _fila(SupabaseClient c, String id) =>
    c.from('partidos').select().eq('id', id).single().timeout(_limite);
Finder _tarjeta(String id) => find.descendant(
  of: find.byType(VistaMisPartidos),
  matching: find.byWidgetPredicate(
    (w) => w is TarjetaPartido && w.partido.id == id,
    description: 'tarjeta del partido esperado por ID',
  ),
);
Future<void> _abrirEdicion(WidgetTester tester, String id) async {
  final boton = find.descendant(
    of: _tarjeta(id),
    matching: find.widgetWithText(OutlinedButton, 'Editar'),
  );
  await _visible(tester, boton);
  final accesible = find.descendant(
    of: _tarjeta(id),
    matching: find.bySemanticsLabel('Editar'),
  );
  _botonAccesible(tester, accesible, 'Editar');
  _areaTactil(tester, boton, 'Editar');
  await _tocar(tester, accesible);
  await _esperar(tester, find.byType(VistaCrearPartido));
}

Future<void> _precarga(WidgetTester tester, ModeloPartido esperado) async {
  expect(
    find.text('Editar partido'),
    findsOneWidget,
    reason: 'Debe abrirse en modo edición.',
  );
  for (final entrada in {
    'partido_titulo': esperado.titulo,
    'partido_ubicacion': esperado.ubicacion,
  }.entries) {
    expect(
      tester
          .widget<TextFormField>(find.byKey(Key(entrada.key)))
          .controller!
          .text,
      entrada.value,
      reason: 'Debe precargar ${entrada.key}.',
    );
  }
  await _visible(tester, _marco(esperado.disciplina));
  expect(
    _datos(
      tester,
      esperado.disciplina,
    ).flagsCollection.isSelected.toBoolOrNull(),
    isTrue,
    reason: 'Debe precargar el deporte seleccionado.',
  );
  final previa = _vistaPrevia(tester);
  expect(
    previa.fechaInicio,
    esperado.fechaInicio,
    reason: 'Debe conservar la fecha y hora originales.',
  );
  for (final nombre in ['Fecha del partido', 'Hora del partido']) {
    await _visible(tester, _marco(nombre));
    final valor = _datos(tester, nombre).value;
    expect(
      valor,
      nombre == 'Fecha del partido'
          ? esperado.fechaHora.split(' · ').first
          : esperado.fechaHora.split(' · ').last,
      reason: 'El selector debe anunciar su valor precargado.',
    );
  }
  _cupos(tester, esperado.cuposTotales);
}

void _cupos(WidgetTester tester, int esperado) {
  expect(
    tester
        .widget<Semantics>(find.byKey(const Key('partido_cupos_valor')))
        .properties
        .value,
    '$esperado',
    reason: 'Debe actualizar el total accesible de cupos.',
  );
  expect(
    _vistaPrevia(tester).cuposTotales,
    esperado,
    reason: 'La vista previa debe coincidir con los cupos elegidos.',
  );
}

Future<void> _elegirFecha(
  WidgetTester tester,
  DateTime original,
  DateTime nueva,
) async {
  await _tocar(tester, _accion('Fecha del partido'));
  await _esperar(tester, find.byType(DatePickerDialog));
  final local = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  );
  final meses =
      (nueva.year - original.year) * 12 + nueva.month - original.month;
  for (var i = 0; i < meses; i++) {
    await _tocar(tester, find.byTooltip(local.nextMonthTooltip));
  }
  await _tocar(
    tester,
    find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.bySemanticsLabel(
        '${local.formatDecimal(nueva.day)}, ${local.formatFullDate(nueva)}',
      ),
    ),
  );
  await _tocar(tester, find.text(local.okButtonLabel));
  await _esperar(tester, find.byType(VistaCrearPartido));
}

Future<void> _guardarConCarga(WidgetTester tester) async {
  await _visible(tester, _guardar());
  await tester.tap(find.bySemanticsLabel('Guardar cambios'));
  await tester.pump();
  expect(
    find.byType(VistaCrearPartido),
    findsOneWidget,
    reason: 'El formulario debe esperar a Supabase.',
  );
  expect(
    tester.widget<BotonAccion>(find.byKey(const Key('partido_guardar'))).estado,
    EstadoBoton.cargando,
    reason: 'Debe activar la carga al enviar.',
  );
  expect(
    find.descendant(
      of: _guardar(),
      matching: find.byType(CircularProgressIndicator),
    ),
    findsOneWidget,
    reason: 'Debe mostrar indicador durante el guardado.',
  );
  expect(
    tester.widget<ElevatedButton>(_guardar()).onPressed,
    isNull,
    reason: 'Debe impedir el doble envío.',
  );
  expect(
    _datos(tester, 'Guardando partido').value,
    'Cargando',
    reason: 'Debe describir la carga de forma accesible.',
  );
  for (final key in ['partido_titulo', 'partido_ubicacion']) {
    expect(
      tester.widget<TextFormField>(find.byKey(Key(key))).enabled,
      isFalse,
      reason: 'Los campos deben bloquearse durante el guardado.',
    );
  }
  for (final nombre in [
    'Básquetbol',
    'Fecha del partido',
    'Hora del partido',
    'Aumentar cupos',
    'Disminuir cupos',
  ]) {
    expect(
      tester.widget<Semantics>(_marco(nombre)).properties.enabled,
      isFalse,
      reason: '$nombre debe bloquearse durante el guardado.',
    );
  }
  expect(
    tester
        .widget<PopScope>(
          find.descendant(
            of: find.byType(VistaCrearPartido),
            matching: find.byWidgetPredicate((w) => w is PopScope),
          ),
        )
        .canPop,
    isFalse,
    reason: 'Atrás debe bloquearse durante el guardado.',
  );
  await _esperar(tester, find.byType(VistaMisPartidos));
}

Future<void> _comprobarTarjeta(
  WidgetTester tester,
  String id,
  String titulo,
  String lugar,
  String deporte,
  DateTime fecha,
  int total,
  int ocupados,
  EstadoPartido estado,
) async {
  await _esperar(tester, _tarjeta(id));
  final texto = find.descendant(of: _tarjeta(id), matching: find.text(titulo));
  await _visible(tester, texto);
  expect(
    texto.hitTestable(),
    findsOneWidget,
    reason: 'El título actualizado debe verse.',
  );
  final p = tester.widget<TarjetaPartido>(_tarjeta(id)).partido;
  expect(
    p.ubicacion,
    lugar,
    reason: 'La tarjeta debe mostrar el lugar guardado.',
  );
  expect(
    p.disciplina,
    deporte,
    reason: 'La tarjeta debe mostrar el deporte guardado.',
  );
  expect(
    p.fechaInicio,
    fecha,
    reason: 'La tarjeta debe mostrar fecha y hora guardadas.',
  );
  expect(
    p.cuposTotales,
    total,
    reason: 'La tarjeta debe mostrar los cupos totales guardados.',
  );
  expect(
    p.cuposOcupados,
    ocupados,
    reason: 'La tarjeta debe conservar los cupos ocupados.',
  );
  expect(
    p.estado,
    estado,
    reason: 'La tarjeta debe mostrar el estado esperado.',
  );
  expect(
    p.soyOrganizador,
    isTrue,
    reason: 'La tarjeta conserva el rol de organizador.',
  );
}

Finder _guardar() => find.descendant(
  of: find.byKey(const Key('partido_guardar')),
  matching: find.byType(ElevatedButton),
);
Finder _marco(String nombre) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == nombre,
  description: 'control accesible $nombre',
);
Finder _accion(String nombre) => find.descendant(
  of: _marco(nombre),
  matching: find.bySemanticsLabel(nombre),
  matchRoot: true,
);
SemanticsData _datos(WidgetTester tester, String nombre) =>
    tester.getSemantics(_accion(nombre)).getSemanticsData();
ModeloPartido _vistaPrevia(WidgetTester tester) => tester
    .widget<TarjetaPartido>(
      find.descendant(
        of: find.byType(VistaCrearPartido),
        matching: find.byType(TarjetaPartido),
      ),
    )
    .partido;

void _botonAccesible(WidgetTester tester, Finder control, String nombre) {
  expect(
    control,
    findsOneWidget,
    reason: '$nombre debe tener nombre accesible único.',
  );
  expect(
    tester.getSemantics(control).getSemanticsData().flagsCollection.isButton,
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

Future<void> _mensajeVisible(WidgetTester tester, String mensaje) async {
  await _visible(tester, find.text(mensaje));
  expect(
    find.text(mensaje).hitTestable(),
    findsOneWidget,
    reason: 'Debe verse el mensaje de validación.',
  );
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
    if (objetivo.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(objetivo, findsOneWidget, reason: motivo);
  await tester.pump(const Duration(milliseconds: 300));
}
