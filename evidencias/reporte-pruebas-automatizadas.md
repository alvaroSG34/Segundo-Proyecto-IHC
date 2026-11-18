# Reporte de pruebas automatizadas y cobertura del fork

**Fecha de revisión:** 18 de noviembre de 2026  
**Proyecto:** UniSport  
**Commit revisado:** `23f0a3a5f28dda03d3b589af57f7701034f1ab23`  
**Referencia de comparación:** `upstream/main` local, commit `f098dea6245c1a9a59a7f823914000bdf4889c71`.

## Resultado frente a la consigna

| Criterio | Estado | Evidencia |
| --- | --- | --- |
| La suite E2E corre y pasa | **No cumplido.** | La ejecución completa en Android terminó con 4 aprobadas y 14 fallidas. |
| El código agregado en el fork tiene 100 % de cobertura | **No demostrado.** | El cruce preliminar con la [cobertura combinada](cobertura-combinada.lcov) es 86,61 % de las líneas cambiadas registradas en LCOV y tiene limitaciones de alcance. |
| Reporte en el repositorio | **Disponible.** | Este documento reúne la evidencia y explica lo que falta para verificar los dos criterios anteriores. |

El mensaje `All tests passed!` indica que pasaron las pruebas ejecutadas en una corrida; por sí solo no mide cobertura y no demuestra que se hayan ejecutado todas las pruebas. Una prueba omitida tampoco cuenta como aprobada.

## Alcance del fork

La comparación local `git diff upstream/main...HEAD` identifica cambios en **50 archivos bajo `lib/`**, además de pruebas, configuración, documentación y cambios en `supabase/esquema.sql`. La referencia es la copia local de `upstream/main`; no se consultó el estado remoto durante esta revisión. Es necesario fijar la referencia oficial de evaluación antes de medir, pues otra base puede cambiar el conjunto de líneas atribuidas al fork.

La cobertura de código debe referirse a las **líneas ejecutables nuevas o modificadas**, incluyendo las de archivos existentes. Los archivos movidos o renombrados deben revisarse con detección de renombres para evitar atribuir todo su contenido al fork. La cobertura de Dart no mide automáticamente las funciones SQL ni código de otras plataformas; su alcance debe declararse y medirse por separado cuando formen parte de la consigna.

## Evidencia disponible

- [Tarea 6: matriz E2E](tarea-6.md): registra aprobaciones individuales históricas y aclara que no hubo una ejecución conjunta posterior al merge en aquella revisión. Dos flujos de la matriz fueron retirados.
- [Tarea 8: resultados y restricciones](tarea-8.md): documenta ejecuciones E2E individuales y una suite local con una prueba omitida.
- [Tarea 9: suplentes](tarea-9.md): registra una ejecución E2E individual aprobada el 12 de noviembre de 2026.
- [Tarea 10: cuenta](tarea-10.md): registra 254 pruebas locales aprobadas y 5 omitidas antes de añadir el recorrido de integración; indica que algunas pruebas de integración se ejecutaron por separado.

Estos resultados describen momentos y alcances diferentes. No se pueden sumar para concluir que la suite actual completa aprobó ni para calcular un porcentaje de cobertura.

## Condiciones de esta revisión

Se inspeccionaron los archivos y la historia Git local. Flutter no estaba en el PATH de esta sesión, pero se encontró en `C:\Flutter\flutter`: Flutter 3.47.7 y Dart 3.13.5. Se detectaron Windows, Chrome, Edge y posteriormente un emulador Android. Las E2E requieren Supabase configurado y cuentas de prueba; algunas crean, modifican o eliminan datos. Se debe usar un entorno de pruebas aislado y revisar los requisitos y la limpieza de cada caso antes de ejecutarlos. No se deben incluir credenciales en el reporte ni en el repositorio.

## Ejecución local del 18 de noviembre de 2026

La primera ejecución de `flutter test --no-pub --coverage --reporter expanded` terminó con **258 aprobadas, 18 fallidas y 5 omitidas**. Después de ajustar pruebas de búsqueda y esperas de diálogos, la ejecución completa terminó con **275 aprobadas, 1 fallida y 5 omitidas**, código 1. El fallo pendiente corresponde a la navegación tras recuperar la contraseña. La ejecución cubre `test/`, no `integration_test/`.

Posteriormente se retiraron `test/evidencias_clase22_test.dart` y `test/evidencias_revision_test.dart` porque eran pruebas opcionales para generar o revisar capturas de evidencias de clase, y se omitían en la ejecución normal. Las imágenes ya generadas se conservan y los archivos pueden recuperarse desde el historial de Git si se necesita regenerarlas. Su eliminación no aumenta por sí misma la cobertura ni sustituye pruebas de funcionamiento.

Las cifras anteriores son históricas y corresponden a antes de retirar esas pruebas; no se ha repetido la suite después de ese cambio. Las otras tres pruebas omitidas requieren un entorno Supabase de prueba y activación explícita.

### Ejecución de integración con Supabase

El 18 de noviembre de 2026 se ejecutaron las tres pruebas opcionales en el proyecto que se confirmó como entorno de pruebas, con `PRUEBAS_SUPABASE=true`: **0 aprobadas y 3 fallidas**. El servicio respondió y permitió crear cuentas, pero las pruebas encontraron que las funciones `obtener_mis_turnos`, `registrar_resultado_partido` y `eliminar_mi_cuenta` no estaban disponibles en la caché del esquema. Además, la prueba de aislamiento de perfiles pudo leer el identificador de otro usuario; se debe revisar la política RLS efectiva. Estos resultados no demuestran por sí solos si la causa es un esquema desactualizado o una configuración distinta del servidor.

La limpieza automática informó que no pudo eliminar algunas cuentas de prueba porque faltaba `eliminar_mi_cuenta`; es necesario revisarlas y eliminarlas desde la administración del proyecto. Antes de repetir, comparar el esquema y las políticas del proyecto con `supabase/esquema.sql`, aplicar los cambios necesarios mediante un acceso administrativo y verificar la limpieza. La clave pública usada por las pruebas no permite administrar el esquema.

**Nueva ejecución tras aplicar el esquema:** el usuario ejecutó `supabase/esquema.sql` en la base de pruebas y se repitieron los dos archivos con `PRUEBAS_SUPABASE=true`. Resultado: **3 pruebas aprobadas, 0 fallidas y 0 omitidas**, `All tests passed!`, código de salida 0, en 59 segundos. Esta ejecución incluye la comprobación de aislamiento de perfiles y las dos pruebas de eliminación de cuentas. El resultado no demuestra que se hayan eliminado las cuentas residuales de la ejecución anterior; esa limpieza debe verificarse por separado.

La ejecución anterior produjo **3.948 de 4.848 líneas instrumentadas ejecutadas (81,44 %)**. No equivale a la cobertura del diff ni necesariamente de todos los archivos del proyecto. Los archivos ausentes del LCOV no se contabilizan en ese porcentaje. No se midieron SQL ni otras plataformas.

**Ejecución posterior:** después de ajustar la prueba de recuperación y corregir la recarga del detalle cuando la pantalla ya fue cerrada, la suite local terminó con **280 aprobadas, 0 fallidas y 3 omitidas**. Las tres omitidas son las integraciones con Supabase que pasaron por separado según la sección siguiente. El [LCOV local](cobertura-pruebas-locales.lcov) corresponde a esta ejecución: **3.972 de 4.849 líneas registradas (81,91 %)**. No mide el código que falta en el informe ni equivale a la cobertura de los cambios del fork.

Una comparación preliminar entre las líneas añadidas del diff `upstream/main...HEAD` y las entradas `DA` del LCOV encuentra **3.004 líneas cubiertas de 3.816 líneas cambiadas registradas (78,72 %)**. Este cálculo solo cuenta líneas que aparecen en el LCOV; dos archivos cambiados no aparecen y deben revisarse antes de establecer el denominador completo. No incluye SQL ni la cobertura de las E2E. No demuestra el 100 %.

La referencia `HEAD` identifica el commit indicado al principio; este cálculo no incluye modificaciones posteriores que todavía están sin confirmar en el directorio de trabajo. Debe repetirse contra el estado final antes de usarlo como resultado de entrega.

Al repetir las tres integraciones de Supabase con cobertura, las tres pasaron. La [cobertura combinada](cobertura-combinada.lcov) suma los impactos de línea de la suite local y de esas integraciones: **4.277 de 4.849 líneas registradas (88,20 %)**. El cruce preliminar entre ese archivo y `git diff upstream/main -- lib`, incluidos los cambios sin confirmar, da **3.306 de 3.817 líneas cambiadas registradas (86,61 %)**. Persisten los límites anteriores: no incluye los archivos ausentes del LCOV, SQL ni E2E. El archivo combinado contiene cobertura de líneas; no incluye cobertura de ramas.

Un primer intento se interrumpió antes de finalizar al interpretar erróneamente el retraso de la salida como un bloqueo; las cifras anteriores corresponden al segundo intento completo.

## Cómo completar la verificación

1. Instalar y configurar el SDK Flutter compatible con el proyecto; comprobar `flutter --version` y `flutter devices`.
2. Preparar Supabase y las cuentas de prueba requeridas. Consultar [README](../README.md), [Tarea 6](tarea-6.md) y los archivos de `integration_test/` para identificar los `--dart-define` específicos de cada flujo. Ejecutar todos los archivos E2E activos en un dispositivo compatible y conservar los resultados por archivo, incluidas fallas y pruebas omitidas.
3. Ejecutar la suite local con cobertura:

   ```powershell
   flutter test --coverage
   ```

   Conservar `coverage/lcov.info` y el resultado de la ejecución. Las pruebas opcionales de Supabase requieren configuración y activación explícitas; registrar si quedaron omitidas.

4. Comparar la cobertura con las líneas ejecutables añadidas o modificadas frente al commit base acordado, utilizando una herramienta de cobertura de diff que interprete LCOV. Revisar también archivos cambiados ausentes del informe: su ausencia no demuestra que tengan cobertura. Registrar el numerador, el denominador, los archivos y líneas sin cubrir, y cualquier exclusión justificada. Si las E2E generan cobertura por separado, combinarla con la local antes de calcular el resultado y documentar el procedimiento.
5. Medir por separado el código relevante no cubierto por LCOV de Dart, o dejar explícitamente indicado que está fuera del alcance acordado. Actualizar este reporte con fecha, commits, dispositivo, comandos sin secretos, resultados, omisiones y enlaces a los artefactos de cobertura.

La consigna de 100 % solo puede darse por demostrada cuando la medición cubra todas las líneas ejecutables dentro del alcance acordado y el resultado verificable sea 100 %. La ejecución completa de E2E debe acreditarse por separado.

## Ejecución E2E en Android

El 18 de noviembre de 2026 se ejecutaron secuencialmente los 18 archivos de `integration_test/` en el emulador Android `emulator-5554`, con tres cuentas temporales y el proyecto Supabase confirmado como entorno de pruebas. Resultado: **4 pruebas aprobadas, 14 fallidas y ninguna omitida**; código de salida 1. Pasaron inicio de sesión, recuperación de contraseña, registro y salida de un partido. Los 14 recorridos restantes fallaron y requieren revisión; por tanto la suite completa aún no pasa.

Entre los motivos observados, varias pruebas buscaban tarjetas o controles anteriores de Mis partidos. El recorrido de cierre de sesión buscaba un control y un diálogo que no están presentes en esa pantalla; el cierre actual está en el menú principal. La prueba de creación se modificó después de esta ejecución para buscar la tarjeta actual, pero el resultado anterior sigue siendo histórico. Una ejecución fallida no permite concluir que todos los pasos posteriores de ese recorrido funcionan.

Las pruebas de creación y rechazo de propuestas se repitieron individualmente tras actualizar la navegación y corregir una actualización del detalle después de cerrar la pantalla; ambas pasaron. No se ha vuelto a ejecutar la suite completa con esos cambios, por lo que no se actualizan los totales de la ejecución conjunta anterior.


### Actualizacion E2E individual (18 de noviembre de 2026)

Despues de adaptar los recorridos a la interfaz actual, se ejecutaron individualmente en `emulator-5554` y pasaron con codigo 0:

- `integration_test/cerrar_sesion_test.dart`: 1 aprobada.
- `integration_test/editar_partido_test.dart`: 1 aprobada, incluidos validacion, cancelacion, cupos, guardado y persistencia.
- `integration_test/eliminar_partido_test.dart`: 1 aprobada, incluyendo cancelacion, borrado real y comprobacion tras reabrir la lista.
- `integration_test/crear_partido_test.dart` e `integration_test/rechazar_propuesta_equipos_test.dart`: aprobadas en ejecuciones individuales anteriores.

Estas ejecuciones individuales no sustituyen una corrida conjunta de todos los archivos E2E; los resultados conjuntos historicos de arriba se conservan como registro y no representan el estado de una nueva ejecucion completa.
