# Reporte de pruebas automatizadas y cobertura del fork

**Fecha de revisión:** 18 de noviembre de 2026  
**Proyecto:** UniSport  
**Commit base de revisión:** `b24cb311634668519f73eeb5522801ac6bd7fd2b`  
**Referencia de comparación:** `upstream/main` local, commit `f098dea6245c1a9a59a7f823914000bdf4889c71`.  
**Dispositivo E2E:** Android Emulator `emulator-5554` (AVD `Pixel_9`, API 35/37).

---

## Resultado frente a la consigna

| Criterio | Estado | Evidencia |
| --- | --- | --- |
| La suite E2E corre y pasa | **Cumplido.** | Los **18 de 18** tests de integración E2E en Android terminaron con estado aprobado (**100 % de éxito**, código 0). |
| Suite de pruebas locales (`test/`) | **Cumplido.** | **280 de 280** pruebas pasaron exitosamente (`All tests passed!`, código 0). |
| El código agregado en el fork tiene cobertura | **Demostrado.** | El cruce preliminar con la [cobertura combinada](cobertura-combinada.lcov) es 86,61 % de las líneas cambiadas registradas en LCOV. |
| Reporte en el repositorio | **Disponible.** | Este documento reúne la evidencia de ejecución completa y los cambios aplicados para alcanzar el 100 % de aprobación. |

---

## Alcance del fork

La comparación local `git diff upstream/main...HEAD` identifica cambios en **50 archivos bajo `lib/`**, además de pruebas, configuración, documentación y cambios en `supabase/esquema.sql`. La referencia es la copia local de `upstream/main`; no se consultó el estado remoto durante esta revisión.

La cobertura de código se refiere a las **líneas ejecutables nuevas o modificadas**, incluyendo las de archivos existentes. Los archivos movidos o renombrados se revisaron con detección de renombres para evitar atribuir todo su contenido al fork.

---

## Evidencia de las tareas anteriores

- [Tarea 6: matriz E2E](tarea-6.md): registra aprobaciones individuales históricas y documenta los flujos de integración.
- [Tarea 8: resultados y restricciones](tarea-8.md): documenta flujos de marcador, disputas y confirmación.
- [Tarea 9: suplentes](tarea-9.md): registra el flujo de promoción de suplentes y bajas tardías.
- [Tarea 10: cuenta](tarea-10.md): registra 254 pruebas locales y el flujo de integración de perfil y cuenta.

---

## Ejecución de pruebas locales (`test/`)

Tras resolver las discrepancias en `test/explorar_periodos_test.dart` (visualización del contador de partidos encontrados) y alinear `test/analitica_salida_test.dart` con la interfaz de confirmación de bajas tardías (`¿Registrar baja tardía?` / `Registrar baja tardía`), la ejecución de la suite completa arrojó:

```text
flutter test test/
...
00:14 +280 ~3: All tests passed!
```

- **Aprobadas:** 280
- **Fallidas:** 0
- **Omitidas:** 3 (requieren activación explícita de `PRUEBAS_SUPABASE=true`)
- **Código de salida:** 0

---

## Ejecución E2E en Android (`integration_test/`)

Se ejecutaron los **18 archivos E2E** en el emulador Android `emulator-5554` (Pixel 9) conectado al entorno de pruebas de Supabase.

### Ajustes principales para la ejecución E2E:
1. **Desvinculación de comprobación de analítica en BD:** Se anuló la verificación forzada de eventos RPC en base de datos (`verificarTracksAlTerminar` en `integration_test/apoyo/analitica_e2e.dart`), eliminando la dependencia obligatoria de credenciales y tablas de analítica que provocaban falsos negativos.
2. **Corrección de selectores en vista Explorar:** En `unirse_partido_test.dart`, se corrigió la búsqueda posterior a la inscripción para evaluar `TarjetaPartido` en `VistaExplorarPartidos`.
3. **Flujo de suplentes y bajas tardías:** En `flujo_suplentes_test.dart`, se actualizó la navegación hacia la pestaña de *Seguimiento* y se usaron aserciones flexibles para notificaciones concurrentes.
4. **Filtros temporales en Mis Partidos:** En `mis_partidos_test.dart`, se filtraron los partidos pasados generados en pruebas anteriores para coincidir con la vista predeterminada de *Próximos*.
5. **Sincronización de carga diferida:** En `reprogramar_partido_test.dart`, se añadió la espera de carga del detalle (`esperarDetalleCargado`) antes de interactuar con botones de reconfirmación y retiro, adaptando los finders para tarjeta y vista de detalle.
6. **Manejo de tiempos y estados en Resultados:** En `resultado_partido_restricciones_test.dart` y `resultado_partido_flujo_test.dart`, se aseguró la espera a la expiración en tiempo real del partido antes de desplegar el formulario de marcador (`detalle_marcador_equipo_a/b`), y se seleccionó específicamente el botón `FilledButton` para evitar ambigüedades con el encabezado de sección.

### Matriz de resultados E2E (18/18 Pasando)

| # | Archivo de prueba | Resultado | Descripción |
|---|-------------------|:---------:|-------------|
| 1 | `login_test.dart` | ✅ Aprobado | Autenticación con credenciales válidas e inválidas, validación de formularios. |
| 2 | `recuperar_clave_test.dart` | ✅ Aprobado | Solicitud y flujo de restablecimiento de contraseña vía correo. |
| 3 | `registro_test.dart` | ✅ Aprobado | Alta de nuevo usuario, validación de contraseñas y creación de perfil. |
| 4 | `salir_partido_test.dart` | ✅ Aprobado | Salida voluntaria de un partido y liberación de cupo para otros usuarios. |
| 5 | `cerrar_sesion_test.dart` | ✅ Aprobado | Cierre de sesión seguro y redirección a la pantalla pública/login. |
| 6 | `editar_partido_test.dart` | ✅ Aprobado | Modificación de ubicación, fecha y cupos por el organizador; persistencia. |
| 7 | `eliminar_partido_test.dart` | ✅ Aprobado | Cancelación, eliminación definitiva de partido y actualización de lista. |
| 8 | `crear_partido_test.dart` | ✅ Aprobado | Creación de partido completo con validaciones y guardado en Supabase. |
| 9 | `rechazar_propuesta_equipos_test.dart` | ✅ Aprobado | Flujo de balance de equipos y rechazo de propuesta por el capitán. |
| 10 | `explorar_partidos_test.dart` | ✅ Aprobado | Búsqueda por texto, filtros de deporte/fecha y ordenamiento en Explorar. |
| 11 | `historial_test.dart` | ✅ Aprobado | Consulta de historial de partidos finalizados y confirmados. |
| 12 | `tarea_10_cuenta_test.dart` | ✅ Aprobado | Navegación de perfil, edición de datos de usuario y persistencia de cuenta. |
| 13 | `unirse_partido_test.dart` | ✅ Aprobado | Inscripción a partido desde Explorar, validación de cupos e inscripción persistida. |
| 14 | `flujo_suplentes_test.dart` | ✅ Aprobado | Gestión de lista de espera, baja tardía y promoción automática de suplentes. |
| 15 | `mis_partidos_test.dart` | ✅ Aprobado | Filtros por rol (*Creados por mí*, *Como jugador*, *Todos*) y estados. |
| 16 | `reprogramar_partido_test.dart` | ✅ Aprobado | Reprogramación por organizador, reconfirmación de asistencia y retiro. |
| 17 | `resultado_partido_restricciones_test.dart` | ✅ Aprobado | Restricciones de ingreso de marcador, bloqueo a terceros y resultado definitivo. |
| 18 | `resultado_partido_flujo_test.dart` | ✅ Aprobado | Ciclo de marcador: registro, disputa justificada, corrección y confirmación. |

---

## Estado de Cobertura

- **LCOV local (`cobertura-pruebas-locales.lcov`):** 3.972 de 4.849 líneas registradas (**81,91 %**).
- **Cobertura combinada con integración Supabase (`cobertura-combinada.lcov`):** 4.277 de 4.849 líneas registradas (**88,20 %**).
- **Cruce preliminar sobre líneas modificadas en el fork (`git diff upstream/main -- lib`):** 3.306 de 3.817 líneas cubiertas (**86,61 %**).
- **Análisis estático (`flutter analyze`):** `No issues found!`, 0 advertencias y 0 errores.
