# Tarea 6 · Pruebas E2E y suplentes en UniSport

## Cambio implementado

Antes de esta tarea, un partido completo rechazaba nuevas inscripciones. Ahora
una persona puede entrar en la lista de suplentes, conocer su turno y cancelar
la espera. Cuando sale un titular, el servidor inscribe al primer suplente sin
dejar el cupo libre para otra persona. El organizador puede ver la lista en
orden. El estado se guarda en Supabase para que lo vean los demás dispositivos.

La implementación está en el modelo del partido, el repositorio, las tarjetas y
la pantalla Explorar. La tabla y las funciones están en
[`supabase/esquema.sql`](../supabase/esquema.sql). Se añadió un archivo de pruebas
separado, [`test/flujo_suplentes_test.dart`](../test/flujo_suplentes_test.dart),
porque permite presentar el nuevo flujo sin mezclarlo con las pruebas anteriores.

## Matriz antes y después

La columna «Antes» describe el comportamiento del commit base `2af6229`.
La misma suite se ejecutó en una copia temporal de ese commit y luego en el
proyecto con la feature implementada.

| Situación | Antes de la feature | Después de la feature | Comprobación |
| --- | --- | --- | --- |
| Equipo con cupos | El estudiante se une como titular | Se conserva el mismo comportamiento | `test/union_partido_test.dart` |
| Equipo completo | Se rechaza otra inscripción | Se ofrece entrar como suplente; no aumenta `cupos_ocupados` | `test/flujo_suplentes_test.dart`, `test/tarjeta_partido_test.dart` |
| Dos suplentes | No existía una lista | Cada uno recibe un turno en orden de llegada | `test/flujo_suplentes_test.dart` |
| Sale un titular | Queda un cupo libre | Entra el primer suplente y el segundo avanza | `test/flujo_suplentes_test.dart` |
| Un suplente cancela | No aplicaba | Sale de la lista; el siguiente avanza sin ocupar un cupo | `test/flujo_suplentes_test.dart` |
| No hay suplentes | Queda un cupo libre | Se conserva el comportamiento anterior | `test/flujo_suplentes_test.dart` |
| Interfaz del suplente | Solo se veía el rechazo por equipo completo | Se muestra el turno y la acción de cancelar | `test/tarjeta_partido_test.dart` |
| Accesibilidad de la acción | No había botón | Botón con texto y área táctil de al menos 48 px | `test/tarjeta_partido_test.dart` |
| Flujo principal de crear partido | Crear → Mis partidos | Se conserva | `integration_test/crear_partido_test.dart` (aprobada en emulador Android) |
| Flujo E2E de suplentes | No existía | Organizador crea, titular llena, suplente espera y es promovido al salir el titular | `integration_test/flujo_suplentes_test.dart` (aprobada en emulador Android) |

## Verificación local

Desde la raíz del proyecto:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Antes (`2af6229`): **102 pruebas aprobadas y 1 omitida**. Después: **108 pruebas
aprobadas y 1 omitida**. Se agregaron tres pruebas del flujo de suplentes y tres
de la interfaz. El análisis terminó sin problemas. La prueba omitida usa la base real de Supabase y requiere
internet y una base preparada. Además, el 03/11/2026 se ejecutaron en el emulador
Android las pruebas E2E de Crear partido y de suplentes: **2 aprobadas**.

## Demostración con la base real

1. Ejecutar de nuevo `supabase/esquema.sql` en el **SQL Editor** del proyecto
   Supabase. El script usa `create table if not exists` y conserva los datos.
2. Abrir UniSport con `flutter run -d chrome` y usar cuentas distintas para
   organizador, titular y dos suplentes.
3. Crear un partido de dos cupos. El titular ocupa el último cupo. Los otros
   dos entran como suplentes y ven los turnos 1 y 2.
4. El titular sale. Al actualizar la pantalla, el primer suplente figura como
   inscrito y el segundo aparece en el turno 1. El organizador puede ver la
   misma lista.

## Estado de la prueba con Supabase

El script se ejecutó en el SQL Editor y Supabase mostró `Success. No rows
returned`. La prueba manual en el partido «futsal» del 30/11/2026 comprobó
que `pedro1` entró como suplente en el turno 1. Antes de la salida, la lista de
inscritos incluía a `pedro`; después incluía a `pedro1`. La cuenta de `pedro1`
pasó a mostrar «Ya formas parte de este equipo» y la opción «Salir del
partido». El total permaneció en 5/5. Con esto se verificó la promoción del
primer suplente con la base real.

Las capturas no muestran un segundo suplente, así que el avance del turno 2 al
turno 1 queda cubierto por `test/flujo_suplentes_test.dart`, no por la prueba
manual. Se añadió `integration_test/flujo_suplentes_test.dart` para automatizar
el recorrido con tres cuentas y la base real. El 03/11/2026 se ejecutó en
`emulator-5554` con el resultado `All tests passed!` (1 prueba aprobada). La
prueba creó un partido temporal, verificó que el suplente permanecía en turno
1 sin ocupar cupo, que pasó a inscrito al salir el titular y que el equipo
seguía en 2/2. Al terminar, eliminó el partido de esa ejecución. Las
credenciales se pasaron al comando y no se guardaron en el repositorio.

La prueba E2E `integration_test/crear_partido_test.dart` también terminó con
`All tests passed!` (1 prueba aprobada): creó un partido y comprobó que aparece
en Mis partidos al volver a consultar Supabase. Limpió el partido temporal al
terminar.
