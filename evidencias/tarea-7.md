# Tarea 7 · Mejoras a partir del feedback recibido

**Feedback recibido:** [Feedback de Alejandro de los Ríos](https://github.com/Alejandrodelosrios/app-p2-ihc/blob/main/clase-19-feedback-a-otro-proyecto/feedback.md)

El evaluador tuvo dificultades para orientarse desde la portada pública y observó que «Agregar jugador» aumentaba el contador sin añadir a nadie a la lista de jugadores.

## Cambios realizados

1. **Portada más clara.** Quitamos la barra inferior que podía llevar a opciones protegidas por inicio de sesión. La portada conserva «Iniciar sesión» y «Crear nueva cuenta».
   - **Evidencia:** [`test/navegacion_explorar_test.dart`](../test/navegacion_explorar_test.dart) comprueba que la portada no muestre la barra y mantenga ambos botones.
   - **Commit:** [`bf9ed5c`](https://github.com/alvaroSG34/Segundo-Proyecto-IHC/commit/bf9ed5c2e4941542ac9bee45dd23ff2dfea49d22) — `fix: quitar navbar de portada pública`.

2. **Contador coherente con las inscripciones.** Eliminamos «Agregar jugador»: los cupos ocupados aumentan únicamente cuando una persona se inscribe y aparece en la lista. La acción «Completar equipo» cierra la convocatoria sin inventar jugadores ni cambiar los cupos ocupados; la tarjeta lo aclara y muestra «Convocatoria cerrada» si aún quedan lugares.
   - **Evidencia:** [`test/estado_partido_test.dart`](../test/estado_partido_test.dart) comprueba que cerrar no modifica los cupos ni crea inscripciones; [`test/tarjeta_partido_test.dart`](../test/tarjeta_partido_test.dart) comprueba la acción y la etiqueta para cierres con lugares libres.
   - **Commit:** [`e873c6f`](https://github.com/alvaroSG34/Segundo-Proyecto-IHC/commit/e873c6f3ce2117342b22d783eb45b7b38bd5f416) — `fix: contar solo inscripciones y cerrar convocatorias`.

**Verificación:** `flutter analyze` y `flutter test` finalizaron correctamente. La prueba de integración con Supabase requiere activación y credenciales externas.
