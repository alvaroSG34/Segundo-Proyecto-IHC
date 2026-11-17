# Reporte Lighthouse — UniSport

**Actualizado:** 16 de noviembre de 2026  
**Base de código:** commit `974be42` más los cambios de optimización descritos abajo.

## Resumen ejecutivo

Se comparó la compilación JavaScript anterior con la versión optimizada compilada en modo release con WebAssembly (Wasm). Se hicieron **cinco ejecuciones** por perfil en la compilación final. El LCP mediano bajó de **50.238 s a 28.979 s en móvil** y de **8.655 s a 5.734 s en escritorio**. El puntaje mediano de rendimiento subió de **25 a 28 en móvil** y de **39 a 47 en escritorio**.

La versión final transfiere aproximadamente **38 % menos bytes** que la compilación de línea base y el TBT mediano bajó **57 % en móvil** y **36 % en escritorio**. La primera pintura móvil sigue variando mucho y el LCP aún es alto; el rendimiento necesita otra ronda de trabajo.

La campaña más reciente se midió con Wrangler, emulando Cloudflare Pages y aplicando Brotli y los encabezados de aislamiento. En tres corridas por perfil, Lighthouse dio una mediana de **38 en móvil** y **63 en escritorio**, con LCP de **19.757 s** y **3.611 s**. La transferencia cayó a **3,287 KiB**. La mejora se midió localmente; todavía no se ha publicado un despliegue nuevo.

### Puntuaciones por categoría

| Categoría | Base móvil | Wasm previo móvil | Pages preview móvil | Base escritorio | Wasm previo escritorio | Pages preview escritorio |
|---|---:|---:|---:|---:|---:|---:|
| Rendimiento | 25 (25–25) | 28 (27–35) | **38 (37–38)** | 39 (39–41) | 47 (45–48) | **63 (62–65)** |
| Accesibilidad | 100 | 100 | 100 | 100 | 100 | 100 |
| Buenas prácticas | 81 | 81 | 81 | 81 | 81 | 81 |
| SEO | 100 | 100 | 100 | 100 | 100 | 100 |

La línea base se midió tres veces por perfil; Wasm previo, cinco veces; Pages preview, tres veces. Entre paréntesis se muestra el rango observado. En las seis corridas de la campaña Pages, Agentic Browsing había marcado 100; la corrida móvil individual detallada al final de este documento marcó 50 y señaló dos problemas adicionales.

## Métricas de la campaña Wasm previa

Los valores son medianas de cinco ejecuciones. Los rangos muestran la variación entre ejecuciones. Los tiempos de esta tabla están en segundos, salvo TBT, que está en milisegundos.

| Métrica | Móvil | Escritorio |
|---|---:|---:|
| First Contentful Paint (FCP) | 19.477 s (1.148–21.260) | 0.164 s (0.163–0.165) |
| Largest Contentful Paint (LCP) | 28.979 s (28.591–29.209) | 5.734 s (5.539–6.244) |
| Speed Index | 19.477 s (12.964–21.260) | 3.546 s (3.444–5.722) |
| Total Blocking Time (TBT) | 2,021 ms (1,873–3,621) | 479 ms (456–490) |
| Cumulative Layout Shift (CLS) | 0.00 (0.00–0.00) | 0.00 (0.00–0.00) |
| Transferencia total | 5,783 KiB | 5,783 KiB |

La variación de FCP móvil es considerable: en tres ejecuciones apareció alrededor de 19–21 s y en dos apareció cerca de 1.1 s. El LCP fue más estable, alrededor de 29 s. Se conserva la mediana y el rango para no ocultar esa variabilidad.

### Iteración más reciente: módulos diferidos

Tres ejecuciones por perfil sobre el build Wasm con carga diferida. Las puntuaciones de accesibilidad, buenas prácticas y SEO se mantuvieron en 100, 81 y 100 en las seis corridas. Los tiempos están en segundos, salvo TBT en milisegundos.

| Métrica | Móvil | Escritorio |
|---|---:|---:|
| Rendimiento | **35 (28–36)** | **48 (48–50)** |
| FCP | 1.300 (1.298–20.206) | 0.164 (0.163–0.164) |
| LCP | 27.576 (27.546–27.923) | 5.437 (5.374–5.477) |
| Speed Index | 12.801 (12.620–20.206) | 3.445 (3.401–4.573) |
| TBT | 3,374 (1,769–3,501) | 431 (409–467) |
| CLS | 0.00 (0.00–0.00) | 0.00 (0.00–0.00) |
| Transferencia total | 5,408 KiB | 5,408 KiB |

La carga diferida mejora la mediana reciente de LCP en torno a **5 %** frente a la campaña Wasm anterior y reduce la transferencia aproximadamente **6 %**. El TBT móvil varía y su mediana reciente es mayor; las campañas usaron versiones distintas de Flutter y Chrome, así que no se atribuye toda la diferencia al código. El FCP móvil mantiene una dispersión alta.

| Perfil | Corrida | Rendimiento | FCP (s) | LCP (s) | Speed Index (s) | TBT (ms) | CLS |
|---|---:|---:|---:|---:|---:|---:|---:|
| Móvil | 1 | 36 | 1.300 | 27.546 | 12.801 | 3,374 | 0.00 |
| Móvil | 2 | 28 | 20.206 | 27.923 | 20.206 | 1,769 | 0.00 |
| Móvil | 3 | 35 | 1.298 | 27.576 | 12.620 | 3,501 | 0.00 |
| Escritorio | 1 | 48 | 0.164 | 5.374 | 3.401 | 467 | 0.00 |
| Escritorio | 2 | 50 | 0.163 | 5.437 | 3.445 | 409 | 0.00 |
| Escritorio | 3 | 48 | 0.164 | 5.477 | 4.573 | 431 | 0.00 |

### Entrega final en Cloudflare Pages (preview local)

Se sirvió el build release desde Wrangler Pages Dev. Cloudflare aplicó Brotli y `web/_headers` añadió COOP/COEP. Lighthouse completó tres corridas por perfil; las categorías accesibilidad, buenas prácticas y SEO puntuaron 100, 81 y 100 en las seis corridas.

| Métrica | Móvil | Escritorio |
|---|---:|---:|
| Rendimiento | **38 (37–38)** | **63 (62–65)** |
| FCP | 0.632 (0.630–0.635) | 0.181 (0.181–0.184) |
| LCP | 19.757 (16.790–20.119) | 3.611 (3.610–3.623) |
| Speed Index | 8.401 (8.360–11.981) | 2.917 (2.557–3.795) |
| TBT | 2,517 (2,485–2,580) | 261 (249–262) |
| CLS | 0.00 (0.00–0.00) | 0.00 (0.00–0.00) |
| Transferencia total | 3,287 KiB | 3,287 KiB |

| Perfil | Corrida | Rendimiento | FCP (s) | LCP (s) | Speed Index (s) | TBT (ms) | CLS |
|---|---:|---:|---:|---:|---:|---:|---:|
| Móvil | 1 | 38 | 0.632 | 20.119 | 8.360 | 2,485 | 0.00 |
| Móvil | 2 | 37 | 0.630 | 16.790 | 11.981 | 2,517 | 0.00 |
| Móvil | 3 | 38 | 0.635 | 19.757 | 8.401 | 2,580 | 0.00 |
| Escritorio | 1 | 63 | 0.181 | 3.610 | 2.917 | 262 | 0.00 |
| Escritorio | 2 | 62 | 0.181 | 3.623 | 3.795 | 261 | 0.00 |
| Escritorio | 3 | 65 | 0.184 | 3.611 | 2.557 | 249 | 0.00 |

Respecto al build diferido servido por Python sin compresión, el total transferido bajó de **5,408 a 3,287 KiB (39 %)**. El LCP mediano simulado bajó **28 % en móvil** y **34 % en escritorio**; el TBT bajó **25 % y 39 %**, respectivamente. `main.dart.wasm` pasó de unos **3,383 KiB** a **1,304 KiB** transferidos. Es una validación local del mismo modo de entrega que se desplegará; después del próximo despliegue se debe volver a medir la URL pública.

### Diagnóstico del LCP móvil

Se inspeccionó el build actual en Chrome 157 con viewport de 393 × 852 px, sin modificar el código. En la corrida Lighthouse móvil simulada el resultado fue rendimiento 35, FCP 1.297 s, LCP 27.673 s y TBT 3,677 ms. En la corrida diagnóstica conservada, sin throttling, Lighthouse dio rendimiento 74, FCP 4.083 s, LCP 4.251 s y TBT 136 ms. Esa corrida contrasta el efecto del perfil simulado; no es directamente comparable ni sustituye las mediciones móviles estándar.

Chrome no produjo entradas nativas `largest-contentful-paint` en una observación instalada antes de cargar la página. La inspección del árbol DOM encontró la vista Flutter bajo `flutter-view > flt-glass-pane > flt-scene-host > flt-scene > flt-canvas-container > canvas`; la bienvenida, incluido el hero, se dibuja dentro de ese canvas. Por eso no hay un nodo DOM al que asignar el LCP de 27.673 s, y no es correcto afirmar que el hero sea el elemento LCP. La medición simulada reporta un LCP, pero el navegador no expone un candidato que permita identificar un widget concreto.

La traza sí señala el trabajo de ejecución como área de costo: cerca de 8.1 s de trabajo de hilo principal, de los que 6.64 s fueron evaluación de scripts. Lighthouse atribuyó aproximadamente 4.21 s de CPU a `main.dart.mjs` y 2.26 s a `skwasm.js`; también encontró 17 tareas largas, incluida una de 945 ms alrededor de los 26.8 s de la línea de tiempo simulada. Estos datos identifican el arranque de Flutter/Wasm como foco de investigación, pero no asignan la demora a un widget específico.

### Línea base: resultados individuales

La tabla conserva las tres mediciones JavaScript anteriores para que la comparación antes/después se pueda revisar sin archivos JSON.

| Perfil | Corrida | Rendimiento | FCP (s) | LCP (s) | Speed Index (s) | TBT (ms) | CLS |
|---|---:|---:|---:|---:|---:|---:|---:|
| Móvil | 1 | 25 | 20.837 | 48.258 | 20.837 | 4,974 | 0.00 |
| Móvil | 2 | 25 | 20.828 | 50.422 | 20.828 | 4,738 | 0.00 |
| Móvil | 3 | 25 | 20.881 | 50.238 | 20.881 | 4,672 | 0.00 |
| Escritorio | 1 | 39 | 0.167 | 8.879 | 4.258 | 744 | 0.00 |
| Escritorio | 2 | 39 | 0.169 | 8.193 | 4.917 | 794 | 0.00 |
| Escritorio | 3 | 41 | 0.169 | 8.655 | 4.096 | 660 | 0.00 |

### Detalle de las cinco ejecuciones finales

#### Móvil

| Corrida | Rendimiento | FCP (s) | LCP (s) | Speed Index (s) | TBT (ms) | CLS |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 28 | 19.505 | 29.209 | 19.505 | 1,873 | 0.00 |
| 2 | 27 | 19.477 | 29.037 | 19.477 | 2,010 | 0.00 |
| 3 | 35 | 1.163 | 28.591 | 13.095 | 3,621 | 0.00 |
| 4 | 35 | 1.148 | 28.884 | 12.964 | 3,505 | 0.00 |
| 5 | 27 | 21.260 | 28.979 | 21.260 | 2,021 | 0.00 |

#### Escritorio

| Corrida | Rendimiento | FCP (s) | LCP (s) | Speed Index (s) | TBT (ms) | CLS |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 45 | 0.163 | 5.859 | 5.722 | 490 | 0.00 |
| 2 | 46 | 0.164 | 5.734 | 5.153 | 479 | 0.00 |
| 3 | 47 | 0.165 | 5.618 | 3.546 | 482 | 0.00 |
| 4 | 48 | 0.164 | 5.539 | 3.475 | 456 | 0.00 |
| 5 | 47 | 0.164 | 6.244 | 3.444 | 467 | 0.00 |

## Cambios aplicados

1. **Arranque asíncrono de la interfaz.** `main()` ahora monta una pantalla de carga antes de inicializar Supabase. Cuando Supabase está listo, la app continúa y restaura el perfil sin bloquear ese primer frame.
2. **Reducción de fuentes de iconos.** Se reemplazó la dependencia completa `lucide_icons_flutter` por los 59 iconos Lucide usados por la app y un asset local. La compilación reduce la fuente de 907 KiB a unos 22 KiB y elimina las seis fuentes variables de 454–514 KiB que se solicitaban en la versión anterior. La licencia MIT está en `third_party/lucide_icons_flutter/LICENSE`.
3. **Metadatos de la página.** `web/index.html` ahora tiene título y descripción específicos de UniSport.
4. **Compilación Wasm.** La compilación final se creó con `--wasm`. Lighthouse en Chrome 159 cargó `main.dart.wasm` y `skwasm.wasm`. La salida también contiene la variante JavaScript de respaldo.
5. **Portada durante el arranque.** La bienvenida se muestra mientras Supabase prepara la sesión, en vez de dejar la vista inicial vacía.
6. **Carga diferida.** La pantalla privada principal se separó del módulo inicial; inicio de sesión y registro se cargan cuando se solicitan. La compilación Flutter 3.50 generó módulos Wasm adicionales de aproximadamente 608 KiB, 66 KiB y 8 KiB. La transferencia bajó de 5,783 KiB a 5,408 KiB y el LCP mediano móvil, de 28.979 s a 27.576 s.
7. **Entrega de Wasm en Cloudflare Pages.** El workflow de despliegue ahora compila con `--wasm --enable-wasm-deferred-loading`. Flutter copia `web/_headers` al build y Cloudflare Pages entrega `main.dart.wasm` con Brotli y tipo MIME `application/wasm`.
8. **Aislamiento y rastreo.** `web/_headers` activa COOP/COEP para que el renderer Wasm pueda usar varios hilos. `web/robots.txt` evita que la regla SPA convierta la respuesta del rastreador en HTML inválido. Se añadieron `preconnect` a los orígenes de Flutter y Google Fonts.

La transferencia total bajó de **9,347 KiB a 5,783 KiB** (aproximadamente **38 %**). El LCP mediano mejoró **42 % en móvil** y **34 % en escritorio** respecto a la línea base.

## Hallazgos pendientes

- **Rendimiento móvil:** en el preview de Cloudflare la mediana de LCP bajó a 19.757 s y el TBT a 2,517 ms, pero el LCP sigue alto. Al ser una interfaz Flutter dibujada en canvas, Lighthouse no expone un nodo LCP nativo. Conviene contrastar la pintura y la respuesta en un móvil real, además del laboratorio simulado.
- **API obsoleta:** Lighthouse aún detecta `Intl.v8BreakIterator` en el bundle generado. El aviso puede originarse en Flutter o en una dependencia; localizarlo en la fuente antes de cambiar paquetes.
- **Source maps:** no hay source maps válidos para el JavaScript de respaldo. Pueden facilitar depuración si se publican en un entorno controlado.
- **Hosting:** el preview local confirma Brotli, MIME Wasm y COOP/COEP en Wrangler. Falta repetir Lighthouse sobre el dominio público tras desplegar este cambio.
- **Accesibilidad manual:** las auditorías automáticas dan 100/100, pero no se verificó con lector de pantalla ni se completó una revisión formal de teclado.

## Cobertura de pantallas

Lighthouse evaluó la ruta inicial `/` en perfiles móvil y escritorio. Se navegó manualmente por bienvenida, inicio de sesión, registro y recuperación de contraseña tras los cambios. Esas vistas se alcanzan mediante navegación interna de Flutter y no tienen URL independiente; por eso no se les asigna una puntuación Lighthouse separada. No se recorrieron las vistas que requieren autenticación.

## Método y entorno

- **Fecha:** 16 de noviembre de 2026.
- **Herramientas:** línea base y Wasm previo: Flutter 3.47.7 / Dart 3.13.5 y Chromium 159; campañas recientes: Flutter 3.50.0 / Dart 3.14.0, Lighthouse 13.6.0, Chrome 157 y Wrangler 4.163.0.
- **Perfiles:** móvil simulado por Lighthouse y preset de escritorio.
- **Repeticiones:** tres por perfil para la línea base JavaScript, la iteración diferida y el preview final de Cloudflare Pages; cinco por perfil para la compilación Wasm previa.
- **Servidor:** `http://127.0.0.1:8765/`, servidor HTTP local de Python sobre `build/web`.
- **Configuración:** se usó la clave publishable local desde `.env` para compilar. No se incluyó en este reporte ni en las evidencias.
- **Variantes:** línea base JavaScript compilada desde el commit `974be42`; versión final release con los cambios de esta revisión y `--wasm`.
- **Servidor final de benchmark:** Wrangler Pages Dev sirvió `build/web`, aplicó el archivo `_headers` y negociación Brotli. El workflow del repositorio publica ese mismo directorio en Cloudflare Pages.

Flutter documenta los encabezados necesarios para el renderer multihilo y la compresión del Wasm; Cloudflare Pages admite reglas en `_headers` y entrega Gzip/Brotli cuando corresponde: [Flutter WebAssembly](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter Web en producción](https://docs.flutter.dev/deployment/web), [encabezados de Cloudflare Pages](https://developers.cloudflare.com/pages/configuration/headers/), [contenido y compresión de Cloudflare Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/).

## Detalle de la corrida móvil final

Este apartado incorpora los resultados del informe Lighthouse móvil que se generó para el preview local de Cloudflare Pages. El HTML se elimina del repositorio; estos datos quedan como evidencia legible y versionable aquí.

### Entorno de la corrida

| Parámetro | Valor |
|---|---|
| URL evaluada | `http://127.0.0.1:8788/` (Wrangler Pages Dev) |
| Fecha de la corrida | 17 de noviembre de 2026, 02:45 UTC (16 de noviembre, 22:45 en Bolivia) |
| Lighthouse / Chrome | 13.6.0 / 157 |
| Dispositivo simulado | Moto G Power (2022), Android 11 |
| Viewport | 412 × 823 px, escala 1.75 |
| Perfil de red | RTT 150 ms, descarga 1,638 Kbit/s, subida 675 Kbit/s |
| CPU | ralentización ×4; throttling simulado |

### Categorías y métricas de esta corrida

| Categoría / métrica | Resultado |
|---|---:|
| Rendimiento | **38/100** |
| Accesibilidad | **100/100** |
| Buenas prácticas | **81/100** |
| SEO | **100/100** |
| Agentic Browsing (categoría adicional) | **50/100** |
| First Contentful Paint (FCP) | 0.635 s |
| Largest Contentful Paint (LCP) | 19.757 s |
| Speed Index | 8.401 s |
| Total Blocking Time (TBT) | 2,580 ms |
| Cumulative Layout Shift (CLS) | 0.00 |
| Time to Interactive (TTI) | 19.757 s |
| Max Potential First Input Delay | 438 ms |

La respuesta inicial del documento fue de 17 ms. El LCP y el TTI elevados, pese a esa respuesta rápida, apuntan al trabajo que ocurre en el navegador tras recibir el documento.

### Carga y trabajo del hilo principal

Lighthouse registró 20 recursos con una transferencia total de **3,365,582 bytes** (aprox. 3,287 KiB). La categoría de recursos de terceros sumó cerca de **1,989,668 bytes**. Los dos recursos Wasm más grandes fueron `main.dart.wasm` (1,335,603 bytes) y `skwasm.wasm` (1,233,728 bytes). El resumen de recursos clasificó 29,891 bytes como scripts y 1,358 bytes como documento HTML.

| Diagnóstico | Resultado |
|---|---:|
| Trabajo total del hilo principal | 5.857 s |
| Evaluación de scripts | 4.403 s |
| Tiempo atribuido a `main.dart.mjs` | 4.788 s, de los que 4.264 s fueron evaluación |
| Otras tareas del hilo principal | 1.303 s |
| Estilo y layout | 84 ms |
| Tareas largas | 17; la mayor duró 438 ms |

Las auditorías de rendimiento señalaron LCP, TBT, Speed Index, ejecución de JavaScript y trabajo del hilo principal. La oportunidad estimada de minificar JavaScript fue pequeña: unos 2.5 KiB. No encontraron JavaScript sin usar, CSS sin usar ni solicitudes que bloquearan el renderizado.

### Resultado de auditorías

- **Accesibilidad:** las comprobaciones automatizadas incluidas aprobaron: nombres accesibles de controles, uso válido de ARIA, título del documento, idioma, viewport y landmark principal, entre otras. Lighthouse deja diez revisiones como manuales; no las considera verificadas por el puntaje automático. Incluyen navegación por teclado, orden de foco, visibilidad para tecnologías de asistencia, etiquetas y roles de controles personalizados.
- **Buenas prácticas:** no se detectaron errores de consola y HTTPS pasó. Hubo una advertencia por `Intl.v8BreakIterator` deprecado en `main.dart.mjs` y Lighthouse no encontró un source map válido para `main.dart.wasm`.
- **SEO:** todas las comprobaciones automáticas pasaron, incluyendo indexabilidad, título, meta description, HTTP 200, enlaces rastreables y `robots.txt`. La validación de datos estructurados queda como revisión manual.
- **Agentic Browsing:** el árbol de accesibilidad y CLS pasaron. `llms.txt` no tenía encabezado H1 ni enlaces; la ruta del manifiesto ARD devolvió HTML en vez de JSON válido. Estos dos hallazgos explican el 50/100 de esta corrida; son distintos de las categorías SEO principales.

## Reproducibilidad

La campaña se midió en build release Wasm con carga diferida, servido por Wrangler Pages Dev para aplicar los encabezados de `web/_headers` y la compresión Brotli. El procedimiento, versiones y repetición por perfil se describen en [Método y entorno](#método-y-entorno). Los valores individuales y medianas relevantes están transcritos en las tablas de este Markdown; no se conserva un archivo HTML ni JSON aparte.

## Conclusión y siguiente trabajo

La compresión Brotli en Pages es la mejora más medible hasta ahora: redujo la transferencia alrededor de 39 % y mejoró el LCP en ambos perfiles. El score móvil subió de 35 a 38; falta validar el despliegue público y revisar la experiencia en un dispositivo real, porque el LCP simulado sigue alto y no identifica un nodo DOM. Mantener accesibilidad en 100, CLS en cero y SEO en 100.
