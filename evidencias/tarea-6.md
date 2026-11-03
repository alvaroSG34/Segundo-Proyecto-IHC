# Tarea 6 · Pruebas E2E y experiencia del usuario


## Matriz de los 15 flujos

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
| 12 | Agregar jugador sin cuenta | [agregar_jugador_test.dart](../integration_test/agregar_jugador_test.dart) | Incremento 1/6 → 2/6 sin inscripción, persistencia al reabrir y mismo organizador; semántica, áreas ≥48 × 48 y 2 toques desde menú | Aprobada 2 veces consecutivas |
| 13 | Completar equipo | [completar_equipo_test.dart](../integration_test/completar_equipo_test.dart) | 1/6 → 6/6 y estado completo sin inscripciones; persistencia, botón ausente y aviso de bloqueo; semántica, áreas ≥48 × 48 y 2 toques | Aprobada 2 veces consecutivas |
| 14 | Consultar jugadores inscritos | [jugadores_inscritos_test.dart](../integration_test/jugadores_inscritos_test.dart) | Organizador consulta un inscrito real, cierra y reabre; nombre persistido y datos intactos; semántica, áreas ≥48 × 48 y 2 toques | Aprobada 2 veces consecutivas |
| 15 | Consultar y filtrar historial | [historial_test.dart](../integration_test/historial_test.dart) | Todos y filtros por rol con IDs/conteos completos y orden descendente; restauración, reapertura y datos intactos; semántica, áreas ≥48 × 48 y acceso en 1 toque | Aprobada 2 veces consecutivas |

**Avance:** 15 E2E implementadas y aprobadas individualmente; ninguna pendiente de implementar. La creación amplía su E2E existente,
sin aumentar el número de flujos cubiertos. La regla de tres toques
se aplica al acceso al formulario o al cierre desde menú, no a la preparación; accesibilidad automática no
sustituye revisión con lector de pantalla.

## Suite antes y después

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
La validación de Historial es individual, sin nueva ejecución conjunta de las 15 E2E.

**Limpieza manual pendiente:** eliminar en Supabase → Authentication → Users solo
estas cuentas de validación; sus perfiles se eliminan en cascada:

- `e2e-registro-1793585652011594@unisport.edu`
- `e2e-registro-1793585755339189@unisport.edu`
- `e2e-registro-1793585799806090@unisport.edu`

No eliminar la semilla. Los 15 flujos de la matriz tienen E2E implementadas con
aprobaciones individuales registradas; queda pendiente publicar en el fork.
