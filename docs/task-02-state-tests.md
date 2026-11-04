# Estado de partido y pruebas

Un partido empieza en `Cupos abiertos` y cambia a `Equipo completo` cuando una inscripción ocupa el último cupo. La inscripción queda vinculada al estudiante y es visible para el organizador; no hay acciones para sumar cupos sin una inscripción o cerrar manualmente la convocatoria.

La regla de unión está en [`lib/modelos/modelo_partido.dart`](../lib/modelos/modelo_partido.dart) y se persiste mediante `unirse_a_partido` en Supabase. El estado completo bloquea nuevas inscripciones y no permite cambiar la cantidad de cupos.

Las pruebas en [`test/estado_partido_test.dart`](../test/estado_partido_test.dart) cubren la transición por la última inscripción, el rechazo de una inscripción posterior, la persistencia y la compatibilidad de datos sin estado. Las pruebas de flujo de dos estudiantes están en [`test/flujo_partidos_test.dart`](../test/flujo_partidos_test.dart).
