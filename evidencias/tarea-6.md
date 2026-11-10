# Tarea 6 · Pruebas E2E de todos los flujos de UniSport

Este documento reúne los 15 flujos originales y el flujo adicional de suplentes.
La matriz y las instrucciones originales se recuperaron del commit `70cbca6`,
porque la integración de la feature dejó únicamente la documentación de suplentes.

Los resultados E2E de las tablas son registros históricos de esas ejecuciones;
no representan una nueva ejecución de los 16 flujos después del merge. En la
revisión local del 03/11/2026, después de corregir la carga de Mis partidos,
`flutter analyze --no-pub` terminó sin incidencias y `flutter test --no-pub`
aprobó **115 pruebas, con 1 omitida**. Esta suite corresponde a `test/`, no a
las E2E de `integration_test/`. Incluye una prueba nueva de carga de suplentes
y recuperación mediante Reintentar. Las E2E con Supabase no se reejecutaron
en esa revisión.

Actualización del 04/11/2026: las acciones «Agregar jugador sin cuenta» y
«Completar equipo» se retiraron del producto. Sus filas siguientes documentan
ejecuciones históricas; ya no corresponden a flujos E2E activos.

## Matriz de los 16 flujos

Una E2E por flujo, con `expect` por criterio. Se verifican flujo principal,
alternativos, accesibilidad por nombre y rol, estados visibles (H1), vacío/error/
permiso según corresponda, áreas táctiles y pasos de acceso. Se excluye regresión
visual (H4). El inventario queda pendiente de contraste con el app map formal.

| N.º | Flujo | Prueba | Cobertura actual | Resultado |
| --- | --- | --- | --- | --- |
| 1 | Registrarse | [registro_test.dart](../integration_test/registro_test.dart) | Éxito y perfil persistido; vacíos, inválidos, duplicado y cancelación; acceso protegido, accesibilidad, carga, áreas ≥48 × 48 y acceso en 1 toque | Aprobada 2 veces consecutivas |
| 2 | Iniciar sesión | [login_test.dart](../integration_test/login_test.dart) | Éxito e identidad; vacíos, inválidos, rechazo y reintento; cancelación, accesos secundarios y ruta protegida; accesibilidad, carga, áreas ≥48 × 48 y acceso en 1 toque | Aprobada 3 veces consecutivas |
| 3 | Solicitar recuperación de contraseña | [recuperar_clave_test.dart](../integration_test/recuperar_clave_test.dart) | Vacío, inválido y cancelación; solicitud genérica sin registrar cuenta y regreso al login; accesibilidad, carga, áreas ≥48 × 48 y acceso en 2 toques | Aprobada 2 veces consecutivas |
| 4 | Cerrar sesión | [cerrar_sesion_test.dart](../integration_test/cerrar_sesion_test.dart) | Desde Mis partidos: cancelar, atrás, confirmar, sesión eliminada y acceso privado bloqueado; accesibilidad, carga, áreas ≥48 × 48 y 3 toques desde menú | Aprobada 2 veces consecutivas |
| 5 | Crear partido | [crear_partido_test.dart](../integration_test/crear_partido_test.dart) | Vacíos, título corto y cancelación sin escritura; selección y vista previa; accesibilidad, áreas ≥48 × 48, acceso en 1 toque y carga bloqueante; persistencia al volver y fila única | Ampliación aprobada 2 veces consecutivas |
| 6 | Consultar y filtrar Mis partidos | [mis_partidos_test.dart](../integration_test/mis_partidos_test.dart) | Dos cuentas reales; acceso protegido, identidad, carga, filtros por rol, IDs y cantidades completos, reapertura; accesibilidad, áreas ≥48 × 48 y acceso en 1 toque. Vacío/error/reintento en 2 widgets | Aprobada 2 veces consecutivas |
| 7 | Editar partido | [editar_partido_test.dart](../integration_test/editar_partido_test.dart) | Precarga, inválidos, cancelación, mínimo ocupado y equipo completo; carga, persistencia, accesibilidad, áreas ≥48 × 48 y acceso en 2 toques. Error/reintento en widgets | Aprobada 2 veces consecutivas |
| 8 | Eliminar partido | [eliminar_partido_test.dart](../integration_test/eliminar_partido_test.dart) | Cancelar conserva datos; confirmar borra en Supabase y no reaparece al reabrir; semántica, áreas ≥48 × 48 y 3 toques | Aprobada 2 veces consecutivas |
| 9 | Explorar, buscar y filtrar partidos | [explorar_partidos_test.dart](../integration_test/explorar_partidos_test.dart) | Búsqueda por nombre, deporte combinado, sin resultados y quitar filtros; IDs/conteos, semántica, áreas ≥48 × 48 y acceso en 1 toque | Aprobada 2 veces consecutivas |
| 10 | Unirse a un partido | [unirse_partido_test.dart](../integration_test/unirse_partido_test.dart) | Cancelar sin inscripción; confirmar 1/6 → 2/6, inscripción única y persistencia como jugador; semántica, áreas ≥48 × 48 y acceso a Explorar en 1 toque | Aprobada 2 veces consecutivas |
| 11 | Salir de un partido | [salir_partido_test.dart](../integration_test/salir_partido_test.dart) | Desde Explorar: unirse al último cupo, cancelar sin cambios y confirmar salida; inscripción eliminada, equipo reabierto, persistencia, semántica y áreas ≥48 × 48 | Aprobada 2 veces consecutivas |
| 12 | Agregar jugador sin cuenta | Retirado | Acción y RPC eliminados del producto el 04/11/2026; los resultados anteriores son históricos | No activo |
| 13 | Completar equipo | Retirado | Acción y RPC eliminados del producto el 04/11/2026; los resultados anteriores son históricos | No activo |
| 15 | Consultar y filtrar historial | [historial_test.dart](../integration_test/historial_test.dart) | Todos y filtros por rol con IDs/conteos completos y orden descendente; restauración, reapertura y datos intactos; semántica, áreas ≥48 × 48 y acceso en 1 toque | Aprobada 2 veces consecutivas |
| 16 | Entrar como suplente y pasar a titular | [flujo_suplentes_test.dart](../integration_test/flujo_suplentes_test.dart) | Tres cuentas reales: partido de 2 cupos, titular ocupa el último, suplente espera en turno 1 sin ocupar cupo y es promovido al salir el titular; persistencia en una sesión nueva y equipo en 2/2. Cancelación y avance del segundo suplente se cubren en `test/` | Aprobada en Android el 03/11/2026, según el registro de la feature |

**Registro histórico:** 16 flujos E2E implementados originalmente: 15 flujos y 1 de suplentes, con aprobaciones individuales registradas. Los flujos 12 y 13 están retirados; no se dispone de una ejecución conjunta posterior al merge. La creación amplía su E2E existente,
sin aumentar el número de flujos cubiertos. La regla de tres toques
se aplica al acceso al formulario o al cierre desde menú, no a la preparación; accesibilidad automática no
sustituye revisión con lector de pantalla.

## Resultados históricos antes y después

Historial de comparaciones en Linux con Supabase real. Cada «antes» corresponde
al estado local inmediatamente previo al cambio indicado.

| Cambio | Verificación | Antes | Después |
| --- | --- | --- | --- |
| Login | Suite de `test/` | 102 aprobadas, 1 omitida | 102 aprobadas, 1 omitida |
| Login | E2E de login | Prueba nueva | 3 ejecuciones consecutivas aprobadas |
| Login | E2E de creación | Aprobada con cuenta E2E | Aprobada con la misma cuenta |
| Login | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Recuperación | Suite de `test/` | 102 aprobadas, 1 omitida | 102 aprobadas, 1 omitida |
| Recuperación | E2E de login | Aprobada con cuenta E2E | Aprobada con la misma cuenta |
| Recuperación | E2E de recuperación | Prueba nueva | 2 ejecuciones consecutivas aprobadas |
| Recuperación | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Cierre | Suite de `test/` | 102 aprobadas, 1 omitida | 102 aprobadas, 1 omitida |
| Cierre | E2E de login | Aprobada con cuenta E2E | Aprobada con la misma cuenta |
| Cierre | E2E de cierre | Prueba nueva | 2 ejecuciones consecutivas aprobadas |
| Cierre | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Creación ampliada | Suite de `test/` | 102 aprobadas, 1 omitida | 104 aprobadas, 1 omitida |
| Creación ampliada | E2E de creación | Recorrido básico aprobado | Ampliación aprobada 2 veces consecutivas |
| Creación ampliada | Guardado pendiente y error/reintento (widgets) | No existían | 2 pruebas nuevas aprobadas; edición existente aprobada |
| Creación ampliada | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Mis partidos | Suite de `test/` | 104 aprobadas, 1 omitida | 106 aprobadas, 1 omitida |
| Mis partidos | E2E de creación | Aprobada | Aprobada con la misma cuenta |
| Mis partidos | E2E de consulta/filtros | Prueba nueva | Aprobada 2 veces consecutivas |
| Mis partidos | Vacío y error/reintento (widgets) | No existían | 2 pruebas nuevas aprobadas |
| Mis partidos | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Edición | Suite de `test/` | 106 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Edición | E2E de creación | Aprobada | Aprobada con la misma cuenta |
| Edición | E2E de edición | Prueba nueva | Aprobada 2 veces consecutivas |
| Edición | Guardado pendiente y error/reintento (widgets) | No existían para edición | 2 pruebas nuevas aprobadas; pruebas de edición anteriores conservadas |
| Edición | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Eliminación | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Eliminación | E2E de eliminación | Prueba nueva | Aprobada 2 veces consecutivas |
| Eliminación | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Explorar | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Explorar | E2E de exploración | Prueba nueva | Aprobada 2 veces consecutivas |
| Explorar | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Unión | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Unión | E2E de unión | Prueba nueva | Aprobada 2 veces consecutivas |
| Unión | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Salida | E2E de salida | Primer intento ejecutado con Supabase real | Falló por una condición de carrera en la espera de la unión; se añadió una primera espera |
| Corrección de salida | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Corrección de salida | E2E de salida | Falló: botón de salida de 40 px en Linux | Aprobada 2 veces consecutivas |
| Corrección de salida | Análisis de archivos modificados | Sin problemas | Sin problemas |
| Agregar jugador | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Agregar jugador | E2E de agregado sin cuenta | Prueba nueva | Aprobada 2 veces consecutivas |
| Agregar jugador | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Completar equipo | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Completar equipo | E2E de completar equipo | Prueba nueva | Aprobada 2 veces consecutivas |
| Completar equipo | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Consultar inscritos | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Consultar inscritos | E2E de consulta | Prueba nueva | Aprobada 2 veces consecutivas |
| Consultar inscritos | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |
| Historial | Suite de `test/` | 108 aprobadas, 1 omitida | 108 aprobadas, 1 omitida |
| Historial | E2E de consulta y filtros | Prueba nueva | Aprobada 2 veces consecutivas |
| Historial | Análisis de archivos modificados | Sin nueva ejecución previa | Sin problemas |

La omitida es la integración de servicios con Supabase, que requiere
`PRUEBAS_SUPABASE=true`. El registro conserva su resultado histórico de dos
ejecuciones aprobadas; no se reejecutó para estos cambios. **No se registró una
ejecución anterior a implementar registro**; las comparaciones posteriores no la sustituyen.

## Ejecución y datos

Requisitos: Flutter, dispositivo o emulador compatible, conexión a internet y
esquema de Supabase aplicado. Las cuentas existentes deben estar habilitadas,
confirmadas y tener perfil completo. Registro requiere confirmación de correo
desactivada. Usar cuentas de prueba sin modificaciones concurrentes.

Ejecutar el archivo indicado en la matriz. Ejemplo para iniciar sesión en Linux,
reemplazando los valores por credenciales válidas:

```bash
flutter test integration_test/login_test.dart -d linux \
  --dart-define=E2E_CORREO=correo-principal \
  '--dart-define=E2E_CLAVE=clave-principal'
```

| Flujos | Parámetros `--dart-define` necesarios |
| --- | --- |
| 1 · Registro | `E2E_CORREO_EXISTENTE` de una cuenta semilla existente |
| 3 · Recuperación | Ninguno; genera un correo único sin registrar |
| 2, 4, 5, 7, 8, 12 y 13 | `E2E_CORREO` y `E2E_CLAVE` |
| 6, 9, 10, 11, 14 y 15 | Los dos anteriores más `E2E_CORREO_AUXILIAR` y `E2E_CLAVE_AUXILIAR`, de otra cuenta existente |
| 16 · Suplentes | `E2E_ORGANIZADOR_CORREO`, `E2E_ORGANIZADOR_CLAVE`, `E2E_TITULAR_CORREO`, `E2E_TITULAR_CLAVE`, `E2E_SUPLENTE_CORREO` y `E2E_SUPLENTE_CLAVE`, de tres cuentas distintas |

Para cada parámetro usar `--dart-define=VARIABLE=valor`; encerrar el argumento
completo entre comillas simples si contiene caracteres especiales. En otros
dispositivos, sustituir `linux` por su identificador de `flutter devices`.
Ejecutar cada E2E dos veces consecutivas para comprobar repetibilidad.

Registro requiere `E2E_CORREO_EXISTENTE` de una cuenta real ya registrada;
login y creación requieren `E2E_CORREO`
y `E2E_CLAVE` válidos. Login reutiliza una cuenta existente, sin crear cuentas ni
modificar su perfil, y cierra sesión al terminar. La creación se verificó con una cuenta E2E
porque las credenciales de la cuenta semilla fueron rechazadas.

Recuperación
usa un correo único sin registrar, sin credenciales ni cuentas nuevas. Verifica
aceptación de la solicitud, no entrega del mensaje ni cambio de contraseña.

Cierre usa `E2E_CORREO` y `E2E_CLAVE`,
sin cuentas nuevas. Solo cubre el cierre de Mis partidos; la limpieza posterior
no se utiliza como evidencia de cierre correcto.

Creación espera a Supabase dentro del
formulario. Borra automáticamente solo sus partidos de prueba y cierra sesión;
no crea cuentas. El fallo y reintento se verifican con widgets, sin provocar errores de red.

Mis partidos requiere
dos cuentas existentes distintas (principal y auxiliar). Prepara y elimina solo
sus tres partidos temporales y la inscripción; incluye datos anteriores en los
conteos. Vacío/error/reintento se verifican con widgets, no con fallos de red reales.

Edición usa una cuenta y limpia sus
dos partidos temporales. Comprueba cupos con Supabase real; error/reintento y
doble envío tienen cobertura de widgets. No comprueba permisos entre cuentas.

Eliminación usa una cuenta y un
partido temporal. Verifica el borrado antes de la limpieza; excluye carga, errores
provocados, permisos entre usuarios y cascada de inscripciones.

Explorar usa dos
cuentas y limpia dos partidos del auxiliar. Cubre nombre y deporte; otros filtros
y unirse quedan para pruebas existentes u otros flujos. No modifica partidos.

Unión usa dos cuentas y limpia
el partido del auxiliar con su inscripción. Comprueba el resultado antes de la
limpieza; excluye último cupo, concurrencia, errores provocados y salida.

Salida usa dos cuentas y limpia
su partido temporal. El jugador se une al último cupo, cancela una salida sin
cambios y luego confirma; verifica la eliminación de su inscripción, la
reapertura del equipo y la consulta persistida desde Explorar. En el primer
intento con Supabase real, el test leyó la tarjeta antes de que terminara la
unión. La reproducción posterior detectó un botón de 40 px en Linux: se fijó
la densidad visual para garantizar 48 × 48 en salida y confirmación. Las esperas
comprueban ahora pertenencia, cupos y estado de la tarjeta. La corrección pasó
dos ejecuciones consecutivas en Linux con Supabase real.

Agregar jugador usa una
cuenta y limpia su partido temporal. Un jugador sin cuenta solo ocupa un cupo;
no genera nombre ni inscripción. Se excluyen equipo completo y errores provocados.

Completar equipo usa una cuenta y
limpia su partido temporal. Marca 6/6 y estado completo sin generar inscripciones.
Comprueba persistencia y aviso de bloqueo sin intentar agregar más jugadores.

Consultar inscritos
usa dos cuentas y limpia el partido del organizador con su inscripción auxiliar.
Verifica nombre real y consulta sin cambios; excluye vacío y listas extensas en E2E.

Historial usa dos
cuentas y limpia sus dos partidos temporales con la inscripción. Incluye datos
anteriores y partidos futuros. Excluye vacío, Disputados y fechas amigables.
La validación de Historial es individual. No se registró una ejecución conjunta de las 16 E2E después de integrar suplentes.

**Limpieza manual pendiente:** eliminar en Supabase → Authentication → Users solo
estas cuentas de validación; sus perfiles se eliminan en cascada:

- `e2e-registro-1793585652011594@unisport.edu`
- `e2e-registro-1793585755339189@unisport.edu`
- `e2e-registro-1793585799806090@unisport.edu`

No eliminar la semilla. Este listado se conserva como pendiente histórico; comprobar en Supabase cuáles de esas cuentas siguen presentes antes de limpiarlas.

## Detalle del flujo 16 · Lista de suplentes

### Cambio implementado

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

### Matriz antes y después de suplentes

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

### Verificación histórica de la feature
Los resultados de esta sección se conservan del registro original de la
feature. La comparación de 102 a 108 pruebas corresponde a esa base y no al
total de la rama integrada; el resultado local posterior es 115 aprobadas y
1 omitida, indicado al comienzo del documento.

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

### Demostración con la base real

1. Ejecutar de nuevo `supabase/esquema.sql` en el **SQL Editor** del proyecto
   Supabase. El script usa `create table if not exists` y conserva los datos.
2. Abrir UniSport con `flutter run -d chrome` y usar cuentas distintas para
   organizador, titular y dos suplentes.
3. Crear un partido de dos cupos. El titular ocupa el último cupo. Los otros
   dos entran como suplentes y ven los turnos 1 y 2.
4. El titular sale. Al actualizar la pantalla, el primer suplente figura como
   inscrito y el segundo aparece en el turno 1. El organizador puede ver la
   misma lista.

### Registro histórico de la prueba con Supabase

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

### Ejecutar la E2E de suplentes

Desde PowerShell, con tres cuentas de prueba ya registradas y el esquema
actualizado en Supabase, reemplazar los valores y el dispositivo:

```powershell
flutter test integration_test/flujo_suplentes_test.dart -d emulator-5554 `
  --dart-define=E2E_ORGANIZADOR_CORREO=correo-organizador `
  --dart-define=E2E_ORGANIZADOR_CLAVE=clave-organizador `
  --dart-define=E2E_TITULAR_CORREO=correo-titular `
  --dart-define=E2E_TITULAR_CLAVE=clave-titular `
  --dart-define=E2E_SUPLENTE_CORREO=correo-suplente `
  --dart-define=E2E_SUPLENTE_CLAVE=clave-suplente
```

No hace falta ejecutar `flutter run` antes. La prueba elimina únicamente su
partido temporal al terminar. Los valores de `--dart-define` quedan incluidos
en la compilación de prueba; usar exclusivamente cuentas de prueba.
