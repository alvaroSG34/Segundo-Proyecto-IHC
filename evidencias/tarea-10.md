# Tarea 10: revisión de patrones oscuros

## Revisión de la aplicación

Se revisó estáticamente el código de inicio, registro, acceso, recuperación de contraseña, perfil, creación y exploración de partidos, mis partidos, reprogramación, suplentes, equipos, resultados, historial y cierre de sesión. La analítica compartida queda fuera de esta revisión por decisión del equipo. Esta revisión de código no sustituye un recorrido visual de todos los estados.

| Criterio | Hallazgo y corrección | Pendiente y principio |
| --- | --- | --- |
| Opciones preseleccionadas | Registro y creación de partidos proponen Futsal, pero permiten cambiarlo. Los filtros propuestos se pueden modificar. No se encontraron casillas de promociones preactivadas. | Decidir si se pide una elección explícita del deporte; la preselección por sí sola no demuestra manipulación. **Control y libertad**. |
| Confirmaciones engañosas | Las bajas tardías decían «Registrar baja tardía» aunque también retiran del partido; ahora el botón dice «Sí, salir» y se explica el registro. Antes de confirmar un resultado se añadió que será definitivo. Eliminar partido y cuenta explica sus consecuencias. | Revisar visualmente tamaños y peso de las opciones de los diálogos, especialmente en pantallas pequeñas. **Prevención de errores y decisión informada**. |
| Urgencia, culpa o escasez falsas | Los cupos y el plazo de baja tardía proceden de los datos y fecha del partido. En el código revisado no se encontraron contadores de urgencia inventados ni mensajes de culpa. | Comprobar visualmente los estados con cupos, sin cupos y baja tardía. **Honestidad**. |
| Datos expuestos sin necesidad | El perfil se restringe a su dueño; las inscripciones y la espera al jugador u organizador. Se muestra la posición propia sin exponer las demás entradas. Se corrigieron las comparaciones de autorización de organizador y capitán cuando la cuenta anterior fue eliminada. | El SQL actualizado fue aplicado según confirmación del equipo; comprobar la protección en Supabase; revisar si todos los nombres que ve el organizador son necesarios. **Minimización de datos y control**. |
| Salir más difícil que entrar | Entrar y cancelar espera tienen acciones visibles; la tarjeta explica la incorporación automática antes de entrar. Existen salida del partido, cierre de sesión y eliminación de cuenta. | Recorrer visualmente en móviles y contrastar los pasos de entrada y salida, incluidos errores y reprogramaciones. **Control y libertad**. |
| Permisos sin explicar | El manifiesto Android declara acceso a internet; no se encontraron solicitudes de ubicación, cámara o contactos en el código revisado ni descripciones para esos permisos en iOS. | Confirmar el comportamiento en dispositivos y al guardar el archivo de datos. **Consentimiento informado**. |

### Cambios de esta revisión

- En Explorar y Mis partidos, la confirmación de baja tardía antes decía «Registrar baja tardía»; ahora dice «Sí, salir». El texto explica que el organizador verá la baja.
- En Equipos, antes no se explicaba junto al botón que confirmar el marcador lo vuelve definitivo; ahora se informa antes de actuar.
- En el esquema, las comparaciones de autorización ahora contemplan identificadores nulos tras eliminar una cuenta. El cliente también admite el organizador eliminado al leer participantes.

La revisión visual local y las capturas se describen más abajo. El equipo aplicó la ampliación del SQL para eventos y se comprobó el inicio y el éxito en Supabase.

## Información antes de actuar

Antes, la pantalla de reprogramación decía «Guardar y avisar al equipo». Ahora indica que el cambio se muestra en UniSport y que no se envía una notificación. La confirmación para eliminar un partido enumera sus consecuencias. Ambas correcciones aplican el principio de **decisión informada**.

La prueba de privacidad se realizó en una base PostgreSQL local con cuentas ficticias: cada jugador vio sus datos y su posición real en la espera; el organizador pudo ver la lista e inscripciones de su partido. La protección debe comprobarse también en Supabase después de aplicar `supabase/esquema.sql`.

## Mis datos

Desde el perfil se pueden consultar y descargar como JSON el perfil, los partidos organizados, las inscripciones, la lista de espera, las bajas tardías y las acciones propias sobre resultados de la cuenta con sesión iniciada. La consulta solicita solo los campos necesarios y no incluye contraseñas ni datos de contacto de otras personas.

### Comprobación con Supabase

- Una prueba con cuentas ficticias comprobó que cada persona puede consultar su propio perfil e inscripción, pero no el perfil de otra cuenta.
- Dos suplentes comprobaron sus turnos 1 y 2 y que cada uno solo puede leer su propia entrada. El organizador pudo ver ambas entradas en orden. El partido de prueba se eliminó al terminar.
- En Chrome se inició sesión con una cuenta ficticia nueva y se descargó el archivo JSON desde «Mi perfil». Se comprobó que el archivo contenía los datos de esa cuenta y las secciones esperadas. Esa cuenta no tenía partidos.
- Las pruebas iniciales de descarga crearon cuentas ficticias que permanecían en Supabase Auth al terminar; las pruebas posteriores de eliminación limpiaron las cuentas creadas por ellas.

## Eliminación de cuenta

En «Mi perfil» la confirmación explica que se elimina la cuenta, se cancelan los partidos futuros organizados y se libera el lugar en los demás partidos, promoviendo al primer suplente cuando exista. Las dos opciones tienen el mismo tamaño. Los resultados confirmados se conservan y las referencias directas a la cuenta eliminada se retiran. La eliminación se realiza en una sola transacción de la base de datos.

En PostgreSQL local, con cuentas ficticias, se comprobó la cancelación de un partido futuro, la promoción del primer suplente, la liberación de un cupo sin suplentes y la conservación de un resultado confirmado al eliminar al organizador y al capitán. Se provocó un fallo de clave foránea para comprobar que las operaciones previas se revierten. También se comprobó el bloqueo ante un resultado confirmado asociado a un partido futuro, una situación inconsistente que impediría conservarlo si se cancelara el partido.

La interfaz se verificó con una cuenta ficticia en memoria: cancelar mantiene la sesión; confirmar elimina la cuenta de prueba e impide volver a ingresar con ella. El recorrido con el servicio real se describe en la siguiente sección; queda pendiente repetirlo con los nuevos eventos y verificar la interfaz conectada a Supabase.

### Prueba de eliminación en Supabase

Con el SQL actualizado, `test/eliminar_cuenta_supabase_test.dart` creó tres cuentas ficticias y un partido futuro. Se comprobó que al eliminar al titular se promociona al suplente, se conserva el número de cupos ocupados y la cuenta eliminada no puede iniciar sesión. Después se eliminó la cuenta organizadora y se comprobó que el partido desapareció y que tampoco pudo iniciar sesión. La prueba eliminó las cuentas ficticias utilizadas.

La comprobación posterior de un resultado confirmado en Supabase se describe en la sección «Resultado confirmado en Supabase».


### Recorrido visual en el entorno local

Se generaron capturas a 390 × 844 píxeles con cuentas ficticias y fuente local de reemplazo. No son capturas de un dispositivo real; Google Fonts no pudo descargar sus fuentes durante la ejecución.

- [Registro](tarea-10-registro.png): se observó Futsal preseleccionado. Las etiquetas anteriores del correo y contraseña quedaban cortadas; además, el texto del correo sugería dominios específicos aunque la validación acepta otros. Se cambiaron a «Correo electrónico» y «Contraseña (mínimo 6)». **Principio: honestidad y prevención de errores**. Las capturas anteriores reconstruidas están enlazadas en «Evidencia del antes y error de exploración».
- [Confirmación de eliminación de cuenta](tarea-10-confirmacion-cuenta.png): se observan las consecuencias y las opciones Cancelar y Eliminar cuenta. Se comprobó en el fixture que tienen el mismo tamaño y que cancelar conserva la sesión.
- La captura anterior de [entrada como suplente](clase-22-suplentes-despues.png) muestra el aviso previo de incorporación automática y la posibilidad de cancelar.

También pasaron 31 pruebas locales de perfil, suplentes, reprogramación, resultados y salida. Las capturas posteriores de acceso, creación, exploración e historial se describen en los apartados siguientes.

### Continuación del recorrido visual

Capturas locales de las pantallas reales con repositorio y cuentas ficticios, a 390 × 844 píxeles:

- [Acceso con credenciales incorrectas](tarea-10-acceso-error.png): el error explica el problema y mantiene las opciones para recuperar la contraseña o intentarlo otra vez. La etiqueta «Correo institucional» se cambió a «Correo electrónico» para coincidir con los correos aceptados en el registro. Principio: **honestidad**.
- [Crear partido](tarea-10-crear-partido.png): la vista previa señala qué datos todavía faltan y se observa Futsal preseleccionado, con otras disciplinas disponibles. La decisión de exigir una selección explícita sigue pendiente.
- [Historial vacío](tarea-10-historial-vacio.png): informa que todavía no hay partidos y ofrece explorar o crear uno, sin mensajes de culpa.
- [Explorar](tarea-10-explorar.png): el partido ficticio muestra 2/10 jugadores y ocho cupos restantes. El nombre del organizador mostrado es ficticio.
- [Búsqueda sin resultados](tarea-10-sin-resultados.png): explica que no hubo coincidencias y permite quitar los filtros.

Las capturas muestran estados concretos de una ejecución local; las siguientes secciones amplían el recorrido visual. La prueba de capturas usa una fuente de reemplazo local porque las fuentes remotas no se descargaron en el entorno de prueba.

### Confirmaciones y respuestas a cambios

Se recorrieron estos estados con pantallas reales y datos ficticios en un fixture local de 390 × 844 píxeles:

- [Unirse al partido](tarea-10-confirmar-union.png): indica que se ocupará un cupo y permite cancelar.
- [Salir con baja tardía](tarea-10-confirmar-salida.png): indica la salida y que el organizador verá la baja. Se comprobó la opción de cancelar.
- [Reconfirmar asistencia](tarea-10-reconfirmacion.png): muestra motivo, fecha y lugar anteriores, además de aclarar que se conserva la plaza mientras está pendiente la respuesta.
- [Resultado pendiente](tarea-10-resultado-pendiente.png): muestra marcador, estado y la advertencia de que confirmar vuelve definitivo el resultado.

En la revisión inicial, las confirmaciones de unión y salida mostraban la acción de confirmar con más peso visual que «Cancelar». Se ajustó el diálogo compartido para usar dos botones del mismo tamaño y estilo en unión, salida, retirada, eliminación del partido y cierre de sesión. También se equilibró el estilo de «Confirmar resultado» y «Disputar resultado». **Principio: control y libertad, y prevención de errores.** Las capturas anteriores reconstruidas están enlazadas más abajo.

Pasaron 40 pruebas locales de salida, edición, propuestas, búsqueda y resultados; `flutter analyze` terminó sin incidencias. Los apartados siguientes documentan el recorrido visual adicional y la conservación de un resultado en Supabase. Las imágenes provienen de datos en memoria, no de una prueba en un dispositivo físico.

### Creación, eliminación y cierre de sesión

Continuación del recorrido visual a 390 × 844 píxeles, con datos ficticios:

- [Controles de creación](tarea-10-crear-controles.png): fecha y hora requieren elección; los cupos incluyen al organizador y se pueden ajustar. Futsal y 10 cupos aparecen como valores iniciales modificables.
- [Validación del formulario](tarea-10-crear-validacion.png): al intentar guardar sin completar, se indican los campos y elecciones que faltan.
- [Eliminar partido](tarea-10-eliminar-partido.png): se explican las inscripciones, suplentes y resultados que se eliminan; cancelar y eliminar tienen tamaño y estilo comparables. Se comprobó cancelar.
- [Cerrar sesión](tarea-10-cerrar-sesion.png): explica a dónde se vuelve, permite cancelar y se comprobó que cancelar conserva la sesión.
- [Error al cargar](tarea-10-error-carga.png): muestra el mensaje y la opción de reintentar. El error fue provocado por un repositorio ficticio; no demuestra una caída real del servidor.

Con estas capturas se completó el recorrido visual local de los puntos indicados como pendientes en el apartado anterior. El rechazo de una regla de negocio y la conservación de un resultado se comprobaron después en Supabase, como se describe más abajo; una caída real del servidor sigue sin comprobarse. Las pruebas locales completas terminaron con 250 aprobadas y 4 omitidas; las pruebas opcionales de Supabase y las capturas requieren activación explícita. El fixture de capturas sí se ejecutó por separado para este recorrido.


### Resultado confirmado en Supabase

Se ejecutó `test/eliminar_cuenta_supabase_test.dart` con `PRUEBAS_SUPABASE=true` para el caso de un resultado confirmado. La prueba creó dos cuentas ficticias, programó un partido cercano, aceptó los equipos y, una vez iniciada la hora del partido, registró y confirmó un marcador 2–1.

Después se eliminó la cuenta del capitán y se comprobó desde la cuenta organizadora que el resultado seguía confirmado con el mismo marcador, que se habían retirado el identificador y el nombre del capitán del reparto y del historial, y que esa cuenta ya no podía iniciar sesión. La prueba pasó y ejecutó la limpieza del partido y de la cuenta organizadora de prueba. Esta comprobación cubre la eliminación de un capitán; la eliminación del organizador con un resultado confirmado se comprobó previamente en PostgreSQL local.

### Evidencia del antes y error de exploración

Las siguientes imágenes anteriores se reconstruyeron en una copia aislada del proyecto usando el formulario y el diálogo compartido de la revisión `7195f75`; las opciones de estilo de unión y salida se restituyeron para reproducir su apariencia. Se usaron los mismos datos ficticios y la misma fuente local de las capturas actuales:

- Registro: [antes](tarea-10-registro-antes.png) y [después](tarea-10-registro.png).
- Confirmación para unirse: [antes](tarea-10-confirmar-union-antes.png) y [después](tarea-10-confirmar-union.png).
- Confirmación para salir: [antes](tarea-10-confirmar-salida-antes.png) y [después](tarea-10-confirmar-salida.png). La reconstrucción corresponde a la apariencia del diálogo anterior al ajuste visual, con el texto de salida ya aclarado.

Al revisar los errores, se encontró que Explorar podía dejar resultados anteriores o un estado vacío tras fallar la consulta. Ahora muestra [un mensaje con la opción Reintentar](tarea-10-explorar-error.png), sin mostrar la cantidad anterior. Una prueba local comprobó el error y la recuperación. **Principios: honestidad y prevención de errores.** La captura simula el fallo con un repositorio en memoria.

Se ejecutó además la prueba de integración en Supabase: al intentar inscribirse por segunda vez, el servidor respondió «Ya formas parte de este equipo», y la aplicación de datos recibió ese motivo. La prueba completó la promoción del suplente y la limpieza de sus cuentas ficticias. Esto comprueba un rechazo real de la regla de negocio; una caída real del servidor sigue sin comprobarse.

### Pruebas específicas de patrones oscuros

- `test/confirmacion_honesta_test.dart`: en anchos de 320 y 390 píxeles comprueba que las opciones del diálogo compartido tienen igual tamaño y estilo, y que cancelar y confirmar devuelven resultados distintos. Antes del ajuste, la prueba falló en ambos anchos: un texto largo hacía que el botón de confirmar fuera más alto. Se corrigió haciendo que ambos botones se adapten a la misma altura.
- `test/analitica_salida_test.dart`: las pruebas existentes de Explorar y Mis partidos ahora comprueban que el diálogo informa de la salida y de la visibilidad de la baja tardía antes de confirmar.
- `test/resultado_partido_test.dart`: la prueba existente comprueba que la advertencia de resultado definitivo y la opción de disputar aparecen antes de confirmar.

Las 20 pruebas seleccionadas pasaron después de la corrección. La suite local completa terminó con 253 aprobadas y 5 omitidas; `flutter analyze` no encontró incidencias. Las integraciones remotas y capturas opcionales no se ejecutaron en esa suite.


### Eventos de eliminación de cuenta

La analítica queda fuera de la revisión de patrones oscuros, pero se usa para demostrar el recorrido de la Tarea 10. Al abrir la confirmación se registra `cuenta_eliminacion_iniciada`; un fallo o bloqueo registra `cuenta_eliminacion_fallida` con código `error` o `bloqueo`; el servidor registra `cuenta_eliminacion_completada` después de eliminar la cuenta. Los eventos usan un identificador aleatorio del intento y no incluyen identificadores de usuario, correos, nombres ni contenido libre. Cancelar conserva la cuenta y deja únicamente el inicio.

Se comprobó en PostgreSQL local la creación de los tres eventos, el rechazo de propiedades adicionales y que el cliente no puede registrar el éxito. Una prueba de Flutter verificó el inicio y el bloqueo con el mismo identificador. Tras aplicar el SQL, la prueba de integración en Supabase comprobó inicio y éxito con el mismo identificador. El bloqueo se comprobó localmente; su caso real en Supabase sigue pendiente.


### Recorrido de perfil con Supabase

`integration_test/tarea_10_cuenta_test.dart` se ejecutó en Linux contra Supabase con cuentas ficticias. Desde Mi perfil consultó los datos, pulsó Descargar JSON y verificó el contenido entregado al guardador de prueba; después confirmó la eliminación, comprobó que no podía iniciar sesión y que los eventos de inicio y éxito compartían identificador y no incluían datos personales. El guardador se sustituyó para inspeccionar los bytes: esta ejecución no comprueba el diálogo de guardado del sistema. La descarga real en Chrome se comprobó por separado como se describe en «Mis datos».

La suite local terminó con 254 pruebas aprobadas y 5 omitidas antes de añadir el recorrido de integración; `flutter analyze` no encontró incidencias. El recorrido Linux y la prueba de eventos en Supabase se ejecutaron por separado y pasaron. Queda pendiente demostrar un bloqueo real de eliminación en Supabase y tomar las capturas correspondientes.
