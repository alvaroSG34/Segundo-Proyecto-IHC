# Reporte Lighthouse — UniSport

**Actualizado:** 17 de noviembre de 2026

**Línea base:** compilación JavaScript del commit 974be42

**Última producción medida:** compilación Wasm con Inter local, commit 1f14c85; anterior a la precarga y caché de la fuente

## Resumen ejecutivo

La aplicación pasó de una compilación JavaScript inicial a una entrega optimizada con Wasm, carga diferida y fuentes locales. En el resumen consolidado, el rendimiento promedio pasó de **32/100** en la línea base a **59/100** en la última producción medida. El LCP general bajó de **29.447 s a 9.046 s**, el TBT de **2,741 ms a 559 ms** y la transferencia de **9,347 KiB a 2,607 KiB**.

La primera versión Wasm ya redujo la transferencia a **5,783 KiB** y el LCP general a **17.357 s**. Las iteraciones de entrega y tipografía bajaron todavía más los bytes. El LCP consolidado sigue alto y el render de Flutter en canvas impide identificar directamente un elemento DOM responsable.

Las cifras consolidadas resumen varias configuraciones de laboratorio con el mismo peso. Son útiles para ver la evolución general, pero el puntaje promediado no es un puntaje oficial que Lighthouse calcule para una sola ejecución.

## Antes y después de las mejoras

| Métrica general | Antes: JavaScript | Primera mejora: Wasm | Después: producción medida (1f14c85) |
|---|---:|---:|---:|
| Rendimiento consolidado | 32/100 | 37.5/100 | 59/100 |
| First Contentful Paint (FCP) | 10.503 s | 9.821 s | 0.735 s |
| Largest Contentful Paint (LCP) | 29.447 s | 17.357 s | 9.046 s |
| Speed Index | 12.548 s | 11.512 s | 7.310 s |
| Total Blocking Time (TBT) | 2,741 ms | 1,250 ms | 559 ms |
| Cumulative Layout Shift (CLS) | 0.00 | 0.00 | 0.00 |
| Transferencia total | 9,347 KiB | 5,783 KiB | 2,607 KiB |

Respecto a la línea base, la primera versión Wasm redujo la transferencia **38 %** y el LCP consolidado **41 %**. La última medición pública del commit 1f14c85 registra **72 % menos transferencia** y **69 % menos LCP** frente a la línea base. Esta comparación describe la evolución registrada; las campañas no usaron exactamente las mismas versiones de Flutter, Chrome ni servidor, por lo que no debe interpretarse como una comparación controlada de una sola variable.

## Comparación: primer reporte vs última medición local

| Métrica general | Primer reporte: línea base | Última medición local | Cambio |
|---|---:|---:|---:|
| Rendimiento consolidado | 32/100 | 61.5/100 | +29.5 puntos |
| First Contentful Paint (FCP) | 10.503 s | 0.425 s | −96 % |
| Largest Contentful Paint (LCP) | 29.447 s | 9.428 s | −68 % |
| Speed Index | 12.548 s | 5.532 s | −56 % |
| Total Blocking Time (TBT) | 2,741 ms | 446 ms | −84 % |
| Cumulative Layout Shift (CLS) | 0.00 | 0.00 | Sin cambio |
| Transferencia total | 9,347 KiB | 2,748 KiB | −71 % |

La última medición se hizo en un preview local con Flutter 3.47.7 y Dart 3.13.5, compilación release Wasm, Lighthouse 13.6.0, Chrome 157 y Wrangler 4.164.0. Se promediaron las medianas de tres corridas por configuración con el mismo peso. El SDK disponible no reconoce `--enable-wasm-deferred-loading`; por eso esta build no incluye la carga diferida del despliegue publicado y la comparación es orientativa, no una prueba controlada.

La mejora específica de la fuente también se verificó en la red: la captura anterior transfería Inter dos veces, **877 KiB** en total; el preview nuevo hizo tres solicitudes al mismo asset, pero sólo una transfirió datos, **469,658 bytes (459 KiB)**. Las otras dos usaron la caché. La transferencia de Inter bajó aproximadamente **418 KiB (48 %)**.

El reporte sigue mostrando por separado la última medición pública del commit 1f14c85 porque esa es la versión de producción para la que se guardaron métricas. La nueva medición local no se presenta como resultado de producción.

[Ver la comparación en formato HTML](comparacion_lighthouse.html).

## Evolución de las iteraciones

| Etapa | Rendimiento consolidado | FCP | LCP | Speed Index | TBT | Transferencia |
|---|---:|---:|---:|---:|---:|---:|
| Módulos Wasm diferidos | 41.5/100 | 0.732 s | 16.507 s | 8.123 s | 1,903 ms | 5,408 KiB |
| Preview local en Cloudflare Pages | 50.5/100 | 0.407 s | 11.684 s | 5.659 s | 1,389 ms | 3,287 KiB |
| Producción antes de Inter local | 59/100 | 0.731 s | 9.660 s | 28.038 s | 395 ms | No registrado |
| Preview local con Inter variable | 61/100 | 0.417 s | 9.307 s | 5.522 s | 544 ms | 2,652 KiB |
| Preview local con Inter precargada y caché (Flutter 3.47.7) | 61.5/100 | 0.425 s | 9.428 s | 5.532 s | 446 ms | 2,748 KiB |
| Producción medida con Inter local (1f14c85) | 59/100 | 0.735 s | 9.046 s | 7.310 s | 559 ms | 2,607 KiB |

Los valores son promedios consolidados de las medianas por configuración. En algunas campañas las versiones de herramientas y Flutter cambiaron; además, Lighthouse mostró variación en Speed Index. Por eso conviene considerar tendencias de varias métricas y ejecuciones, no una puntuación aislada.

### Categorías Lighthouse

| Categoría | Línea base | Primera versión Wasm | Producción medida (1f14c85) |
|---|---:|---:|---:|
| Accesibilidad | 100/100 | 100/100 | 100/100 |
| Buenas prácticas | 81/100 | 81/100 | 81/100 |
| SEO | 100/100 | 100/100 | 100/100 |

Estos son resultados automatizados. No reemplazan una revisión manual de accesibilidad con teclado y lector de pantalla.

## Método de consolidación

Para cada campaña se calculó primero la mediana de sus corridas en cada configuración de laboratorio; luego se promediaron esas medianas con el mismo peso. Las cifras se redondearon a tres decimales para tiempos en segundos, a milisegundos enteros para TBT y a KiB enteros para transferencia. La categoría de rendimiento también se promedió; por eso puede tener decimales y debe leerse como indicador resumido, no como un resultado directo de Lighthouse.

La línea base y la primera campaña Wasm se midieron tres y cinco veces, respectivamente. Las etapas posteriores se midieron tres veces por configuración. La medición pública del commit 1f14c85 se ejecutó el 17 de noviembre de 2026 con Lighthouse 13.6.0 y Chrome 157; se hicieron tres corridas por configuración sobre https://unisport-ihc.pages.dev/.

La línea base se compiló con Flutter 3.47.7 y Dart 3.13.5. Las campañas recientes usaron Flutter 3.50.0, Dart 3.14.0, Lighthouse 13.6.0, Chrome 157 y Wrangler Pages Dev. La compilación pública medida respondió HTTP 200, sirve Wasm con MIME application/wasm, negociación Brotli y encabezados COOP/COEP.

## Cambios aplicados

1. **Arranque de la interfaz:** la app monta una pantalla inicial antes de terminar de preparar Supabase y restaurar la sesión.
2. **Menos recursos de iconos:** se sustituyó la dependencia completa de Lucide por los 59 iconos utilizados y un asset local.
3. **Wasm y carga diferida:** la compilación release usa Wasm; las vistas privadas y de autenticación se solicitan cuando se necesitan.
4. **Entrega en Cloudflare Pages:** el workflow compila con carga diferida; Pages sirve Wasm comprimido con los encabezados de aislamiento requeridos.
5. **Tipografía local:** se eliminó Google Fonts y se usa una fuente variable Inter autoalojada también como respaldo de Roboto. Esto quitó las peticiones remotas de fuentes.
6. **Metadatos y rastreo:** el documento tiene título y descripción de UniSport, y se conserva la configuración necesaria para el renderer Flutter y los rastreadores.

## Diagnóstico y pendientes

- La transferencia y los tiempos generales mejoraron; la última medición pública consolidada, del commit 1f14c85, registró LCP de **9.046 s**.
- Flutter dibuja la interfaz dentro de un canvas. En la inspección del navegador no apareció un candidato LCP DOM que permita asignar el tiempo a un widget concreto.
- Las trazas identifican la descarga e inicialización de Wasm y la ejecución de main.dart.mjs como trabajo relevante. La evidencia disponible no atribuye toda la demora a una sola operación.
- La advertencia de Lighthouse sobre Intl.v8BreakIterator y la falta de un source map válido para la variante JavaScript de respaldo siguen pendientes de diagnóstico.
- Accesibilidad automática conserva 100/100; no se completó una revisión formal con tecnologías de asistencia ni de navegación por teclado.
- La ruta evaluada fue la portada /. Se navegaron bienvenida, inicio de sesión, registro y recuperación de contraseña, pero las vistas autenticadas no tuvieron una puntuación Lighthouse independiente.

## Reproducibilidad

Las campañas se sirvieron localmente con Wrangler Pages Dev cuando se necesitó validar encabezados y compresión. La producción se midió directamente en https://unisport-ihc.pages.dev/. Los resultados por etapa y la regla de consolidación están transcritos en este documento; los informes HTML y JSON individuales no se conservan en el repositorio.

Referencias técnicas: [Flutter WebAssembly](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter Web en producción](https://docs.flutter.dev/deployment/web), [encabezados de Cloudflare Pages](https://developers.cloudflare.com/pages/configuration/headers/) y [contenido y compresión de Cloudflare Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/).
