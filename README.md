# UniSport ⚽🏀🏐 - Proyecto 2 IHC

> **Materia:** Interacción Humano-Computador (Clase 12 / Proyecto 2)  
> **Modalidad P2:** Con IA  
> **Integrantes:**  
> - Diego Astete Paz  
> - Lorgio Leonardo Choque Severiche  
> **Tecnología:** Flutter (Dart) - Móvil

---

## 📌 Propósito del Producto
**UniSport** es una aplicación diseñada para resolver la fricción de coordinar encuentros deportivos en el campus universitario:
- **Crear partidos** definiendo disciplina (Futsal, Básquetbol, Vóley), cancha y horario.
- **Completar equipos** permitiendo que estudiantes se unan a convocatorias abiertas con cupos disponibles.

---

## 🚀 Guía de Ejecución

### 1. Requisitos Previos
* Flutter SDK (3.x o superior) instalado y configurado en el sistema (Windows, macOS o Linux).
* Emulador Android / iOS, dispositivo móvil conectado, o navegador Web (Chrome / Edge).

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Configurar la base de datos compartida (Supabase)
Los datos (cuentas, partidos e inscripciones) se guardan en **Supabase**, una base PostgreSQL en la nube compartida por todos los dispositivos. Una sola vez:

1. Crear un proyecto gratuito en <https://supabase.com>.
2. *SQL Editor* → pegar y ejecutar [`supabase/esquema.sql`](supabase/esquema.sql) (tablas, seguridad y reglas).
3. *Authentication* → *Sign In / Providers* → *Email* → desactivar **Confirm email**.
4. Copiar la **Project URL** y la **Publishable key** en [`lib/config/configuracion_supabase.dart`](lib/config/configuracion_supabase.dart).

Guía completa, arquitectura y cómo comprobarlo con dos teléfonos: [`docs/base-de-datos-supabase.md`](docs/base-de-datos-supabase.md).

### 4. Ejecutar la aplicación
Ejecutar el comando estándar (Flutter detectará automáticamente el dispositivo o emulador disponible):
```bash
flutter run
```

*Si se desea especificar una plataforma concreta:*
* **En Navegador Web:**
  ```bash
  flutter run -d chrome
  ```
* **En Emulador o Teléfono Móvil:**
  ```bash
  flutter run -d android
  ```
* **En Escritorio (Windows / macOS / Linux):**
  ```bash
  flutter run -d windows    # En Windows
  flutter run -d macos      # En macOS
  flutter run -d linux      # En Linux
  ```

### 5. Ejecutar pruebas automatizadas
```bash
flutter test
```

Solo las pruebas unitarias de la Tarea 2 (cambio de estado del partido):
```bash
flutter test test/estado_partido_test.dart
```
Detalle de la tarea y de las pruebas en [`docs/task-02-state-tests.md`](docs/task-02-state-tests.md).

Pruebas de la restricción de la Tarea 3 y de la edición:
```bash
flutter test test/restriccion_partido_test.dart
flutter test test/edicion_partido_test.dart
```
Detalle en [`docs/task-03-lifecycle-restriction.md`](docs/task-03-lifecycle-restriction.md).

Pruebas de "Unirse a un partido" (requisito #5) y "Buscar y filtrar partidos" (requisito #6):
```bash
flutter test test/union_partido_test.dart       # regla de unión (permitidos y rechazados)
flutter test test/flujo_partidos_test.dart      # dos estudiantes: crear, unirse, ver quién se unió
flutter test test/tarjeta_partido_test.dart     # botón y motivo del rechazo en pantalla
flutter test test/filtro_partidos_test.dart     # filtrado y consulta enviada a la base de datos
flutter test test/panel_filtros_test.dart       # filtros activos, quitar filtros y mensaje sin resultados
flutter test test/explorar_filtros_test.dart    # punta a punta con la pantalla Explorar
```

Prueba contra la **base de datos real de Supabase** (dos clientes, como dos teléfonos; requiere internet):
```bash
flutter test test/supabase_integracion_test.dart --dart-define=PRUEBAS_SUPABASE=true
```

### Prueba E2E: Crear partido → Mis partidos

Con Android iniciado y visible en `flutter devices`, ejecutar desde la raíz:

```powershell
flutter test integration_test/crear_partido_test.dart -d emulator-5554 --dart-define=E2E_CORREO=diego@unisport.edu --dart-define=E2E_CLAVE=123456
```

Reemplazar el identificador del dispositivo y las credenciales si corresponde.
La cuenta debe estar registrada previamente y Supabase debe estar configurado
con el esquema aplicado; esta prueba requiere internet. También se puede usar
`-d windows`. No necesita ejecutar `flutter run` antes.

La prueba abre la app real, inicia sesión (cierra cualquier sesión previa del
dispositivo), completa Crear partido con un título único, ubicación, mañana a
las 19:00 y los valores iniciales de Futsal y 10 cupos. Comprueba el mensaje de
guardado y que la tarjeta aparece en Mis partidos. Luego vuelve al menú y abre
la lista otra vez para verificar la persistencia en Supabase. Al terminar,
elimina solamente el partido de esa ejecución, incluso si falla la comprobación.

Referencia: [pruebas de integración de Flutter](https://docs.flutter.dev/testing/integration-tests).

---

## ⚡ Cuentas Semilla para Pruebas (Seeds)

Las cuentas viven en Supabase. Después de configurar el proyecto, regístrenlas **una vez** desde la pantalla de registro de la app:

| Estudiante | Correo | Contraseña | Carrera | Deporte |
| :--- | :--- | :--- | :--- | :--- |
| **Diego Astete** | `diego@unisport.edu` | `123456` | Ingeniería en Sistemas | Futsal |
| **Lorgio Choque** | `lorgio@unisport.edu` | `123456` | Ingeniería en Sistemas | Básquetbol |

*Cualquier estudiante puede crear su cuenta en el formulario de **Registro**; la cuenta sirve en todos los dispositivos.*

---

## 🛡️ Verificación de Requisitos (Tarea 1 - Acceso y Rutas Protegidas)

1. **Ruta Pública (Bienvenida):**  
   Al abrir la aplicación sin sesión, se muestra la portada de UniSport con su propuesta de valor, disciplinas y accesos para iniciar sesión o registrarse.

2. **Ruta Privada Protegida ("Mis Partidos"):**  
   - Si un usuario sin autenticación intenta abrir `"Mis Partidos"` (o pulsa el botón de prueba en la portada), el sistema **bloquea el acceso y lo redirige automáticamente al Login** con un mensaje de alerta.
   - Una vez autenticado, la pantalla muestra en la cabecera el **nombre del estudiante logueado**, su correo y su estado activo, junto con sus partidos programados y filtros por rol (Organizador / Jugador).

3. **Persistencia de Sesión:**  
   La sesión la maneja Supabase Auth y se conserva en el dispositivo. Si cierras la aplicación o la recargas, abre directamente en *"Mis Partidos"*.

4. **Recuperación de Contraseña:**  
   Supabase envía un enlace al correo para crear una nueva contraseña, con retroalimentación visual inmediata (Heurística de Visibilidad de Estado de Nielsen).

5. **Cierre de Sesión (Logout):**  
   Cierra la sesión en Supabase y regresa al estado público como invitado.

---

## ✅ Tarea 2 - Cambio de estado y pruebas unitarias

- **Nueva acción:** en *Mis partidos*, el organizador pulsa **Completar equipo** y el partido pasa de **Cupos abiertos** a **Equipo completo** (los cupos quedan completos).
- **Persistencia:** el cambio se guarda y se conserva al recargar la aplicación.
- **Pruebas unitarias:** 8 pruebas sobre la regla de cambio de estado, ejecutadas y aprobadas con `flutter test`.
- **Documentación:** [`docs/task-02-state-tests.md`](docs/task-02-state-tests.md)

---

## 📁 Estructura del Código (En Español)

```
lib/
├── main.dart                       # Entrada: conexión a Supabase y sesión
├── config/
│   └── configuracion_supabase.dart # URL y clave pública del proyecto Supabase
├── modelos/
│   ├── modelo_usuario.dart         # Perfil del estudiante
│   ├── modelo_partido.dart         # Partido, cupos y reglas de negocio
│   └── filtro_partidos.dart        # Búsqueda y filtros (requisito #6)
├── servicios/
│   ├── servicio_autenticacion.dart # Login, registro y sesión (Supabase Auth)
│   ├── repositorio_partidos.dart   # Contrato de datos de partidos
│   └── repositorio_supabase.dart   # Consultas y funciones de la base compartida
├── tema/
│   ├── tema_app.dart               # Tema claro: paleta verde/cian, tipografía y componentes
│   ├── iconos_deporte.dart         # Ícono y color de cada disciplina
│   └── caja_mensaje.dart           # Avisos de error / información / éxito
├── widgets/
│   ├── tarjeta_partido.dart        # Tarjeta de partido con sus acciones
│   ├── panel_filtros.dart          # Búsqueda, filtros activos y mensaje sin resultados
│   ├── campo_clave.dart            # Campo de contraseña con balones animados
│   ├── boton_accion.dart           # Botón con estados (normal / cargando / éxito)
│   └── animaciones.dart            # Entrada escalonada y sacudida de formulario
└── vistas/
    ├── vista_inicio_publico.dart   # Ruta Pública: Portada de UniSport
    ├── vista_login.dart            # Formulario de inicio de sesión con autollenado
    ├── vista_registro.dart         # Formulario de registro para nuevos estudiantes
    ├── vista_recuperar_clave.dart  # Recuperación de contraseña por correo
    ├── vista_mis_partidos.dart     # Ruta Privada: Mis Partidos (Protegida)
    ├── vista_explorar_partidos.dart# Explorar, buscar, filtrar y unirse
    └── vista_crear_partido.dart    # Formulario para crear y editar un partido

supabase/
└── esquema.sql                     # Tablas, seguridad (RLS) y reglas en el servidor

test/
├── apoyo/                          # Repositorio y sesión en memoria para las pruebas
├── supabase_integracion_test.dart  # Prueba contra la base real (dos dispositivos)
└── ...                             # Pruebas de reglas, filtros e interfaz
```
