# Base de datos compartida (Supabase)

UniSport guarda las cuentas, los partidos y las inscripciones en **Supabase**, una base de datos PostgreSQL en la nube. Todos los dispositivos usan la misma base: un partido creado en un teléfono aparece en el otro, y la unión de un jugador la ve el organizador desde su propio teléfono.

## 1. Configurar el proyecto (una sola vez)

1. Crear una cuenta gratuita en <https://supabase.com> y un proyecto nuevo (*New project*). Anotar la contraseña de la base que pide.
2. **Crear las tablas y reglas:** en el proyecto, *SQL Editor* → *New query* → pegar todo el archivo [`supabase/esquema.sql`](../supabase/esquema.sql) → *Run*. Debe terminar con "Success". Se puede volver a ejecutar sin perder datos.
3. **Permitir entrar sin confirmar el correo:** *Authentication* → *Sign In / Providers* → *Email* → desactivar **Confirm email** → *Save*. Los correos de prueba (`@unisport.edu`) no existen, así que no podrían confirmarse.
4. **Copiar los datos de conexión:** *Project Settings* → *API Keys* (o *Data API*):
   - **Project URL** (por ejemplo `https://abcd1234.supabase.co`)
   - **Publishable key** (o *anon public key*). **No** usar la *Secret key* / *service_role*.
5. Pegarlos en [`lib/config/configuracion_supabase.dart`](../lib/config/configuracion_supabase.dart), en los `defaultValue` de `url` y `clavePublica`.
6. Ejecutar la app (`flutter run`) y **registrar las cuentas de prueba** desde la pantalla de registro:
   - `diego@unisport.edu` / `123456`
   - `lorgio@unisport.edu` / `123456`

La clave pública puede estar en el código: lo que protege los datos son las reglas por fila (RLS) del esquema.

## 2. Cómo está organizado

```
Pantallas (lib/vistas)
   │  usan
   ▼
ServicioAutenticacion  ── sesión del estudiante (Supabase Auth)
   │  .partidos
   ▼
RepositorioPartidos    ── contrato de datos (lib/servicios/repositorio_partidos.dart)
   │  implementado por
   ▼
RepositorioSupabase    ── consultas y funciones del servidor
   │
   ▼
Supabase (PostgreSQL): perfiles · partidos · inscripciones
```

| Tabla | Qué guarda |
| :--- | :--- |
| `auth.users` | Cuentas (correo y contraseña **cifrada**), la maneja Supabase Auth |
| `perfiles` | Nombre, carrera y deporte de cada estudiante (se crea sola al registrarse) |
| `partidos` | Un partido por fila, con su organizador, fecha real, cupos y estado |
| `inscripciones` | Quién se unió a qué partido |

### Dónde se aplican las reglas

Las reglas del modelo (`lib/modelos/modelo_partido.dart`) deciden qué muestra la pantalla: el botón o el motivo del bloqueo. Al guardar, **el servidor vuelve a aplicarlas** en funciones SQL, con los mismos mensajes:

| Acción | Función del servidor | Regla |
| :--- | :--- | :--- |
| Unirme al equipo | `unirse_a_partido` | No ser parte del equipo, fecha futura, cupos abiertos; al último cupo pasa a "Equipo completo" |
| Editar partido | `editar_partido` | Equipo completo no cambia cupos; no menos cupos que inscritos |
| Reprogramar partido | `reprogramar_partido` | Solo el organizador; fecha futura y motivo; marca a los titulares como pendientes sin liberar plazas |
| Confirmar o retirarse | `responder_reprogramacion` | Cada titular responde una sola vez; al retirarse, asciende el primer suplente sin duplicar inscripciones |

Solo una inscripción ocupa un cupo. La función de unión bloquea la fila del partido (`select ... for update`) mientras trabaja: si dos teléfonos intentan tomar el último cupo al mismo tiempo, uno lo consigue y el otro recibe "Convocatoria cerrada: el equipo ya está completo.".

### Seguridad (RLS)

- Cualquier usuario con sesión puede **leer** partidos, perfiles e inscripciones.
- Solo el organizador puede **crear como suyo** y **eliminar** su partido.
- Nadie puede modificar partidos ni inscripciones directamente: los cambios se hacen a través de las funciones disponibles.

### Búsqueda y filtros (requisito #6)

`FiltroPartidos.condicionesConsulta()` traduce la búsqueda y los filtros a condiciones (`ilike`, `eq`, `gte`, `lt`) que `RepositorioSupabase.buscarPartidos()` envía a PostgreSQL. El filtro "con cupos" usa la columna calculada `hay_cupos` junto con el estado y la fecha, que es la misma regla de unión del #5.

## 3. Cómo comprobarlo con dos dispositivos

1. Teléfono A: entrar como Lorgio y crear un partido.
2. Teléfono B (o emulador / Chrome): entrar como Diego → **Explorar partidos**. El partido de Lorgio aparece y se puede buscar y filtrar.
3. Diego pulsa **Unirme al equipo**.
4. Teléfono A: en *Mis partidos* (recargar) aparece "Se unieron (1): Diego" y los cupos actualizados.
5. En Supabase, *Table Editor* → `partidos` / `inscripciones` muestra las filas guardadas.

## 4. Pruebas

```bash
flutter test                                   # todas (sin internet)
flutter test test/supabase_integracion_test.dart --dart-define=PRUEBAS_SUPABASE=true
```

La segunda ejecuta una prueba contra la base **real**: crea dos estudiantes en dos clientes distintos (como dos teléfonos), uno publica un partido y el otro lo busca, se une y comprueba los rechazos del servidor y la seguridad RLS. Crea cuentas `prueba-...@unisport.edu` en cada ejecución, que se pueden borrar desde *Authentication* → *Users*.

### Activar y comprobar la reprogramación

Si el proyecto Supabase ya existía, vuelve a ejecutar el archivo completo [`supabase/esquema.sql`](../supabase/esquema.sql) desde el SQL Editor antes de usar la app actualizada. El script agrega columnas sin borrar partidos ni inscripciones existentes.

Para probarlo con tres cuentas, crea un partido futuro de dos cupos como organizador, une a un titular y anota a la tercera cuenta como suplente. Como organizador, usa **Reprogramar partido** y escribe un motivo. El titular verá la fecha nueva y **Confirmar mi plaza** o **No puedo asistir: retirarme**. Si se retira, el suplente pasa a titular y debe reconfirmar. El organizador verá cuántas respuestas faltan.

Las demás pruebas usan un repositorio en memoria (`test/apoyo/`) con el mismo contrato, para correr sin internet.
