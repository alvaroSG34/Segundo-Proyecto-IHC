import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisport/main.dart' as app;
import 'package:unisport/modelos/filtro_partidos.dart';
import 'package:unisport/modelos/modelo_partido.dart';
import 'package:unisport/tema/caja_mensaje.dart';
import 'package:unisport/vistas/partidos/vista_crear_partido.dart';
import 'package:unisport/vistas/inicio/vista_inicio_publico.dart';
import 'package:unisport/vistas/autenticacion/vista_login.dart';
import 'package:unisport/vistas/partidos/vista_mis_partidos.dart';
import 'package:unisport/vistas/inicio/vista_principal.dart';
import 'package:unisport/widgets/boton_accion.dart';
import 'package:unisport/widgets/tarjeta_partido.dart';

const _correo = String.fromEnvironment('E2E_CORREO');
const _clave = String.fromEnvironment('E2E_CLAVE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Crear partido: alternativos, accesibilidad, guardado y persistencia',
    (tester) async {
      expect(
        _correo.trim().contains('@') && _clave.trim().length >= 6,
        isTrue,
        reason: 'Indica E2E_CORREO y E2E_CLAVE mediante --dart-define con una cuenta existente.',
      );
      final marca = DateTime.now().microsecondsSinceEpoch;
      final titulo = 'E2E Crear partido $marca';
      final cancelado = 'E2E Cancelar partido $marca';
      final ubicacion = 'Cancha E2E $marca';
      final semantica = tester.ensureSemantics();
      try {
        // 1. Sesión real y limpieza registrada antes de cualquier escritura.
        debugPrint('Crear E2E · 1/10: Preparación');
        app.main();
        await _esperar(
          tester,
          find.byWidgetPredicate(
            (w) => w is VistaInicioPublico || w is VistaPrincipal,
          ),
        );
        final cliente = Supabase.instance.client;
        addTearDown(() async {
          await cliente.auth.signOut().timeout(const Duration(seconds: 45));
        });
        if (find.byType(VistaPrincipal).evaluate().isNotEmpty) {
          await _tocar(tester, find.text('CERRAR SESIÓN'));
          await _esperar(tester, find.byType(VistaInicioPublico));
        }
        await _tocar(
          tester,
          find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
        );
        await _esperar(tester, find.byType(VistaLogin));
        await _escribir(tester, 'login_correo', _correo.trim());
        await _escribir(tester, 'login_clave', _clave);
        await _visible(tester, find.byKey(const Key('login_enviar')));
        await _tocar(tester, find.bySemanticsLabel('Entrar a UniSport'));
        await _esperar(tester, find.byType(VistaPrincipal));
        final usuarioId = cliente.auth.currentUser!.id;
        // addTearDown se ejecuta en orden inverso: borrar antes de cerrar sesión.
        addTearDown(() async {
          await cliente
              .from('partidos')
              .delete()
              .eq('organizador_id', usuarioId)
              .inFilter('titulo', [titulo, cancelado])
              .timeout(const Duration(seconds: 45));
        });

        // 2. Acceso al formulario: no contar el llenado ni los alternativos.
        debugPrint('Crear E2E · 2/10: Acceso en un toque');
        final crear = find.widgetWithText(ElevatedButton, 'Crear\nPartido');
        await _visible(tester, crear);
        _botonAccesible(
          tester,
          find.bySemanticsLabel('Crear\nPartido'),
          'Crear partido',
        );
        _areaTactil(tester, crear, 'Crear partido');
        var toquesDeAcceso = 0;
        Future<void> tocarParaAcceder(Finder control) async {
          await _tocar(tester, control);
          toquesDeAcceso++;
        }

        await tocarParaAcceder(find.bySemanticsLabel('Crear\nPartido'));
        await _esperar(tester, find.byType(VistaCrearPartido));
        expect(toquesDeAcceso, 1, reason: 'Crear debe abrirse en un toque.');
        expect(
          toquesDeAcceso,
          lessThanOrEqualTo(3),
          reason: 'El acceso debe respetar tres toques.',
        );

        // 3. Árbol semántico y áreas táctiles de todos los controles del formulario.
        debugPrint('Crear E2E · 3/10: Accesibilidad y áreas táctiles');
        for (final nombre in ['Título del partido', 'Ubicación del partido']) {
          final marco = _marco(nombre);
          await _visible(tester, marco);
          final datos = tester.getSemantics(marco).getSemanticsData();
          expect(
            datos.label.startsWith(nombre),
            isTrue,
            reason: '$nombre debe tener nombre accesible.',
          );
          expect(
            datos.flagsCollection.isTextField,
            isTrue,
            reason: '$nombre debe tener rol de campo de texto.',
          );
        }
        for (final nombre in [
          ...ModeloPartido.disciplinas,
          ...FiltroPartidos.lugaresSugeridos,
          'Fecha del partido',
          'Hora del partido',
          'Hoy',
          'Mañana',
          'Sábado',
          '08:00',
          '16:00',
          '19:00',
          'Disminuir cupos',
          'Aumentar cupos',
        ]) {
          await _visible(tester, _marco(nombre));
          _botonAccesible(tester, _accion(nombre), nombre);
          _areaTactil(tester, _marco(nombre), nombre);
          if (ModeloPartido.disciplinas.contains(nombre) ||
              FiltroPartidos.lugaresSugeridos.contains(nombre) ||
              [
                'Hoy',
                'Mañana',
                'Sábado',
                '08:00',
                '16:00',
                '19:00',
              ].contains(nombre)) {
            expect(
              _datos(tester, nombre).flagsCollection.isSelected.toBoolOrNull(),
              nombre == 'Futsal',
              reason: '$nombre debe anunciar su selección inicial.',
            );
          }
        }
        await _visible(tester, _guardar());
        _botonAccesible(
          tester,
          find.bySemanticsLabel('Guardar partido'),
          'Guardar partido',
        );
        _areaTactil(tester, _guardar(), 'Guardar partido');

        // 4. Campos vacíos: cuatro errores sin abandonar el formulario.
        debugPrint('Crear E2E · 4/10: Formulario vacío');
        await _tocar(tester, find.bySemanticsLabel('Guardar partido'));
        for (final error in [
          'Escribe un título',
          'Escribe el lugar del partido',
          'Elige una fecha',
          'Elige una hora',
        ]) {
          await _mensajeVisible(tester, error);
        }
        _sinConfirmacion();

        // 5. Título corto y ubicación corregida, aún sin fecha y hora.
        debugPrint('Crear E2E · 5/10: Título inválido');
        await _escribir(tester, 'partido_titulo', 'AB');
        await _escribir(tester, 'partido_ubicacion', ubicacion);
        await _visible(tester, _guardar());
        await _tocar(tester, find.bySemanticsLabel('Guardar partido'));
        await _mensajeVisible(tester, 'Debe tener al menos 3 caracteres');
        expect(
          find.text('Escribe el lugar del partido'),
          findsNothing,
          reason: 'La ubicación corregida no debe conservar el error.',
        );
        for (final error in ['Elige una fecha', 'Elige una hora']) {
          await _mensajeVisible(tester, error);
        }
        _sinConfirmacion();

        // 6. Cancelar no debe persistir la vista previa ni el formulario.
        debugPrint('Crear E2E · 6/10: Cancelación');
        await _escribir(tester, 'partido_titulo', cancelado);
        await tester.pageBack();
        await _esperar(tester, find.byType(VistaPrincipal));
        final filasCanceladas = await cliente
            .from('partidos')
            .select('id')
            .eq('organizador_id', usuarioId)
            .eq('titulo', cancelado)
            .timeout(const Duration(seconds: 45));
        expect(
          filasCanceladas.isEmpty,
          isTrue,
          reason: 'Cancelar no debe crear un partido.',
        );

        // 7. La selección modifica la vista previa; usar una fecha futura.
        debugPrint('Crear E2E · 7/10: Datos válidos y vista previa');
        await _tocar(tester, crear);
        await _esperar(tester, find.byType(VistaCrearPartido));
        await _escribir(tester, 'partido_titulo', titulo);
        await _escribir(tester, 'partido_ubicacion', ubicacion);
        for (final disciplina in ['Básquetbol', 'Futsal']) {
          await _visible(tester, _marco(disciplina));
          await _tocar(tester, _accion(disciplina));
          expect(
            _datos(
              tester,
              disciplina,
            ).flagsCollection.isSelected.toBoolOrNull(),
            isTrue,
            reason: 'La disciplina elegida debe anunciarse seleccionada.',
          );
          expect(
            _vistaPrevia(tester).disciplina,
            disciplina,
            reason: 'La vista previa debe reflejar la disciplina.',
          );
        }
        expect(
          _datos(
            tester,
            'Básquetbol',
          ).flagsCollection.isSelected.toBoolOrNull(),
          isFalse,
          reason: 'Solo debe quedar seleccionada Futsal.',
        );
        final ahora = DateTime.now();
        final fechaEsperada = DateTime(
          ahora.year,
          ahora.month,
          ahora.day + 1,
          19,
        );
        for (final atajo in ['Mañana', '19:00']) {
          await _visible(tester, _marco(atajo));
          await _tocar(tester, _accion(atajo));
          expect(
            _datos(tester, atajo).flagsCollection.isSelected.toBoolOrNull(),
            isTrue,
            reason: 'El atajo elegido debe anunciarse seleccionado.',
          );
        }
        for (final cambio in [
          ('Aumentar cupos', 11),
          ('Disminuir cupos', 10),
        ]) {
          await _visible(tester, _marco(cambio.$1));
          await _tocar(tester, _accion(cambio.$1));
          expect(
            tester
                .getSemantics(find.byKey(const Key('partido_cupos_valor')))
                .getSemanticsData()
                .value,
            '${cambio.$2}',
            reason: 'Debe anunciarse el total de cupos.',
          );
          expect(
            _vistaPrevia(tester).cuposTotales,
            cambio.$2,
            reason: 'Los cupos de la vista previa deben actualizarse.',
          );
        }
        final previa = _vistaPrevia(tester);
        expect(
          previa.titulo,
          titulo,
          reason: 'La vista previa debe reflejar el título.',
        );
        expect(
          previa.ubicacion,
          ubicacion,
          reason: 'La vista previa debe reflejar el lugar.',
        );
        expect(
          previa.fechaInicio,
          fechaEsperada,
          reason: 'Debe reflejar mañana a las 19:00.',
        );
        expect(
          previa.cuposOcupados,
          1,
          reason: 'El organizador debe ocupar un cupo.',
        );

        // 8. El formulario debe esperar al servidor, con controles deshabilitados.
        debugPrint('Crear E2E · 8/10: Guardado real y carga');
        await _visible(tester, _guardar());
        await tester.tap(find.bySemanticsLabel('Guardar partido'));
        await tester.pump();
        expect(
          find.byType(VistaCrearPartido),
          findsOneWidget,
          reason: 'El formulario debe permanecer abierto mientras guarda.',
        );
        expect(
          tester
              .widget<BotonAccion>(find.byKey(const Key('partido_guardar')))
              .estado,
          EstadoBoton.cargando,
          reason: 'El envío debe mostrar carga.',
        );
        expect(
          find.descendant(
            of: _guardar(),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason: 'El guardado debe mostrar un indicador.',
        );
        expect(
          tester.widget<ElevatedButton>(_guardar()).onPressed == null,
          isTrue,
          reason: 'No debe poder enviarse dos veces durante el guardado.',
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Guardando partido'))
              .getSemanticsData()
              .value,
          'Cargando',
          reason: 'La carga debe tener nombre y descripción accesibles.',
        );
        for (final key in ['partido_titulo', 'partido_ubicacion']) {
          expect(
            tester.widget<TextFormField>(find.byKey(Key(key))).enabled,
            isFalse,
            reason: 'El campo $key debe deshabilitarse mientras guarda.',
          );
        }
        for (final nombre in [
          'Fecha del partido',
          'Hora del partido',
          'Futsal',
          'Mañana',
          'Aumentar cupos',
          'Disminuir cupos',
        ]) {
          expect(
            tester.widget<Semantics>(_marco(nombre)).properties.enabled,
            isFalse,
            reason: '$nombre debe deshabilitarse mientras guarda.',
          );
        }
        final bloqueoAtras = find.descendant(
          of: find.byType(VistaCrearPartido),
          matching: find.byWidgetPredicate((w) => w is PopScope),
        );
        expect(
          tester.widget<PopScope>(bloqueoAtras).canPop,
          isFalse,
          reason: 'Atrás debe bloquearse durante el guardado.',
        );
        await _esperar(tester, find.byType(VistaPrincipal));
        await _esperar(
          tester,
          find.text('Partido creado y guardado correctamente.'),
        );

        // 9. Dos consultas independientes desde Mis partidos deben recuperarlo.
        debugPrint('Crear E2E · 9/10: Persistencia al volver');
        for (var lectura = 0; lectura < 2; lectura++) {
          await _tocar(
            tester,
            find.widgetWithText(ElevatedButton, 'Mis\nPartidos'),
          );
          await _comprobarPartido(tester, titulo, ubicacion, fechaEsperada);
          if (lectura == 0) {
            await tester.pageBack();
            await _esperar(tester, find.byType(VistaPrincipal));
          }
        }

        // 10. La escritura única debe coincidir con lo mostrado por la interfaz.
        debugPrint('Crear E2E · 10/10: Unicidad en Supabase');
        final filas = await cliente
            .from('partidos')
            .select()
            .eq('organizador_id', usuarioId)
            .eq('titulo', titulo)
            .timeout(const Duration(seconds: 45));
        expect(
          filas.length,
          1,
          reason: 'Debe persistir exactamente un partido de esta ejecución.',
        );
        final fila = filas.single;
        for (final entrada in {
          'titulo': titulo,
          'ubicacion': ubicacion,
          'disciplina': 'Futsal',
          'cupos_totales': 10,
          'cupos_ocupados': 1,
          'estado': 'cuposAbiertos',
        }.entries) {
          expect(
            fila[entrada.key],
            entrada.value,
            reason: 'Debe persistir ${entrada.key}.',
          );
        }
        expect(
          DateTime.parse(fila['fecha_inicio'] as String).toLocal(),
          fechaEsperada,
          reason: 'La fecha persistida debe coincidir con el formulario.',
        );
        expect(
          fila['organizador_id'] == usuarioId,
          isTrue,
          reason: 'El partido debe pertenecer a la cuenta autenticada.',
        );
      } finally {
        semantica.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
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

void _sinConfirmacion() {
  expect(
    find.byType(VistaCrearPartido),
    findsOneWidget,
    reason: 'Los errores deben conservar el formulario.',
  );
  expect(
    find.text('Partido creado y guardado correctamente.'),
    findsNothing,
    reason: 'La validación fallida no debe confirmar creación.',
  );
}

Future<void> _comprobarPartido(
  WidgetTester tester,
  String titulo,
  String ubicacion,
  DateTime fecha,
) async {
  await _esperar(tester, find.byType(VistaMisPartidos));
  final tarjeta = find.descendant(
    of: find.byType(VistaMisPartidos),
    matching: find.byWidgetPredicate(
      (w) => w is TarjetaPartido && w.partido.titulo == titulo,
    ),
  );
  await _esperar(
    tester,
    tarjeta,
    motivo: 'El partido guardado debe aparecer en Mis partidos.',
  );
  final texto = find.descendant(of: tarjeta, matching: find.text(titulo));
  await _visible(tester, texto);
  expect(
    texto.hitTestable(),
    findsOneWidget,
    reason: 'El título debe ser visible.',
  );
  expect(
    find.descendant(of: tarjeta, matching: find.text(ubicacion)),
    findsOneWidget,
  );
  final p = tester.widget<TarjetaPartido>(tarjeta).partido;
  expect(p.disciplina, 'Futsal');
  expect(p.fechaInicio, fecha);
  expect(p.cuposTotales, 10);
  expect(p.cuposOcupados, 1);
  expect(p.soyOrganizador, isTrue);
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
