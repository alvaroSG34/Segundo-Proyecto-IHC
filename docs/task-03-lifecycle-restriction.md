# Tarea 3 · Ciclo del elemento y restricción de estado

**Proyecto:** UniSport · **Elemento:** Partido · **Fecha:** 7 de octubre de 2026

---

## 1. Funcionalidades implementadas

### A. Editar datos del partido
* **Ubicación:** Botón de edición (ícono de lápiz) en la tarjeta del partido para el organizador.
* **Comportamiento:** Abre el formulario pre-cargado con los datos del partido (`VistaCrearPartido`), permitiendo modificar título, deporte, ubicación, fecha/hora y cupos totales.
* **Consistencia:** No permite reducir los cupos totales por debajo de los jugadores que ya están inscritos.
* **Persistencia:** Al guardar los cambios, se actualiza en memoria y se guarda en la base de datos compartida (Supabase).

### B. Eliminar el partido solicitando confirmación
* **Ubicación:** Botón de eliminar (ícono de papelera) en la tarjeta del partido para el organizador.
* **Comportamiento:** Abre un cuadro de diálogo modal (`AlertDialog`) solicitando confirmación explícita (*"¿Estás seguro de que deseas eliminar [Título]? Esta acción no se puede deshacer"*).
* **Persistencia:** Si se confirma, el partido se remueve de la lista del usuario y se elimina de la base de datos compartida (Supabase).

### C. Restricción según su estado: "Un equipo completo no permite agregar más jugadores"
* **Regla de negocio:** Un partido en estado `Equipo completo` (o con todos sus cupos ocupados) bloquea la incorporación de nuevos jugadores.
* **Explicación clara en la UI:**
  * Cuando la acción está bloqueada, la interfaz muestra un aviso visible:
    > **No puedes unirte:** Convocatoria cerrada: el equipo ya está completo.
  * Si el equipo aún tiene cupos abiertos, se muestra el botón interactivo **"Unirme al equipo"** que suma un jugador y actualiza la barra de progreso.
* **Ocupación de cupos:** solo una inscripción real mediante **"Unirme al equipo"** ocupa un cupo. Al registrarse el último jugador, el partido pasa a *Equipo completo*; la tarjeta del organizador muestra las inscripciones asociadas.
* **Restricción:** si el partido está completo, una nueva inscripción se rechaza con un motivo claro. No hay acciones para agregar jugadores sin cuenta ni cerrar manualmente la convocatoria.
* **Arquitectura:** la validación de unión está protegida en [`lib/modelos/modelo_partido.dart`](../lib/modelos/modelo_partido.dart) y en el RPC `unirse_a_partido`.

### D. Base de datos compartida (Supabase)
* **Tecnología:** Supabase (PostgreSQL en la nube). Todos los dispositivos usan la misma base: lo que se crea, edita o elimina en un teléfono se ve en los demás.
* **Tablas:** `perfiles`, `partidos` e `inscripciones`; las cuentas y contraseñas (cifradas) las maneja Supabase Auth.
* **Reglas en el servidor:** editar y unirse se ejecutan como funciones SQL que validan las mismas reglas del modelo y bloquean la fila del partido, así dos teléfonos no pueden ocupar el mismo cupo al mismo tiempo.
* **Seguridad (RLS):** solo el organizador puede crear como suyo, editar o eliminar su partido.
* **Código:** [`lib/servicios/repositorio_supabase.dart`](../lib/servicios/repositorio_supabase.dart) y [`supabase/esquema.sql`](../supabase/esquema.sql).
* **Guía de configuración y verificación:** [`docs/base-de-datos-supabase.md`](base-de-datos-supabase.md).

---

## 2. Pruebas unitarias

Archivo: [`test/restriccion_partido_test.dart`](../test/restriccion_partido_test.dart)

### Comando para ejecutar

```bash
flutter test test/restriccion_partido_test.dart
```

Pruebas de la edición (regla de cupos y fecha conservada):

```bash
flutter test test/edicion_partido_test.dart
```

Prueba contra la base de datos real de Supabase (dos dispositivos):

```bash
flutter test test/supabase_integracion_test.dart --dart-define=PRUEBAS_SUPABASE=true
```

Pruebas de interfaz de unión y rechazo:

```bash
flutter test test/tarjeta_partido_test.dart
```

Para correr todas las pruebas del proyecto:

```bash
flutter test
```

### Casos de prueba incluidos (5)

1. Un partido con cupos abiertos permite inscribirse e incrementa `cuposOcupados`.
2. Restricción: un partido en estado `Equipo completo` tiene `puedeAgregarJugador == false`.
3. La propiedad `motivoBloqueoAgregarJugador` explica con precisión el motivo del bloqueo.
4. Intentar inscribirse en un partido completo lanza `StateError` impidiendo la mutación inválida.
5. Al llenar el último cupo disponible, la transición a `Equipo completo` se efectúa automáticamente y bloquea nuevas adhesiones.

---

## 3. Archivos modificados y creados

| Archivo | Rol |
| :--- | :--- |
| `lib/modelos/modelo_partido.dart` | Inmutabilidad (`copyWith`) y reglas de inscripción y cupos |
| `lib/vistas/vista_crear_partido.dart` | Soporte para modo edición (`partidoAEditar`) y validación de cupos mínimos |
| `lib/vistas/vista_mis_partidos.dart` | Flujos de edición, diálogo modal de confirmación de eliminación y acción de unirse |
| `lib/widgets/tarjeta_partido.dart` | Botones de edición/eliminación para organizador y flujo de inscripción |
| `lib/servicios/repositorio_supabase.dart` | Operaciones sobre la base de datos compartida (Supabase) |
| `supabase/esquema.sql` | Tablas, seguridad (RLS) y reglas de negocio en el servidor |
| `test/edicion_partido_test.dart` | Regla de cupos al editar y fecha conservada |
| `test/tarjeta_partido_test.dart` | Pruebas de inscripción y ausencia de acciones para ocupar cupos sin inscripción |
| `test/restriccion_partido_test.dart` | 5 pruebas unitarias automatizadas para la restricción de UniSport |
| `docs/task-03-lifecycle-restriction.md` | Este documento de respaldo |
